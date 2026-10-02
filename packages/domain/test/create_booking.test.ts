import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { DomainError } from '../src/errors.js';

describe('Task 4: createBookingDraft', () => {
  it('creates draft booking and holds calendar day as pending', async () => {
    const world = createBookingWorld();
    const booking = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
      note: 'Chụp áo dài',
    });

    assert.equal(booking.status, 'draft');
    assert.equal(booking.deposit, 300_000);
    assert.equal(booking.remaining, 700_000);
    assert.equal(booking.end, '16:00'); // 14:00 + 120 mins
    assert.equal(booking.note, 'Chụp áo dài');

    // Check calendar availability
    const dayRecord = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.deepEqual(dayRecord, {
      state: 'pending',
      bookingId: booking.id,
    });

    // Check private contact snapshot
    const contact = await world.store.getContactSnapshot(booking.id);
    assert.equal(contact?.phone, '+84903123456');
    assert.equal(contact?.allowZalo, true);
  });

  it('Review Focus 1: another customer attempting same day gets day_taken', async () => {
    const world = createBookingWorld();
    await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    // Customer c2 tries to book the same day
    await assert.rejects(
      createBookingDraft(world.deps, {
        customerId: 'c2',
        photographerId: 'p1',
        serviceId: 'srv_01',
        day: '2026-10-15',
        start: '09:00',
        place: { name: 'Bờ Hồ' },
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'day_taken',
    );
  });

  it('Review Focus 2: customer own earlier draft is replaced, not day_taken', async () => {
    const world = createBookingWorld();
    const draft1 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    // Customer c1 changes mind to 10:00 on the same day
    const draft2 = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '10:00',
      place: { name: 'Phố cổ' },
    });

    assert.notEqual(draft1.id, draft2.id);
    assert.equal(draft2.start, '10:00');

    // Earlier draft deleted from store
    const old = await world.store.getBooking(draft1.id);
    assert.equal(old, null);

    // Day still held by draft2
    const dayRecord = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.deepEqual(dayRecord, {
      state: 'pending',
      bookingId: draft2.id,
    });
  });

  it('fails with phone_required if customer has no phone', async () => {
    const world = createBookingWorld();
    // remove phone for c1
    world.contacts.delete('c1');

    await assert.rejects(
      createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 'srv_01',
        day: '2026-10-15',
        start: '14:00',
        place: { name: 'Nhà thờ Lớn' },
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'phone_required',
    );
  });

  it('fails with day_taken if day is off or booked', async () => {
    const world = createBookingWorld();
    await world.store.setAvailabilityDay('p1', '2026-10-15', { state: 'booked', bookingId: 'b_other' });

    await assert.rejects(
      createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 'srv_01',
        day: '2026-10-15',
        start: '14:00',
        place: { name: 'Nhà thờ Lớn' },
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'day_taken',
    );
  });

  it('fails with invalid_argument if place name is too short', async () => {
    const world = createBookingWorld();
    await assert.rejects(
      createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 'srv_01',
        day: '2026-10-15',
        start: '14:00',
        place: { name: 'ab' },
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
  });
});
