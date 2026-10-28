/**
 * Chụp ngay money (#202, plan Task 11, Decision 5): the `instant_request` subject of V1's payment
 * extension point. The customer pays 100% before any offer goes out; the money is held, released to
 * the photographer 24 h after the job (Decision 7) by the existing bookingClock step. Money arrives
 * only through V1's settlement (`InstantPaymentSettler`, registered in `SettlementDeps.subjects`);
 * refunds go out once with V2's `sendRefundOnce` after the transaction that wrote them, and those left
 * `pending` are re-sent only by V2's re-send through `instantRefundHandler` (`RefundSubjects`), never
 * by `runInstantSweep`.
 */
import type { TransferNotification, TransferOutcome } from './booking_ports.js';
import { DomainError } from './errors.js';
import { applyRefundToPayment, type Payment, type Refund } from './escrow.js';
import type { InstantOffer, InstantRequest } from './instant.js';
import type { InstantDeps } from './instant_ports.js';
import { instantOfferChecks, pushInstantOffers, sendInstantOffers, type InstantOfferChecks } from './instant_requests.js';
import { runInstant, type InstantRefundSend, type InstantWork } from './instant_work.js';
import { payerAccountOf } from './payer_account.js';
import type { SubjectSettler } from './payment_ports.js';
import { applyTransfer, expireUnpaid, transferRecordId, transferRecordOf } from './payment_settlement.js';
import { refundWithoutPayment, type RefundSubjectHandler } from './refund_subjects.js';
import { mergeRefundOutcome, sendRefundOnce, transferRefund } from './refunds.js';

/** Why a paid instant payment went back in full: it arrived when the request no longer waited for it. */
export const INSTANT_LATE_PAYMENT_REASON = 'late_payment';

const NO_CHECKS: InstantOfferChecks = { blockers: new Map(), dayStates: new Map() };

/**
 * A policy refund of a paid request's escrow (`applyRefundToPayment`, `percent` of the amount),
 * stored with its `refund_issued` ledger line and queued to be sent after the commit. The caller
 * mirrors it on the request (`mirrorRefund`).
 */
export function refundInstantShare(
  w: InstantWork,
  deps: Pick<InstantDeps, 'ids'>,
  payment: Payment,
  percent: number,
  reason: string,
  providerRef?: string,
): { payment: Payment; refund: Refund } {
  const out = applyRefundToPayment({
    payment, refundId: deps.ids.newId(), percent, ledgerEntryId: deps.ids.newId(), reason, now: w.now,
  });
  const refund: Refund = providerRef === undefined ? out.refund : { ...out.refund, providerRef };
  w.setPayment(out.payment);
  w.putRefund(refund);
  w.putLedgerEntry(out.ledgerEntry);
  w.queueRefundSend(refund, out.payment);
  return { payment: out.payment, refund };
}

/** The request shows its customer's refund (S13.07/S13.08 "hoàn … về …"). */
export const mirrorRefund = (r: InstantRequest, refund: Refund): InstantRequest => ({
  ...r, refundId: refund.id, refundStatus: refund.status,
});

/**
 * Sends the refunds a transaction wrote, one gateway call each under the refund's id. Never throws:
 * the transaction that wrote them has committed, so the caller's answer stands. A refund whose
 * outcome could not be stored stays `pending` and V2's re-send sends it again under the same id
 * (the gateway treats a repeated id as the same refund). Reports how many failed to `deps.log` and returns it.
 */
export async function sendInstantRefunds(deps: InstantDeps, sends: readonly InstantRefundSend[]): Promise<{ failed: number }> {
  let failed = 0;
  for (const { refund, payment } of sends) {
    try {
      await dispatchInstantRefund(deps, refund, payment);
    } catch {
      failed += 1;
    }
  }
  if (failed > 0) deps.log?.refundSendsFailed(failed);
  return { failed };
}

/** V2: one gateway call under the refund's id (`sendRefundOnce`), then the outcome stored and mirrored. */
export async function dispatchInstantRefund(
  deps: InstantDeps,
  refund: Refund,
  payment: Pick<Payment, 'id' | 'provider'>,
): Promise<Refund> {
  const next = await sendRefundOnce(deps, refund, payment);
  return (await instantRefundHandler(deps).record(next)) ?? next;
}

