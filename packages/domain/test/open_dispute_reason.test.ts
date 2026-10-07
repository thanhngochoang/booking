import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createBookingDraft } from '../src/create_booking.js';
import { openDispute } from '../src/open_dispute.js';
import { transitionBooking } from '../src/transition_booking.js';
import { createBookingWorld, payDraft } from './support/booking_world.js';

describe('openDispute reason', () => {
  it('a dispute stores the trimmed reason and the time on the payment', async () => {
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
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'complete', actorId: 'p1' });
    world.clock.setTime(new Date('2026-10-15T19:30:00.000Z'));
    await openDispute(world.deps, { bookingId: draft.id, customerId: 'c1', reason: '  Giao ảnh muộn  ' });

    const payment = (await world.store.getPaymentsForBooking(draft.id))[0];
    assert.equal(payment?.escrowStatus, 'disputed');
    assert.deepEqual(payment?.dispute, { reason: 'Giao ảnh muộn', openedAt: '2026-10-15T19:30:00.000Z' });
  });
});
