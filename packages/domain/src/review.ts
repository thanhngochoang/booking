import type { BookingStatus } from './booking.js';
import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const REVIEW_TEXT_MIN = 10;
export const REVIEW_TEXT_MAX = 1000;
export const REVIEW_PHOTOS_MAX = 10;
/** Most hits a customer can throw (spec §4.1). */
export const REVIEW_HITS_MAX = 10;
/** Intensity of a single hit; ten hits reach 1. */
export const INTENSITY_FLOOR = 0.4;
/** Fewer reviews than this show "Mới" instead of a tomato percentage. */
export const TOMATO_PCT_MIN_REVIEWS = 5;

export const VERDICTS = ['tomato', 'brick'] as const;
export type Verdict = (typeof VERDICTS)[number];

export const REVIEW_REASONS = [
  'late',
  'not_as_portfolio',
  'slow_delivery',
  'attitude',
  'price_changed',
  'other',
] as const;
export type ReviewReason = (typeof REVIEW_REASONS)[number];

export const REVIEW_SUBJECT_TYPES = ['photographer', 'studio'] as const;
export type ReviewSubjectType = (typeof REVIEW_SUBJECT_TYPES)[number];

const round2 = (x: number): number => Math.round(x * 100) / 100;

/** Weight of a verdict thrown with `hits` taps: round2(0.4 + 0.6 * log10(hits)), hits in 1..10. */
export function intensityOf(hits: number): number {
  if (!Number.isInteger(hits) || hits < 1 || hits > REVIEW_HITS_MAX) {
    throw new DomainError('invalid_argument');
  }
  return round2(INTENSITY_FLOOR + (1 - INTENSITY_FLOOR) * Math.log10(hits));
}

/** `bookingId` for the photographer review, `{bookingId}_studio` for the studio review. */
export function reviewDocId(bookingId: string, subjectType: ReviewSubjectType): string {
  return subjectType === 'studio' ? `${bookingId}_studio` : bookingId;
}

/** A booking can be reviewed once the shoot is completed. */
export function isReviewable(status: BookingStatus): boolean {
  return status === 'completed';
}

export interface ReviewPhoto {
  readonly url: string;
  readonly storagePath: string;
  readonly blurHash: string | null;
  readonly w: number | null;
  readonly h: number | null;
}

export interface ReviewInput {
  readonly bookingId: string;
  readonly verdict: Verdict;
  readonly hits: number;
  readonly reasons: readonly ReviewReason[];
  readonly text: string;
  readonly postId: string | null;
  readonly photos: readonly ReviewPhoto[];
}

export interface Review {
  /** `reviewDocId(bookingId, subjectType)`. */
  readonly id: string;
  readonly bookingId: string;
  readonly subjectType: ReviewSubjectType;
  /** The account whose stats this review counts into. */
  readonly subjectId: string;
  /** Equal to `subjectId`; keeps the profile query working. */
  readonly photographerId: string;
  readonly customerId: string;
  readonly serviceId: string;
  /** Snapshot of the booked service name, for display. */
  readonly serviceName: string;
  /** Snapshot of the booking day (yyyy-MM-dd), for display. */
  readonly bookingDay: string;
  readonly verdict: Verdict;
  readonly hits: number;
  /** Server only: `intensityOf(hits)`. */
  readonly intensity: number;
  readonly reasons: readonly ReviewReason[];
  readonly text: string;
  readonly photoPostId: string | null;
  readonly createdAt: Date;
  readonly countedAt: Date | null;
}

export interface RealShootPost {
  readonly id: string;
  readonly authorId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly bookingId: string;
  readonly imageUrls: readonly string[];
  readonly imageMeta: readonly {
    blurHash: string | null;
    w: number | null;
    h: number | null;
  }[];
  readonly caption: string;
  readonly locationName: string | null;
  readonly createdAt: Date;
}

