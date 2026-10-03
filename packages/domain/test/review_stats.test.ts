import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { Review } from '../src/review.js';
import {
  addRating,
  countReview,
  type StatsStore,
  type StatsTx,
} from '../src/review_stats.js';

class MemoryStatsStore implements StatsStore {
  readonly reviews = new Map<string, Review>();
  readonly stats = new Map<
    string,
    { ratingSum?: unknown; reviewCount?: unknown; rating?: unknown }
  >();

  async runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> {
    const tx: StatsTx = {
      getReview: async (id: string) => this.reviews.get(id) ?? null,
      getPhotographerStats: async (uid: string) => this.stats.get(uid) ?? null,
      setPhotographerStats: (uid: string, patch) => {
        this.stats.set(uid, patch);
      },
      markCounted: (bookingId: string, at: Date) => {
        const r = this.reviews.get(bookingId);
        if (r) {
          this.reviews.set(bookingId, { ...r, countedAt: at });
        }
      },
    };
    return fn(tx);
  }
}

describe('addRating', () => {
  it('first review sets sum, count and rating', () => {
    const patch = addRating({}, 5);
    assert.deepEqual(patch, {
      ratingSum: 5,
      reviewCount: 1,
      rating: 5,
    });
  });

  it('rating rounds to one decimal half up (4.25 → 4.3)', () => {
    // 17 / 4 = 4.25 -> rounds to 4.3
    const patch1 = addRating({ ratingSum: 12, reviewCount: 3 }, 5);
    assert.equal(patch1.ratingSum, 17);
    assert.equal(patch1.reviewCount, 4);
    assert.equal(patch1.rating, 4.3);

    // 17 / 5 = 3.4 -> 3.4
    const patch2 = addRating({ ratingSum: 13, reviewCount: 4 }, 4);
    assert.equal(patch2.rating, 3.4);

    // 21 / 5 = 4.2 -> 4.2
    const patch3 = addRating({ ratingSum: 17, reviewCount: 4 }, 4);
    assert.equal(patch3.rating, 4.2);
  });

  it('malformed counters start from zero', () => {
    for (const bad of [null, undefined, 'bad', -5, NaN]) {
      const patch = addRating({ ratingSum: bad, reviewCount: bad }, 4);
      assert.deepEqual(patch, {
        ratingSum: 4,
        reviewCount: 1,
        rating: 4,
      });
    }
  });
});

describe('countReview', () => {
  let store: MemoryStatsStore;
  const now = new Date('2026-10-10T12:00:00.000Z');

  beforeEach(() => {
    store = new MemoryStatsStore();
  });

  it('the same review is counted once', async () => {
    const review: Review = {
      bookingId: 'book1',
      customerId: 'cust1',
      photographerId: 'photo1',
      serviceId: 'pkg1',
      rating: 5,
      text: 'Chụp rất đẹp',
      photoPostId: null,
      createdAt: now,
      countedAt: null,
    };
    store.reviews.set('book1', review);

    const first = await countReview(store, 'book1', now);
    assert.equal(first, 'counted');

    const statsAfterFirst = store.stats.get('photo1');
    assert.deepEqual(statsAfterFirst, {
      ratingSum: 5,
      reviewCount: 1,
      rating: 5,
    });

    const reviewAfterFirst = store.reviews.get('book1');
    assert.equal(reviewAfterFirst?.countedAt, now);

    // Second call is already counted
    const second = await countReview(store, 'book1', now);
    assert.equal(second, 'already');

    // Stats remain unchanged
    const statsAfterSecond = store.stats.get('photo1');
    assert.deepEqual(statsAfterSecond, {
      ratingSum: 5,
      reviewCount: 1,
      rating: 5,
    });
  });
});
