import * as logger from 'firebase-functions/logger';
import {
  PLATFORM_PAYEE,
  refreshEarnings,
  refreshPayerHistory,
  type EarningsDeps,
  type PayerHistoryDeps,
} from '@photobooking/domain';
import { db } from '../infra/admin.js';

type Doc = {
  payeeId?: unknown;
  payerId?: unknown;
  subjectType?: unknown;
  subjectId?: unknown;
  milestones?: unknown;
  status?: unknown;
  escrowStatus?: unknown;
  receivedAmount?: unknown;
  refundedAmount?: unknown;
  paidAt?: unknown;
} | undefined;

const payeeOf = (d: Doc): string | undefined => (typeof d?.payeeId === 'string' && d.payeeId !== '' ? d.payeeId : undefined);

const positive = (v: unknown): boolean => typeof v === 'number' && v > 0;

/** The document shows money arrived (S22.01 rows exist only then; #141 Decision 2). */
const hasMoney = (d: Doc): boolean =>
  d !== undefined &&
  (d.status === 'paid' || d.status === 'partially_refunded' || d.status === 'refunded' ||
    positive(d.receivedAmount) || positive(d.refundedAmount) || (d.paidAt !== undefined && d.paidAt !== null));

/** Milestone kind, amount and status: a released milestone lowers what is held without changing `escrowStatus`. */
const milestonesKey = (v: unknown): string =>
  Array.isArray(v)
    ? v.map((m: { kind?: unknown; amount?: unknown; status?: unknown } | null) => `${String(m?.kind)}:${String(m?.amount)}:${String(m?.status)}`).join(',')
    : '';

/**
 * #141 Decision 1: the payer's row changes only with `status`, `escrowStatus`, `receivedAmount`,
 * `refundedAmount`, the milestones or the payee (Chụp ngay accept/cancel); a write of a payment that
 * never had money is skipped.
 */
export function payerRowChanged(before: Doc, after: Doc): boolean {
  if (!hasMoney(before) && !hasMoney(after)) return false;
  if (before === undefined || after === undefined) return true;
  return (
    before.status !== after.status ||
    before.escrowStatus !== after.escrowStatus ||
    // Chụp ngay: a photographer accepting (or cancelling) sets (or clears) the payee; "đang tìm thợ" follows.
    before.payeeId !== after.payeeId ||
    (before.receivedAmount ?? 0) !== (after.receivedAmount ?? 0) ||
    (before.refundedAmount ?? 0) !== (after.refundedAmount ?? 0) ||
    milestonesKey(before.milestones) !== milestonesKey(after.milestones)
  );
}

/**
 * A payment write refreshes the payee's earnings row and totals, the payer's S22.01 row and totals
 * (when `history` is given and a field it shows changed, #141), and syncs milestone subcollection.
 * When the payee changed (#202: an instant photographer cancelled, `payeeId` back to `''`, then another
 * accepted), the old payee is refreshed too so their row goes. Idempotent; safe to retry.
 */
export async function handlePaymentWrite(
  paymentId: string,
  before: Doc,
  after: Doc,
  deps: EarningsDeps,
  history?: PayerHistoryDeps,
): Promise<string | null> {
  const payeeId = payeeOf(after) ?? payeeOf(before);
  const formerPayee = payeeOf(before);

  // Sync milestones if booking payment
  if (after?.subjectType === 'booking' && typeof after.subjectId === 'string' && Array.isArray(after.milestones)) {
    const bookingId = after.subjectId;
    const batch = db().batch();
    for (const m of after.milestones) {
      if (m && typeof m === 'object' && typeof m.kind === 'string') {
        const ref = db().collection('bookings').doc(bookingId).collection('milestones').doc(m.kind);
        batch.set(ref, {
          kind: m.kind,
          amount: m.amount,
          status: m.status,
          releaseAfter: m.releaseAfter ?? null,
          releasedAt: m.releasedAt ?? null,
          payoutId: m.payoutId ?? null,
        });
      }
    }
    await batch.commit();
  }

  if (formerPayee !== undefined && formerPayee !== payeeId && formerPayee !== PLATFORM_PAYEE) {
    await refreshEarnings(deps, { payeeId: formerPayee, paymentIds: [paymentId] });
  }
  // Platform-hosted event tickets: the platform keeps the money; it has no earnings page. A group payment
  // (S30) is the customer's own transfer (payee = payer): its lines are the earnings.
  const isGroup = after?.subjectType === 'payment_group' || before?.subjectType === 'payment_group';
  const earningsPayee = payeeId === undefined || payeeId === PLATFORM_PAYEE || isGroup ? null : payeeId;
  if (earningsPayee !== null) {
    await refreshEarnings(deps, { payeeId: earningsPayee, paymentIds: [paymentId] });
    logger.info('onPaymentWritten', { payeeId: earningsPayee });
  }

  // After the earnings, so a failing payer refresh never holds back the payee's row (the retry redoes both).
  if (history !== undefined && payerRowChanged(before, after)) {
    const payerId = typeof before?.payerId === 'string' ? before.payerId : undefined;
    const result = await refreshPayerHistory(history, paymentId, after === undefined && payerId !== undefined ? { payerId } : undefined);
    logger.info('onPaymentWritten payer row', { paymentId, result });
  }
  return earningsPayee;
}
