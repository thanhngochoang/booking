/**
 * Paid event tickets (plan 10c Task 9, Decisions 9, 11, 12, 15, 28): the payment that turns a
 * 10-minute hold into a ticket, refunds (customer cancel ≥ 48 h, host cancel, late payment), the
 * hold sweep, and the escrow stamp at completion. Money uses the booking collections and rules:
 * `payments`, `refunds`, `ledger_entries`, refunds only from held money (invariant 12), and the
 * existing `bookingClock` step 5 releases ticket money once `releaseAfter` has passed.
 */

import { PAYMENT_PROVIDERS, type PaymentProvider } from './booking.js';
import { DISPUTE_WINDOW_HOURS } from './booking_policy.js';
import { DomainError } from './errors.js';
import { applyRefundToPayment, type LedgerEntry, type Payment, type Refund } from './escrow.js';
import {
  FREE_CANCEL_HOURS,
  registrationContactOf,
  statusAfterSeats,
  type EventCaller,
  type EventRecord,
  type RegistrationDoc,
  type RegistrationStatus,
} from './event.js';
import type { EventDeps, EventPaymentDeps, EventTx } from './event_ports.js';
import { cancelEvent } from './event_use_cases.js';
import { isId } from './ids.js';
import { isVnE164 } from './phone.js';

const HOUR_MS = 3_600_000;
const SWEEP_BATCH = 200;

export type TicketRefundReason = 'customer_cancel' | 'event_cancelled';

/** Spec §3g (O4): a paid ticket cancelled at least 48 h before the start gets 100% back, later nothing. */
export function ticketRefundPercent(startAt: Date, now: Date): 100 | 0 {
  return startAt.getTime() - now.getTime() >= FREE_CANCEL_HOURS * HOUR_MS ? 100 : 0;
}

/** One payment per registration and provider; a second tap with the same provider reuses it. */
export const ticketIdempotencyKey = (registrationId: string, provider: PaymentProvider): string =>
  `tkt_${registrationId}_${provider}`;

/** `undefined`/`null` → null; a known code → it; anything else is `invalid_argument`. */
export function parseTicketProvider(v: unknown): PaymentProvider | null {
  if (v === undefined || v === null) return null;
  if (typeof v !== 'string' || !(PAYMENT_PROVIDERS as readonly string[]).includes(v)) {
    throw new DomainError('invalid_argument');
  }
  return v as PaymentProvider;
}

/** The host photographer is paid; a platform-hosted event's money stays with the platform. */
export const ticketPayeeOf = (ev: Pick<EventRecord, 'host'>): string =>
  ev.host.type === 'photographer' && ev.host.id !== null ? ev.host.id : 'platform';

/** A fresh, unpaid ticket payment (`status created`, escrow `held` like a booking deposit intent). */
export function newTicketPayment(params: {
  readonly id: string;
  readonly event: Pick<EventRecord, 'id' | 'host'>;
  readonly registrationId: string;
  readonly payerId: string;
  readonly provider: PaymentProvider;
  readonly amount: number;
  readonly now: Date;
}): Payment {
  const at = params.now.toISOString();
  return {
    id: params.id,
    subjectType: 'event_registration',
    subjectId: params.registrationId,
    eventId: params.event.id,
    payerId: params.payerId,
    payeeId: ticketPayeeOf(params.event),
    provider: params.provider,
    amount: params.amount,
    status: 'created',
    escrowStatus: 'held',
    idempotencyKey: ticketIdempotencyKey(params.registrationId, params.provider),
    createdAt: at,
    updatedAt: at,
  };
}

/**
 * Asks the gateway for a pay URL, outside any transaction (a retried transaction must not create
 * two intents). The provider reference is saved while the payment is still unpaid.
 */
export async function issueTicketIntent(deps: EventPaymentDeps, payment: Payment): Promise<string> {
  const intent = await deps.gateway.createDepositIntent({
    paymentId: payment.id,
    bookingId: payment.subjectId, // the port's subject id (plan I6 renames it)
    amount: payment.amount,
    provider: payment.provider,
  });
  const ref = intent.providerRef;
  if (ref !== undefined && ref !== payment.providerRef) {
    await deps.events.runTransaction(async (tx) => {
      const cur = await tx.getPayment(payment.id);
      if (cur === null || cur.status !== 'created' || cur.providerRef === ref) return;
      tx.putPayment({ ...cur, providerRef: ref, updatedAt: deps.clock.now().toISOString() });
    });
  }
  return intent.payUrl;
}