/**
 * Instant refunds in V2's `RefundSubjects` registry: the payment clock's re-send of pending refunds
 * and refund events. `record` merges the outcome (`mergeRefundOutcome`) and mirrors `refundStatus` on
 * the request whose `refundId` it is.
 */
export function instantRefundHandler(deps: InstantDeps): RefundSubjectHandler {
  return {
    async resend(refund: Refund): Promise<Refund> {
      // Re-read: only a refund still pending is sent (an event or staff may have settled it since the query).
      const { stored, payment } = await deps.store.runTransaction(async (tx) => {
        const s = await tx.getRefund(refund.id);
        return { stored: s, payment: s === null ? null : await tx.getPayment(s.paymentId) };
      });
      if (stored === null || stored.status !== 'pending') return stored ?? refund;
      if (payment === null) {
        const gone = refundWithoutPayment(stored, deps.clock.now());
        return (await this.record(gone)) ?? gone;
      }
      const next = await sendRefundOnce(deps, stored, payment);
      return (await this.record(next)) ?? next;
    },

    async record(next: Refund): Promise<Refund | null> {
      return runInstant(deps, async (w) => {
        // Reads first: the refund, its payment, the request it may be mirrored on.
        const stored = await w.refund(next.id);
        const payment = await w.payment(next.paymentId);
        const r = payment?.subjectType === 'instant_request' ? await w.request(payment.subjectId) : null;
        const merged = stored ? mergeRefundOutcome(stored, next) : next;
        if (merged === null) return null;
        w.putRefund(merged);
        if (r !== null && r.refundId === merged.id && r.refundStatus !== merged.status) {
          w.setRequest({ ...r, refundStatus: merged.status });
        }
        return merged;
      });
    },
  };
}

/**
 * V1's `SubjectSettler` for `instant_request`, over the InstantStore (Decision 5).
 * `settle`: one instant transaction, reads first — the transfer record (`duplicate`), the payment, the
 * request (settled), the invitees' presences — then #129's `applyTransfer`. Paid while the request still
 * waits in `pending_payment` on this payment → `paidAt`, `committedAt` and the offers go out to
 * `pendingInviteIds`; paid in any other case (cancelled, the payment window passed, another payment)
 * → refunded 100% (`late_payment`). Over, under and late transfers follow #129's table. Refunds and
 * offer pushes go out after the commit.
 */
export class InstantPaymentSettler implements SubjectSettler {
  constructor(private readonly deps: InstantDeps) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    const deps = this.deps;
    const recordId = transferRecordId(transfer);
    // The sender's account, encrypted before the transaction (V2 Decision 2).
    const captured = await payerAccountOf(deps.cipher, transfer.payer);
    // Plain reads before the transaction: #198's gate and today's day for the invitees (as inviteInstant does).
    const pre = await deps.store.runTransaction(async (tx) => {
      const p = await tx.getPayment(paymentId);
      return p === null ? null : tx.getRequest(p.subjectId);
    });
    // A missing or switched-off config never loses a payment: it is recorded, and no offer goes out
    // (the request is back in `choosing` with the money held; the customer may cancel for 100%).
    const cfg = pre === null ? null : await deps.config.get().catch(() => null);
    const live = cfg !== null && cfg.enabled;
    const checkedIds = pre !== null && pre.status === 'pending_payment' && live ? pre.pendingInviteIds : [];
    const checks = checkedIds.length > 0 && pre !== null
      ? await instantOfferChecks(deps, pre.customerId, checkedIds, deps.clock.now())
      : NO_CHECKS;
    let sends: InstantRefundSend[] = [];
    let offers: InstantOffer[] = [];