export function validateReviewInput(
  raw: unknown,
  callerId: string,
  urlPrefixes: readonly string[]
): ReviewInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const r = raw as Record<string, unknown>;

  if (typeof r.bookingId !== 'string' || !isId(r.bookingId)) {
    throw new DomainError('invalid_argument');
  }

  const verdict = VERDICTS.find((v) => v === r.verdict);
  if (verdict === undefined) {
    throw new DomainError('invalid_argument');
  }

  if (
    typeof r.hits !== 'number' ||
    !Number.isInteger(r.hits) ||
    r.hits < 1 ||
    r.hits > REVIEW_HITS_MAX
  ) {
    throw new DomainError('invalid_argument');
  }
  const hits = r.hits;

  const reasons = validateReasons(verdict, r.reasons);

  if (typeof r.text !== 'string') {
    throw new DomainError('invalid_argument');
  }

  const trimmed = r.text.trim();
  const textLength = graphemeCount(trimmed);
  if (textLength < REVIEW_TEXT_MIN || textLength > REVIEW_TEXT_MAX) {
    throw new DomainError('invalid_argument');
  }

  const rawPhotos = r.photos;
  let photosList: unknown[] = [];
  if (rawPhotos !== undefined && rawPhotos !== null) {
    if (!Array.isArray(rawPhotos)) {
      throw new DomainError('invalid_argument');
    }
    photosList = rawPhotos;
  }

  if (photosList.length > REVIEW_PHOTOS_MAX) {
    throw new DomainError('invalid_argument');
  }

  if (photosList.length === 0) {
    return {
      bookingId: r.bookingId,
      verdict,
      hits,
      reasons,
      text: trimmed,
      postId: null,
      photos: [],
    };
  }

  if (typeof r.postId !== 'string' || !isId(r.postId)) {
    throw new DomainError('invalid_argument');
  }

  const postId = r.postId;
  const expectedStoragePathPrefix = `posts/${callerId}/${postId}/`;

  const validatedPhotos: ReviewPhoto[] = [];
  for (const item of photosList) {
    if (typeof item !== 'object' || item === null) {
      throw new DomainError('invalid_argument');
    }
    const p = item as Record<string, unknown>;

    if (
      typeof p.storagePath !== 'string' ||
      !p.storagePath.startsWith(expectedStoragePathPrefix)
    ) {
      throw new DomainError('invalid_argument');
    }

    if (typeof p.url !== 'string') {
      throw new DomainError('invalid_argument');
    }

    const encodedStoragePath = encodeURIComponent(p.storagePath);
    const matchesPrefix = urlPrefixes.some((prefix) =>
      (p.url as string).startsWith(`${prefix}${encodedStoragePath}`)
    );
    if (!matchesPrefix) {
      throw new DomainError('invalid_argument');
    }

    const blurHash =
      typeof p.blurHash === 'string' ? p.blurHash : null;
    const w = typeof p.w === 'number' && Number.isFinite(p.w) ? p.w : null;
    const h = typeof p.h === 'number' && Number.isFinite(p.h) ? p.h : null;

    validatedPhotos.push({
      url: p.url,
      storagePath: p.storagePath,
      blurHash,
      w,
      h,
    });
  }

  return {
    bookingId: r.bookingId,
    verdict,
    hits,
    reasons,
    text: trimmed,
    postId,
    photos: validatedPhotos,
  };
}

/** A brick needs one or more distinct known reasons; a tomato has none. */
function validateReasons(verdict: Verdict, raw: unknown): readonly ReviewReason[] {
  if (verdict === 'tomato') {
    if (raw === undefined || raw === null) return [];
    if (Array.isArray(raw) && raw.length === 0) return [];
    throw new DomainError('invalid_argument');
  }
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > REVIEW_REASONS.length) {
    throw new DomainError('invalid_argument');
  }
  const reasons: ReviewReason[] = [];
  for (const item of raw) {
    const reason = REVIEW_REASONS.find((x) => x === item);
    if (reason === undefined || reasons.includes(reason)) {
      throw new DomainError('invalid_argument');
    }
    reasons.push(reason);
  }
  return reasons;
}