/** Gateway refund after the money moved in the ledger; a failure is left to staff (`manual`), like bookings. */
async function dispatchTicketRefund(deps: EventPaymentDeps, refund: Refund, provider: PaymentProvider): Promise<Refund> {
  let result: { success: boolean; providerRef?: string };
  try {
    result = await deps.gateway.issueRefund({
      paymentId: refund.paymentId,
      refundId: refund.id,
      amount: refund.amount,
      provider,
      providerRef: refund.providerRef,
    });
  } catch {
    result = { success: false };
  }
  const updated: Refund = {
    ...refund,
    status: result.success ? 'done' : 'failed',
    manual: !result.success,
    providerRef: result.providerRef ?? refund.providerRef,
    updatedAt: deps.clock.now().toISOString(),
  };
  await deps.events.runTransaction(async (tx) => {
    tx.putRefund(updated);
  });
  return updated;
}

type PendingRefund = { refund: Refund; provider: PaymentProvider };

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

/** Seats of a hold go back (writes only). */
function releaseHoldWrites(tx: EventTx, ev: EventRecord | null, holds: readonly RegistrationDoc[], now: Date): void {
  let held = ev?.heldCount ?? 0;
  for (const s of holds) {
    tx.putRegistration({ ...s, status: 'cancelled', cancelledAt: now, updatedAt: now, version: s.version + 1 });
    held -= s.quantity;
  }
  if (ev !== null && holds.length > 0) {
    const next = { ...ev, heldCount: Math.max(0, held) };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
  }
}

/**
 * The gateway (or the fake confirmation) says a ticket payment was paid. While its registration is
 * still a live hold, the ticket becomes `paid` (held seats → registered, contact snapshot written,
 * O3); otherwise (hold expired, cancelled, another intent already paid, event cancelled) the money
 * is refunded 100% at once (`late_payment_hold_expired`, as bookings do). Idempotent: a repeated
 * confirmation changes nothing. `createdAt` stays the hold time (the group chat compares it with a
 * moderator removal, so a hold taken before a removal never re-admits the user).
 */
export async function handleTicketPayment(
  deps: EventPaymentDeps,
  params: { paymentId: string; providerRef?: string; paidAt?: Date },
): Promise<{ registration: RegistrationDoc | null; refunded: boolean }> {
  const box: { pending: PendingRefund | null } = { pending: null };
  const out = await deps.events.runTransaction(async (tx) => {
    box.pending = null;
    const now = params.paidAt ?? deps.clock.now();
    const p = await tx.getPayment(params.paymentId);
    if (p === null || p.subjectType !== 'event_registration' || p.eventId === undefined) {
      throw new DomainError('not_found');
    }
    const reg = await tx.getRegistration(p.eventId, p.subjectId);
    if (p.status === 'paid') return { registration: reg, refunded: false };
    if (p.status === 'refunded' || p.status === 'partially_refunded') return { registration: reg, refunded: true };
    if (p.status !== 'created') throw new DomainError('conflict');
    const ev = await tx.getEvent(p.eventId);
    const live = reg !== null && ev !== null && reg.status === 'held' && ev.status !== 'cancelled'
      && reg.holdExpiresAt !== null && reg.holdExpiresAt.getTime() > now.getTime();
    const contact = live ? await deps.contacts.get(p.payerId) : null;

    // ---- writes from here ----
    const at = now.toISOString();
    const paid: Payment = {
      ...p, status: 'paid', escrowStatus: 'held', providerRef: params.providerRef ?? p.providerRef,
      paidAt: at, updatedAt: at,
    };
    tx.putPayment(paid);
    const received: LedgerEntry = {
      id: deps.ids.newId(), type: 'ticket_received', paymentId: p.id, subjectType: 'event_registration',
      subjectId: p.subjectId, accountOwnerId: 'platform_escrow', amount: p.amount,
      note: `Ticket for event ${p.eventId}`, at,
    };
    tx.putLedgerEntry(received);

    if (!live || reg === null || ev === null) {
      const res = applyRefundToPayment({
        payment: paid, refundId: deps.ids.newId(), percent: 100, ledgerEntryId: deps.ids.newId(),
        reason: 'late_payment_hold_expired', now,
      });
      tx.putPayment(res.payment);
      tx.putRefund(res.refund);
      tx.putLedgerEntry(res.ledgerEntry);
      box.pending = { refund: res.refund, provider: p.provider };
      // A lapsed hold the sweep has not reached yet gives its seats back now.
      if (reg !== null && reg.status === 'held' && ev !== null) {
        releaseHoldWrites(tx, ev, [reg], now);
        return { registration: { ...reg, status: 'cancelled' as const, cancelledAt: now }, refunded: true };
      }
      return { registration: reg, refunded: true };
    }

    const ticket: RegistrationDoc = {
      ...reg, status: 'paid', paymentId: p.id, contactEligible: true,
      updatedAt: now, version: reg.version + 1,
    };
    tx.putRegistration(ticket);
    const phone = contact?.phone;
    if (isVnE164(phone)) tx.putRegistrationContact(ev.id, reg.id, registrationContactOf(reg.userName, phone, contact));
    const next = { ...ev, heldCount: Math.max(0, ev.heldCount - reg.quantity), registeredCount: ev.registeredCount + reg.quantity };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return { registration: ticket, refunded: false };
  });
  if (box.pending !== null) await dispatchTicketRefund(deps, box.pending.refund, box.pending.provider);
  return out;
}

