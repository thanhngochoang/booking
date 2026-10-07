import * as logger from 'firebase-functions/logger';
import { refreshEarnings, type EarningsDeps } from '@photobooking/domain';

type Doc = { payeeId?: unknown; items?: unknown } | undefined;

const payeeOf = (d: Doc): string | undefined => (typeof d?.payeeId === 'string' && d.payeeId !== '' ? d.payeeId : undefined);

function idsOf(d: Doc): string[] {
  if (!Array.isArray(d?.items)) return [];
  return (d.items as { paymentId?: unknown }[]).flatMap((i) => (typeof i?.paymentId === 'string' ? [i.paymentId] : []));
}

/**
 * A payout write (batch created, held, paid, failed) refreshes the rows of every payment in it,
 * before or after: a failed payout empties `payoutId` on its payments, and the paid date of a
 * row comes from the payout. Idempotent; safe to retry.
 */
export async function handlePayoutWrite(before: Doc, after: Doc, deps: EarningsDeps): Promise<string | null> {
  const payeeId = payeeOf(after) ?? payeeOf(before);
  if (payeeId === undefined) return null;
  const paymentIds = [...new Set([...idsOf(before), ...idsOf(after)])];
  await refreshEarnings(deps, { payeeId, paymentIds });
  logger.info('onPayoutWritten', { payeeId, payments: paymentIds.length });
  return payeeId;
}
