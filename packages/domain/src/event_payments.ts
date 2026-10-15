/**
 * Paid event tickets: payment settlement via TicketPaymentSettler, refunds (customer cancel >= 48h,
 * host cancel, late payment), hold sweeps, and escrow release.
 */

import { DomainError } from './errors.js';
import {
  applyRefundToPayment,
  type Payment,
  type PaymentMethod,
  type Refund,
} from './escrow.js';
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
import { PLATFORM_PAYEE } from './payout.js';
import { isVnE164 } from './phone.js';
import type { SubjectSettler } from './payment_ports.js';
import type { SettlementDeps } from './payment_settlement.js';
import {
  applyTransfer,
  expireUnpaid,
  transferRecordId,
  transferRecordOf,
} from './payment_settlement.js';
import type { TransferNotification, TransferOutcome } from './booking_ports.js';
import { DISPUTE_WINDOW_HOURS } from './booking_policy.js';
import { transferRefund } from './refunds.js';
import { checkSubjectPayments } from './create_payment.js';
import { transferCodeFor } from './payment_code.js';

const HOUR_MS = 3_600_000;
const SWEEP_BATCH = 200;

export type TicketRefundReason = 'customer_cancel' | 'event_cancelled';

/** Spec §3g (O4): a paid ticket cancelled at least 48 h before the start gets 100% back, later nothing. */
export function ticketRefundPercent(startAt: Date, now: Date): 100 | 0 {
  return startAt.getTime() - now.getTime() >= FREE_CANCEL_HOURS * HOUR_MS ? 100 : 0;
}

/** One payment per registration and method; a second tap with the same method reuses it. */
export const ticketIdempotencyKey = (registrationId: string, method: PaymentMethod): string =>
  `tkt_${registrationId}_${method}`;

/** The host photographer is paid; a platform-hosted event's money stays with the platform. */
export const ticketPayeeOf = (ev: Pick<EventRecord, 'host'>): string =>
  ev.host.type === 'photographer' && ev.host.id !== null ? ev.host.id : PLATFORM_PAYEE;

