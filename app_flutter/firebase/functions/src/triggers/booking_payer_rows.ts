import * as logger from 'firebase-functions/logger';
import { refreshPayerHistoryOfSubject, type PayerHistoryDeps } from '@photobooking/domain';

type Doc = { readonly status?: unknown; readonly day?: unknown; readonly photographerId?: unknown; readonly [field: string]: unknown } | undefined;

/**
 * S22.01 (#141): a booking change that touches no payment (a cancel with no refund, a decline,
 * a reschedule, a studio reassignment) still changes what its payer rows show ("đã huỷ", the day,
 * the photographer): refresh them. Only on `status`, `day` or `photographerId` changes of an
 * existing booking; idempotent.
 */
export async function handleBookingPayerRows(
  bookingId: string,
  before: Doc,
  after: Doc,
  deps: PayerHistoryDeps,
): Promise<number> {
  if (before === undefined || after === undefined) return 0;
  if (before.status === after.status && before.day === after.day && before.photographerId === after.photographerId) return 0;
  const n = await refreshPayerHistoryOfSubject(deps, 'booking', bookingId);
  if (n > 0) logger.info('onBookingWrite payer rows', { bookingId, n });
  return n;
}
