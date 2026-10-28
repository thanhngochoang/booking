/**
 * Paid event tickets: payment settlement via TicketPaymentSettler, refunds (customer cancel >= 48h,
 * host cancel, late payment), hold sweeps, and escrow release.
 */

import { DomainError } from './errors.js';
import {
  applyRefundToPayment,
  type LineKind,
  type Payment,
  type PaymentMethod,
  type Refund,
} from './escrow.js';
import {
  FREE_CANCEL_HOURS,
  isEventManager,
  statusAfterSeats,
  type EventCaller,
  type EventRecord,
  type RegistrationDoc,
  type RegistrationStatus,
} from './event.js';
import { formatVnDate, isDateString } from './booking_policy.js';
import { ENTRY_CLOSE_BATCH, emptyEntryDay, entryFieldsOf, isOpenDay } from './entry_tickets.js';
import { NO_ENTRY_DAYS, readEntryDays, releaseDeltas, visitDayOf, writeEntryDays, type EntryDays } from './entry_days.js';
import { notifyEntryDayClosed } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import type { EventDeps, EventPaymentDeps, EventTx } from './event_ports.js';
import { cancelEvent } from './event_use_cases.js';
import { isId } from './ids.js';
import { PLATFORM_PAYEE } from './payout.js';
import type { SubjectSettler } from './payment_ports.js';
import type { SettlementDeps } from './payment_settlement.js';
import {
  applyTransfer,
  expireUnpaid,
  transferRecordId,
  transferRecordOf,
} from './payment_settlement.js';
import type { BookingTicketLines, TransferNotification, TransferOutcome } from './booking_ports.js';
import { DISPUTE_WINDOW_HOURS } from './booking_policy.js';
import { mergeRefundOutcome, sendRefundOnce, transferRefund } from './refunds.js';
import { refundWithoutPayment, type RefundSubjectHandler } from './refund_subjects.js';
import { checkSubjectPayments } from './create_payment.js';
import { ticketPaidUpdate } from './ticket_paid.js';
import { freshPassCode, newPass, writePass } from './pass.js';
import { transferCodeFor } from './payment_code.js';
import { payerAccountOf } from './payer_account.js';

const HOUR_MS = 3_600_000;
const SWEEP_BATCH = 200;

/**
 * `day_closed` (S30): the organizer closed an entry ticket's visit day (`closeEntryDay`).
 * `provider_cancelled` (S30, spec §5.3): the booking a ticket was bought with was declined, expired or
 * cancelled by its provider.
 */
export type TicketRefundReason = 'customer_cancel' | 'event_cancelled' | 'day_closed' | 'provider_cancelled';

/** Spec §3g (O4): a paid ticket cancelled at least 48 h before the start gets 100% back, later nothing. */
export function ticketRefundPercent(startAt: Date, now: Date): 100 | 0 {
  return startAt.getTime() - now.getTime() >= FREE_CANCEL_HOURS * HOUR_MS ? 100 : 0;
}

/** One payment per registration and method; a second tap with the same method reuses it. */
export const ticketIdempotencyKey = (registrationId: string, method: PaymentMethod): string =>
  `tkt_${registrationId}_${method}`;

/**
 * The host photographer or organizer (S30 Decision 12) is paid; a platform-hosted event's money stays
 * with the platform.
 */
export const ticketPayeeOf = (ev: Pick<EventRecord, 'host'>): string =>
  (ev.host.type === 'photographer' || ev.host.type === 'organizer') && ev.host.id !== null ? ev.host.id : PLATFORM_PAYEE;

/**
 * A fresh, unpaid ticket payment. An organizer-hosted event's payment is stamped `payeeKind: organizer`
 * (no commission, no tax withheld); an entry ticket carries `lineKind: entry_ticket` and its release
 * instant from the start (`entryReleaseAt(visitDay)`, so completion's `stampTicketRelease` keeps it).
 */
