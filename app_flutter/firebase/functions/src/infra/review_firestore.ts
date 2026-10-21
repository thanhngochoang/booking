import {
  type DocumentData,
  FieldValue,
  type Firestore,
  Timestamp,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  intensityOf,
  REVIEW_HITS_MAX,
  REVIEW_REASONS,
  REVIEW_SUBJECT_TYPES,
  STUDIO_BRICK_REASONS,
  VERDICTS,
  type RealShootPost,
  type Review,
  type ReviewReason,
  type StudioBrickReason,
  type ReviewStore,
  type ReviewTx,
  type StatsStore,
  type StatsTx,
  type Verdict,
} from '@photobooking/domain';
import {
  BOOKINGS_COLLECTION,
  bookingFromFirestore,
  bookingToFirestore,
} from './booking_firestore.js';

export const REVIEWS_COLLECTION = 'reviews';
export const POSTS_COLLECTION = 'posts';
export const PHOTOGRAPHERS_COLLECTION = 'photographers';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return null;
}

/** `reviews/{reviewId}` fields (the id is the document id). No `rating` is written. */
export function reviewToFirestore(r: Review): DocumentData {
  return {
    bookingId: r.bookingId,
    subjectType: r.subjectType,
    subjectId: r.subjectId,
    photographerId: r.photographerId,
    customerId: r.customerId,
    serviceId: r.serviceId,
    serviceName: r.serviceName,
    bookingDay: r.bookingDay,
    verdict: r.verdict,
    hits: r.hits,
    intensity: r.intensity,
    reasons: [...r.reasons],
    text: r.text,
    photoPostId: r.photoPostId ?? null,
    createdAt: Timestamp.fromDate(r.createdAt),
    countedAt: r.countedAt ? Timestamp.fromDate(r.countedAt) : null,
    ...(r.viaStudioId !== undefined ? { viaStudioId: r.viaStudioId } : {}),
    ...(r.viaStudioName !== undefined ? { viaStudioName: r.viaStudioName } : {}),
    ...(r.assigneeId !== undefined ? { assigneeId: r.assigneeId } : {}),
    ...(r.assigneeName !== undefined ? { assigneeName: r.assigneeName } : {}),
  };
}

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

function isHits(v: unknown): v is number {
  return typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= REVIEW_HITS_MAX;
}

/**
 * Tolerant reader. A legacy star doc (no `verdict`, from a saved emulator export) reads as
 * `tomato` when `rating >= 4`, else `brick`, with one hit and no reasons (display only).
 */
export function reviewFromFirestore(
  id: string,
  d: DocumentData | undefined
): Review | null {
  if (!d) return null;
  const createdAt = toDate(d.createdAt);
  if (!createdAt) return null;

  const known = VERDICTS.find((v) => v === d.verdict);
  const verdict: Verdict =
    known ?? (typeof d.rating === 'number' && d.rating >= 4 ? 'tomato' : 'brick');
  const hits = known !== undefined && isHits(d.hits) ? d.hits : 1;
  const intensity =
    known !== undefined && typeof d.intensity === 'number' && Number.isFinite(d.intensity)
      ? d.intensity
      : intensityOf(hits);
  const reasons: (ReviewReason | StudioBrickReason)[] = [];
  const allowed: readonly (ReviewReason | StudioBrickReason)[] =
    d.subjectType === 'studio' ? STUDIO_BRICK_REASONS : REVIEW_REASONS;
  if (known === 'brick' && Array.isArray(d.reasons)) {
    for (const x of d.reasons as unknown[]) {
      const reason = allowed.find((r) => r === x);
      if (reason !== undefined && !reasons.includes(reason)) reasons.push(reason);
    }
  }
  const photographerId = str(d.photographerId);
  const subjectType = REVIEW_SUBJECT_TYPES.find((t) => t === d.subjectType) ?? 'photographer';
  const subjectId = str(d.subjectId) || photographerId;

  return {
    id,
    bookingId: str(d.bookingId) || id,
    subjectType,
    subjectId,
    photographerId: photographerId || subjectId,
    customerId: str(d.customerId),
    serviceId: str(d.serviceId),
    serviceName: str(d.serviceName),
    bookingDay: str(d.bookingDay),
    verdict,
    hits,
    intensity,
    reasons,
    text: str(d.text),
    photoPostId: typeof d.photoPostId === 'string' ? d.photoPostId : null,
    createdAt,
    countedAt: toDate(d.countedAt),
    ...(typeof d.viaStudioId === 'string' ? { viaStudioId: d.viaStudioId } : {}),
    ...(typeof d.viaStudioName === 'string' ? { viaStudioName: d.viaStudioName } : {}),
    ...(typeof d.assigneeId === 'string' ? { assigneeId: d.assigneeId } : {}),
    ...(typeof d.assigneeName === 'string' ? { assigneeName: d.assigneeName } : {}),
  };
}

