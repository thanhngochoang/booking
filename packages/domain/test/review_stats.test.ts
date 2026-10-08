import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { intensityOf, type Review, type Verdict } from '../src/review.js';
import {
  addVerdict,
  countReview,
  mentionsPunctual,
  type PhotographerStatsPatch,
  type StatsStore,
  type StatsTx,
} from '../src/review_stats.js';

class MemoryStatsStore implements StatsStore {
  readonly reviews = new Map<string, Review>();
  readonly stats = new Map<string, Record<string, unknown>>();

  async runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> {
    const tx: StatsTx = {
      getReview: async (id: string) => this.reviews.get(id) ?? null,
      getPhotographerStats: async (uid: string) => this.stats.get(uid) ?? null,
      setPhotographerStats: (uid: string, patch: PhotographerStatsPatch) => {
        this.stats.set(uid, { ...patch });
      },
      markCounted: (reviewId: string, at: Date) => {
        const r = this.reviews.get(reviewId);
        if (r) {
          this.reviews.set(reviewId, { ...r, countedAt: at });
        }
      },
    };
    return fn(tx);
  }
}

describe('addVerdict', () => {
  it('from empty stats', () => {
    assert.deepEqual(addVerdict({}, 'tomato', 0.91), {
      reviewCount: 1,
      tomatoCount: 1,
      brickCount: 0,
      signedSum: 0.91,
      tomatoPct: 100,
      score: 0.91,
      punctualMentions: 0,
    });
  });

  it('mixed verdicts', () => {
    let stats: Record<string, unknown> = {};
    for (let i = 0; i < 56; i++) stats = { ...addVerdict(stats, 'tomato', 1.0) };
    for (let i = 0; i < 2; i++) stats = { ...addVerdict(stats, 'brick', 0.69) };
    assert.equal(stats.reviewCount, 58);
    assert.equal(stats.tomatoCount, 56);
    assert.equal(stats.brickCount, 2);
    assert.equal(stats.signedSum, 54.62);
    assert.equal(stats.tomatoPct, 97);
    assert.equal(stats.score, Math.round(((56 - 1.38) / 58) * 1000) / 1000);
    assert.equal(stats.score, 0.942);
  });

  it('rounding of tomatoPct (2 of 3 is 67)', () => {
    let stats: Record<string, unknown> = {};
    stats = { ...addVerdict(stats, 'tomato', 1) };
    stats = { ...addVerdict(stats, 'tomato', 1) };
    stats = { ...addVerdict(stats, 'brick', 1) };
    assert.equal(stats.tomatoPct, 67);
  });

  it('ignores a legacy reviewCount', () => {
    const patch = addVerdict({ reviewCount: 58, rating: 4.9, ratingSum: 284 }, 'tomato', 0.4);
    assert.equal(patch.reviewCount, 1);
    assert.equal(patch.tomatoCount, 1);
    assert.equal(patch.tomatoPct, 100);
    assert.equal('rating' in patch, false);
    assert.equal('ratingSum' in patch, false);
  });

  it('corrupt fields count as 0', () => {
    for (const bad of ['x', -5, NaN, null, undefined, Infinity]) {
      const patch = addVerdict(
        { tomatoCount: bad, brickCount: bad, signedSum: bad === -5 ? 'x' : bad, punctualMentions: bad },
        'brick',
        0.58
      );
      assert.deepEqual(patch, {
        reviewCount: 1,
        tomatoCount: 0,
        brickCount: 1,
        signedSum: -0.58,
        tomatoPct: 0,
        score: -0.58,
        punctualMentions: 0,
      });
    }
  });

  it('a punctual mention increments punctualMentions', () => {
    assert.equal(addVerdict({ punctualMentions: 2 }, 'tomato', 1, true).punctualMentions, 3);
    assert.equal(addVerdict({ punctualMentions: 2 }, 'tomato', 1).punctualMentions, 2);
  });
});

describe('countReview', () => {
  let store: MemoryStatsStore;
  const now = new Date('2026-10-10T12:00:00.000Z');

  beforeEach(() => {
    store = new MemoryStatsStore();
  });

  const reviewWith = (
    id: string,
    text: string,
    over: Partial<Review> = {},
    verdict: Verdict = 'tomato',
    hits = 7
  ): Review => ({
    id,
    bookingId: id.replace(/_studio$/, ''),
    subjectType: 'photographer',
    subjectId: 'photo1',
    photographerId: 'photo1',
    customerId: 'cust1',
    serviceId: 'pkg1',
    serviceName: 'Chụp chân dung',
    bookingDay: '2026-10-10',
    verdict,
    hits,
    intensity: intensityOf(hits),
    reasons: verdict === 'brick' ? ['late'] : [],
    text,
    photoPostId: null,
    createdAt: now,
    countedAt: null,
    ...over,
  });

  it('counts once', async () => {
    store.reviews.set('book1', reviewWith('book1', 'Chụp rất đẹp'));

    assert.equal(await countReview(store, 'book1', now), 'counted');
    const after = store.stats.get('photo1');
    assert.deepEqual(after, {
      reviewCount: 1,
      tomatoCount: 1,
      brickCount: 0,
      signedSum: 0.91,
      tomatoPct: 100,
      score: 0.91,
      punctualMentions: 0,
    });
    assert.equal(store.reviews.get('book1')?.countedAt, now);

    assert.equal(await countReview(store, 'book1', now), 'already');
    assert.deepEqual(store.stats.get('photo1'), after);
  });

  it('counts a studio review into the studio', async () => {
    store.reviews.set(
      'book1_studio',
      reviewWith('book1_studio', 'Studio rất ổn', {
        subjectType: 'studio',
        subjectId: 'studio-1',
        photographerId: 'studio-1',
      })
    );
    assert.equal(await countReview(store, 'book1_studio', now), 'counted');
    assert.equal(store.stats.get('studio-1')?.reviewCount, 1);
    assert.equal(store.stats.has('photo1'), false);
    assert.ok(store.reviews.get('book1_studio')?.countedAt);
  });

  it('skips a missing review', async () => {
    assert.equal(await countReview(store, 'nope', now), 'already');
    assert.equal(store.stats.size, 0);
  });

  it('a review counted before is not counted again even for a studio id', async () => {
    store.reviews.set('b1_studio', reviewWith('b1_studio', 'ok ok ok ok', { subjectId: 's1', countedAt: now }));
    assert.equal(await countReview(store, 'b1_studio', now), 'already');
    assert.equal(store.stats.size, 0);
  });

  it("a review praising 'Đúng giờ' bumps punctualMentions", async () => {
    store.reviews.set('b1', reviewWith('b1', 'Anh Đúng giờ, chụp đẹp'));
    store.reviews.set('b2', reviewWith('b2', 'Chụp đẹp lắm'));
    await countReview(store, 'b1', now);
    assert.equal(store.stats.get('photo1')?.punctualMentions, 1);
    await countReview(store, 'b2', now);
    assert.equal(store.stats.get('photo1')?.punctualMentions, 1);
    assert.equal(store.stats.get('photo1')?.reviewCount, 2);
  });

  it("'dung gio' without diacritics also counts", () => {
    assert.equal(mentionsPunctual('rat dung gio'), true);
    assert.equal(mentionsPunctual('ĐÚNG GIỜ'), true);
    assert.equal(mentionsPunctual('đúng  giờ'), false);
    assert.equal(mentionsPunctual('trễ giờ'), false);
  });
});
