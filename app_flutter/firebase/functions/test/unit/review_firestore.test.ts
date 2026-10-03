import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { RealShootPost, Review, StatsStore, StatsTx } from '@photobooking/domain';
import {
  realShootPostToFirestore,
  reviewFromFirestore,
  reviewToFirestore,
} from '../../src/infra/review_firestore.js';
import { handleReviewWrite } from '../../src/triggers/review_write.js';

class MockStatsStore implements StatsStore {
  readonly stats = new Map<string, { ratingSum: number; reviewCount: number; rating: number }>();
  readonly counted = new Set<string>();

  async runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> {
    const tx: StatsTx = {
      getReview: async (id: string) => {
        return {
          bookingId: id,
          customerId: 'cust1',
          photographerId: 'photo1',
          serviceId: 'pkg1',
          rating: 5,
          text: 'Great shoot',
          photoPostId: null,
          createdAt: new Date(),
          countedAt: this.counted.has(id) ? new Date() : null,
        };
      },
      getPhotographerStats: async (uid: string) => this.stats.get(uid) ?? null,
      setPhotographerStats: (uid: string, patch) => {
        this.stats.set(uid, patch);
      },
      markCounted: (bookingId: string) => {
        this.counted.add(bookingId);
      },
    };
    return fn(tx);
  }
}

describe('review_firestore mapping and trigger unit tests', () => {
  it('Review and RealShootPost map to the documents the feed reads', () => {
    const now = new Date('2026-10-10T12:00:00.000Z');
    const review: Review = {
      bookingId: 'book_1',
      customerId: 'cust_1',
      photographerId: 'photo_1',
      serviceId: 'svc_1',
      rating: 5,
      text: 'Chụp ảnh xuất sắc',
      photoPostId: 'post_1',
      createdAt: now,
      countedAt: null,
    };

    const firestoreReview = reviewToFirestore(review);
    assert.ok(firestoreReview.createdAt instanceof Timestamp);
    assert.equal(firestoreReview.countedAt, null);

    const restoredReview = reviewFromFirestore('book_1', firestoreReview);
    assert.deepEqual(restoredReview, review);

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
      createdAt: now,
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

  it('handleReviewWrite processes review creation and skips updates', async () => {
    const store = new MockStatsStore();

    // Skip on update
    const skipped = await handleReviewWrite(
      {
        bookingId: 'book_1',
        before: { rating: 4 },
        after: { rating: 5 },
      },
      store
    );
    assert.equal(skipped, 'skipped');

    // Count on create
    const counted = await handleReviewWrite(
      {
        bookingId: 'book_1',
        before: undefined,
        after: { photographerId: 'photo1', rating: 5 },
      },
      store
    );
    assert.equal(counted, 'counted');
    assert.equal(store.stats.get('photo1')?.rating, 5);

    // Second write for same booking is already counted
    const already = await handleReviewWrite(
      {
        bookingId: 'book_1',
        before: undefined,
        after: { photographerId: 'photo1', rating: 5 },
      },
      store
    );
    assert.equal(already, 'already');
  });
});
