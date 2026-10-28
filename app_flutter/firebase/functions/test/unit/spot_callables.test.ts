import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  MemorySpotStore,
  type SpotScheduleDeps,
  type Spot,
  type ServiceRecord,
  MAX_OPEN_SCHEDULES,
} from '@photobooking/domain';
import {
  handleSaveSpotSchedule,
  handleCancelSpotSchedule,
  handleSaveSlotOffer,
  handleCloseSlotOffer,
} from '../../src/callables/spot.js';

function createTestDeps(): { deps: SpotScheduleDeps; store: MemorySpotStore } {
  const store = new MemorySpotStore();
  let idCounter = 1;

  const sampleSpot: Spot = {
    id: 'spot1',
    name: 'Hồ Gươm',
    city: 'Hà Nội',
    areaCode: 'hn-hoan-kiem',
    point: { lat: 21.0285, lng: 105.8542 },
    geohash: 'w7er8u0xx',
    radiusM: 1000,
    cover: null,
    description: 'Hồ Hoàn Kiếm',
    tips: [],
    seasonMonths: [10, 11, 12, 1],
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 10,
    stats: { posts14d: 0, events: 0, bookings14d: 0, openSchedules: 0, providersWeek: 0, providersWeekend: 0 },
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
    rankedAt: null,
    managedBy: null,
    access: null,
    openHours: null,
    updatedBy: 'system',
  };
  store.seedSpot(sampleSpot);

  const services: ServiceRecord[] = [
    { id: 'svc1', photographerId: 'ph1', name: 'Gói chụp chân dung', price: 1_000_000, durationMinutes: 120, active: true },
  ];
  store.seedServices('ph1', services);

  const deps: SpotScheduleDeps = {
    schedules: store,
    providers: {
      acceptsOrders: async () => true,
      orderProfile: async () => ({ acceptsOrders: true, providerType: 'individual' }),
    },
    roster: {
      relationOf: async () => null,
      person: async () => null,
    },
    clock: { now: () => new Date('2026-10-15T00:00:00.000Z') },
    ids: { newId: () => `id_${idCounter++}` },
  };

  return { deps, store };
}