async function readPayment(deps: EventDeps, id: string): Promise<Payment | null> {
  return deps.events.runTransaction((tx) => tx.getPayment(id));
}

/** Fake gateway mode (dev and emulator only, gated in the callable): the payer confirms their own payment. */
export async function confirmFakeTicketPayment(
  deps: EventPaymentDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ status: RegistrationStatus }> {
  const paymentId = idOf(obj(raw).paymentId);
  const p = await readPayment(deps, paymentId);
  if (p === null || p.subjectType !== 'event_registration') throw new DomainError('not_found');
  if (p.payerId !== caller.uid) throw new DomainError('permission_denied');
  const res = await handleTicketPayment(deps, { paymentId, providerRef: `fake_confirmed_${paymentId}` });
  return { status: res.registration?.status ?? 'cancelled' };
}

/** Back from the gateway (or "Thanh toán tiếp"): asks the gateway and applies a payment it reports. */
export async function checkTicketPayment(
  deps: EventPaymentDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ paid: boolean; status: RegistrationStatus }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const regId = idOf(r.registrationId);
  const reg = await deps.events.runTransaction((tx) => tx.getRegistration(eventId, regId));
  if (reg === null) throw new DomainError('not_found');
  if (reg.userId !== caller.uid) throw new DomainError('permission_denied');
  if (reg.status !== 'held' || reg.paymentId === null) return { paid: reg.status === 'paid', status: reg.status };
  const p = await readPayment(deps, reg.paymentId);
  if (p === null) return { paid: false, status: reg.status };
  const status = await deps.gateway.checkPaymentStatus({ paymentId: p.id, provider: p.provider, providerRef: p.providerRef });
  if (!status.paid) return { paid: false, status: reg.status };
  const res = await handleTicketPayment(deps, { paymentId: p.id, providerRef: status.providerRef });
  const now = res.registration?.status ?? 'cancelled';
  return { paid: now === 'paid', status: now };
}

/**
 * Refunds a ticket's held money (`percent` 100) in its own transaction; the gateway call happens
 * after it. Idempotent: an already refunded ticket, or money no longer held (invariant 12), is
 * `skipped` (and its `refundDue` flag cleared so the clock stops trying).
 */
