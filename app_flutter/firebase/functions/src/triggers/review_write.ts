import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { countReview, type StatsStore } from '@photobooking/domain';

export interface ReviewWriteInput {
  readonly bookingId: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

/**
 * Hook for awarding badges after a review is counted.
 * No-op in phase 1 (Decision 7); will be filled by the badges plan.
 */
export async function awardBadgesAfterReview(
  photographerId: string
): Promise<void> {
  // No-op for now; placeholder for badges plan (Decision 7).
  void photographerId;
}

export async function handleReviewWrite(
  input: ReviewWriteInput,
  store: StatsStore,
  now: Date = new Date()
): Promise<'counted' | 'already' | 'skipped'> {
  // Only process on create
  if (input.before !== undefined || input.after === undefined) {
    return 'skipped';
  }

  const outcome = await countReview(store, input.bookingId, now);
  if (outcome === 'counted') {
    const photographerId = String(input.after.photographerId ?? '');
    if (photographerId) {
      await awardBadgesAfterReview(photographerId);
    }
    logger.info('onReviewWrite', { bookingId: input.bookingId, outcome });
  }

  return outcome;
}
