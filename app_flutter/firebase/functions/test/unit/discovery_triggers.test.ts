import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { MemoryDiscoveryStore, MemoryChatStore, type DiscoveryDeps } from '@photobooking/domain';
import { handleAvailabilityWrite } from '../../src/triggers/availability_write.js';
import { handleEngagementWrite } from '../../src/triggers/engagement_write.js';
import { handleServiceDiscovery } from '../../src/triggers/service_write.js';
import { handleBookingWrite } from '../../src/triggers/booking_write.js';
import { handleRollNextFree } from '../../src/scheduled/roll_next_free.js';

const NOW = new Date('2026-10-01T12:00:00Z');

function createDiscoveryDeps(store = new MemoryDiscoveryStore()): DiscoveryDeps {
  return {
    stats: store,
    catalog: store,
    engagement: store,
    clock: { now: () => NOW },
  };
}

describe('discovery triggers (in-memory deps)', () => {
  test('onAvailabilityWrite refreshes the photographer when day inside horizon', async () => {
    const store = new MemoryDiscoveryStore();
    store.addPhotographer('p1', { nextFreeDate: null });
    const deps = createDiscoveryDeps(store);

    const outcome = await handleAvailabilityWrite('p1', '2026-10-05', deps);
    assert.equal(outcome, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.nextFreeDate, '2026-10-01');
  });

  test('a day outside the horizon is skipped', async () => {
    const store = new MemoryDiscoveryStore();
    store.addPhotographer('p1', { nextFreeDate: null });
    const deps = createDiscoveryDeps(store);

    // past day
    const pastOutcome = await handleAvailabilityWrite('p1', '2026-09-30', deps);
    assert.equal(pastOutcome, 'skipped');

    // today + 60
    const farOutcome = await handleAvailabilityWrite('p1', '2026-12-01', deps);
    assert.equal(farOutcome, 'skipped');
  });

  test('a like marker create and delete recount; an update is skipped', async () => {
    const store = new MemoryDiscoveryStore();
    store.addPost('post1', { likeCount: 0, saveCount: 0 });
    const deps = createDiscoveryDeps(store);

    // Create marker
    store.addEngagement('like', 'post1', 'u1');
    const createOutcome = await handleEngagementWrite('like', undefined, { postId: 'post1', userId: 'u1' }, deps);
    assert.equal(createOutcome, 'written');

    // Update marker (both before and after defined)
    const updateOutcome = await handleEngagementWrite('like', { postId: 'post1', userId: 'u1' }, { postId: 'post1', userId: 'u1' }, deps);
    assert.equal(updateOutcome, 'skipped');

    // Delete marker
    const deleteStore = new MemoryDiscoveryStore();
    deleteStore.addPost('post1', { likeCount: 1, saveCount: 0 });
    // marker removed (no addEngagement)
    const deleteDeps = createDiscoveryDeps(deleteStore);
    const deleteOutcome = await handleEngagementWrite('like', { postId: 'post1', userId: 'u1' }, undefined, deleteDeps);
    assert.equal(deleteOutcome, 'written');
  });

  test('a marker without postId is skipped', async () => {
    const deps = createDiscoveryDeps();
    const outcome = await handleEngagementWrite('like', undefined, { userId: 'u1' }, deps);
    assert.equal(outcome, 'skipped');
  });

  test('a price change refreshes startingPrice; a name change does not', async () => {
    const store = new MemoryDiscoveryStore();
    store.addPhotographer('p1', { startingPrice: 2_000_000 });
    store.addService('p1', { price: 1_000_000, active: true, specialty: 'portrait', coverUrl: null });
    const deps = createDiscoveryDeps(store);

    // Price change
    const priceChange = await handleServiceDiscovery('p1', { price: 2_000_000, active: true }, { price: 1_000_000, active: true }, deps);
    assert.equal(priceChange.price, 'written');
    const snap = await store.snapshot('p1');
    assert.equal(snap?.startingPrice, 1_000_000);

    // Name change only (no price, active, specialty, coverUrl change)
    const nameChange = await handleServiceDiscovery('p1', { name: 'Old', price: 1_000_000, active: true }, { name: 'New', price: 1_000_000, active: true }, deps);
    assert.equal(nameChange.price, 'skipped');
    assert.deepEqual(nameChange.categories, []);
  });

  test('a specialty change refreshes both categories', async () => {
    const store = new MemoryDiscoveryStore();
    const deps = createDiscoveryDeps(store);

    const change = await handleServiceDiscovery(
      'p1',
      { specialty: 'portrait', active: true, price: 1_000_000 },
      { specialty: 'wedding', active: true, price: 1_000_000 },
      deps,
    );
    assert.deepEqual(change.categories.sort(), ['portrait', 'wedding'].sort());
  });

  test('a booking entering completed refreshes completedCount; completed -> reviewed does not', async () => {
    const store = new MemoryDiscoveryStore();
    store.addPhotographer('p1', { completedCount: 0 });
    store.addBooking('p1', 'completed');
    const deps = createDiscoveryDeps(store);

    // entering completed
    const baseBooking = {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 's1',
      serviceSnapshot: { name: 'Service', price: 1000, durationMinutes: 60 },
      day: '2026-10-05',
      start: '10:00',
      end: '11:00',
      place: { name: 'Studio' },
    };
    const chatStore = new MemoryChatStore();
    const chatDeps = {
      chats: chatStore,
      photographers: { acceptsInquiries: async () => true },
      blocks: { isBlockedEitherWay: async () => false },
      clock: { now: () => NOW },
      ids: { newId: () => 'id1' },
    };
    await handleBookingWrite(
      {
        id: 'b1',
        before: { ...baseBooking, status: 'upcoming' },
        after: { ...baseBooking, status: 'completed' },
      },
      chatDeps,
      undefined,
      undefined,
      deps,
    );
    const snap = await store.snapshot('p1');
    assert.equal(snap?.completedCount, 1);

    // completed -> reviewed
    let refreshedAgain = false;
    const trackedDeps: DiscoveryDeps = {
      ...deps,
      stats: {
        snapshot: (uid) => store.snapshot(uid),
        blockedDays: (uid, from, to) => store.blockedDays(uid, from, to),
        activeServicePrices: (uid) => store.activeServicePrices(uid),
        apply: (uid, patch) => store.apply(uid, patch),
        staleNextFree: (beforeDay, limit, afterUid) => store.staleNextFree(beforeDay, limit, afterUid),
        completedBookings: async (uid) => {
          refreshedAgain = true;
          return store.completedBookings(uid);
        },
      },
    };
    await handleBookingWrite(
      {
        id: 'b1',
        before: { ...baseBooking, status: 'completed' },
        after: { ...baseBooking, status: 'reviewed' },
      },
      chatDeps,
      undefined,
      undefined,
      trackedDeps,
    );
    assert.equal(refreshedAgain, false);
  });

  test('the rollover handler returns the use-case totals', async () => {
    const store = new MemoryDiscoveryStore();
    // Stale photographer
    store.addPhotographer('p1', { nextFreeDate: '2026-09-20' });
    const deps = createDiscoveryDeps(store);

    const totals = await handleRollNextFree(deps);
    assert.equal(totals.refreshed, 1);
    assert.equal(totals.pages, 1);
  });
});
