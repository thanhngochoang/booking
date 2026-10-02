import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { createDeposit } from '../src/create_deposit.js';
import { confirmFakePayment } from '../src/handle_payment.js';
import { transitionBooking } from '../src/transition_booking.js';
import { openDispute } from '../src/open_dispute.js';
import { verifyPaymentLedgerInvariant } from '../src/escrow.js';

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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });

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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });
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
    assert.equal(cancelled.depositRefunded, 150_000);
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
    const dep = await createDeposit(world.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
    await confirmFakePayment(world.deps, { paymentId: dep.paymentId, customerId: 'c1' });
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
});
