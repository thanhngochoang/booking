import * as logger from 'firebase-functions/logger';
import { refreshPayerHistory, type PayerHistoryDeps } from '@photobooking/domain';

type Doc = { readonly paymentId?: unknown; readonly [field: string]: unknown } | undefined;

const paymentOf = (d: Doc): string | undefined =>
  typeof d?.paymentId === 'string' && d.paymentId !== '' ? d.paymentId : undefined;

/**
 * Every refund write (created, sent, done, failed, waiting for an account) refreshes the payer's
 * S22.01 row of its payment and their totals (#141 Decision 1). Idempotent; safe to replay.
 */
export async function handleRefundWrite(
  refundId: string,
  before: Doc,
  after: Doc,
  deps: PayerHistoryDeps,
): Promise<'written' | 'deleted' | 'missing' | null> {
  const paymentId = paymentOf(after) ?? paymentOf(before);
  if (paymentId === undefined) return null;
  const result = await refreshPayerHistory(deps, paymentId);
  logger.info('onRefundWritten', { refundId, paymentId, result });
  return result;
}
