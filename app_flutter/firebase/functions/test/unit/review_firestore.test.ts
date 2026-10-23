import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { FieldValue, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import { countReview, type RealShootPost, type Review } from '@photobooking/domain';
import {
  FirestoreReviewStore,
  FirestoreStatsStore,
  realShootPostToFirestore,
  reviewFromFirestore,
  reviewToFirestore,
} from '../../src/infra/review_firestore.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');

function review(over: Partial<Review> = {}): Review {
  return {
    id: 'book_1',
    bookingId: 'book_1',
    subjectType: 'photographer',
    subjectId: 'photo_1',
    photographerId: 'photo_1',
    customerId: 'cust_1',
    serviceId: 'svc_1',
    serviceName: 'Chân dung 2 giờ',
    bookingDay: '2026-10-08',
    verdict: 'brick',
    hits: 3,
    intensity: 0.69,
    reasons: ['late', 'slow_delivery'],
    text: 'Đến trễ 30 phút, ảnh giao sau 10 ngày.',
    photoPostId: 'post_1',
    createdAt: NOW,
    countedAt: null,
    ...over,
  };
}

interface Write {
  readonly path: string;
  readonly data: DocumentData;
  readonly opts?: unknown;
}

/** Transaction-only fake: `get` answers from `docs`, writes are recorded. */
function fakeFirestore(docs: Record<string, DocumentData>) {
  const sets: Write[] = [];
  const updates: Write[] = [];
  const ref = (path: string) => ({
    path,
    id: path.split('/').at(-1) ?? '',
    collection: (sub: string) => ({ doc: (id: string) => ref(`${path}/${sub}/${id}`) }),
  });
  const db = {
    collection: (name: string) => ({ doc: (id: string) => ref(`${name}/${id}`) }),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> =>
      fn({
        get: async (r: { path: string; id: string }) => ({
          id: r.id,
          exists: docs[r.path] !== undefined,
          data: () => docs[r.path],
        }),
        set: (r: { path: string }, data: DocumentData, opts?: unknown) => {
          sets.push({ path: r.path, data, opts });
        },
        update: (r: { path: string }, data: DocumentData) => {
          updates.push({ path: r.path, data });
        },
      }),
  } as unknown as Firestore;
  return { db, sets, updates };
}

describe('review_firestore mapping', () => {
  it('reviewToFirestore writes verdict, hits, intensity, reasons, subject fields and no rating', () => {
    const d = reviewToFirestore(review());
    assert.equal('rating' in d, false);
    assert.deepEqual(
      {
        bookingId: d.bookingId,
        subjectType: d.subjectType,
        subjectId: d.subjectId,
        photographerId: d.photographerId,
        customerId: d.customerId,
        serviceId: d.serviceId,
        serviceName: d.serviceName,
        bookingDay: d.bookingDay,
        verdict: d.verdict,
        hits: d.hits,
        intensity: d.intensity,
        reasons: d.reasons,
        text: d.text,
        photoPostId: d.photoPostId,
        countedAt: d.countedAt,
      },
      {
        bookingId: 'book_1',
        subjectType: 'photographer',
        subjectId: 'photo_1',
        photographerId: 'photo_1',
        customerId: 'cust_1',
        serviceId: 'svc_1',
        serviceName: 'Chân dung 2 giờ',
        bookingDay: '2026-10-08',
        verdict: 'brick',
        hits: 3,
        intensity: 0.69,
        reasons: ['late', 'slow_delivery'],
        text: 'Đến trễ 30 phút, ảnh giao sau 10 ngày.',
        photoPostId: 'post_1',
        countedAt: null,
      },
    );
    assert.ok(d.createdAt instanceof Timestamp);
    assert.equal('id' in d, false, 'the id is the document id, not a field');
  });

  it('reviewFromFirestore reads a verdict doc', () => {
    const tomato = review({ verdict: 'tomato', hits: 10, intensity: 1, reasons: [], countedAt: NOW });
    assert.deepEqual(reviewFromFirestore('book_1', reviewToFirestore(tomato)), tomato);
    const brick = review();
    assert.deepEqual(reviewFromFirestore('book_1', reviewToFirestore(brick)), brick);
    const studio = review({ id: 'book_1_studio', subjectType: 'studio', subjectId: 'studio_1', photographerId: 'studio_1', reasons: ['late_assignment', 'slow_response'], assigneeId: 'member_1', assigneeName: 'Minh Thợ' });
    assert.deepEqual(reviewFromFirestore('book_1_studio', reviewToFirestore(studio)), studio);
    const member = review({ viaStudioId: 'studio_1', viaStudioName: 'Studio Ánh Sáng' });
    assert.deepEqual(reviewFromFirestore('book_1', reviewToFirestore(member)), member);
  });

  it('reviewFromFirestore maps a legacy rating 5 doc to tomato ×1 and rating 2 to brick ×1', () => {
    const legacy = (rating: number) => ({
      customerId: 'cust_1',
      photographerId: 'photo_1',
      serviceId: 'svc_1',
      rating,
      text: 'Chụp rất đẹp',
      photoPostId: null,
      createdAt: Timestamp.fromDate(NOW),
      countedAt: Timestamp.fromDate(NOW),
    });
    const five = reviewFromFirestore('book_9', legacy(5));
    assert.deepEqual(five, {
      id: 'book_9',
      bookingId: 'book_9',
      subjectType: 'photographer',
      subjectId: 'photo_1',
      photographerId: 'photo_1',
      customerId: 'cust_1',
      serviceId: 'svc_1',
      serviceName: '',
      bookingDay: '',
      verdict: 'tomato',
      hits: 1,
      intensity: 0.4,
      reasons: [],
      text: 'Chụp rất đẹp',
      photoPostId: null,
      createdAt: NOW,
      countedAt: NOW,
    });
    const two = reviewFromFirestore('book_9', legacy(2));
    assert.equal(two?.verdict, 'brick');
    assert.equal(two?.hits, 1);
    assert.equal(two?.intensity, 0.4);
    assert.deepEqual(two?.reasons, []);
  });

  it('reviewFromFirestore drops unknown reason codes and returns null without createdAt', () => {
    const d = reviewToFirestore(review());
    const r = reviewFromFirestore('book_1', { ...d, reasons: ['late', 'weather', 3] });
    assert.deepEqual(r?.reasons, ['late']);
    assert.equal(reviewFromFirestore('book_1', { ...d, createdAt: null }), null);
    assert.equal(reviewFromFirestore('book_1', undefined), null);
  });

  it('RealShootPost maps to the document the feed reads', () => {
    const post: RealShootPost = {
      id: 'post_1',
      authorId: 'cust_1',
      photographerId: 'photo_1',
      serviceId: 'svc_1',
      bookingId: 'book_1',
      imageUrls: ['https://storage.test/img1.webp'],
      imageMeta: [{ blurHash: 'hash1', w: 1000, h: 800 }],
      caption: 'Chụp ảnh xuất sắc',
      locationName: 'Công viên Thống Nhất',
      createdAt: NOW,
    };

    const firestorePost = realShootPostToFirestore(post);
    assert.equal(firestorePost.kind, 'real_shoot');
    assert.equal(firestorePost.authorId, 'cust_1');
    assert.equal(firestorePost.photographerId, 'photo_1');
    assert.equal(firestorePost.serviceId, 'svc_1');
    assert.equal(firestorePost.bookingId, 'book_1');
    assert.deepEqual(firestorePost.imageUrls, ['https://storage.test/img1.webp']);
    assert.deepEqual(firestorePost.imageMeta, [{ blurHash: 'hash1', w: 1000, h: 800 }]);
    assert.equal(firestorePost.caption, 'Chụp ảnh xuất sắc');
    assert.deepEqual(firestorePost.location, { name: 'Công viên Thống Nhất' });
    assert.equal(firestorePost.likeCount, 0);
    assert.equal(firestorePost.saveCount, 0);
    assert.equal(firestorePost.inPortfolio, false);
    assert.ok(firestorePost.createdAt instanceof Timestamp);
  });
});