export function newTicketPayment(params: {
  readonly id: string;
  readonly event: Pick<EventRecord, 'id' | 'host'>;
  readonly registrationId: string;
  readonly payerId: string;
  readonly method: PaymentMethod;
  readonly provider: Payment['provider'];
  readonly amount: number;
  readonly now: Date;
  readonly expiresAt: Date;
  readonly lineKind?: LineKind;
  readonly releaseAfter?: Date;
}): Payment {
  const at = params.now.toISOString();
  return {
    ...(params.event.host.type === 'organizer' ? { payeeKind: 'organizer' as const } : {}),
    ...(params.lineKind !== undefined ? { lineKind: params.lineKind } : {}),
    ...(params.releaseAfter !== undefined ? { releaseAfter: params.releaseAfter.toISOString() } : {}),
    id: params.id,
    subjectType: 'event_registration',
    subjectId: params.registrationId,
    eventId: params.event.id,
    payerId: params.payerId,
    payeeId: ticketPayeeOf(params.event),
    method: params.method,
    provider: params.provider,
    amount: params.amount,
    status: 'created',
    escrowStatus: 'held',
    idempotencyKey: ticketIdempotencyKey(params.registrationId, params.method),
    transferCode: transferCodeFor(params.id),
    expiresAt: params.expiresAt.toISOString(),
    receivedAmount: 0,
    createdAt: at,
    updatedAt: at,
  };
}

/**
 * Seats of a hold go back (writes only). An entry ticket's visit day gives back its `held` too; `days`
 * holds those rows, read before (`readEntryDays`).
 */
function releaseHoldWrites(
  tx: EventTx,
  ev: EventRecord | null,
  holds: readonly RegistrationDoc[],
  now: Date,
  days: EntryDays = NO_ENTRY_DAYS,
): void {
  let held = ev?.heldCount ?? 0;
  for (const s of holds) {
    tx.putRegistration({ ...s, status: 'cancelled', cancelledAt: now, updatedAt: now, version: s.version + 1 });
    held -= s.quantity;
  }
  if (ev !== null) writeEntryDays(tx, ev.id, days, releaseDeltas(ev, holds.filter((s) => s.status === 'held')), now);
  if (ev !== null && holds.length > 0) {
    const next = { ...ev, heldCount: Math.max(0, held) };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
  }
}

/**
 * Ticket refund subject handler: records outcomes via mergeRefundOutcome and mirrors refundStatus on registration.
 */
export function ticketRefundHandler(deps: EventPaymentDeps): RefundSubjectHandler {
  return {
    async resend(refund: Refund): Promise<Refund> {
      // Re-read in a transaction: only a refund still pending is sent (a done or failed one never again).
      const found = await deps.events.runTransaction(async (tx) => {
        const stored = await tx.getRefund(refund.id);
        const payment = stored === null ? null : await tx.getPayment(stored.paymentId);
        return { stored, payment };
      });
      const { stored, payment } = found;
      if (stored === null || stored.status !== 'pending') return stored ?? refund;
      if (payment === null) {
        const gone = refundWithoutPayment(stored, deps.clock.now());
        return (await this.record(gone)) ?? gone;
      }
      const next = await sendRefundOnce(deps, stored, payment);
      const recorded = await this.record(next);
      return recorded ?? next;
    },

    async record(next: Refund): Promise<Refund | null> {
      return deps.events.runTransaction(async (tx) => {
        // Reads first
        const stored = await tx.getRefund(next.id);
        const merged = stored ? mergeRefundOutcome(stored, next) : next;
        if (!merged) return null;

        const payment = await tx.getPayment(merged.paymentId);
        let reg: RegistrationDoc | null = null;
        if (payment?.subjectType === 'event_registration' && payment.eventId !== undefined) {
          reg = await tx.getRegistration(payment.eventId, payment.subjectId);
        }

        // Writes
        tx.putRefund(merged);

        if (reg !== null && reg.refundId === merged.id && reg.refundStatus !== merged.status) {
          const now = deps.clock.now();
          tx.putRegistration({
            ...reg,
            refundStatus: merged.status,
            updatedAt: now,
            version: reg.version + 1,
          });
        }

        return merged;
      });
    },
  };
}

/**
 * Gateway refund after the money moved in the ledger, keyed by the refund id: the gateway treats a
 * repeated id as the same refund, so sending it again never pays twice.
 */