export function realShootPostToFirestore(p: RealShootPost): DocumentData {
  return {
    kind: 'real_shoot',
    authorId: p.authorId,
    photographerId: p.photographerId,
    serviceId: p.serviceId,
    bookingId: p.bookingId,
    ...(p.assigneeId !== undefined ? { assigneeId: p.assigneeId } : {}),
    imageUrls: [...p.imageUrls],
    imageMeta: p.imageMeta.map((m) => ({
      blurHash: m.blurHash ?? null,
      w: m.w ?? null,
      h: m.h ?? null,
    })),
    caption: p.caption,
    location: p.locationName ? { name: p.locationName } : null,
    likeCount: 0,
    saveCount: 0,
    inPortfolio: false,
    createdAt: Timestamp.fromDate(p.createdAt),
  };
}

export class FirestoreReviewStore implements ReviewStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: ReviewTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const tx: ReviewTx = {
        getBooking: async (id) => {
          const snap = await fTx.get(
            this.firestore.collection(BOOKINGS_COLLECTION).doc(id)
          );
          return bookingFromFirestore(snap.id, snap.data());
        },
        getReview: async (reviewId) => {
          const snap = await fTx.get(
            this.firestore.collection(REVIEWS_COLLECTION).doc(reviewId)
          );
          return reviewFromFirestore(snap.id, snap.data());
        },
        getUserName: async (uid) => {
          const snap = await fTx.get(this.firestore.collection('users').doc(uid));
          const name: unknown = snap.data()?.displayName;
          return typeof name === 'string' && name !== '' ? name : null;
        },
        setBooking: (b) => {
          fTx.set(
            this.firestore.collection(BOOKINGS_COLLECTION).doc(b.id),
            bookingToFirestore(b)
          );
        },
        addBookingEvent: (event) => {
          const ref = this.firestore
            .collection(BOOKINGS_COLLECTION)
            .doc(event.bookingId)
            .collection('events')
            .doc(event.id);
          fTx.set(ref, {
            status: event.status,
            at: Timestamp.fromDate(new Date(event.at)),
            actorId: event.actorId ?? null,
          });
        },
        setReview: (r) => {
          fTx.set(
            this.firestore.collection(REVIEWS_COLLECTION).doc(r.id),
            reviewToFirestore(r)
          );
        },
        createPost: (p) => {
          fTx.set(
            this.firestore.collection(POSTS_COLLECTION).doc(p.id),
            realShootPostToFirestore(p)
          );
        },
      };

      return fn(tx);
    });
  }
}

export class FirestoreStatsStore implements StatsStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const tx: StatsTx = {
        getReview: async (id) => {
          const snap = await fTx.get(
            this.firestore.collection(REVIEWS_COLLECTION).doc(id)
          );
          return reviewFromFirestore(snap.id, snap.data());
        },
        getPhotographerStats: async (uid) => {
          const snap = await fTx.get(
            this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid)
          );
          const data = snap.data();
          if (!data || typeof data.stats !== 'object' || data.stats === null) {
            return null;
          }
          return data.stats as Record<string, unknown>;
        },
        // merge: true keeps the other stats fields (completedCount, responseMinutes, nextFreeDate, …);
        // the legacy star fields go on the first verdict write.
        setPhotographerStats: (uid, patch) => {
          fTx.set(
            this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid),
            {
              stats: {
                ...patch,
                rating: FieldValue.delete(),
                ratingSum: FieldValue.delete(),
              },
            },
            { merge: true }
          );
        },
        markCounted: (reviewId, at) => {
          fTx.update(
            this.firestore.collection(REVIEWS_COLLECTION).doc(reviewId),
            {
              countedAt: Timestamp.fromDate(at),
            }
          );
        },
      };

      return fn(tx);
    });
  }
}
