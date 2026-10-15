import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, withSpot, withSchedule, withOffer } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { isDomainError } from '../src/errors.js';
import { EMPTY_SPOT_STATS, type Spot } from '../src/spot.js';
import type { SpotSchedule } from '../src/spot_schedule.js';
import type { SlotOffer } from '../src/spot_slots.js';
import type { ServiceRecord } from '../src/booking_ports.js';
import { spotBusyAt } from '../src/spot_booking.js';

describe('spot_booking use cases', () => {
  const hoTaySpot: Spot = {
    id: 'spot-ho-tay',
    name: 'Hồ Tây',
    city: 'Hà Nội',
    areaCode: 'hn',
    point: { lat: 21.05, lng: 105.82 },
    geohash: 'w7e5q',
    radiusM: 1000,
    cover: null,
    description: 'Điểm ngắm hoàng hôn và bình minh đẹp nhất Hà Nội',
    tips: ['Đi sớm đón bình minh'],
    seasonMonths: [10, 11, 12],
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 10,
    stats: EMPTY_SPOT_STATS,
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
    rankedAt: null,
    updatedBy: 'admin',
  };

  const hoTaySchedule: SpotSchedule = {
    id: 'sched-an-ho-tay',
    providerId: 'p-an',
    assigneeId: null,
    spotId: 'spot-ho-tay',
    days: ['2026-10-17'],
    window: { start: '06:00', end: '11:00' },
    serviceIds: ['seed-service-portrait'],
    priceFrom: 490_000,
    status: 'open',
    createdAt: '2026-10-08T00:00:00.000Z',
    updatedAt: '2026-10-08T00:00:00.000Z',
  };

  const binhMinhOffer: SlotOffer = {
    id: 'offer-binh-minh',
    providerId: 'p-an',
    scheduleId: 'sched-an-ho-tay',
    spotId: 'spot-ho-tay',
    name: 'Bình minh Hồ Tây 30 phút',
    price: 490_000,
    slotMinutes: 30,
    gapMinutes: 10,
    photoCount: 30,
    editedCount: 10,
    deliveryDays: 3,
    status: 'open',
    createdAt: '2026-10-08T00:00:00.000Z',
    updatedAt: '2026-10-08T00:00:00.000Z',
  };

  const portraitService: ServiceRecord = {
    id: 'seed-service-portrait',
    photographerId: 'p-an',
    name: 'Chân dung',
    price: 1_000_000,
    durationMinutes: 120,
    active: true,
  };

  function setupWorld() {
    const world = createBookingWorld(new Date('2026-10-10T03:00:00.000Z')); // 10:00 VN
    world.providers.set('p-an', { verified: true, onboardingComplete: true });
    world.services.set('seed-service-portrait', portraitService);
    world.store.availability.set('p-an_2026-10-17', {
      state: 'spot',
      scheduleId: 'sched-an-ho-tay',
      spotId: 'spot-ho-tay',
    });
    withSpot(world, hoTaySpot);
    withSchedule(world, hoTaySchedule);
    withOffer(world, binhMinhOffer);
    return world;
  }

  it('a package booking 06:00–08:00 creates a draft with spotId, spotScheduleId, source spot, place = spot name and point, and adds 06:00–08:00 to spot_days', async () => {
    const world = setupWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'Nhà tôi' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    assert.equal(draft.spotId, 'spot-ho-tay');
    assert.equal(draft.spotScheduleId, 'sched-an-ho-tay');
    assert.equal(draft.source, 'spot');
    assert.deepEqual(draft.place, { name: 'Hồ Tây', point: hoTaySpot.point });

    const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
    assert.ok(spotDay);
    assert.deepEqual(spotDay.taken, [{ start: '06:00', end: '08:00' }]);
  });

  it('the place sent by the client is ignored', async () => {
    const world = setupWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'Nhà tôi' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    assert.equal(draft.place.name, 'Hồ Tây');
    assert.deepEqual(draft.place.point, hoTaySpot.point);
  });

  it('a second customer at 08:15–10:15 succeeds; at 08:10 is slot_taken', async () => {
    const world = setupWorld();
    await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    // 08:10 vs 06:00-08:00 has gap 10 < 15 min required -> slot_taken
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c2',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '08:10',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'slot_taken',
    );

    // 08:15 vs 06:00-08:00 has gap 15 -> succeeds
    const draft2 = await createBookingDraft(world.deps, {
      customerId: 'c2',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '08:15',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });
    assert.equal(draft2.start, '08:15');
    assert.equal(draft2.end, '10:15');
  });

  it('a time outside the window (10:00 for 120 min) is outside_schedule; a day not in the schedule is outside_schedule; a package not in serviceIds is outside_schedule; a cancelled schedule is outside_schedule', async () => {
    const world = setupWorld();

    // 10:00 for 120 min ends at 12:00, outside 11:00 window
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '10:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );

    // Day not in schedule
    world.store.availability.set('p-an_2026-10-18', {
      state: 'spot',
      scheduleId: 'sched-an-ho-tay',
      spotId: 'spot-ho-tay',
    });
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-18',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );

    // Package not in serviceIds
    world.services.set('seed-service-other', {
      id: 'seed-service-other',
      photographerId: 'p-an',
      name: 'Khác',
      price: 500_000,
      durationMinutes: 60,
      active: true,
    });
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-other',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );

    // Cancelled schedule
    const cancelledSched = { ...hoTaySchedule, id: 'sched-cancelled', status: 'cancelled' as const };
    withSchedule(world, cancelledSched);
    world.store.availability.set('p-an_2026-10-17', {
      state: 'spot',
      scheduleId: 'sched-cancelled',
      spotId: 'spot-ho-tay',
    });
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-cancelled',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );
  });

  it('an archived spot is spot_archived', async () => {
    const world = setupWorld();
    withSpot(world, { ...hoTaySpot, status: 'archived' });

    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'spot_archived',
    );
  });

  it('a slot booking at 06:40 builds the synthetic service (name, 490.000, 30 min), serviceId = offerId, source spot_slot, interval carries offerId', async () => {
    const world = setupWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'offer-binh-minh',
      day: '2026-10-17',
      start: '06:40',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
      slotOfferId: 'offer-binh-minh',
    });

    assert.equal(draft.serviceId, 'offer-binh-minh');
    assert.equal(draft.serviceSnapshot.name, 'Bình minh Hồ Tây 30 phút');
    assert.equal(draft.serviceSnapshot.price, 490_000);
    assert.equal(draft.serviceSnapshot.durationMinutes, 30);
    assert.equal(draft.end, '07:10');
    assert.equal(draft.source, 'spot_slot');
    assert.equal(draft.slotOfferId, 'offer-binh-minh');

    const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
    assert.ok(spotDay);
    assert.deepEqual(spotDay.taken, [{ start: '06:40', end: '07:10', offerId: 'offer-binh-minh' }]);
  });

  it('two slots of the same offer back to back both succeed; a package booking right after a slot needs 15 minutes', async () => {
    const world = setupWorld();
    // Slots for offer: 06:00-06:30, 06:40-07:10 (10 min gap between slots of offer is built-in)
    // 06:00-06:30
    await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'offer-binh-minh',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
      slotOfferId: 'offer-binh-minh',
    });

    // 06:40-07:10 (same offer) succeeds!
    const draft2 = await createBookingDraft(world.deps, {
      customerId: 'c2',
      photographerId: 'p-an',
      serviceId: 'offer-binh-minh',
      day: '2026-10-17',
      start: '06:40',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
      slotOfferId: 'offer-binh-minh',
    });
    assert.equal(draft2.start, '06:40');

    // Package booking at 07:20 (10 min after slot ends 07:10, but package needs 15 min) -> slot_taken
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '07:20',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'slot_taken',
    );

    // Package booking at 07:25 (15 min after slot ends 07:10) -> succeeds!
    const draft3 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '07:25',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });
    assert.equal(draft3.start, '07:25');
  });

  it('a slot start off the grid (06:30) is outside_schedule; a closed offer is outside_schedule; expectedPrice ≠ offer price is price_changed', async () => {
    const world = setupWorld();

    // Off grid (grid is 06:00, 06:40, 07:20...)
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-binh-minh',
          day: '2026-10-17',
          start: '06:30',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
          slotOfferId: 'offer-binh-minh',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );

    // Closed offer
    withOffer(world, { ...binhMinhOffer, id: 'offer-closed', status: 'closed' });
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-closed',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
          slotOfferId: 'offer-closed',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'outside_schedule',
    );

    // expectedPrice mismatch
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-binh-minh',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
          slotOfferId: 'offer-binh-minh',
          expectedPrice: 400_000,
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'price_changed',
    );
  });

  it('a slot booking with addons or pickup is invalid_argument (T6); a package booking at a spot keeps add-ons and pickup (#190)', async () => {
    const world = setupWorld();

    // Slot booking with addons
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-binh-minh',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
          slotOfferId: 'offer-binh-minh',
          addons: [{ id: 'addon_1', quantity: 1 }],
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );

    // Slot booking with pickup
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-binh-minh',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
          slotOfferId: 'offer-binh-minh',
          pickup: { address: 'Hà Nội' },
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );
  });

  it('slotOfferId without spotScheduleId is invalid_argument', async () => {
    const world = setupWorld();
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'offer-binh-minh',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          slotOfferId: 'offer-binh-minh',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );
  });

  it('two concurrent spot drafts for clashing times: exactly one succeeds, the other is slot_taken', async () => {
    const world = setupWorld();
    const p1 = createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });
    const p2 = createBookingDraft(world.deps, {
      customerId: 'c2',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '07:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    const firstRejected = rejected[0];
    assert.ok(firstRejected);
    assert.ok(isDomainError(firstRejected.reason));
    assert.equal(firstRejected.reason.code, 'slot_taken');
  });

  it('a customer\'s second draft on the same schedule replaces the first and its interval', async () => {
    const world = setupWorld();
    const d1 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    const d2 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '08:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    // Previous draft d1 deleted
    assert.equal(await world.store.getBooking(d1.id), null);
    // New draft exists
    assert.ok(await world.store.getBooking(d2.id));

    // Spot interval replaced
    const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
    assert.ok(spotDay);
    assert.deepEqual(spotDay.taken, [{ start: '08:00', end: '10:00' }]);
  });

  it('a provider who stopped accepting orders is refused before any spot read', async () => {
    const world = setupWorld();
    world.providers.set('p-an', { verified: true, onboardingComplete: false }); // not accepting

    let spotRead = false;
    const origGetSpot = world.store.getSpot.bind(world.store);
    world.store.getSpot = async (id: string) => {
      spotRead = true;
      return origGetSpot(id);
    };

    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'ignored' },
          spotScheduleId: 'sched-an-ho-tay',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'not_accepting_orders',
    );

    assert.equal(spotRead, false);
  });

  it('a studio spot booking is pre-assigned to the schedule\'s member (assigneeId, assigneeKind member, assignedAt) and is not added to studio_day_load', async () => {
    const world = setupWorld();
    const studioSched: SpotSchedule = {
      ...hoTaySchedule,
      id: 'sched-studio',
      providerId: 'studio_1',
      assigneeId: 'member_1',
    };
    withSchedule(world, studioSched);
    world.providers.set('studio_1', { verified: true, onboardingComplete: true });
    world.providers.set('member_1', { verified: true, onboardingComplete: true });
    world.services.set('seed-service-portrait', {
      ...portraitService,
      photographerId: 'studio_1',
    });
    world.store.availability.set('member_1_2026-10-17', {
      state: 'spot',
      scheduleId: 'sched-studio',
      spotId: 'spot-ho-tay',
    });

    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'studio_1',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-studio',
    });

    assert.equal(draft.assigneeId, 'member_1');
    assert.equal(draft.assigneeKind, 'member');
    assert.ok(draft.assignedAt);
  });

  it('spotBusyAt is true inside the window of today\'s spot day and false outside it or on another day', () => {
    const rec = { state: 'spot' as const, scheduleId: 'sched-an-ho-tay', spotId: 'spot-ho-tay' };
    const sched: SpotSchedule = {
      ...hoTaySchedule,
      days: ['2026-10-17'],
      window: { start: '06:00', end: '11:00' },
    };

    // 2026-10-17 07:00 VN (+07:00) -> UTC 00:00
    const inside = new Date('2026-10-17T07:00:00+07:00');
    assert.equal(spotBusyAt(rec, sched, inside), true);

    // 2026-10-17 05:30 VN -> before window
    const before = new Date('2026-10-17T05:30:00+07:00');
    assert.equal(spotBusyAt(rec, sched, before), false);

    // 2026-10-17 12:00 VN -> after window
    const after = new Date('2026-10-17T12:00:00+07:00');
    assert.equal(spotBusyAt(rec, sched, after), false);

    // Another day: 2026-10-18 07:00 VN
    const otherDay = new Date('2026-10-18T07:00:00+07:00');
    assert.equal(spotBusyAt(rec, sched, otherDay), false);
  });
});
