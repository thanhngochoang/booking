import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit, computeRefund } from '../src/booking_policy.js';
import { createBookingWorld, payDraft } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { transitionBooking } from '../src/transition_booking.js';
import { openDispute } from '../src/open_dispute.js';
import { verifyPaymentLedgerInvariant } from '../src/escrow.js';
import { DomainError } from '../src/errors.js';

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

describe('Task 5: transitionBooking and openDispute', () => {
  it('accepts requested booking and marks availability day as booked', async () => {
    const world = createBookingWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft.id);

    const accepted = await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'accept',
      actorId: 'p1',
    });

    assert.equal(accepted.status, 'accepted');
    const day = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.deepEqual(day, {
      state: 'booked',
      bookingId: draft.id,
    });
  });

  it('Review Focus 4: customer cancels 30h before: 50% back now, rest released after start + 24h', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00', // 2026-10-15 07:00 UTC
      place: { name: 'Nhà thờ Lớn' },
    });
    const dep = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });

    // Advance clock to 30 hours before start: 2026-10-14 01:00 UTC
    world.clock.setTime(new Date('2026-10-14T01:00:00.000Z'));

    const cancelled = await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'cancel',
      actorId: 'c1',
      reason: 'Bận đột xuất',
    });

    assert.equal(cancelled.status, 'cancelled');
    assert.equal(cancelled.depositRefunded, computeRefund(PAID, 50));
    assert.equal(cancelled.escrowStatus, 'partially_refunded');

    // Day is freed
    const day = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.equal(day, null);

    // Private contact snapshot removed
    const contact = await world.store.getContactSnapshot(draft.id);
    assert.equal(contact, null);

    // Kept portion releaseAfter is start + 24h: 2026-10-16 07:00 UTC
    const payments = await world.store.getPaymentsForBooking(draft.id);
    assert.equal(payments[0]?.releaseAfter, '2026-10-16T07:00:00.000Z');

    // Invariant check
    const refunds = await world.store.getRefundsForPayment(dep.paymentId);
    const entries = await world.store.getLedgerEntriesForPayment(dep.paymentId);
    const payment = payments[0];
    assert.ok(payment);
    assert.equal(verifyPaymentLedgerInvariant(payment, refunds, entries), true);
  });

  it('openDispute: customer opens dispute within 24h window of completion', async () => {
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

    // Set time after shoot end (shoot ends 16:00 VN = 09:00 UTC)
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'complete', actorId: 'p1' });

    // 10 hours after completion, customer opens dispute
    world.clock.setTime(new Date('2026-10-15T19:30:00.000Z'));
    const disputed = await openDispute(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      reason: 'Nhiếp ảnh gia giao ảnh muộn và thiếu file RAW',
    });

    assert.equal(disputed.escrowStatus, 'disputed');
    const payment = (await world.store.getPaymentsForBooking(draft.id))[0];
    assert.equal(payment?.escrowStatus, 'disputed');
  });

  it('openDispute accepts shot within 24 h of shotAt and approved before checkUntil, refuses approved after checkUntil', async () => {
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

    // Mark shot at 2026-10-15 09:30 UTC
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'mark_shot', actorId: 'p1' });

    // 10 hours after shotAt: customer opens dispute on shot
    world.clock.setTime(new Date('2026-10-15T19:30:00.000Z'));
    const disputedShot = await openDispute(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      reason: 'Vấn đề buổi chụp',
    });
    assert.equal(disputedShot.status, 'shot'); // status unchanged
    assert.equal(disputedShot.escrowStatus, 'disputed');

    // Test approved state:
    world.clock.setTime(new Date('2026-10-10T10:00:00.000Z'));
    const draft2 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-16',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft2.id);
    const b2 = await world.store.getBooking(draft2.id);
    assert.ok(b2);
    world.store.bookings.set(draft2.id, {
      ...b2,
      status: 'approved',
      approvedAt: '2026-10-16T10:00:00.000Z',
      checkUntil: '2026-10-18T10:00:00.000Z',
    });

    // Before checkUntil: accepts
    world.clock.setTime(new Date('2026-10-18T09:00:00.000Z'));
    const disputedApproved = await openDispute(world.deps, {
      bookingId: draft2.id,
      customerId: 'c1',
      reason: 'Bộ ảnh gốc link hỏng',
    });
    assert.equal(disputedApproved.status, 'approved');
    assert.equal(disputedApproved.escrowStatus, 'disputed');

    // After checkUntil: refuses
    world.clock.setTime(new Date('2026-10-10T10:00:00.000Z'));
    const draft3 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-17',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });
    await payDraft(world, draft3.id);
    const b3 = await world.store.getBooking(draft3.id);
    assert.ok(b3);
    world.store.bookings.set(draft3.id, {
      ...b3,
      status: 'approved',
      approvedAt: '2026-10-16T10:00:00.000Z',
      checkUntil: '2026-10-18T10:00:00.000Z',
    });
    world.clock.setTime(new Date('2026-10-18T10:00:01.000Z'));
    await assert.rejects(
      () =>
        openDispute(world.deps, {
          bookingId: draft3.id,
          customerId: 'c1',
          reason: 'Báo muộn sau 48h',
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'conflict',
    );
  });
});
