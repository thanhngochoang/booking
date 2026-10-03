import {
  type DocumentData,
  type Firestore,
  Timestamp,
  type Transaction,
} from 'firebase-admin/firestore';
import type {
  RealShootPost,
  Review,
  ReviewStore,
  ReviewTx,
  StatsStore,
  StatsTx,
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

export function reviewToFirestore(r: Review): DocumentData {
  return {
    bookingId: r.bookingId,
    customerId: r.customerId,
    photographerId: r.photographerId,
    serviceId: r.serviceId,
    rating: r.rating,
    text: r.text,
    photoPostId: r.photoPostId ?? null,
    createdAt: Timestamp.fromDate(r.createdAt),
    countedAt: r.countedAt ? Timestamp.fromDate(r.countedAt) : null,
  };
}

export function reviewFromFirestore(
  id: string,
  d: DocumentData | undefined
): Review | null {
  if (!d) return null;
  const createdAt = toDate(d.createdAt);
  if (!createdAt) return null;

  return {
    bookingId: id,
    customerId: typeof d.customerId === 'string' ? d.customerId : '',
    photographerId: typeof d.photographerId === 'string' ? d.photographerId : '',
    serviceId: typeof d.serviceId === 'string' ? d.serviceId : '',
    rating: typeof d.rating === 'number' ? d.rating : 5,
    text: typeof d.text === 'string' ? d.text : '',
    photoPostId: typeof d.photoPostId === 'string' ? d.photoPostId : null,
    createdAt,
    countedAt: toDate(d.countedAt),
  };
}

export function realShootPostToFirestore(p: RealShootPost): DocumentData {
  return {
    kind: 'real_shoot',
    authorId: p.authorId,
    photographerId: p.photographerId,
    serviceId: p.serviceId,
    bookingId: p.bookingId,
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
        getReview: async (bookingId) => {
          const snap = await fTx.get(
            this.firestore.collection(REVIEWS_COLLECTION).doc(bookingId)
          );
          return reviewFromFirestore(snap.id, snap.data());
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
            this.firestore.collection(REVIEWS_COLLECTION).doc(r.bookingId),
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
          return data.stats as { ratingSum?: unknown; reviewCount?: unknown };
        },
        setPhotographerStats: (uid, patch) => {
          fTx.set(
            this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid),
            { stats: patch },
            { merge: true }
          );
        },
        markCounted: (bookingId, at) => {
          fTx.update(
            this.firestore.collection(REVIEWS_COLLECTION).doc(bookingId),
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
