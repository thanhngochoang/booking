import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { BADGE_CATALOG, type BadgeMetric, type Metrics } from '../src/badge.js';
import type { BadgeDeps, BadgeMetricsReader } from '../src/badge_ports.js';
import { evaluateUserBadges, reconcileBadges } from '../src/badge_use_cases.js';
import { MemoryBadgeStore } from '../src/memory_badge_store.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

class FakeMetrics implements BadgeMetricsReader {
  readonly photographers = new Set<string>();
  readonly values = new Map<string, Metrics>();
  lastRequested: ReadonlySet<BadgeMetric> = new Set();

  async isPhotographer(uid: string): Promise<boolean> {
    return this.photographers.has(uid);
  }

  async read(uid: string, metrics: ReadonlySet<BadgeMetric>): Promise<Metrics> {
    this.lastRequested = metrics;
    return this.values.get(uid) ?? {};
  }
}

describe('badge use cases', () => {
  let w: NotifyWorld;
  let store: MemoryBadgeStore;
  let metrics: FakeMetrics;
  let deps: BadgeDeps;

  beforeEach(() => {
    w = createNotifyWorld();
    store = new MemoryBadgeStore();
    metrics = new FakeMetrics();
    deps = { badges: store, metrics, notify: w.deps, clock: w.clock };
  });

  it('a new user gets new_member and a badge_new notification', async () => {
    metrics.values.set('u1', { accountAgeDays: 0 });
    const r = await evaluateUserBadges(deps, 'u1');
    assert.deepEqual(r, { awarded: ['new_member'], revoked: [] });
    assert.deepEqual(store.earnedIds('u1'), ['new_member']);
    const [row] = w.store.rowsOf('u1');
    assert.equal(row?.id, 'n_badge_new_new_member_20261010');
    assert.equal(row?.title, 'Bạn nhận huy hiệu “Thành viên mới”');
    assert.equal(row?.target, '/u/u1/badges');
    assert.equal(w.push.sent.length, 1);
  });

  it('a second evaluation awards nothing and sends nothing', async () => {
    metrics.values.set('u1', { accountAgeDays: 0 });
    await evaluateUserBadges(deps, 'u1');
    w.clock.advanceMinutes(10);
    const r = await evaluateUserBadges(deps, 'u1');
    assert.deepEqual(r, { awarded: [], revoked: [] });
    assert.equal(w.store.rowsOf('u1').length, 1);
    assert.equal(w.push.sent.length, 1);
  });

  it('keeps the snapshot written at award time', async () => {
    metrics.values.set('p1', { rating: 4.9, reviewCount: 58 });
    metrics.photographers.add('p1');
    await evaluateUserBadges(deps, 'p1');
    const first = [...(store.earned.get('p1')?.values() ?? [])].find((e) => e.badgeId === 'top_rated');
    assert.equal(first?.snapshotText, '4,9 sao từ 58 đánh giá');
    metrics.values.set('p1', { rating: 4.8, reviewCount: 70 });
    w.clock.advanceHours(1);
    await evaluateUserBadges(deps, 'p1');
    const again = store.earned.get('p1')?.get('top_rated');
    assert.equal(again?.snapshotText, '4,9 sao từ 58 đánh giá');
    assert.equal(again?.awardedAt.getTime(), first?.awardedAt.getTime());
  });

  it('a dropped rating removes top_rated', async () => {
    metrics.photographers.add('p1');
    metrics.values.set('p1', { rating: 4.9, reviewCount: 30 });
    await evaluateUserBadges(deps, 'p1');
    assert.ok(store.earnedIds('p1').includes('top_rated'));
    metrics.values.set('p1', { rating: 4.5, reviewCount: 31 });
    const r = await evaluateUserBadges(deps, 'p1');
    assert.deepEqual(r.revoked, ['top_rated']);
    assert.equal(store.earnedIds('p1').includes('top_rated'), false);
  });

  it('progress is written for locked badges only', async () => {
    metrics.photographers.add('p1');
    metrics.values.set('p1', { completedShoots: 12, workPosts: 2, rating: 5, reviewCount: 3 });
    await evaluateUserBadges(deps, 'p1');
    const p = store.progress.get('p1');
    assert.ok(p);
    assert.equal('shoots_10' in p, false);
    assert.deepEqual(p.shoots_50, { current: 12, target: 50 });
    assert.deepEqual(p.top_rated, { current: 3, target: 20 });
    assert.equal('fast_reply' in p, false);
  });

  it('reads only the metrics of eligible badges', async () => {
    await evaluateUserBadges(deps, 'u1');
    assert.equal(metrics.lastRequested.has('completedShoots'), false);
    assert.equal(metrics.lastRequested.has('customerShoots'), true);
  });

  it('a failed notify does not undo the award', async () => {
    metrics.values.set('u1', { accountAgeDays: 0 });
    w.store.getPrefs = async () => {
      throw new Error('prefs down');
    };
    const r = await evaluateUserBadges(deps, 'u1');
    assert.deepEqual(r.awarded, ['new_member']);
    assert.deepEqual(store.earnedIds('u1'), ['new_member']);
    assert.equal(w.pushErrors.length, 1);
  });

  it('reconcile syncs changed catalogue docs only', async () => {
    assert.equal((await reconcileBadges(deps)).catalogWrites, 12);
    assert.equal((await reconcileBadges(deps)).catalogWrites, 0);
    store.catalog.set('sharer', { ...BADGE_CATALOG.filter((b) => b.id === 'sharer')[0], description: 'old' } as (typeof BADGE_CATALOG)[number]);
    assert.equal((await reconcileBadges(deps)).catalogWrites, 1);
  });

  it('reconcile removes new_member after 30 days', async () => {
    metrics.values.set('old', { accountAgeDays: 0 });
    metrics.values.set('fresh', { accountAgeDays: 0 });
    await evaluateUserBadges(deps, 'old');
    w.clock.advanceHours(24 * 20);
    await evaluateUserBadges(deps, 'fresh');
    w.clock.advanceHours(24 * 12); // old: 32 days, fresh: 12 days
    metrics.values.set('old', { accountAgeDays: 32 });
    metrics.values.set('fresh', { accountAgeDays: 12 });
    const r = await reconcileBadges(deps);
    assert.equal(r.reevaluated, 1);
    assert.deepEqual(store.earnedIds('old'), []);
    assert.deepEqual(store.earnedIds('fresh'), ['new_member']);
  });

  it('reconcile pages through holders that stay holders', async () => {
    const old = new Date('2026-01-01T00:00:00.000Z');
    for (let i = 0; i < 450; i++) {
      const uid = `u${String(i).padStart(4, '0')}`;
      store.seedEarned(uid, { badgeId: 'new_member', awardedAt: old, snapshotText: 'x' });
      metrics.values.set(uid, { accountAgeDays: 0 }); // still meets: stays a holder
    }
    const r = await reconcileBadges(deps);
    assert.equal(r.reevaluated, 450);
  });
});