export async function dispatchTicketRefund(deps: EventPaymentDeps, refund: Refund, payment: Payment): Promise<Refund> {
  const next = await sendRefundOnce(deps, refund, payment);
  const recorded = await ticketRefundHandler(deps).record(next);
  return recorded ?? next;
}

/**
 * SubjectSettler implementation for event registrations.
 */
export class TicketPaymentSettler implements SubjectSettler {
  constructor(private readonly deps: EventPaymentDeps) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    const recordId = transferRecordId(transfer);
    const now = this.deps.clock.now();
    // The sender's account, encrypted before the transaction (V2 Decision 2); a cipher failure fails the call.
    const captured = await payerAccountOf(this.deps.cipher, transfer.payer);
    let pendingRefunds: Refund[] = [];
    let paymentForRefund: Payment | null = null;

    const outcome = await this.deps.events.runTransaction(async (tx): Promise<Exclude<TransferOutcome, 'needs_review'>> => {
      pendingRefunds = [];
      const seen = await tx.getTransferRecord(recordId);
      if (seen !== null) return 'duplicate';

      const p = await tx.getPayment(paymentId);
      if (p === null || p.subjectType !== 'event_registration' || p.eventId === undefined) {
        throw new DomainError('not_found');
      }
      paymentForRefund = p;

      const reg = await tx.getRegistration(p.eventId, p.subjectId);
      const ev = await tx.getEvent(p.eventId);
      // An entry ticket (S30): its visit day moves held → sold; a day closed meanwhile refunds instead.
      const days = reg === null ? NO_ENTRY_DAYS : await readEntryDays(tx, ev, [reg]);
      const visitDay = reg === null ? null : visitDayOf(ev, reg);
      const dayClosed = visitDay !== null && days.get(visitDay)?.closed === true;
      const live = reg !== null && ev !== null && reg.status === 'held' && ev.status !== 'cancelled'
        && reg.holdExpiresAt !== null && reg.holdExpiresAt.getTime() > now.getTime() && !dayClosed;
      const contact = live ? await this.deps.contacts.get(p.payerId) : null;
      // S30 (Decision 7): a lone entry ticket paid now gets its pass; the code is drawn (a read) first.
      const passCode = live && ev !== null && ev.type === 'entry'
        && applyTransfer({ payment: p, transfer, ledgerEntryId: 'probe', now }).decision.kind === 'paid'
        ? await freshPassCode(this.deps.random, (c) => tx.passTaken(c))
        : null;

      // Apply transfer using pure helper
      const applied = applyTransfer({
        payment: p,
        transfer,
        ledgerEntryId: this.deps.ids.newId(),
        now,
      });

      tx.putLedgerEntry(applied.ledgerEntry);

      // The first sender that counts toward the payment is kept as its payer.
      const counted: Payment = { ...applied.payment, payer: p.payer ?? captured };

      if (applied.decision.kind === 'partial') {
        tx.putPayment(counted);
        tx.putTransferRecord(transferRecordOf(transfer, 'partial', p.id));
        return 'partial';
      }

      if (applied.decision.kind === 'refund') {
        const refundResult = transferRefund({
          payment: p,
          refundId: this.deps.ids.newId(),
          amount: transfer.amount,
          reason: applied.decision.reason,
          ledgerEntryId: this.deps.ids.newId(),
          destination: captured ?? p.payer,
          providerRef: transfer.txnId,
          now,
        });
        const refund: Refund = refundResult.refund;
        // The payment keeps its status; only refundedAmount grows.
        tx.putPayment({ ...refundResult.payment, updatedAt: now.toISOString() });
        tx.putRefund(refund);
        tx.putLedgerEntry(refundResult.ledgerEntry);
        pendingRefunds.push(refund);

        // Mark registration refund pending if held or cancelled and this is its payment
        if (reg !== null && (reg.status === 'held' || (reg.status === 'cancelled' && reg.paymentId === p.id))) {
          const mark = { refundId: refund.id, refundStatus: refund.status };
          if (reg.status === 'held' && ev !== null) {
            releaseHoldWrites(tx, ev, [{ ...reg, ...mark }], now, days);
          } else {
            tx.putRegistration({ ...reg, ...mark, updatedAt: now, version: reg.version + 1 });
          }
        }

        tx.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        return 'refunded';
      }

      // applied.decision.kind === 'paid'
      if (!live || reg === null || ev === null) {
        // Late transfer or expired hold: 100% refund
        const refundResult = applyRefundToPayment({
          payment: counted,
          refundId: this.deps.ids.newId(),
          percent: 100,
          reason: 'late_payment_hold_expired',
          ledgerEntryId: this.deps.ids.newId(),
          now,
        });
        const refund: Refund = { ...refundResult.refund, providerRef: transfer.txnId };
        tx.putPayment(refundResult.payment);
        tx.putRefund(refund);
        tx.putLedgerEntry(refundResult.ledgerEntry);
        pendingRefunds.push(refund);

        const mark = reg !== null && (reg.status === 'held' || (reg.status === 'cancelled' && reg.paymentId === p.id))
          ? { refundId: refund.id, refundStatus: refund.status }
          : null;

        if (reg !== null && reg.status === 'held' && ev !== null) {
          releaseHoldWrites(tx, ev, [{ ...reg, ...(mark ?? {}) }], now, days);
        } else if (reg !== null && mark !== null) {
          tx.putRegistration({ ...reg, ...mark, updatedAt: now, version: reg.version + 1 });
        }

        tx.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        return 'refunded';
      }

      // Live registration: marks paid, seats move, contact snapshot
      let excessRefund: Refund | null = null;
      let paidPayment: Payment = counted;
      if (applied.excess > 0) {
        const excessRes = transferRefund({
          payment: paidPayment,
          refundId: this.deps.ids.newId(),
          amount: applied.excess,
          reason: 'overpaid_excess',
          ledgerEntryId: this.deps.ids.newId(),
          destination: captured ?? p.payer,
          providerRef: transfer.txnId,
          now,
        });
        paidPayment = excessRes.payment;
        excessRefund = excessRes.refund;
        tx.putRefund(excessRefund);
        tx.putLedgerEntry(excessRes.ledgerEntry);
        pendingRefunds.push(excessRefund);
      }

      tx.putPayment(paidPayment);
      const paid = ticketPaidUpdate({ ev, reg, paymentId: p.id, contact, now, passCode });
      tx.putRegistration(paid.registration);
      if (paid.contact !== null) tx.putRegistrationContact(ev.id, reg.id, paid.contact);
      if (paid.day !== null) writeEntryDays(tx, ev.id, days, [paid.day], now);
      tx.putEvent(paid.event);
      if (passCode !== null) {
        await writePass(tx, newPass({
          code8: passCode, customerId: reg.userId, day: visitDay ?? formatVnDate(now), bookingId: null, eventId: ev.id,
          registrationIds: [reg.id], now,
        }));
      }

      const finalOutcome: Exclude<TransferOutcome, 'needs_review'> = applied.excess > 0 ? 'paid_with_refund' : 'paid';
      tx.putTransferRecord(transferRecordOf(transfer, finalOutcome, p.id));
      return finalOutcome;
    });

