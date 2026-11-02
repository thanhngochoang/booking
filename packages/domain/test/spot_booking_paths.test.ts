import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, withSpot, withSchedule, withOffer } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { createPayment } from '../src/create_payment.js';
import { transitionBooking } from '../src/transition_booking.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { proposeReschedule } from '../src/reschedule.js';
import { publishEvent, saveEventDraft, updateEvent } from '../src/event_use_cases.js';
import { createEventWorld, ph1, publishedEvent, rawEvent } from './support/event_world.js';
import { createChatWorld } from './support/chat_world.js';
import { MemoryBookingStore } from '../src/memory_booking_store.js';
import { chatIdFor, type Chat } from '../src/chat.js';
import { isDomainError } from '../src/errors.js';
import { EMPTY_SPOT_STATS, type Spot } from '../src/spot.js';
import type { SpotSchedule } from '../src/spot_schedule.js';
import type { SlotOffer } from '../src/spot_slots.js';
import type { Booking } from '../src/booking.js';

describe('spot_booking availability paths', () => {
  const hoTaySpot: Spot = {
    id: 'spot-ho-tay',
    name: 'Hồ Tây',
    city: 'Hà Nội',
    areaCode: 'hn',
    point: { lat: 21.05, lng: 105.82 },
    geohash: 'w7e5q',
    radiusM: 1000,
    cover: null,
    description: 'Hồ Tây',
    tips: [],
    seasonMonths: [],
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 10,
    stats: EMPTY_SPOT_STATS,
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
    rankedAt: null,
    managedBy: null,
    access: null,
    openHours: null,
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

  function setupWorld() {
    const world = createBookingWorld(new Date('2026-10-10T03:00:00.000Z')); // 10:00 VN
    world.providers.set('p-an', { verified: true, onboardingComplete: true });
    world.services.set('seed-service-portrait', {
      id: 'seed-service-portrait',
      photographerId: 'p-an',
      name: 'Chân dung',
      price: 1_000_000,
      durationMinutes: 120,
      active: true,
    });
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

  it('a package booking without spotScheduleId on a spot day is day_taken', async () => {
    const world = setupWorld();
    await assert.rejects(
      async () => {
        await createBookingDraft(world.deps, {
          customerId: 'c1',
          photographerId: 'p-an',
          serviceId: 'seed-service-portrait',
          day: '2026-10-17',
          start: '06:00',
          place: { name: 'Hồ Gươm' },
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'day_taken',
    );
  });

  it('createPayment on a spot draft succeeds while its interval exists; after the interval is gone it is day_taken', async () => {
    const world = setupWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    // While interval exists in spot_days, createPayment succeeds
    const payment = await createPayment(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      method: 'bank_qr',
    });
    assert.ok(payment.paymentId);

    // Remove the interval from spot_days
    const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
    assert.ok(spotDay);
    await world.store.setSpotDay({ ...spotDay, taken: [] });

    // Now createPayment gives day_taken
    await assert.rejects(
      async () => {
        await createPayment(world.deps, {
          bookingId: draft.id,
          customerId: 'c1',
          method: 'bank_qr',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'day_taken',
    );
  });

  it('accept writes nothing to availability for a spot booking', async () => {
    const world = setupWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '06:00',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    // Transition draft to requested
    const requested = {
      ...draft,
      status: 'requested' as const,
      acceptDeadline: new Date(world.clock.now().getTime() + 24 * 60 * 60 * 1000).toISOString(),
    };
    await world.store.runTransaction(async (tx) => {
      await tx.setBooking(requested);
    });

    // Accept by photographer
    await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'accept',
      actorId: 'p-an',
    });

    // Availability remains state: 'spot' (not 'booked')
    const avail = await world.store.getAvailabilityDay('p-an', '2026-10-17');
    assert.equal(avail?.state, 'spot');
    assert.equal(avail?.scheduleId, 'sched-an-ho-tay');
  });

  it('decline, expire and cancel each remove exactly the booking\'s interval', async () => {
    // 1. Decline
    {
      const world = setupWorld();
      const b1 = await createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '06:00',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });
      await createBookingDraft(world.deps, {
        customerId: 'c2',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '08:15',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });

      await world.store.runTransaction(async (tx) => {
        await tx.setBooking({
          ...b1,
          status: 'requested',
          acceptDeadline: new Date(world.clock.now().getTime() + 24 * 60 * 60 * 1000).toISOString(),
        });
      });

      await transitionBooking(world.deps, {
        bookingId: b1.id,
        action: 'decline',
        actorId: 'p-an',
      });

      const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
      assert.ok(spotDay);
      assert.deepEqual(spotDay.taken, [{ start: '08:15', end: '10:15' }]);
    }

    // 2. Expire
    {
      const world = setupWorld();
      const b1 = await createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '06:00',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });
      await createBookingDraft(world.deps, {
        customerId: 'c2',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '08:15',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });

      await world.store.runTransaction(async (tx) => {
        await tx.setBooking({
          ...b1,
          status: 'requested',
          acceptDeadline: new Date(world.clock.now().getTime() - 1000).toISOString(),
        });
      });

      await transitionBooking(world.deps, {
        bookingId: b1.id,
        action: 'expire',
      });

      const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
      assert.ok(spotDay);
      assert.deepEqual(spotDay.taken, [{ start: '08:15', end: '10:15' }]);
    }

    // 3. Cancel
    {
      const world = setupWorld();
      const b1 = await createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '06:00',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });
      await createBookingDraft(world.deps, {
        customerId: 'c2',
        photographerId: 'p-an',
        serviceId: 'seed-service-portrait',
        day: '2026-10-17',
        start: '08:15',
        place: { name: 'ignored' },
        spotScheduleId: 'sched-an-ho-tay',
      });

      await world.store.runTransaction(async (tx) => {
        await tx.setBooking({
          ...b1,
          status: 'requested',
          acceptDeadline: new Date(world.clock.now().getTime() + 24 * 60 * 60 * 1000).toISOString(),
        });
      });

      await transitionBooking(world.deps, {
        bookingId: b1.id,
        action: 'cancel',
        actorId: 'c1',
      });

      const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
      assert.ok(spotDay);
      assert.deepEqual(spotDay.taken, [{ start: '08:15', end: '10:15' }]);
    }
  });

  it('the draft sweep removes the expired draft\'s interval and leaves the others', async () => {
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

    // Advance 10 minutes before d2 so d1 expires before d2
    world.clock.advanceMinutes(10);

    await createBookingDraft(world.deps, {
      customerId: 'c2',
      photographerId: 'p-an',
      serviceId: 'seed-service-portrait',
      day: '2026-10-17',
      start: '08:15',
      place: { name: 'ignored' },
      spotScheduleId: 'sched-an-ho-tay',
    });

    // Advance clock past d1's payableUntil (30 min from d1: 10 + 25 = 35 min total, d2 is at 25 min)
    world.clock.advanceMinutes(25);

    const sweepResult = await runBookingSweeps(world.deps);
    assert.equal(sweepResult.cleanedDrafts, 1);

    const spotDay = await world.store.getSpotDay('sched-an-ho-tay', '2026-10-17');
    assert.ok(spotDay);
    assert.deepEqual(spotDay.taken, [{ start: '08:15', end: '10:15' }]);
  });

  it('a reschedule proposal on a spot booking is not_eligible; a reschedule proposal of a normal booking into a spot day is day_taken', async () => {
    const { deps: chatDeps, chats: chatStore } = createChatWorld();
    const bookings = new MemoryBookingStore();
    const deps = { ...chatDeps, bookings };

    // 1. Reschedule proposal on a spot booking -> not_eligible
    const spotBooking: Booking = {
      id: 'book_spot',
      customerId: 'cust1',
      photographerId: 'phot1',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1000000, durationMinutes: 60 },
      day: '2026-10-17',
      start: '06:00',
      end: '07:00',
      place: { name: 'Hồ Tây' },
      status: 'accepted',
      deposit: 1000000,
      remaining: 0,
      spotScheduleId: 'sched-an-ho-tay',
      spotId: 'spot-ho-tay',
      source: 'spot',
      version: 1,
      createdAt: '2026-10-01T12:00:00.000Z',
      updatedAt: '2026-10-01T12:00:00.000Z',
    };
    bookings.bookings.set(spotBooking.id, { ...spotBooking });
    const spotChatId = chatIdFor(spotBooking.customerId, spotBooking.photographerId);
    const spotChat: Chat = {
      id: spotChatId,
      kind: 'booking',
      customerId: spotBooking.customerId,
      photographerId: spotBooking.photographerId,
      assigneeId: null,
      bookingId: spotBooking.id,
      bookingStatus: 'accepted',
      photographerRepliedAt: new Date('2026-10-01T12:00:00.000Z'),
      customerMessagesBeforeReply: 0,
      rescheduleUsed: false,
      lastMessageAt: null,
      lastMessagePreview: null,
      lastSenderId: null,
      readOnlyAt: null,
      blockedAt: null,
      createdAt: new Date('2026-10-01T12:00:00.000Z'),
      updatedAt: new Date('2026-10-01T12:00:00.000Z'),
    };
    chatStore.chats.set(spotChatId, spotChat);

    await assert.rejects(
      async () => {
        await proposeReschedule(deps, {
          actorId: 'cust1',
          bookingId: spotBooking.id,
          day: '2026-10-18',
          start: '09:00',
          clientId: 'client_msg_1',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'not_eligible',
    );

    // 2. Normal booking proposal into a spot day -> day_taken
    const normalBooking: Booking = {
      id: 'book_normal',
      customerId: 'cust2',
      photographerId: 'phot1',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1000000, durationMinutes: 60 },
      day: '2026-10-15',
      start: '10:00',
      end: '11:00',
      place: { name: 'Hồ Gươm' },
      status: 'accepted',
      deposit: 1000000,
      remaining: 0,
      version: 1,
      createdAt: '2026-10-01T12:00:00.000Z',
      updatedAt: '2026-10-01T12:00:00.000Z',
    };
    bookings.bookings.set(normalBooking.id, { ...normalBooking });
    bookings.availability.set('phot1_2026-10-17', {
      state: 'spot',
      scheduleId: 'sched-an-ho-tay',
      spotId: 'spot-ho-tay',
    });
    const normalChatId = chatIdFor(normalBooking.customerId, normalBooking.photographerId);
    chatStore.chats.set(normalChatId, {
      ...spotChat,
      id: normalChatId,
      customerId: normalBooking.customerId,
      bookingId: normalBooking.id,
    });

    await assert.rejects(
      async () => {
        await proposeReschedule(deps, {
          actorId: 'cust2',
          bookingId: normalBooking.id,
          day: '2026-10-17',
          start: '09:00',
          clientId: 'client_msg_2',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'day_taken',
    );
  });

  it('publishEvent on a host\'s spot day is day_taken; updateEvent moving to a spot day is day_taken', async () => {
    const w = createEventWorld();
    const dayKey = '2026-10-17';
    w.store.seedAvailability('ph1', dayKey, { state: 'spot' });

    // publishEvent on spot day
    const ev1Id = 'ev1_aaaaaaaaaaaaaaaaaaaa';
    await saveEventDraft(
      w.deps,
      ph1,
      rawEvent(ev1Id, 'ph1', {
        startAt: '2026-10-17T02:00:00.000Z',
        endAt: '2026-10-17T04:00:00.000Z',
        registrationDeadline: '2026-10-16T12:00:00.000Z',
      }),
    );

    await assert.rejects(
      async () => {
        await publishEvent(w.deps, ph1, { eventId: ev1Id });
      },
      (err: unknown) => isDomainError(err) && err.code === 'day_taken',
    );

    // updateEvent moving to spot day
    const ev2Id = await publishedEvent(
      w,
      {
        startAt: '2026-10-15T02:00:00.000Z',
        endAt: '2026-10-15T04:00:00.000Z',
        registrationDeadline: '2026-10-14T12:00:00.000Z',
      },
      ph1,
      'ev2_aaaaaaaaaaaaaaaaaaaa',
    );

    await assert.rejects(
      async () => {
        await updateEvent(w.deps, ph1, {
          eventId: ev2Id,
          startAt: '2026-10-17T02:00:00.000Z',
          endAt: '2026-10-17T04:00:00.000Z',
          registrationDeadline: '2026-10-16T12:00:00.000Z',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'day_taken',
    );
  });
});
