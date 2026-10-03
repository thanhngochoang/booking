import type { Review } from './review.js';

export interface PhotographerStatsPatch {
  readonly ratingSum: number;
  readonly reviewCount: number;
  readonly rating: number;
}

export function addRating(
  current: { ratingSum?: unknown; reviewCount?: unknown },
  rating: number
): PhotographerStatsPatch {
  const currentSum =
    typeof current.ratingSum === 'number' &&
    Number.isInteger(current.ratingSum) &&
    current.ratingSum >= 0
      ? current.ratingSum
      : 0;

  const currentCount =
    typeof current.reviewCount === 'number' &&
    Number.isInteger(current.reviewCount) &&
    current.reviewCount >= 0
      ? current.reviewCount
      : 0;

  const ratingSum = currentSum + rating;
  const reviewCount = currentCount + 1;
  const rawRating = ratingSum / reviewCount;
  const roundedRating = Math.round(rawRating * 10) / 10;

  return {
    ratingSum,
    reviewCount,
    rating: roundedRating,
  };
}

export interface StatsTx {
  getReview(id: string): Promise<Review | null>;
  getPhotographerStats(
    uid: string
  ): Promise<{ ratingSum?: unknown; reviewCount?: unknown } | null>;
  setPhotographerStats(uid: string, patch: PhotographerStatsPatch): void;
  markCounted(bookingId: string, at: Date): void;
}

export interface StatsStore {
  runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T>;
}

export async function countReview(
  store: StatsStore,
  bookingId: string,
  now: Date
): Promise<'counted' | 'already'> {
  return store.runTransaction(async (tx) => {
    const review = await tx.getReview(bookingId);
    if (review === null || review.countedAt !== null) {
      return 'already';
    }

    const currentStats = await tx.getPhotographerStats(review.photographerId);
    const patch = addRating(currentStats ?? {}, review.rating);

    tx.setPhotographerStats(review.photographerId, patch);
    tx.markCounted(bookingId, now);

    return 'counted';
  });
}
