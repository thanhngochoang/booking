import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { countReview, evaluateUserBadges, notifyReviewVerdict, type BadgeDeps, type StatsStore } from '@photobooking/domain';
import { reviewFromFirestore } from '../infra/review_firestore.js';

export interface ReviewWriteInput {
  /** `reviewDocId(bookingId, subjectType)`: the booking id, or `{bookingId}_studio`. */
  readonly reviewId: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

/**
 * `reviews/{reviewId}` created: count it into the subject's stats once, then the verdict notice
 * (#138's `notifyReviewVerdict`, the only caller) and badges for subject and customer.
 */
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

  const outcome = await countReview(store, input.reviewId, now);
  const review = reviewFromFirestore(input.reviewId, input.after);
  // A review born counted (seed or import) was never submitted: nothing to announce.
  const imported = review !== null && review.countedAt !== null;
  // Notice and badges are idempotent (#138's dedupe key review_{verdict}_{bookingId}_{subjectUserId}),
  // so a retry after a failure finds the review already counted and still completes them.
  if (badges && review && !imported && review.subjectId !== '') {
    await notifyReviewVerdict(badges.notify, {
      bookingId: review.bookingId,
      subjectUserId: review.subjectId,
      customerId: review.customerId,
      verdict: review.verdict,
      hits: review.hits,
      day: review.bookingDay,
      text: review.text,
    });
    // Both sides are evaluated even when one fails; the event is then retried (the retry sees 'already').
    const results = await Promise.allSettled(
      [review.subjectId, review.customerId].filter((u) => u !== '').map((u) => evaluateUserBadges(badges, u)),
    );
    const failed = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
    if (failed) throw new Error(`badge evaluation failed after review: ${String(failed.reason)}`);
  }
  logger.info('onReviewWrite', { reviewId: input.reviewId, outcome });

  return outcome;
}
