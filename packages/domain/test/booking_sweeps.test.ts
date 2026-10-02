import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { createDeposit } from '../src/create_deposit.js';
import { confirmFakePayment } from '../src/handle_payment.js';
import { transitionBooking } from '../src/transition_booking.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';

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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });

    // Advance 25 hours (past 24h accept deadline)
    world.clock.advanceHours(25);

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.expiredRequests, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'expired');
    assert.equal(b?.depositRefunded, 300_000);

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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Advance to 2026-10-14 07:00 UTC (exactly 24h before start)
    world.clock.setTime(new Date('2026-10-14T07:00:00.000Z'));

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.upcomingTransitions, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'upcoming');
  });

  it('auto-completes upcoming booking 24h after end time', async () => {
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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Advance to 2026-10-16 09:00 UTC (24h after end time)
    world.clock.setTime(new Date('2026-10-16T09:00:00.000Z'));

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.autoCompletions, 1);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.status, 'completed');
  });

  it('releases held escrow 24h after completion', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Complete at 2026-10-15 09:30 UTC
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'complete', actorId: 'p1' });

    // Advance to 24 hours after completion: 2026-10-16 09:30 UTC
    world.clock.setTime(new Date('2026-10-16T09:30:00.000Z'));

    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.releasedEscrows, 1);

    const payment = (await world.store.getPaymentsForBooking(draft.id))[0];
    assert.equal(payment?.escrowStatus, 'released');
    assert.ok(payment?.releasedAt);

    const b = await world.store.getBooking(draft.id);
    assert.equal(b?.escrowStatus, 'released');
  });
});
