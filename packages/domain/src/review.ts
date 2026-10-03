import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const REVIEW_TEXT_MIN = 10;
export const REVIEW_TEXT_MAX = 1000;
export const REVIEW_PHOTOS_MAX = 10;

export interface ReviewPhoto {
  readonly url: string;
  readonly storagePath: string;
  readonly blurHash: string | null;
  readonly w: number | null;
  readonly h: number | null;
}

export interface ReviewInput {
  readonly bookingId: string;
  readonly rating: number;
  readonly text: string;
  readonly postId: string | null;
  readonly photos: readonly ReviewPhoto[];
}

export interface Review {
  readonly bookingId: string;
  readonly customerId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly rating: number;
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

  if (
    typeof r.rating !== 'number' ||
    !Number.isInteger(r.rating) ||
    r.rating < 1 ||
    r.rating > 5
  ) {
    throw new DomainError('invalid_argument');
  }

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
      rating: r.rating,
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
    rating: r.rating,
    text: trimmed,
    postId,
    photos: validatedPhotos,
  };
}