    const payObj = paymentForRefund;
    if (outcome !== 'duplicate' && pendingRefunds.length > 0 && payObj !== null) {
      await Promise.all(pendingRefunds.map((r) => this.dispatchRefund(r, payObj)));
    }

    return outcome;
  }

  async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
    let pendingRefund: Refund | null = null;
    let paymentObj: Payment | null = null;

    const outcome = await this.deps.events.runTransaction(async (tx): Promise<'expired' | 'unchanged'> => {
      pendingRefund = null;
      const p = await tx.getPayment(paymentId);
      if (p === null || p.subjectType !== 'event_registration' || p.status !== 'created' || !p.expiresAt) {
        return 'unchanged';
      }
      if (Date.parse(p.expiresAt) > now.getTime()) {
        return 'unchanged';
      }

      const expired = expireUnpaid({
        payment: p,
        refundId: this.deps.ids.newId(),
        ledgerEntryId: this.deps.ids.newId(),
        now,
      });
      tx.putPayment(expired.payment);
      paymentObj = expired.payment;

      if (expired.refund && expired.ledgerEntry) {
        tx.putRefund(expired.refund);
        tx.putLedgerEntry(expired.ledgerEntry);
        pendingRefund = expired.refund;
      }
      return 'expired';
    });

    if (outcome === 'expired' && pendingRefund !== null && paymentObj !== null) {
      await this.dispatchRefund(pendingRefund, paymentObj);
    }

    return outcome;
  }

  async dispatchRefund(refund: Refund, payment: Payment): Promise<Refund> {
    return dispatchTicketRefund(this.deps, refund, payment);
  }

  async statusOf(payment: Payment): Promise<string> {
    const eventId = payment.eventId;
    if (eventId === undefined) return 'gone';
    const reg = await this.deps.events.runTransaction((tx) => tx.getRegistration(eventId, payment.subjectId));
    return reg?.status ?? 'gone';
  }
}

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

