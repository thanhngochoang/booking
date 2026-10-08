import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryBadgeStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type BadgeDeps,
  type PhotographerStatsPatch,
  type Review,
  type StatsStore,
  type StatsTx,
} from '@photobooking/domain';
import { reviewToFirestore } from '../../src/infra/review_firestore.js';
import { handleReviewWrite } from '../../src/triggers/review_write.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');

function review(over: Partial<Review> = {}): Review {
  return {
    id: 'b1',
    bookingId: 'b1',
    subjectType: 'photographer',
    subjectId: 'p1',
    photographerId: 'p1',
    customerId: 'c1',
    serviceId: 's1',
    serviceName: 'Chân dung 2 giờ',
    bookingDay: '2026-10-12',
    verdict: 'tomato',
    hits: 7,
    intensity: 0.91,
    reasons: [],
    text: 'Đúng giờ, kiên nhẫn với bé. Rất ưng.',
    photoPostId: null,
    createdAt: NOW,
    countedAt: null,
    ...over,
  };
}

/** One review in memory; `markCounted` sets its countedAt like the Firestore adapter. */
class OneReviewStore implements StatsStore {
  readonly stats = new Map<string, PhotographerStatsPatch>();
  constructor(public current: Review) {}

  async runTransaction<T>(fn: (tx: StatsTx) => Promise<T>): Promise<T> {
    return fn({
      getReview: async (id) => (id === this.current.id ? this.current : null),
      getPhotographerStats: async (uid) => (this.stats.get(uid) as Record<string, unknown> | undefined) ?? null,
      setPhotographerStats: (uid, patch) => {
        this.stats.set(uid, patch);
      },
      markCounted: (_id, at) => {
        this.current = { ...this.current, countedAt: at };
      },
    });
  }
}

function world() {
  const notifyStore = new MemoryNotificationStore();
  const users = new MemoryUserDirectory();
  users.users.set('c1', { name: 'Lan', avatarUrl: null });
  const evaluated: string[] = [];
  const clock = { now: () => NOW };
  const badges: BadgeDeps = {
    badges: new MemoryBadgeStore(),
    metrics: {
      isPhotographer: async (uid) => {
        evaluated.push(uid);
        return false;
      },
      read: async () => ({}),
    },
    notify: { store: notifyStore, push: new MemoryPushSender(), users, clock },
    clock,
  };
  return { notifyStore, badges, evaluated };
}

describe('onReviewWrite', () => {
  it('skips updates and deletes', async () => {
    const r = review();
    const store = new OneReviewStore(r);
    const { badges, notifyStore } = world();
    const doc = reviewToFirestore(r);
    assert.equal(await handleReviewWrite({ reviewId: 'b1', before: doc, after: doc }, store, NOW, badges), 'skipped');
    assert.equal(await handleReviewWrite({ reviewId: 'b1', before: doc, after: undefined }, store, NOW, badges), 'skipped');
    assert.equal(store.stats.size, 0);
    assert.equal(notifyStore.rows.size, 0);
  });

  it('the trigger calls notifyReviewVerdict with subjectUserId, verdict, hits, day and text and emits no review_new', async () => {
    const r = review();
    const store = new OneReviewStore(r);
    const { badges, notifyStore, evaluated } = world();

    const out = await handleReviewWrite({ reviewId: 'b1', before: undefined, after: reviewToFirestore(r) }, store, NOW, badges);

    assert.equal(out, 'counted');
    const rows = notifyStore.rowsOf('p1');
    assert.equal(rows.length, 1);
    const row = rows[0];
    assert.equal(row?.id, 'n_review_tomato_b1_p1');
    assert.equal(row?.type, 'review_tomato');
    assert.equal(row?.title, 'Bạn nhận 🍅 ×7 từ buổi chụp T2 12/10');
    assert.match(row?.body ?? '', /Đúng giờ, kiên nhẫn với bé/);
    assert.equal(row?.target, '/u/p1?tab=reviews');
    assert.equal(row?.actors[0]?.name, 'Lan');
    assert.equal([...notifyStore.rows.values()].some((x) => x.type === 'review_new'), false);
    assert.deepEqual(evaluated.sort(), ['c1', 'p1']);
  });

  it('a brick notifies its subject with the brick copy', async () => {
    const r = review({ id: 'b2', bookingId: 'b2', verdict: 'brick', hits: 3, intensity: 0.69, reasons: ['late'] });
    const store = new OneReviewStore(r);
    const { badges, notifyStore } = world();

    await handleReviewWrite({ reviewId: 'b2', before: undefined, after: reviewToFirestore(r) }, store, NOW, badges);

    const row = notifyStore.rowsOf('p1')[0];
    assert.equal(row?.id, 'n_review_brick_b2_p1');
    assert.equal(row?.type, 'review_brick');
    assert.equal(row?.title, 'Có góp ý mới về buổi chụp T2 12/10');
    assert.equal(store.stats.get('p1')?.brickCount, 1);
  });

  it('the trigger counts once when retried', async () => {
    const r = review();
    const store = new OneReviewStore(r);
    const { badges, notifyStore } = world();
    const input = { reviewId: 'b1', before: undefined, after: reviewToFirestore(r) };

    assert.equal(await handleReviewWrite(input, store, NOW, badges), 'counted');
    assert.equal(await handleReviewWrite(input, store, NOW, badges), 'already');

    assert.equal(store.stats.get('p1')?.reviewCount, 1);
    assert.equal(store.stats.get('p1')?.tomatoCount, 1);
    // The notice is deduped by #138's key review_{verdict}_{bookingId}_{subjectUserId}.
    assert.equal(notifyStore.rowsOf('p1').length, 1);
    assert.equal(notifyStore.rowsOf('p1')[0]?.id, 'n_review_tomato_b1_p1');
  });

  it('a studio review counts into the studio and notifies the studio', async () => {
    const r = review({ id: 'b1_studio', subjectType: 'studio', subjectId: 'st1', photographerId: 'st1' });
    const store = new OneReviewStore(r);
    const { badges, notifyStore } = world();

    await handleReviewWrite({ reviewId: 'b1_studio', before: undefined, after: reviewToFirestore(r) }, store, NOW, badges);

    assert.equal(store.stats.get('st1')?.reviewCount, 1);
    assert.equal(store.stats.has('p1'), false);
    assert.equal(notifyStore.rowsOf('st1')[0]?.id, 'n_review_tomato_b1_st1');
  });

  it('a review created already counted (seed or import) sends no notice', async () => {
    const r = review({ countedAt: NOW });
    const store = new OneReviewStore(r);
    const { badges, notifyStore } = world();

    const out = await handleReviewWrite({ reviewId: 'b1', before: undefined, after: reviewToFirestore(r) }, store, NOW, badges);

    assert.equal(out, 'already');
    assert.equal(store.stats.size, 0);
    assert.equal(notifyStore.rows.size, 0);
  });

  it('counts without badge deps (no notice)', async () => {
    const r = review();
    const store = new OneReviewStore(r);
    assert.equal(await handleReviewWrite({ reviewId: 'b1', before: undefined, after: reviewToFirestore(r) }, store, NOW), 'counted');
    assert.equal(store.stats.get('p1')?.reviewCount, 1);
  });
});
