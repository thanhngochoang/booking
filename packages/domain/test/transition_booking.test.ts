import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit, computeRefund } from '../src/booking_policy.js';
import {
  acceptedStudioBooking,
  createBookingWorld,
  payDraft,
  withStudio,
  type BookingWorld,
} from './support/booking_world.js';
import type { Booking } from '../src/booking.js';
import { assignBooking, declineAssigneeChange, requestAssigneeChange } from '../src/studio_assignment.js';
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

const STUDIO_DAY = '2026-10-15';
// 2026-10-15 14:00 VN = 07:00Z; the assign deadline is 24 h earlier.
const STUDIO_DEADLINE = new Date('2026-10-14T07:00:00.000Z');
const rejectsWith = (p: Promise<unknown>, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
const studioWorld = (): BookingWorld => withStudio(createBookingWorld());
async function assignedStudioBooking(w: BookingWorld, assigneeId = 'm1'): Promise<Booking> {
  const b = await acceptedStudioBooking(w);
  return assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId });
}

describe('studio bookings through transitionBooking (#136)', () => {
  it('cancel frees the assignee\'s day', async () => {
    const w = studioWorld();
    const b = await assignedStudioBooking(w, 'm1');
    await transitionBooking(w.deps, { bookingId: b.id, action: 'cancel', actorId: 's1' });
    assert.equal(await w.store.getAvailabilityDay('m1', STUDIO_DAY), null);
    assert.deepEqual(w.store.getStudioDayLoad('s1', STUDIO_DAY)?.assignedIds, []);
  });

  it('the assignee may complete, not accept or cancel', async () => {
    const w = studioWorld();
    const b = await assignedStudioBooking(w, 'm1');
    await rejectsWith(transitionBooking(w.deps, { bookingId: b.id, action: 'cancel', actorId: 'm1' }), 'permission_denied');
    await rejectsWith(transitionBooking(w.deps, { bookingId: b.id, action: 'accept', actorId: 'm1' }), 'permission_denied');
    w.clock.setTime(new Date('2026-10-15T09:00:00.000Z')); // after the 16:00 VN end
    const shot = await transitionBooking(w.deps, { bookingId: b.id, action: 'complete', actorId: 'm1' });
    assert.equal(shot.status, 'shot');
  });

  it('a former assignee cannot act on the booking', async () => {
    const w = studioWorld();
    const b = await assignedStudioBooking(w, 'm1');
    await assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm2' });
    w.clock.setTime(new Date('2026-10-15T09:00:00.000Z'));
    await rejectsWith(transitionBooking(w.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'm1' }), 'permission_denied');
  });

  it('cancel_studio_fault refunds 100% when overdue (before the sweep)', async () => {
    const w = studioWorld();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(STUDIO_DEADLINE);
    const after = await transitionBooking(w.deps, { bookingId: b.id, action: 'cancel_studio_fault', actorId: 'c1' });
    assert.equal(after.status, 'cancelled');
    assert.deepEqual(after.cancel, { by: 'studio_fault', reason: 'assign_overdue', at: STUDIO_DEADLINE.toISOString(), refundPercent: 100 });
    assert.equal(after.depositRefunded, b.deposit);
    const refunds = [...w.store.refunds.values()];
    assert.equal(refunds.length, 1);
    assert.equal(refunds[0]?.amount, b.deposit);
  });

  it('cancel_studio_fault without a fault is not_eligible', async () => {
    const w = studioWorld();
    const b = await assignedStudioBooking(w);
    await rejectsWith(
      transitionBooking(w.deps, { bookingId: b.id, action: 'cancel_studio_fault', actorId: 'c1' }),
      'not_eligible',
    );
  });

  it('only the customer uses cancel_studio_fault', async () => {
    const w = studioWorld();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(STUDIO_DEADLINE);
    await rejectsWith(
      transitionBooking(w.deps, { bookingId: b.id, action: 'cancel_studio_fault', actorId: 's1' }),
      'permission_denied',
    );
  });

  it('a second cancel_studio_fault is conflict', async () => {
    const w = studioWorld();
    const b = await assignedStudioBooking(w);
    await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    await declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: 'Kín lịch' });
    const after = await transitionBooking(w.deps, { bookingId: b.id, action: 'cancel_studio_fault', actorId: 'c1' });
    assert.equal(after.cancel?.reason, 'change_declined');
    assert.equal(await w.store.getAvailabilityDay('m1', STUDIO_DAY), null);
    await rejectsWith(
      transitionBooking(w.deps, { bookingId: b.id, action: 'cancel_studio_fault', actorId: 'c1' }),
      'conflict',
    );
    assert.equal([...w.store.refunds.values()].length, 1);
  });
});