/** Back from the gateway (or "Thanh toán tiếp"): asks the gateway and applies a payment it reports. */
export async function checkTicketPayment(
  deps: EventPaymentDeps & { settlement?: SettlementDeps },
  caller: EventCaller,
  raw: unknown,
): Promise<{ paid: boolean; status: RegistrationStatus }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const regId = idOf(r.registrationId);
  const reg = await deps.events.runTransaction((tx) => tx.getRegistration(eventId, regId));
  if (reg === null) throw new DomainError('not_found');
  if (reg.userId !== caller.uid) throw new DomainError('permission_denied');
  const paymentId = reg.paymentId;
  if (reg.status !== 'held' || paymentId === null) return { paid: reg.status === 'paid', status: reg.status };
  const p = await deps.events.runTransaction((tx) => tx.getPayment(paymentId));
  if (p === null) return { paid: false, status: reg.status };

  const settlement: SettlementDeps = deps.settlement ?? {
    payments: deps.payments,
    gateway: deps.gateway,
    clock: deps.clock,
    subjects: { event_registration: new TicketPaymentSettler(deps) },
  };

  await checkSubjectPayments(settlement, [p]);

  const updatedReg = await deps.events.runTransaction((tx) => tx.getRegistration(eventId, regId));
  const finalStatus = updatedReg?.status ?? 'cancelled';
  return { paid: finalStatus === 'paid', status: finalStatus };
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
  options: {
    /**
     * S30 (Task 4): a used ticket (`checkedInAt` or `gateCheckedInAt`, the gate let them in) keeps its money:
     * `skipped`, its owed flags cleared. The booking ticket-line settle asks for it.
     */
    readonly unusedOnly?: boolean;
  } = {},
): Promise<'refunded' | 'skipped'> {
  let pendingRefund: { refund: Refund; payment: Payment } | null = null;
  const out = await deps.events.runTransaction(async (tx): Promise<'refunded' | 'skipped'> => {
    pendingRefund = null;
    const now = deps.clock.now();
    const reg = await tx.getRegistration(eventId, regId);
    if (reg === null || reg.status === 'refunded' || reg.paymentId === null || reg.amount <= 0) return 'skipped';
    const ev = await tx.getEvent(eventId);
    const p = await tx.getPayment(reg.paymentId);
    const days = reg.status === 'paid' ? await readEntryDays(tx, ev, [reg]) : NO_ENTRY_DAYS;
    const held = p !== null && p.status === 'paid'
      && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded');
    // A customer refunds a live ticket; a host cancel also refunds late-cancelled tickets whose money is held.
    // Closing an entry day (S30) refunds like a host cancel.
    const eligible = reason === 'customer_cancel'
      ? reg.status === 'paid'
      : reg.status === 'paid' || (reg.status === 'cancelled' && reg.refundDue === true);
    const used = reg.checkedInAt !== null || (reg.gateCheckedInAt ?? null) !== null;
    if (!held || !eligible || p === null || (options.unusedOnly === true && used)) {
      if (reg.refundDue === true || (reg.bookingLineDue ?? null) !== null) {
        tx.putRegistration({ ...reg, refundDue: false, bookingLineDue: null, updatedAt: now, version: reg.version + 1 });
      }
      return 'skipped';
    }
    // #141 Decision 5: a bank-QR ticket refund waits for the customer's account choice (S22.04);
    // the registration mirrors `refundStatus: 'awaiting_account'` below.
    const res = applyRefundToPayment({
      payment: p, refundId: deps.ids.newId(), percent, ledgerEntryId: deps.ids.newId(), reason, now, waitForAccount: true,
    });
    tx.putPayment(res.payment);
    tx.putRefund(res.refund);
    tx.putLedgerEntry(res.ledgerEntry);
    tx.putRegistration({
      ...reg, status: 'refunded', refundPercent: percent, refundDue: false, cancelledAt: reg.cancelledAt ?? now,
      ...((reg.bookingLineDue ?? null) !== null ? { bookingLineDue: null } : {}),
      refundId: res.refund.id, refundStatus: res.refund.status, updatedAt: now, version: reg.version + 1,
    });
    tx.deleteRegistrationContact(eventId, regId);
    if (reg.status === 'paid' && ev !== null) {
      writeEntryDays(tx, ev.id, days, releaseDeltas(ev, [reg]), now);
      const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    }
    if (res.refund.status !== 'awaiting_account') pendingRefund = { refund: res.refund, payment: res.payment };
    return 'refunded';
  });
  if (pendingRefund !== null) await dispatchTicketRefund(deps, (pendingRefund as { refund: Refund; payment: Payment }).refund, (pendingRefund as { refund: Refund; payment: Payment }).payment);
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
        const days = await readEntryDays(tx, ev, stale);
        releaseHoldWrites(tx, ev, stale, now, days);
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

/**
 * S30 (Decision 11): the organizer closes a visit day of an entry event. In one transaction the day is
 * marked `closed` (no more sales) and every paid ticket of it, and every ticket of it cancelled late
 * whose money is still held, gets `refundDue`; then the first
 * ENTRY_CLOSE_BATCH tickets are refunded 100% here, each in its own transaction (`refundTicket`,
 * reason `day_closed`), and the event clock refunds what is `left` (`runEventSweeps`). Every customer
 * whose ticket is flagged here gets `entry_day_closed` (best effort). Managers only.
 */
export async function closeEntryDay(
  deps: EventPaymentDeps & { readonly notify?: NotifyDeps },
  caller: EventCaller,
  raw: unknown,
): Promise<{ refunded: number; left: number }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  if (!isDateString(r.day)) throw new DomainError('invalid_argument', 'day');
  const day = r.day;
  const closed = await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null || ev.type !== 'entry' || ev.status === 'draft') throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    if (day < formatVnDate(now)) throw new DomainError('not_eligible');
    if (!isOpenDay(entryFieldsOf(ev), day)) throw new DomainError('invalid_argument', 'day');
    const row = await tx.getEntryDay(ev.id, day);
    const live = (await tx.registrationsOfDay(ev.id, day)).filter((x) => x.amount > 0);
    // Tickets of the day cancelled late (no refund, money still held) are refunded too: an organizer
    // never keeps money for a day it closed (as `cancelEvent` does for late cancels).
    const liveIds = new Set(live.map((x) => x.id));
    const heldIds = [...new Set((await tx.heldTicketPayments(ev.id)).map((p) => p.subjectId))].filter((id) => !liveIds.has(id));
    const late = (await Promise.all(heldIds.map((id) => tx.getRegistration(ev.id, id))))
      .filter((x): x is RegistrationDoc => x !== null && x.status === 'cancelled' && (x.visitDay ?? null) === day);
    const paid = [...live, ...late];
    const flagged = paid.filter((x) => x.refundDue !== true);
    for (const x of flagged) tx.putRegistration({ ...x, refundDue: true, updatedAt: now, version: x.version + 1 });
    if (row?.closed !== true) {
      tx.putEntryDay({ ...(row ?? emptyEntryDay(ev.id, day, now)), closed: true, updatedAt: now.toISOString() });
    }
    return { ev, ids: paid.map((x) => x.id), flagged };
  });

  const notify = deps.notify;
  if (notify !== undefined) {
    const place = closed.ev.location?.name ?? closed.ev.title;
    await Promise.allSettled(closed.flagged.map((x) => notifyEntryDayClosed(notify, {
      userId: x.userId, eventId: closed.ev.id, registrationId: x.id, spot: place, day, thumbUrl: closed.ev.coverUrl,
    })));
  }

  let refunded = 0;
  let failed = 0;
  for (const id of closed.ids.slice(0, ENTRY_CLOSE_BATCH)) {
    try {
      if ((await refundTicket(deps, eventId, id, 100, 'day_closed')) === 'refunded') refunded += 1;
    } catch {
      failed += 1; // still `refundDue`: the event clock retries it
    }
  }
  return { refunded, left: Math.max(0, closed.ids.length - ENTRY_CLOSE_BATCH) + failed };
}

