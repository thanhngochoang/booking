import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { countReview, evaluateUserBadges, notify, type BadgeDeps, type StatsStore } from '@photobooking/domain';

export interface ReviewWriteInput {
  readonly bookingId: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

export async function handleReviewWrite(
  input: ReviewWriteInput,
  store: StatsStore,
  now: Date = new Date(),
  badges?: BadgeDeps,
): Promise<'counted' | 'already' | 'skipped'> {
  // Only process on create
  if (input.before !== undefined || input.after === undefined) {
    return 'skipped';
  }

  const outcome = await countReview(store, input.bookingId, now);
  if (outcome === 'counted') {
    const photographerId = String(input.after.photographerId ?? '');
    const customerId = String(input.after.customerId ?? '');
    if (badges && photographerId) {
      await notifyNewReview(badges, input.bookingId, photographerId, customerId, input.after);
      // Both sides are evaluated even when one fails; the event is retried afterwards (idempotent).
      const results = await Promise.allSettled(
        [photographerId, customerId].filter((u) => u !== '').map((u) => evaluateUserBadges(badges, u)),
      );
      const failed = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
      if (failed) throw new Error(`badge evaluation failed after review: ${String(failed.reason)}`);
    }
    logger.info('onReviewWrite', { bookingId: input.bookingId, outcome });
  }

  return outcome;
}

async function notifyNewReview(
  deps: BadgeDeps,
  bookingId: string,
  photographerId: string,
  customerId: string,
  review: DocumentData,
): Promise<void> {
  const customer = customerId ? await deps.notify.users.get(customerId) : null;
  const name = customer?.name ?? 'Khách hàng';
  const rating = typeof review.rating === 'number' ? review.rating : 5;
  await notify(deps.notify, {
    userId: photographerId,
    content: { type: 'review_new', customer: name, rating, text: typeof review.text === 'string' ? review.text : '' },
    target: `/u/${photographerId}?tab=reviews`,
    dedupeKey: `review_new_${bookingId}`,
    actor: { id: customerId, name, avatarUrl: customer?.avatarUrl ?? null },
    thumbUrl: customer?.avatarUrl ?? null,
  });
}
