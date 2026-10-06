import * as logger from 'firebase-functions/logger';
import { refreshEarnings, type EarningsDeps } from '@photobooking/domain';

type Doc = { payeeId?: unknown } | undefined;

const payeeOf = (d: Doc): string | undefined => (typeof d?.payeeId === 'string' && d.payeeId !== '' ? d.payeeId : undefined);

/** A payment write refreshes the payee's earnings row and totals. Idempotent; safe to retry. */
export async function handlePaymentWrite(
  paymentId: string,
  before: Doc,
  after: Doc,
  deps: EarningsDeps,
): Promise<string | null> {
  const payeeId = payeeOf(after) ?? payeeOf(before);
  if (payeeId === undefined) return null;
  await refreshEarnings(deps, { payeeId, paymentIds: [paymentId] });
  logger.info('onPaymentWritten', { payeeId });
  return payeeId;
}
