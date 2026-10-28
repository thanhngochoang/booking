import * as logger from 'firebase-functions/logger';
import {
  announceRefundAccountNeeded,
  refreshPayerHistory,
  type BookingStore,
  type NotifyDeps,
  type PayerHistoryDeps,
} from '@photobooking/domain';
import { refundFromFirestore } from '../infra/booking_firestore.js';
import { errorCodeOf } from '../infra/live_payout.js';

type Doc = { readonly paymentId?: unknown; readonly [field: string]: unknown } | undefined;

/** #141 Decision 6: what the `refund_account_needed` notice needs (the payer comes from the payment). */
export interface RefundNoticeDeps {
  readonly notify: NotifyDeps;
  readonly payments: Pick<BookingStore, 'getPayment'>;
}

const paymentOf = (d: Doc): string | undefined =>
  typeof d?.paymentId === 'string' && d.paymentId !== '' ? d.paymentId : undefined;

/**
 * Every refund write (created, sent, done, failed, waiting for an account) refreshes the payer's
 * S22.01 row of its payment and their totals (#141 Decision 1). A refund that enters
 * `awaiting_account` (a booking, ticket or dispute refund of a bank-QR payment) first tells its payer
 * to choose the account (S22.04; #138 dedupes by refund id). A failed notice is logged by its code
 * and never stops the row refresh. Idempotent; safe to replay.
 */
export async function handleRefundWrite(
  refundId: string,
  before: Doc,
  after: Doc,
  deps: PayerHistoryDeps,
  notice?: RefundNoticeDeps,
): Promise<'written' | 'deleted' | 'missing' | null> {
  if (notice !== undefined && after !== undefined) {
    try {
      await announceRefundAccountNeeded(
        notice,
        before === undefined ? null : refundFromFirestore(refundId, before),
        refundFromFirestore(refundId, after),
      );
    } catch (e) {
      logger.error('refund_account_needed notice failed', { refundId, code: errorCodeOf(e) });
    }
  }
  const paymentId = paymentOf(after) ?? paymentOf(before);
  if (paymentId === undefined) return null;
  const result = await refreshPayerHistory(deps, paymentId);
  logger.info('onRefundWritten', { refundId, paymentId, result });
  return result;
}
