import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { createBookingWorld, newDraft, payDraft } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { createBookingDraft } from '../src/create_booking.js';
import { transitionBooking } from '../src/transition_booking.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { freezeBookingPayment } from './support/dispute_world.js';

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

describe('Task 5: runBookingSweeps', () => {
  it('cleans up unpaid draft after 30 minutes and frees calendar day', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    // Advance 31 minutes
    world.clock.advanceMinutes(31);

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.cleanedDrafts, 1);

    // Booking gone
    const b = await world.store.getBooking(draft.id);
    assert.equal(b, null);

    // Day is freed
    const day = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.equal(day, null);
  });

  it('expires unaccepted request past acceptDeadline and refunds 100%', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft.id);

    // Advance 25 hours (past 24h accept deadline)
    world.clock.advanceHours(25);

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.expiredRequests, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'expired');
    assert.equal(b?.depositRefunded, PAID);

    // Day is freed
    const day = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.equal(day, null);
  });

  it('transitions accepted to upcoming at T-24h', async () => {
    // Booking start: 2026-10-15 14:00 VN = 07:00 UTC
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Advance to 2026-10-14 07:00 UTC (exactly 24h before start)
    world.clock.setTime(new Date('2026-10-14T07:00:00.000Z'));

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.upcomingTransitions, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'upcoming');
  });

  it('auto mark-shots upcoming booking 24h after end time', async () => {
    // Booking end: 2026-10-15 16:00 VN = 09:00 UTC
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Advance to 2026-10-16 09:00 UTC (24h after end time)
    world.clock.setTime(new Date('2026-10-16T09:00:00.000Z'));

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.autoShots, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'shot');
  });

  it('auto-approve a delivered booking past autoApproveAt', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const booking = {
      id: 'b_del',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '14:00',
      end: '16:00',
      place: { name: 'Studio' },
      status: 'delivered' as const,
      deposit: 1_000_000,
      remaining: 0,
      deliveryRound: 1,
      autoApproveAt: '2026-10-18T10:00:00.000Z',
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };
    world.store.bookings.set(booking.id, booking);

    world.clock.setTime(new Date('2026-10-18T10:00:01.000Z'));
    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.autoApprovals, 1);

    const updated = await world.store.getBooking(booking.id);
    assert.equal(updated?.status, 'approved');
  });

  it('finish an approved booking past checkUntil', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const booking = {
      id: 'b_app',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '14:00',
      end: '16:00',
      place: { name: 'Studio' },
      status: 'approved' as const,
      deposit: 1_000_000,
      remaining: 0,
      deliveryRound: 1,
      checkUntil: '2026-10-20T10:00:00.000Z',
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };
    world.store.bookings.set(booking.id, booking);

    world.clock.setTime(new Date('2026-10-20T10:00:01.000Z'));
    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.finishedChecks, 1);

    const updated = await world.store.getBooking(booking.id);
    assert.equal(updated?.status, 'completed');
    assert.ok(updated?.samplesPurgeAfter);
  });

  it('a failing item does not stop the batch', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    // seeded bad booking in delivered with no delivery document
    const badBooking = {
      id: 'b_bad',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '14:00',
      end: '16:00',
      place: { name: 'Studio' },
      status: 'delivered' as const,
      deposit: 1_000_000,
      remaining: 0,
      deliveryRound: 1,
      autoApproveAt: '2026-10-18T10:00:00.000Z',
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };
    const goodBooking = {
      ...badBooking,
      id: 'b_good',
    };
    world.store.bookings.set(badBooking.id, badBooking);
    world.store.bookings.set(goodBooking.id, goodBooking);

    world.clock.setTime(new Date('2026-10-18T10:00:01.000Z'));
    const sweeps = await runBookingSweeps(world.deps);
    // both processed
    assert.equal(sweeps.autoApprovals, 2);
  });

  it('drafts are deleted when payableUntil has passed', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await newDraft(world);
    assert.equal(draft.payableUntil, '2026-10-10T10:30:00.000Z');

    world.clock.advanceMinutes(29);
    assert.equal((await runBookingSweeps(world.deps)).cleanedDrafts, 0);

    world.clock.advanceMinutes(1); // payableUntil <= now
    assert.equal((await runBookingSweeps(world.deps)).cleanedDrafts, 1);
    assert.equal(await world.store.getBooking(draft.id), null);
    assert.equal(await world.store.getAvailabilityDay('p1', '2026-10-15'), null);
  });

  it('a draft with a live QR past 30 minutes is kept', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await newDraft(world);
    world.clock.advanceMinutes(20);
    await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    // QR expires 10:35, payableUntil 10:40

    world.clock.setTime(new Date('2026-10-10T10:31:00.000Z'));
    assert.equal((await runBookingSweeps(world.deps)).cleanedDrafts, 0);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');

    world.clock.setTime(new Date('2026-10-10T10:40:00.000Z'));
    assert.equal((await runBookingSweeps(world.deps)).cleanedDrafts, 1);
    assert.equal(await world.store.getBooking(draft.id), null);
  });

  it('a draft without payableUntil (old data) is not swept', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await newDraft(world);
    world.store.bookings.set(draft.id, { ...draft, payableUntil: undefined });
    world.clock.advanceHours(5);

    assert.equal((await runBookingSweeps(world.deps)).cleanedDrafts, 0);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
  });
  it('a disputed payment is not released by runBookingSweeps even after releaseAfter', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const legacy = await newDraft(world);
    const { paymentId: legacyPay } = await payDraft(world, legacy.id);
    await transitionBooking(world.deps, { bookingId: legacy.id, action: 'accept', actorId: 'p1' });
    const split = await newDraft(world, { day: '2026-10-16' });
    const { paymentId: splitPay } = await payDraft(world, split.id);
    await transitionBooking(world.deps, { bookingId: split.id, action: 'accept', actorId: 'p1' });

    // Legacy: completed without milestones (releaseAfter = +24 h); split: marked shot (shoot milestone releases at +24 h).
    world.clock.setTime(new Date('2026-10-16T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: legacy.id, action: 'complete', actorId: 'p1' });
    await transitionBooking(world.deps, { bookingId: split.id, action: 'mark_shot', actorId: 'p1' });
    assert.ok(world.store.payments.get(legacyPay)?.releaseAfter);
    freezeBookingPayment(world.store, legacy.id, world.clock.now());
    freezeBookingPayment(world.store, split.id, world.clock.now());

    world.clock.setTime(new Date('2026-10-18T10:00:00.000Z'));
    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.releasedEscrows, 0);
    assert.equal(world.store.payments.get(legacyPay)?.escrowStatus, 'disputed');
    const shoot = world.store.payments.get(splitPay)?.milestones?.find((m) => m.kind === 'shoot');
    assert.equal(shoot?.status, 'disputed');
    assert.equal(world.store.payments.get(splitPay)?.escrowStatus, 'disputed');
    assert.equal([...world.store.ledgerEntries.values()].filter((e) => e.type === 'escrow_released').length, 0);
  });
});
