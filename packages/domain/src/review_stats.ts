import type { Review } from './review.js';

export interface PhotographerStatsPatch {
  readonly ratingSum: number;
  readonly reviewCount: number;
  readonly rating: number;
  /** Reviews that praise punctuality ("đúng giờ"); feeds the `punctual` badge. */
  readonly punctualMentions: number;
}

/** Case- and diacritic-insensitive match on "đúng giờ" (folded: "dung gio"). */
export function mentionsPunctual(text: string): boolean {
  const folded = text
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
  return folded.includes('dung gio');
}

export function addRating(
  current: { ratingSum?: unknown; reviewCount?: unknown; punctualMentions?: unknown },
  rating: number,
  punctual = false
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

  const currentPunctual =
    typeof current.punctualMentions === 'number' &&
    Number.isInteger(current.punctualMentions) &&
    current.punctualMentions >= 0
      ? current.punctualMentions
      : 0;

  const ratingSum = currentSum + rating;
  const reviewCount = currentCount + 1;
  const rawRating = ratingSum / reviewCount;
  const roundedRating = Math.round(rawRating * 10) / 10;

  return {
    ratingSum,
    reviewCount,
    rating: roundedRating,
    punctualMentions: currentPunctual + (punctual ? 1 : 0),
  };
}

export interface StatsTx {
  getReview(id: string): Promise<Review | null>;
  getPhotographerStats(
    uid: string
  ): Promise<{ ratingSum?: unknown; reviewCount?: unknown; punctualMentions?: unknown } | null>;
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
    const patch = addRating(currentStats ?? {}, review.rating, mentionsPunctual(review.text));

    tx.setPhotographerStats(review.photographerId, patch);
    tx.markCounted(bookingId, now);

    return 'counted';
  });
}