/**
 * Writes the late-cancel of a paid ticket (the customer's own rule, `cancelRegistration` after the
 * cutoff): `cancelled` with `refundPercent` 0, seats and its day's `sold` back, the money stays held for
 * the host. `skipped` unless the ticket is still paid.
 */
export async function cancelTicketKeepingMoney(deps: EventDeps, eventId: string, regId: string): Promise<'cancelled' | 'skipped'> {
  return deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const reg = await tx.getRegistration(eventId, regId);
    const ev = await tx.getEvent(eventId);
    if (reg === null || ev === null) return 'skipped';
    if (reg.status !== 'paid' || reg.checkedInAt !== null || (reg.gateCheckedInAt ?? null) !== null) {
      if (reg.refundDue === true || (reg.bookingLineDue ?? null) !== null) {
        tx.putRegistration({ ...reg, refundDue: false, bookingLineDue: null, updatedAt: now, version: reg.version + 1 });
      }
      return 'skipped';
    }
    const days = await readEntryDays(tx, ev, [reg]);
    tx.putRegistration({
      ...reg, status: 'cancelled', cancelledAt: now, refundPercent: 0, refundDue: false, bookingLineDue: null,
      updatedAt: now, version: reg.version + 1,
    });
    tx.deleteRegistrationContact(eventId, regId);
    writeEntryDays(tx, ev.id, days, releaseDeltas(ev, [reg]), now);
    const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return 'cancelled';
  });
}

