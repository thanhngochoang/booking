import * as logger from 'firebase-functions/logger';
import { notifyPayoutReleased, refreshEarnings, type EarningsDeps, type NotifyDeps } from '@photobooking/domain';

type Doc = { payeeId?: unknown; items?: unknown; status?: unknown; amount?: unknown; amountNet?: unknown } | undefined;

const payeeOf = (d: Doc): string | undefined => (typeof d?.payeeId === 'string' && d.payeeId !== '' ? d.payeeId : undefined);

function idsOf(d: Doc): string[] {
  if (!Array.isArray(d?.items)) return [];
  return (d.items as { paymentId?: unknown }[]).flatMap((i) => (typeof i?.paymentId === 'string' ? [i.paymentId] : []));
}

const money = (v: unknown): number | undefined => (typeof v === 'number' && Number.isFinite(v) ? v : undefined);

/**
 * A payout write (batch created, held, paid, failed) refreshes the rows of every payment in it,
 * before or after: a failed payout empties `payoutId` on its payments, and the paid date of a
 * row comes from the payout. When the payout becomes `paid`, the payee gets `payout_released`
 * (S17 Decision 5: `amountNet` when the doc has it, else `amount`). The refresh runs first; a
 * notification failure is rethrown after it so the trigger retries (dedupe
 * `payout_released_{payoutId}` prevents a second row). Idempotent; safe to retry.
 */
export async function handlePayoutWrite(
  payoutId: string,
  before: Doc,
  after: Doc,
  deps: EarningsDeps,
  notify?: NotifyDeps,
): Promise<string | null> {
  const payeeId = payeeOf(after) ?? payeeOf(before);
  if (payeeId === undefined) return null;
  const paymentIds = [...new Set([...idsOf(before), ...idsOf(after)])];
  await refreshEarnings(deps, { payeeId, paymentIds });
  logger.info('onPayoutWritten', { payeeId, payments: paymentIds.length });

  if (notify !== undefined && before?.status !== 'paid' && after?.status === 'paid') {
    const amount = money(after.amountNet) ?? money(after.amount);
    if (amount === undefined) {
      logger.warn('onPayoutWritten payout_released skipped: no amount', { payoutId });
      return payeeId;
    }
    try {
      await notifyPayoutReleased(notify, { payoutId, payeeId, amount, count: idsOf(after).length });
    } catch (e) {
      logger.error('onPayoutWritten payout_released failed', { payoutId, error: e instanceof Error ? e.name : 'unknown' });
      throw e;
    }
  }
  return payeeId;
}
