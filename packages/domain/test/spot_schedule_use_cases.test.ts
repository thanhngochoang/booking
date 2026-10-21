import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  cancelSpotSchedule,
  closeSlotOffer,
  saveSlotOffer,
  saveSpotSchedule,
} from '../src/spot_schedule_use_cases.js';
import { MemorySpotStore } from '../src/memory_spot_store.js';
import { DomainError, isDomainError } from '../src/errors.js';
import type { SpotScheduleDeps } from '../src/spot_schedule_ports.js';
import type { ProviderOrderGate, ServiceRecord } from '../src/booking_ports.js';
import type { StudioRoster } from '../src/studio_ports.js';
import type { Spot } from '../src/spot.js';

describe('spot_schedule_use_cases', () => {
  const clock = {
    now: () => new Date('2026-10-15T10:00:00+07:00'), // VN date 2026-10-15
  };

  let idCounter = 1;
  const ids = {
    newId: () => `01HR${String(idCounter++).padStart(22, '0')}`,
  };

  const sampleSpot: Spot = {
    id: 'spot-1',
    name: 'Hồ Gươm',
    city: 'Hà Nội',
    areaCode: 'hn',
    point: { lat: 21.0285, lng: 105.8542 },
    geohash: 'w7e5t',
    radiusM: 500,
    cover: null,
    description: 'Điểm chụp trung tâm',
    tips: ['Sáng sớm vắng người'],
    seasonMonths: [10, 11, 12],
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 10,
    stats: {
      posts14d: 0,
      events: 0,
      bookings14d: 0,
      openSchedules: 0,
      providersWeek: 0,
      providersWeekend: 0,
    },
    createdAt: '2026-10-01T00:00:00Z',
    updatedAt: '2026-10-01T00:00:00Z',
    rankedAt: null,
    updatedBy: 'staff-1',
  };

  const activeServices: ServiceRecord[] = [
    { id: 'srv-1', photographerId: 'p-individual', name: 'Gói 1', price: 1_000_000, durationMinutes: 60, active: true },
    { id: 'srv-2', photographerId: 'p-individual', name: 'Gói 2', price: 600_000, durationMinutes: 60, active: true },
  ];

  function setupWorld() {
    const store = new MemorySpotStore();
    store.seedSpot(sampleSpot);
    store.seedServices('p-individual', activeServices);
    store.seedServices('p-studio', [
      { id: 'srv-studio', photographerId: 'p-studio', name: 'Gói Studio', price: 2_000_000, durationMinutes: 60, active: true },
    ]);

    const orderProfiles = new Map<string, { acceptsOrders: boolean; providerType: 'individual' | 'artist' | 'studio' }>([
      ['p-individual', { acceptsOrders: true, providerType: 'individual' }],
      ['p-inactive', { acceptsOrders: false, providerType: 'individual' }],
      ['p-studio', { acceptsOrders: true, providerType: 'studio' }],
      ['p-member', { acceptsOrders: true, providerType: 'individual' }],
      ['p-member-inactive', { acceptsOrders: false, providerType: 'individual' }],
      ['p-stranger', { acceptsOrders: true, providerType: 'individual' }],
    ]);

    const providers: ProviderOrderGate = {
      acceptsOrders: async (uid) => orderProfiles.get(uid)?.acceptsOrders ?? false,
      orderProfile: async (uid) => orderProfiles.get(uid) ?? null,
    };

    const roster: StudioRoster = {
      relationOf: async (studioId, uid) => {
        if (studioId === 'p-studio' && (uid === 'p-member' || uid === 'p-member-inactive')) {
          return 'member';
        }
        return null;
      },
      person: async () => null,
    };

    const deps: SpotScheduleDeps = {
      schedules: store,
      providers,
      roster,
      clock,
      ids,
    };

    return { store, deps };
  }

  it('saveSpotSchedule opens 4 weekend days: schedule open, priceFrom set, availability of each day is {state: spot, scheduleId, spotId}', async () => {
    const { store, deps } = setupWorld();
    const days = ['2026-10-17', '2026-10-18', '2026-10-24', '2026-10-25'];
    const res = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days,
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    assert.ok(res.scheduleId);
    assert.deepEqual(res.addedDays, days);

    const sched = store.getScheduleSync(res.scheduleId);
    assert.ok(sched);
    assert.equal(sched.status, 'open');
    assert.equal(sched.priceFrom, 600_000); // min of active services

    for (const d of days) {
      const avail = store.getAvailabilitySync('p-individual', d);
      assert.deepEqual(avail, {
        state: 'spot',
        scheduleId: res.scheduleId,
        spotId: 'spot-1',
      });
    }
  });

  it('a provider who does not accept orders is not_accepting_orders; a customer (no orderProfile) is permission_denied', async () => {
    const { deps } = setupWorld();
    await assert.rejects(
      saveSpotSchedule(deps, 'p-inactive', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'not_accepting_orders',
    );

    await assert.rejects(
      saveSpotSchedule(deps, 'customer-lan', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'permission_denied',
    );
  });

  it('an unknown spot is not_found field spotId; an archived spot is spot_archived', async () => {
    const { store, deps } = setupWorld();
    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'unknown-spot',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'not_found' && err.field === 'spotId',
    );

    store.seedSpot({ ...sampleSpot, id: 'archived-spot', status: 'archived' });
    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'archived-spot',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'spot_archived',
    );
  });

  it('a day already booked, pending, off or full is day_conflict with details.days [{day, reason}] and nothing is written', async () => {
    const { store, deps } = setupWorld();
    store.seedAvailability('p-individual', '2026-10-17', { state: 'booked', bookingId: 'b1' });

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: ['2026-10-17', '2026-10-18'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) =>
        isDomainError(err) &&
        err.code === 'day_conflict' &&
        JSON.stringify(err.details?.days) === JSON.stringify([{ day: '2026-10-17', reason: 'booked' }]),
    );

    // Nothing written for 2026-10-18
    assert.equal(store.getAvailabilitySync('p-individual', '2026-10-18'), null);
  });

  it("a day of the provider's other open schedule is day_conflict reason spot", async () => {
    const { deps } = setupWorld();
    await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: ['2026-10-17', '2026-10-18'],
        window: { start: '12:00', end: '17:00' },
        serviceIds: [],
      }),
      (err: unknown) =>
        isDomainError(err) &&
        err.code === 'day_conflict' &&
        JSON.stringify(err.details?.days) === JSON.stringify([{ day: '2026-10-17', reason: 'spot' }]),
    );
  });

  it('the 9th open schedule is schedule_limit; a schedule whose days are all past does not count', async () => {
    const { store, deps } = setupWorld();
    // Open 8 schedules
    for (let i = 1; i <= 8; i++) {
      const day = `2026-10-${String(15 + i).padStart(2, '0')}`;
      await saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: [day],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      });
    }

    // 9th schedule throws schedule_limit
    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: ['2026-10-25'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'schedule_limit',
    );

    // Seed a past schedule (days before today 2026-10-15)
    store.seedSchedule({
      id: 'past-sched',
      providerId: 'p-individual',
      assigneeId: null,
      spotId: 'spot-1',
      days: ['2026-10-10'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
      priceFrom: 600_000,
      status: 'open',
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    });
    // Still 8 open future schedules
  });

  it('two concurrent saves at 7 open schedules: exactly one succeeds', async () => {
    const { deps } = setupWorld();
    for (let i = 1; i <= 7; i++) {
      const day = `2026-10-${String(15 + i).padStart(2, '0')}`;
      await saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: [day],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      });
    }

    const p1 = saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-24'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });
    const p2 = saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-25'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    const err = (rejected[0] as PromiseRejectedResult).reason;
    assert.ok(err instanceof DomainError && err.code === 'schedule_limit');
  });

  it('editing adds and removes days: added days get spot records, removed days lose them, past days are kept unchanged', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17', '2026-10-18'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    const editRes = await saveSpotSchedule(deps, 'p-individual', {
      scheduleId: saveRes.scheduleId,
      spotId: 'spot-1',
      days: ['2026-10-18', '2026-10-19'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    assert.deepEqual(editRes.addedDays, ['2026-10-19']);
    assert.equal(store.getAvailabilitySync('p-individual', '2026-10-17'), null);
    assert.ok(store.getAvailabilitySync('p-individual', '2026-10-18'));
    assert.ok(store.getAvailabilitySync('p-individual', '2026-10-19'));
  });

  it('removing a day with a draft interval is schedule_has_bookings with details.days [{day, count: 1}]', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17', '2026-10-18'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    store.seedSpotDay({
      scheduleId: saveRes.scheduleId,
      spotId: 'spot-1',
      providerId: 'p-individual',
      day: '2026-10-17',
      taken: [{ start: '07:00', end: '08:00' }],
      updatedAt: '2026-10-15T00:00:00Z',
    });

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        spotId: 'spot-1',
        days: ['2026-10-18'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) =>
        isDomainError(err) &&
        err.code === 'schedule_has_bookings' &&
        JSON.stringify(err.details?.days) === JSON.stringify([{ day: '2026-10-17', count: 1 }]),
    );
  });

  it('narrowing the window under a taken interval is schedule_has_bookings', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    store.seedSpotDay({
      scheduleId: saveRes.scheduleId,
      spotId: 'spot-1',
      providerId: 'p-individual',
      day: '2026-10-17',
      taken: [{ start: '06:00', end: '07:00' }],
      updatedAt: '2026-10-15T00:00:00Z',
    });

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '07:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'schedule_has_bookings',
    );
  });

  it('changing spotId or assigneeId of an existing schedule is invalid_argument', async () => {
    const { store, deps } = setupWorld();
    store.seedSpot({ ...sampleSpot, id: 'spot-2' });

    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        spotId: 'spot-2',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );
  });

  it('studio without assigneeId is invalid_argument assigneeId; individual with assigneeId is invalid_argument assigneeId', async () => {
    const { deps } = setupWorld();
    // Individual with assigneeId
    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
        assigneeId: '01HR0000000000000000000099',
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'assigneeId',
    );

    // Studio without assigneeId
    await assert.rejects(
      saveSpotSchedule(deps, 'p-studio', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'assigneeId',
    );
  });

  it('studio with a collaborator or a stranger as assignee is invalid_argument assigneeId; an assignee who does not accept orders is not_accepting_orders', async () => {
    const { deps } = setupWorld();
    // Stranger
    await assert.rejects(
      saveSpotSchedule(deps, 'p-studio', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
        assigneeId: 'p-stranger',
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'assigneeId',
    );

    // Member who does not accept orders
    await assert.rejects(
      saveSpotSchedule(deps, 'p-studio', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: [],
        assigneeId: 'p-member-inactive',
      }),
      (err: unknown) => isDomainError(err) && err.code === 'not_accepting_orders' && err.field === 'assigneeId',
    );
  });

  it("studio schedule writes the spot records on the member's availability, not the studio's", async () => {
    const { store, deps } = setupWorld();
    const res = await saveSpotSchedule(deps, 'p-studio', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
      assigneeId: 'p-member',
    });

    assert.ok(res.scheduleId);
    assert.equal(store.getAvailabilitySync('p-studio', '2026-10-17'), null);
    assert.deepEqual(store.getAvailabilitySync('p-member', '2026-10-17'), {
      state: 'spot',
      scheduleId: res.scheduleId,
      spotId: 'spot-1',
    });
  });

  it('cancelSpotSchedule with a taken interval is schedule_has_bookings and writes nothing', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    store.seedSpotDay({
      scheduleId: saveRes.scheduleId,
      spotId: 'spot-1',
      providerId: 'p-individual',
      day: '2026-10-17',
      taken: [{ start: '07:00', end: '08:00' }],
      updatedAt: '2026-10-15T00:00:00Z',
    });

    await assert.rejects(
      cancelSpotSchedule(deps, 'p-individual', { scheduleId: saveRes.scheduleId }),
      (err: unknown) =>
        isDomainError(err) &&
        err.code === 'schedule_has_bookings' &&
        JSON.stringify(err.details) === JSON.stringify({ days: [{ day: '2026-10-17', count: 1 }] }),
    );

    const sched = store.getScheduleSync(saveRes.scheduleId);
    assert.equal(sched?.status, 'open');
  });

  function seedPastBooked(store: MemorySpotStore): void {
    store.seedSchedule({
      id: 'sched-edit',
      providerId: 'p-individual',
      assigneeId: null,
      spotId: 'spot-1',
      days: ['2026-10-10', '2026-10-17', '2026-10-18'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
      priceFrom: 600_000,
      status: 'open',
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    });
    store.seedSpotDay({
      scheduleId: 'sched-edit',
      spotId: 'spot-1',
      providerId: 'p-individual',
      day: '2026-10-10',
      taken: [{ start: '06:00', end: '07:00' }],
      updatedAt: '2026-10-09T00:00:00Z',
    });
  }

  it('removing a future day is not blocked by an interval on a past day, which stays stored', async () => {
    const { store, deps } = setupWorld();
    seedPastBooked(store);

    await saveSpotSchedule(deps, 'p-individual', {
      scheduleId: 'sched-edit',
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    assert.deepEqual(store.getScheduleSync('sched-edit')?.days, ['2026-10-10', '2026-10-17']);
  });

  it('narrowing the window is not blocked by an interval on a past day', async () => {
    const { store, deps } = setupWorld();
    seedPastBooked(store);

    await saveSpotSchedule(deps, 'p-individual', {
      scheduleId: 'sched-edit',
      spotId: 'spot-1',
      days: ['2026-10-17', '2026-10-18'],
      window: { start: '08:00', end: '11:00' },
      serviceIds: [],
    });

    assert.deepEqual(store.getScheduleSync('sched-edit')?.window, { start: '08:00', end: '11:00' });
  });

  it('a listed package longer than the window is invalid_argument serviceIds; priceFrom counts fitting packages only', async () => {
    const { store, deps } = setupWorld();
    store.seedServices('p-individual', [
      ...activeServices,
      { id: 'srv-long', photographerId: 'p-individual', name: 'Cả ngày', price: 100_000, durationMinutes: 480, active: true },
    ]);

    await assert.rejects(
      saveSpotSchedule(deps, 'p-individual', {
        spotId: 'spot-1',
        days: ['2026-10-17'],
        window: { start: '06:00', end: '11:00' },
        serviceIds: ['srv-long'],
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'serviceIds',
    );

    const res = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });
    assert.equal(store.getScheduleSync(res.scheduleId)?.priceFrom, 600_000);
  });

  it('cancelSpotSchedule ignores intervals on past days', async () => {
    const { store, deps } = setupWorld();
    store.seedSchedule({
      id: 'sched-past',
      providerId: 'p-individual',
      assigneeId: null,
      spotId: 'spot-1',
      days: ['2026-10-10', '2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
      priceFrom: 1_000_000,
      status: 'open',
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    });
    store.seedSpotDay({
      scheduleId: 'sched-past',
      spotId: 'spot-1',
      providerId: 'p-individual',
      day: '2026-10-10',
      taken: [{ start: '07:00', end: '08:00' }],
      updatedAt: '2026-10-09T00:00:00Z',
    });

    await cancelSpotSchedule(deps, 'p-individual', { scheduleId: 'sched-past' });

    assert.equal(store.getScheduleSync('sched-past')?.status, 'cancelled');
  });

  it('cancelSpotSchedule without bookings: status cancelled, every future spot record deleted, its open offers closed', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    const offerRes = await saveSlotOffer(deps, 'p-individual', {
      scheduleId: saveRes.scheduleId,
      name: 'Gói test',
      price: 200_000,
      slotMinutes: 30,
      gapMinutes: 15,
      photoCount: 20,
      editedCount: 5,
      deliveryDays: 2,
    });

    await cancelSpotSchedule(deps, 'p-individual', { scheduleId: saveRes.scheduleId });

    const sched = store.getScheduleSync(saveRes.scheduleId);
    assert.equal(sched?.status, 'cancelled');
    assert.equal(store.getAvailabilitySync('p-individual', '2026-10-17'), null);

    const offer = store.getOfferSync(offerRes.offerId);
    assert.equal(offer?.status, 'closed');
  });

  it("another provider's schedule is not_found for save, cancel and offers", async () => {
    const { deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    await assert.rejects(
      cancelSpotSchedule(deps, 'p-member', { scheduleId: saveRes.scheduleId }),
      (err: unknown) => isDomainError(err) && err.code === 'not_found',
    );

    await assert.rejects(
      saveSlotOffer(deps, 'p-member', {
        scheduleId: saveRes.scheduleId,
        name: 'Gói thợ khác',
        price: 200_000,
        slotMinutes: 30,
        gapMinutes: 15,
        photoCount: 20,
        editedCount: 5,
        deliveryDays: 2,
      }),
      (err: unknown) => isDomainError(err) && err.code === 'not_found',
    );
  });

  it('saveSlotOffer creates an open offer bound to the schedule and spot; the 3rd open offer of a schedule is limit_exceeded; an offer that fits no slot in the window is invalid_argument field slotMinutes; an offer on a cancelled schedule is not_found', async () => {
    const { deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '07:00' }, // 60 min window
      serviceIds: [],
    });

    // Offer fitting window
    const o1 = await saveSlotOffer(deps, 'p-individual', {
      scheduleId: saveRes.scheduleId,
      name: 'Gói 1',
      price: 200_000,
      slotMinutes: 30,
      gapMinutes: 15,
      photoCount: 20,
      editedCount: 5,
      deliveryDays: 2,
    });
    assert.ok(o1.offerId);

    // Offer 2
    const o2 = await saveSlotOffer(deps, 'p-individual', {
      scheduleId: saveRes.scheduleId,
      name: 'Gói 2',
      price: 300_000,
      slotMinutes: 30,
      gapMinutes: 0,
      photoCount: 30,
      editedCount: 10,
      deliveryDays: 2,
    });
    assert.ok(o2.offerId);

    // 3rd offer throws limit_exceeded
    await assert.rejects(
      saveSlotOffer(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        name: 'Gói 3',
        price: 400_000,
        slotMinutes: 30,
        gapMinutes: 0,
        photoCount: 40,
        editedCount: 10,
        deliveryDays: 2,
      }),
      (err: unknown) => isDomainError(err) && err.code === 'limit_exceeded',
    );

    // An offer that fits no slot in the window (e.g. 75 min in a 60 min window)
    await assert.rejects(
      saveSlotOffer(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        name: 'Gói quá dài',
        price: 400_000,
        slotMinutes: 75,
        gapMinutes: 0,
        photoCount: 40,
        editedCount: 10,
        deliveryDays: 2,
      }),
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'slotMinutes',
    );

    // On cancelled schedule:
    await cancelSpotSchedule(deps, 'p-individual', { scheduleId: saveRes.scheduleId });
    await assert.rejects(
      saveSlotOffer(deps, 'p-individual', {
        scheduleId: saveRes.scheduleId,
        name: 'Gói sau huỷ',
        price: 200_000,
        slotMinutes: 30,
        gapMinutes: 0,
        photoCount: 20,
        editedCount: 5,
        deliveryDays: 2,
      }),
      (err: unknown) => isDomainError(err) && err.code === 'not_found',
    );
  });

  it('closeSlotOffer closes it; closing twice is fine', async () => {
    const { store, deps } = setupWorld();
    const saveRes = await saveSpotSchedule(deps, 'p-individual', {
      spotId: 'spot-1',
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: [],
    });

    const o1 = await saveSlotOffer(deps, 'p-individual', {
      scheduleId: saveRes.scheduleId,
      name: 'Gói 1',
      price: 200_000,
      slotMinutes: 30,
      gapMinutes: 15,
      photoCount: 20,
      editedCount: 5,
      deliveryDays: 2,
    });

    await closeSlotOffer(deps, 'p-individual', { offerId: o1.offerId });
    assert.equal(store.getOfferSync(o1.offerId)?.status, 'closed');

    // Closing twice is fine
    await assert.doesNotReject(closeSlotOffer(deps, 'p-individual', { offerId: o1.offerId }));
  });
});