/**
 * S30 (Decision 15, spec §5.3): settles what a booking left owed to its ticket (`bookingLineDue`,
 * stamped in the booking's transaction): 100 → `refundTicket` with the stamped reason (never for a ticket
 * used at the gate meanwhile: `checkedInAt` / `gateCheckedInAt`, Task 4), 0 →
 * `cancelTicketKeepingMoney`. A cancelled event or a closed visit day refunds 100% whatever was
 * stamped (their own rules win). Idempotent: the immediate attempt after the booking commits and the
 * event clock's retry (`runEventSweeps`) both call it; a settled ticket is `skipped`.
 */
export async function settleBookingLine(
  deps: EventPaymentDeps,
  eventId: string,
  regId: string,
): Promise<'refunded' | 'cancelled' | 'skipped'> {
  const found = await deps.events.runTransaction(async (tx) => {
    const reg = await tx.getRegistration(eventId, regId);
    const ev = await tx.getEvent(eventId);
    const day = ev !== null && reg !== null ? visitDayOf(ev, reg) : null;
    const row = ev !== null && day !== null ? await tx.getEntryDay(ev.id, day) : null;
    return { reg, ev, closed: row?.closed === true };
  });
  const due = found.reg?.bookingLineDue ?? null;
  if (found.reg === null || due === null) return 'skipped';
  // A ticket the gate already let in is used: never refunded here (checked again in the refund's own transaction).
  const unused = { unusedOnly: true } as const;
  if (found.ev?.status === 'cancelled') return refundTicket(deps, eventId, regId, 100, 'event_cancelled', unused);
  if (found.closed) return refundTicket(deps, eventId, regId, 100, 'day_closed', unused);
  if (due.percent === 100) return refundTicket(deps, eventId, regId, 100, due.reason, unused);
  return cancelTicketKeepingMoney(deps, eventId, regId);
}

/** The booking side's port (`BookingDeps.tickets`): the immediate attempt after the booking commits. */
export function bookingTicketLines(deps: EventPaymentDeps): BookingTicketLines {
  return {
    async settle(line) {
      await settleBookingLine(deps, line.eventId, line.registrationId);
    },
  };
}