describe('review_firestore stores', () => {
  it('setReview writes reviews/{review.id}', async () => {
    const { db, sets } = fakeFirestore({});
    await new FirestoreReviewStore(db).runTransaction(async (tx) => {
      tx.setReview(review({ id: 'book_1_studio', subjectType: 'studio', subjectId: 's1', photographerId: 's1' }));
    });
    assert.deepEqual(sets.map((s) => s.path), ['reviews/book_1_studio']);
    assert.equal(sets[0]?.data.bookingId, 'book_1');
  });

  it('stats write keeps the other stats fields', async () => {
    const { db, sets, updates } = fakeFirestore({
      'reviews/book_1': reviewToFirestore(review({ verdict: 'tomato', hits: 10, intensity: 1, reasons: [] })),
      'photographers/photo_1': {
        stats: { completedCount: 12, responseMinutes: 30, rating: 4.9, ratingSum: 284, reviewCount: 58 },
      },
    });
    assert.equal(await countReview(new FirestoreStatsStore(db), 'book_1', NOW), 'counted');

    assert.equal(sets.length, 1);
    const write = sets[0] as Write;
    assert.equal(write.path, 'photographers/photo_1');
    assert.deepEqual(write.opts, { merge: true });
    assert.deepEqual(Object.keys(write.data), ['stats']);
    const stats = write.data.stats as Record<string, unknown>;
    assert.deepEqual(Object.keys(stats).sort(), [
      'brickCount',
      'punctualMentions',
      'rating',
      'ratingSum',
      'reviewCount',
      'score',
      'signedSum',
      'tomatoCount',
      'tomatoPct',
    ]);
    assert.ok((stats.rating as FieldValue).isEqual(FieldValue.delete()));
    assert.ok((stats.ratingSum as FieldValue).isEqual(FieldValue.delete()));
    // A legacy star reviewCount is never added to.
    assert.equal(stats.reviewCount, 1);
    assert.equal(stats.tomatoCount, 1);
    assert.equal(stats.tomatoPct, 100);
    assert.equal(stats.score, 1);

    assert.deepEqual(updates.map((u) => u.path), ['reviews/book_1']);
    assert.ok((updates[0]?.data.countedAt as Timestamp).isEqual(Timestamp.fromDate(NOW)));
  });
});