describe('spot callables', () => {
  it('unauthenticated calls throw unauthenticated HttpsError', async () => {
    const { deps } = createTestDeps();
    await assert.rejects(
      handleSaveSpotSchedule({ data: {} }, deps),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'unauthenticated');
        return true;
      },
    );
    await assert.rejects(
      handleCancelSpotSchedule({ data: {} }, deps),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'unauthenticated');
        return true;
      },
    );
    await assert.rejects(
      handleSaveSlotOffer({ data: {} }, deps),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'unauthenticated');
        return true;
      },
    );
    await assert.rejects(
      handleCloseSlotOffer({ data: {} }, deps),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'unauthenticated');
        return true;
      },
    );
  });

  it('saveSpotSchedule passes the caller uid and returns {scheduleId, addedDays}', async () => {
    const { deps } = createTestDeps();
    const result = await handleSaveSpotSchedule(
      {
        auth: { uid: 'ph1' },
        data: {
          spotId: 'spot1',
          days: ['2026-10-18'],
          window: { start: '06:00', end: '11:00' },
          serviceIds: ['svc1'],
        },
      },
      deps,
    );

    assert.equal(result.scheduleId, 'id_1');
    assert.deepEqual(result.addedDays, ['2026-10-18']);
  });

  it('day_conflict maps to failed-precondition with details.code day_conflict, details.field days and details.days', async () => {
    const { deps, store } = createTestDeps();
    store.seedAvailability('ph1', '2026-10-18', { state: 'booked', bookingId: 'b_existing' });

    await assert.rejects(
      handleSaveSpotSchedule(
        {
          auth: { uid: 'ph1' },
          data: {
            spotId: 'spot1',
            days: ['2026-10-18'],
            window: { start: '06:00', end: '11:00' },
            serviceIds: ['svc1'],
          },
        },
        deps,
      ),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'failed-precondition');
        assert.equal(err.message, 'day_conflict');
        assert.equal((err.details as Record<string, unknown>).code, 'day_conflict');
        assert.equal((err.details as Record<string, unknown>).field, 'days');
        assert.deepEqual((err.details as Record<string, unknown>).days, [
          { day: '2026-10-18', reason: 'booked' },
        ]);
        return true;
      },
    );
  });

  it('schedule_has_bookings maps to failed-precondition with details.days [{day, count}]', async () => {
    const { deps, store } = createTestDeps();
    store.seedSchedule({
      id: 'sched1',
      providerId: 'ph1',
      assigneeId: null,
      spotId: 'spot1',
      days: ['2026-10-18', '2026-10-19'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['svc1'],
      priceFrom: 1_000_000,
      status: 'open',
      createdAt: '2026-10-15T00:00:00.000Z',
      updatedAt: '2026-10-15T00:00:00.000Z',
    });
    store.seedSpotDay({
      scheduleId: 'sched1',
      spotId: 'spot1',
      providerId: 'ph1',
      day: '2026-10-19',
      taken: [{ start: '06:00', end: '08:00' }],
      updatedAt: '2026-10-15T00:00:00.000Z',
    });

    // Try to remove 2026-10-19 which has bookings
    await assert.rejects(
      handleSaveSpotSchedule(
        {
          auth: { uid: 'ph1' },
          data: {
            scheduleId: 'sched1',
            spotId: 'spot1',
            days: ['2026-10-18'],
            window: { start: '06:00', end: '11:00' },
            serviceIds: ['svc1'],
          },
        },
        deps,
      ),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'failed-precondition');
        assert.equal(err.message, 'schedule_has_bookings');
        assert.equal((err.details as Record<string, unknown>).code, 'schedule_has_bookings');
        assert.deepEqual((err.details as Record<string, unknown>).days, [
          { day: '2026-10-19', count: 1 },
        ]);
        return true;
      },
    );
  });

  it('schedule_limit maps to resource-exhausted', async () => {
    const { deps, store } = createTestDeps();
    for (let i = 0; i < MAX_OPEN_SCHEDULES; i++) {
      store.seedSchedule({
        id: `sched_${i}`,
        providerId: 'ph1',
        assigneeId: null,
        spotId: 'spot1',
        days: ['2026-10-20'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: ['svc1'],
        priceFrom: 1_000_000,
        status: 'open',
        createdAt: '2026-10-15T00:00:00.000Z',
        updatedAt: '2026-10-15T00:00:00.000Z',
      });
    }

    await assert.rejects(
      handleSaveSpotSchedule(
        {
          auth: { uid: 'ph1' },
          data: {
            spotId: 'spot1',
            days: ['2026-10-21'],
            window: { start: '06:00', end: '11:00' },
            serviceIds: ['svc1'],
          },
        },
        deps,
      ),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'resource-exhausted');
        assert.equal(err.message, 'schedule_limit');
        assert.equal((err.details as Record<string, unknown>).code, 'schedule_limit');
        return true;
      },
    );
  });

  it('after a successful save, afterSave runs with the holder uid and a failing afterSave does not fail the call', async () => {
    const { deps } = createTestDeps();
    const recorded: { holder: string; days: string[] }[] = [];
    const afterSaveSuccess = async (holder: string, days: string[]) => {
      recorded.push({ holder, days });
    };

    const res = await handleSaveSpotSchedule(
      {
        auth: { uid: 'ph1' },
        data: {
          spotId: 'spot1',
          days: ['2026-10-18', '2026-10-19'],
          window: { start: '06:00', end: '11:00' },
          serviceIds: ['svc1'],
        },
      },
      deps,
      afterSaveSuccess,
    );

    assert.equal(res.scheduleId, 'id_1');
    assert.deepEqual(recorded, [{ holder: 'ph1', days: ['2026-10-18', '2026-10-19'] }]);

    // Failing afterSave does not fail the callable
    const afterSaveFail = async () => {
      throw new Error('quote withdrawal network timeout');
    };

    const res2 = await handleSaveSpotSchedule(
      {
        auth: { uid: 'ph1' },
        data: {
          spotId: 'spot1',
          days: ['2026-10-25'],
          window: { start: '06:00', end: '11:00' },
          serviceIds: ['svc1'],
        },
      },
      deps,
      afterSaveFail,
    );

    assert.equal(res2.scheduleId, 'id_2');
    assert.deepEqual(res2.addedDays, ['2026-10-25']);
  });

  it('saveSlotOffer contact_leak -> invalid-argument field name', async () => {
    const { deps, store } = createTestDeps();
    store.seedSchedule({
      id: 'sched1',
      providerId: 'ph1',
      assigneeId: null,
      spotId: 'spot1',
      days: ['2026-10-18'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['svc1'],
      priceFrom: 1_000_000,
      status: 'open',
      createdAt: '2026-10-15T00:00:00.000Z',
      updatedAt: '2026-10-15T00:00:00.000Z',
    });

    await assert.rejects(
      handleSaveSlotOffer(
        {
          auth: { uid: 'ph1' },
          data: {
            scheduleId: 'sched1',
            name: 'Gọi 0903 123 456',
            price: 500_000,
            slotMinutes: 30,
            gapMinutes: 10,
            photoCount: 20,
            editedCount: 5,
            deliveryDays: 3,
          },
        },
        deps,
      ),
      (err: unknown) => {
        assert.ok(err instanceof HttpsError);
        assert.equal(err.code, 'invalid-argument');
        assert.equal(err.message, 'contact_leak');
        assert.equal((err.details as Record<string, unknown>).code, 'contact_leak');
        assert.equal((err.details as Record<string, unknown>).field, 'name');
        return true;
      },
    );
  });
});