    const outcome = await runInstant(deps, async (w): Promise<Exclude<TransferOutcome, 'needs_review'>> => {
      sends = [];
      offers = [];
      if ((await w.transferRecord(recordId)) !== null) return 'duplicate';
      const p = await w.payment(paymentId);
      if (p === null || p.subjectType !== 'instant_request') throw new DomainError('not_found');
      const r = await w.settle(p.subjectId);
      const now = w.now;

      // ---- decisions and changes (flushed together)
      const applied = applyTransfer({ payment: p, transfer, ledgerEntryId: deps.ids.newId(), now });
      w.putLedgerEntry(applied.ledgerEntry);
      // The first sender that counts toward the payment is kept as its payer (the refund destination).
      const counted: Payment = { ...applied.payment, payer: p.payer ?? captured };

      const giveBack = (payment: Payment, amount: number, reason: Parameters<typeof transferRefund>[0]['reason']): Payment => {
        const out = transferRefund({
          payment, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), amount, reason,
          destination: captured ?? p.payer, providerRef: transfer.txnId, now,
        });
        w.putRefund(out.refund);
        w.putLedgerEntry(out.ledgerEntry);
        w.queueRefundSend(out.refund, out.payment);
        return out.payment;
      };

      if (applied.decision.kind === 'partial') {
        w.setPayment(counted);
        w.putTransferRecord(transferRecordOf(transfer, 'partial', p.id));
        sends = w.refundSends();
        return 'partial';
      }
      if (applied.decision.kind === 'refund') {
        // A late or extra transfer goes straight back; the payment keeps its status.
        w.setPayment({ ...giveBack(p, transfer.amount, applied.decision.reason), updatedAt: now.toISOString() });
        w.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        sends = w.refundSends();
        return 'refunded';
      }

      // paid
      let paid: Payment = counted;
      if (applied.excess > 0) paid = giveBack(paid, applied.excess, 'overpaid_excess');
      if (r !== null && r.status === 'pending_payment' && r.paymentId === p.id) {
        w.setPayment(paid);
        const ids = live ? r.pendingInviteIds : [];
        // The choice changed since the plain reads (a second tap): check the people chosen now, so
        // nobody is marked unavailable for want of a check.
        const sameChoice = ids.length === checkedIds.length && ids.every((id, i) => id === checkedIds[i]);
        const fresh = sameChoice ? checks : await instantOfferChecks(deps, r.customerId, ids, now);
        // The price list the customer paid for (the request's snapshot, also its `earningVnd`): a
        // photographer is offered exactly what was paid, even if the config moved since.
        const out = await sendInstantOffers(
          w, deps, { ...r, paidAt: now, pendingInviteIds: [] }, ids, { priceListVersion: r.priceListVersion }, fresh,
        );
        offers = out.offers;
        const final = applied.excess > 0 ? 'paid_with_refund' : 'paid';
        w.putTransferRecord(transferRecordOf(transfer, final, p.id));
        sends = w.refundSends();
        return final;
      }
      // Nobody waits for this money any more: back in full.
      const back = refundInstantShare(w, deps, paid, 100, INSTANT_LATE_PAYMENT_REASON, transfer.txnId);
      if (r !== null && r.paymentId === p.id) w.setRequest(mirrorRefund(r, back.refund));
      w.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
      sends = w.refundSends();
      return 'refunded';
    });

    if (outcome !== 'duplicate') {
      await sendInstantRefunds(deps, sends);
      await pushInstantOffers(deps, offers);
    }
    return outcome;
  }

  async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
    const deps = this.deps;
    let sends: InstantRefundSend[] = [];
    const outcome = await deps.store.runTransaction(async (tx): Promise<'expired' | 'unchanged'> => {
      sends = [];
      const p = await tx.getPayment(paymentId);
      if (p === null || p.subjectType !== 'instant_request' || p.status !== 'created' || !p.expiresAt) return 'unchanged';
      if (Date.parse(p.expiresAt) > now.getTime()) return 'unchanged';
      const out = expireUnpaid({ payment: p, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), now });
      tx.putPayment(out.payment);
      if (out.refund !== null && out.ledgerEntry !== null) {
        tx.putRefund(out.refund);
        tx.putLedgerEntry(out.ledgerEntry);
        sends = [{ refund: out.refund, payment: out.payment }];
      }
      return 'expired';
    });
    await sendInstantRefunds(deps, sends);
    return outcome;
  }

  async dispatchRefund(refund: Refund, payment: Payment): Promise<Refund> {
    return dispatchInstantRefund(this.deps, refund, payment);
  }

  /** The status of the request `payment.subjectId`, `gone` when it does not exist. */
  async statusOf(payment: Payment): Promise<string> {
    const r = await this.deps.store.runTransaction((tx) => tx.getRequest(payment.subjectId));
    return r?.status ?? 'gone';
  }
}
