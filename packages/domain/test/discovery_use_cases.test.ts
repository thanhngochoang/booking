import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createDiscoveryWorld } from './support/discovery_world.js';
import {
  refreshNextFreeDate,
  refreshStartingPrice,
  refreshCompletedCount,
  rollNextFreeDates,
  refreshEngagementCount,
  refreshExploreCategory,
} from '../src/discovery_use_cases.js';

describe('discovery_use_cases', () => {
  it('refreshNextFreeDate uses the Vietnam day', async () => {
    // 2026-10-07T17:30:00Z = 2026-10-08T00:30:00+07:00 (VN)
    const { deps, store } = createDiscoveryWorld({
      nowIso: '2026-10-07T17:30:00Z',
    });
    store.addPhotographer('p1', { nextFreeDate: null });

    const outcome = await refreshNextFreeDate(deps, 'p1');
    assert.equal(outcome, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.nextFreeDate, '2026-10-08');
  });

  it('booking the stored free day moves the date', async () => {
    const { deps, store } = createDiscoveryWorld({
      nowIso: '2026-10-07T17:30:00Z', // VN today is 2026-10-08
    });
    store.addPhotographer('p1', { nextFreeDate: '2026-10-08', score: 0 });

    // Block 2026-10-08
    store.setBlockedDay('p1', '2026-10-08');

    const outcome = await refreshNextFreeDate(deps, 'p1');
    assert.equal(outcome, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.nextFreeDate, '2026-10-09');

    // Run again without new blocks -> unchanged
    const outcome2 = await refreshNextFreeDate(deps, 'p1');
    assert.equal(outcome2, 'unchanged');
  });

  it('a missing photographer is missing, nothing written', async () => {
    const { deps } = createDiscoveryWorld();
    const outcome = await refreshNextFreeDate(deps, 'p_nonexistent');
    assert.equal(outcome, 'missing');
  });

  it('refreshStartingPrice ignores inactive packages', async () => {
    const { deps, store } = createDiscoveryWorld();
    store.addPhotographer('p1', { startingPrice: null });
    store.addService('p1', { price: 200000, active: false });
    store.addService('p1', { price: 500000, active: true });
    store.addService('p1', { price: 800000, active: true });

    const outcome = await refreshStartingPrice(deps, 'p1');
    assert.equal(outcome, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.startingPrice, 500000);
  });

  it('refreshCompletedCount writes the count', async () => {
    const { deps, store } = createDiscoveryWorld();
    store.addPhotographer('p1', { completedCount: 0 });
    store.addBooking('p1', 'completed');
    store.addBooking('p1', 'reviewed');
    store.addBooking('p1', 'requested'); // ignored

    const outcome = await refreshCompletedCount(deps, 'p1');
    assert.equal(outcome, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.completedCount, 2);
  });

  it('roll refreshes only stale photographers and pages', async () => {
    const { deps, store } = createDiscoveryWorld({
      nowIso: '2026-10-07T17:30:00Z', // VN today is 2026-10-08
    });
    // 5 stale photographers (nextFreeDate before 2026-10-08)
    for (let i = 1; i <= 5; i++) {
      store.addPhotographer(`stale_${i}`, {
        nextFreeDate: '2026-10-01',
        score: 0,
      });
    }
    // 2 current photographers (nextFreeDate on or after 2026-10-08)
    store.addPhotographer('curr_1', {
      nextFreeDate: '2026-10-08',
      score: 0,
    });
    store.addPhotographer('curr_2', {
      nextFreeDate: '2026-10-15',
      score: 0,
    });

    const result = await rollNextFreeDates(deps, { pageSize: 2 });
    assert.equal(result.refreshed, 5);
    assert.equal(result.pages, 3); // 2 + 2 + 1 = 3 pages

    // Stale photographers are updated to 2026-10-08
    for (let i = 1; i <= 5; i++) {
      const snap = await store.snapshot(`stale_${i}`);
      assert.equal(snap?.nextFreeDate, '2026-10-08');
    }
    // Current ones untouched
    const curr1 = await store.snapshot('curr_1');
    assert.equal(curr1?.nextFreeDate, '2026-10-08');
    const curr2 = await store.snapshot('curr_2');
    assert.equal(curr2?.nextFreeDate, '2026-10-15');
  });

  it('roll stops at maxPages', async () => {
    const { deps, store } = createDiscoveryWorld({
      nowIso: '2026-10-07T17:30:00Z',
    });
    for (let i = 1; i <= 10; i++) {
      store.addPhotographer(`p_${i}`, {
        nextFreeDate: '2026-10-01',
        score: 0,
      });
    }

    const result = await rollNextFreeDates(deps, { pageSize: 2, maxPages: 2 });
    assert.equal(result.refreshed, 4); // 2 pages of 2
    assert.equal(result.pages, 2);
  });

  it('recounting twice writes once', async () => {
    const { deps, store } = createDiscoveryWorld();
    store.addPost('post1', { likeCount: 0, saveCount: 0 });
    store.addEngagement('like', 'post1', 'user1');
    store.addEngagement('like', 'post1', 'user2');

    const outcome1 = await refreshEngagementCount(deps, 'like', 'post1');
    assert.equal(outcome1, 'written');

    const outcome2 = await refreshEngagementCount(deps, 'like', 'post1');
    assert.equal(outcome2, 'unchanged');
  });

  it('a deleted post is missing', async () => {
    const { deps } = createDiscoveryWorld();
    const outcome = await refreshEngagementCount(deps, 'like', 'nonexistent');
    assert.equal(outcome, 'missing');
  });

  it('refreshExploreCategory writes count and newest cover', async () => {
    const { deps, store } = createDiscoveryWorld();
    store.addServiceWithCatalog({
      specialty: 'portrait',
      active: true,
      coverUrl: 'https://example.com/cover1.jpg',
      updatedAt: 100,
    });
    store.addServiceWithCatalog({
      specialty: 'portrait',
      active: true,
      coverUrl: 'https://example.com/cover2.jpg',
      updatedAt: 200,
    });
    store.addServiceWithCatalog({
      specialty: 'portrait',
      active: true,
      coverUrl: null,
      updatedAt: 300,
    });
    store.addServiceWithCatalog({
      specialty: 'portrait',
      active: false,
      coverUrl: 'https://example.com/inactive.jpg',
      updatedAt: 400,
    });

    const outcome = await refreshExploreCategory(deps, 'portrait');
    assert.equal(outcome, 'written');

    const cat = await store.current('portrait');
    assert.equal(cat?.serviceCount, 3);
    assert.equal(cat?.coverUrl, 'https://example.com/cover2.jpg');
  });

  it('a category with no packages writes 0 and null cover', async () => {
    const { deps, store } = createDiscoveryWorld();
    const outcome = await refreshExploreCategory(deps, 'weddings');
    assert.equal(outcome, 'written');

    const cat = await store.current('weddings');
    assert.equal(cat?.serviceCount, 0);
    assert.equal(cat?.coverUrl, null);
  });

  it('an unknown specialty is ignored', async () => {
    const { deps } = createDiscoveryWorld();
    const outcome = await refreshExploreCategory(deps, 'Invalid-Specialty!!');
    assert.equal(outcome, 'unchanged');
  });
});
