import * as logger from 'firebase-functions/logger';
import { refreshPayerHistoryOfSubject, type InstantRequest, type PayerHistoryDeps } from '@photobooking/domain';

/**
 * S22.01 (#141): a Chụp ngay request that changes status without a payment write (searching or
 * choosing → no_match and back) changes its payer row ("đang tìm thợ"): refresh it. Only on a
 * `status` change of an existing request; idempotent.
 */
export async function handleInstantPayerRows(
  requestId: string,
  before: Pick<InstantRequest, 'status'> | null,
  after: Pick<InstantRequest, 'status'> | null,
  deps: PayerHistoryDeps,
): Promise<number> {
  if (before === null || after === null || before.status === after.status) return 0;
  const n = await refreshPayerHistoryOfSubject(deps, 'instant_request', requestId);
  if (n > 0) logger.info('onInstantRequestWrite payer rows', { requestId, n });
  return n;
}