/** A fresh, unpaid ticket payment. */
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
}): Payment {
  const at = params.now.toISOString();
  return {
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
 * Gateway refund after the money moved in the ledger, keyed by the refund id: the gateway treats a
 * repeated id as the same refund, so sending it again never pays twice.
 */
export async function dispatchTicketRefund(deps: EventPaymentDeps, refund: Refund, payment: Payment): Promise<Refund> {
  let result: { success: boolean; providerRef?: string };
  try {
    result = await deps.gateway.issueRefund({
      paymentId: refund.paymentId,
      refundId: refund.id,
      amount: refund.amount,
      provider: payment.provider,
      providerRef: refund.providerRef,
      method: refund.method,
    });
  } catch {
    result = { success: false };
  }
  return deps.events.runTransaction(async (tx) => {
    const cur = await tx.getRefund(refund.id);
    const reg = payment.eventId === undefined ? null : await tx.getRegistration(payment.eventId, payment.subjectId);
    if (cur !== null && cur.status !== 'pending') return cur;
    const now = deps.clock.now();
    const updated: Refund = {
      ...(cur ?? refund),
      status: result.success ? 'done' : 'failed',
      manual: !result.success,
      providerRef: result.providerRef ?? refund.providerRef,
      updatedAt: now.toISOString(),
    };
    tx.putRefund(updated);
    if (reg !== null && reg.refundId === refund.id && reg.refundStatus !== updated.status) {
      tx.putRegistration({ ...reg, refundStatus: updated.status, updatedAt: now, version: reg.version + 1 });
    }
    return updated;
  });
}

export const TICKET_REFUND_RESEND_AFTER_MINUTES = 10;

export async function resendTicketRefund(deps: EventPaymentDeps, refundId: string): Promise<boolean> {
  const found = await deps.events.runTransaction(async (tx) => {
    const r = await tx.getRefund(refundId);
    if (r === null || r.status !== 'pending') return null;
    const p = await tx.getPayment(r.paymentId);
    if (p === null || p.subjectType !== 'event_registration') return null;
    return { refund: r, payment: p };
  });
  if (found === null) return false;
  await dispatchTicketRefund(deps, found.refund, found.payment);
  return true;
}

/**
 * SubjectSettler implementation for event registrations.
 */
export class TicketPaymentSettler implements SubjectSettler {
  constructor(private readonly deps: EventPaymentDeps) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    const recordId = transferRecordId(transfer);
    const now = this.deps.clock.now();
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
      const live = reg !== null && ev !== null && reg.status === 'held' && ev.status !== 'cancelled'
        && reg.holdExpiresAt !== null && reg.holdExpiresAt.getTime() > now.getTime();
      const contact = live ? await this.deps.contacts.get(p.payerId) : null;

      // Apply transfer using pure helper
      const applied = applyTransfer({
        payment: p,
        transfer,
        ledgerEntryId: this.deps.ids.newId(),
        now,
      });

      tx.putLedgerEntry(applied.ledgerEntry);

      if (applied.decision.kind === 'partial') {
        tx.putPayment(applied.payment);
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
          now,
        });
        const refund: Refund = { ...refundResult.refund, providerRef: transfer.txnId };
        tx.putRefund(refund);
        tx.putLedgerEntry(refundResult.ledgerEntry);
        pendingRefunds.push(refund);

        // Mark registration refund pending if held or cancelled and this is its payment
        if (reg !== null && (reg.status === 'held' || (reg.status === 'cancelled' && reg.paymentId === p.id))) {
          const mark = { refundId: refund.id, refundStatus: 'pending' as const };
          if (reg.status === 'held' && ev !== null) {
            releaseHoldWrites(tx, ev, [{ ...reg, ...mark }], now);
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
          payment: applied.payment,
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
          ? { refundId: refund.id, refundStatus: 'pending' as const }
          : null;

        if (reg !== null && reg.status === 'held' && ev !== null) {
          releaseHoldWrites(tx, ev, [{ ...reg, ...(mark ?? {}) }], now);
        } else if (reg !== null && mark !== null) {
          tx.putRegistration({ ...reg, ...mark, updatedAt: now, version: reg.version + 1 });
        }

        tx.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        return 'refunded';
      }

      // Live registration: marks paid, seats move, contact snapshot
      let excessRefund: Refund | null = null;
      if (applied.excess > 0) {
        const excessRes = transferRefund({
          payment: applied.payment,
          refundId: this.deps.ids.newId(),
          amount: applied.excess,
          reason: 'overpaid_excess',
          ledgerEntryId: this.deps.ids.newId(),
          now,
        });
        excessRefund = { ...excessRes.refund, providerRef: transfer.txnId };
        tx.putRefund(excessRefund);
        tx.putLedgerEntry(excessRes.ledgerEntry);
        pendingRefunds.push(excessRefund);
      }

      tx.putPayment(applied.payment);
      const ticket: RegistrationDoc = {
        ...reg,
        status: 'paid',
        paymentId: p.id,
        contactEligible: true,
        updatedAt: now,
        version: reg.version + 1,
      };
      tx.putRegistration(ticket);

      const phone = contact?.phone;
      if (isVnE164(phone)) {
        tx.putRegistrationContact(ev.id, reg.id, registrationContactOf(reg.userName, phone, contact));
      }

      const next = {
        ...ev,
        heldCount: Math.max(0, ev.heldCount - reg.quantity),
        registeredCount: ev.registeredCount + reg.quantity,
      };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });

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
): Promise<'refunded' | 'skipped'> {
  let pendingRefund: { refund: Refund; payment: Payment } | null = null;
  const out = await deps.events.runTransaction(async (tx): Promise<'refunded' | 'skipped'> => {
    pendingRefund = null;
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
      refundId: res.refund.id, refundStatus: 'pending', updatedAt: now, version: reg.version + 1,
    });
    tx.deleteRegistrationContact(eventId, regId);
    if (reg.status === 'paid' && ev !== null) {
      const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    }
    pendingRefund = { refund: res.refund, payment: res.payment };
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
