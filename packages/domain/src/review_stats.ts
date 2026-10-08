import type { Review, Verdict } from './review.js';

export interface PhotographerStatsPatch {
  /** Always `tomatoCount + brickCount`; a legacy star `reviewCount` is never read. */
  readonly reviewCount: number;
  readonly tomatoCount: number;
  readonly brickCount: number;
  /** Sum of +intensity (tomato) and -intensity (brick), 2 decimals. */
  readonly signedSum: number;
  /** Integer 0..100, 0 without reviews. */
  readonly tomatoPct: number;
  /** signedSum / reviewCount, 3 decimals, -1..1. */
  readonly score: number;
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

const round2 = (x: number): number => Math.round(x * 100) / 100;

export function addVerdict(
  current: Record<string, unknown>,
  verdict: Verdict,
  intensity: number,
  punctual = false
): PhotographerStatsPatch {
  const n = (k: string): number =>
    typeof current[k] === 'number' && Number.isFinite(current[k]) && (current[k] as number) >= 0
      ? (current[k] as number)
      : 0;
  const tomatoCount = Math.trunc(n('tomatoCount')) + (verdict === 'tomato' ? 1 : 0);
  const brickCount = Math.trunc(n('brickCount')) + (verdict === 'brick' ? 1 : 0);
  const reviewCount = tomatoCount + brickCount; // never the legacy reviewCount
  const prevSigned =
    typeof current.signedSum === 'number' && Number.isFinite(current.signedSum)
      ? current.signedSum
      : 0;
  const signedSum = round2(prevSigned + (verdict === 'tomato' ? intensity : -intensity));
  return {
    reviewCount,
    tomatoCount,
    brickCount,
    signedSum,
    tomatoPct: Math.round((100 * tomatoCount) / reviewCount),
    score: Math.round((signedSum / reviewCount) * 1000) / 1000,
    punctualMentions: Math.trunc(n('punctualMentions')) + (punctual ? 1 : 0),
  };
}

export interface StatsTx {
  getReview(id: string): Promise<Review | null>;
  getPhotographerStats(uid: string): Promise<Record<string, unknown> | null>;
  setPhotographerStats(uid: string, patch: PhotographerStatsPatch): void;
  markCounted(reviewId: string, at: Date): void;
}

export interface StatsStore {
  runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T>;
}

/** Counts a review once into the account named by `review.subjectId`. */
export async function countReview(
  store: StatsStore,
  reviewId: string,
  now: Date
): Promise<'counted' | 'already'> {
  return store.runTransaction(async (tx) => {
    const review = await tx.getReview(reviewId);
    if (review === null || review.countedAt !== null) {
      return 'already';
    }

    const currentStats = await tx.getPhotographerStats(review.subjectId);
    const patch = addVerdict(
      currentStats ?? {},
      review.verdict,
      review.intensity,
      mentionsPunctual(review.text)
    );

    tx.setPhotographerStats(review.subjectId, patch);
    tx.markCounted(reviewId, now);

    return 'counted';
  });
}
