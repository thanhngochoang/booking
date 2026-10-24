import * as logger from 'firebase-functions/logger';
import { PLATFORM_PAYEE, refreshEarnings, type EarningsDeps } from '@photobooking/domain';
import { db } from '../infra/admin.js';

type Doc = { payeeId?: unknown; subjectType?: unknown; subjectId?: unknown; milestones?: unknown } | undefined;

const payeeOf = (d: Doc): string | undefined => (typeof d?.payeeId === 'string' && d.payeeId !== '' ? d.payeeId : undefined);

/**
 * A payment write refreshes the payee's earnings row and totals, and syncs milestone subcollection.
 * When the payee changed (#202: an instant photographer cancelled, `payeeId` back to `''`, then another
 * accepted), the old payee is refreshed too so their row goes. Idempotent; safe to retry.
 */
export async function handlePaymentWrite(
  paymentId: string,
  before: Doc,
  after: Doc,
  deps: EarningsDeps,
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
  // Platform-hosted event tickets: the platform keeps the money; it has no earnings page.
  if (payeeId === undefined || payeeId === PLATFORM_PAYEE) return null;
  await refreshEarnings(deps, { payeeId, paymentIds: [paymentId] });
  logger.info('onPaymentWritten', { payeeId });
  return payeeId;
}