export async function refundTicket(
  deps: EventPaymentDeps,
  eventId: string,
  regId: string,
  percent: 100,
  reason: TicketRefundReason,
): Promise<'refunded' | 'skipped'> {
  const box: { pending: PendingRefund | null } = { pending: null };
  const out = await deps.events.runTransaction(async (tx): Promise<'refunded' | 'skipped'> => {
    box.pending = null;
    const now = deps.clock.now();
    const reg = await tx.getRegistration(eventId, regId);
    if (reg === null || reg.status === 'refunded' || reg.paymentId === null || reg.amount <= 0) return 'skipped';
    const ev = await tx.getEvent(eventId);
    const p = await tx.getPayment(reg.paymentId);
    const held = p !== null && p.status === 'paid'
      && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded');
    // A customer refunds a live ticket; a host cancel also refunds late-cancelled tickets whose money is held.
    const eligible = reason === 'customer_cancel'
      ? reg.status === 'paid'
      : reg.status === 'paid' || (reg.status === 'cancelled' && reg.refundDue === true);
    if (!held || !eligible || p === null) {
      if (reg.refundDue === true) tx.putRegistration({ ...reg, refundDue: false, updatedAt: now, version: reg.version + 1 });
      return 'skipped';
    }
    const res = applyRefundToPayment({
      payment: p, refundId: deps.ids.newId(), percent, ledgerEntryId: deps.ids.newId(), reason, now,
    });
    tx.putPayment(res.payment);
    tx.putRefund(res.refund);
    tx.putLedgerEntry(res.ledgerEntry);
    tx.putRegistration({
      ...reg, status: 'refunded', refundPercent: percent, refundDue: false, cancelledAt: reg.cancelledAt ?? now,
      updatedAt: now, version: reg.version + 1,
    });
    tx.deleteRegistrationContact(eventId, regId);
    if (reg.status === 'paid' && ev !== null) {
      const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    }
    box.pending = { refund: res.refund, provider: p.provider };
    return 'refunded';
  });
  if (box.pending !== null) await dispatchTicketRefund(deps, box.pending.refund, box.pending.provider);
  return out;
}

/**
 * `cancelEvent` (Decision 12) then a 100% refund of every ticket whose money is held, each in its own
 * transaction. A refund that fails keeps `refundDue` and is retried by the event clock.
 */
export async function cancelEventWithRefunds(
  deps: EventPaymentDeps,
  caller: EventCaller,
  raw: unknown,
  onError: (registrationId: string, error: unknown) => void = () => undefined,
): Promise<{ paidRegistrationIds: string[]; refunded: number; failed: number }> {
  const { paidRegistrationIds } = await cancelEvent(deps, caller, raw);
  const eventId = idOf(obj(raw).eventId);
  let refunded = 0;
  let failed = 0;
  for (const id of paidRegistrationIds) {
    try {
      if ((await refundTicket(deps, eventId, id, 100, 'event_cancelled')) === 'refunded') refunded += 1;
    } catch (e) {
      failed += 1;
      onError(id, e);
    }
  }
  return { paidRegistrationIds, refunded, failed };
}

/** The 1-minute hold sweep: every expired hold gives its seats back (one transaction per event). */
export async function releaseEventHolds(
  deps: EventDeps,
  onError: (eventId: string, error: unknown) => void = () => undefined,
): Promise<number> {
  const due = await deps.events.expiredHoldsAll(deps.clock.now(), SWEEP_BATCH);
  let released = 0;
  for (const eventId of new Set(due.map((r) => r.eventId))) {
    try {
      released += await deps.events.runTransaction(async (tx) => {
        const now = deps.clock.now();
        const ev = await tx.getEvent(eventId);
        const stale = await tx.expiredHolds(eventId, now);
        releaseHoldWrites(tx, ev, stale, now);
        return stale.length;
      });
    } catch (e) {
      onError(eventId, e);
    }
  }
  return released;
}

/** Completion (writes only): each held ticket payment is released `DISPUTE_WINDOW_HOURS` after the end. */
export function stampTicketRelease(tx: EventTx, ev: EventRecord, payments: readonly Payment[], now: Date): number {
  if (ev.endAt === null) return 0;
  const releaseAfter = new Date(ev.endAt.getTime() + DISPUTE_WINDOW_HOURS * HOUR_MS).toISOString();
  let n = 0;
  for (const p of payments) {
    if (p.releaseAfter !== undefined) continue;
    tx.putPayment({ ...p, releaseAfter, updatedAt: now.toISOString() });
    n += 1;
  }
  return n;
}
