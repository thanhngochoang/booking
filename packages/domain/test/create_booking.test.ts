import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { createBookingWorld, newDraft } from './support/booking_world.js';
import {
  buildBookingDraft,
  createBookingDraft,
  draftTotal,
  type BookingDraftInput,
} from '../src/create_booking.js';
import { DomainError } from '../src/errors.js';

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

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
    assert.equal(booking.deposit, PAID);
    assert.equal(booking.remaining, 0);
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

  it('Review Focus 5: a changed price is refused with price_changed and nothing is written', async () => {
    const world = createBookingWorld();
    // service srv_01 price is 1_000_000
    await assert.rejects(
      createBookingDraft(world.deps, {
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 'srv_01',
        day: '2026-10-15',
        start: '14:00',
        place: { name: 'Nhà thờ Lớn' },
        expectedPrice: 900_000,
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'price_changed',
    );

    // Verify nothing written: availability day is untouched
    const dayRecord = await world.store.getAvailabilityDay('p1', '2026-10-15');
    assert.equal(dayRecord, null);
  });

  it('accepts matching expectedPrice', async () => {
    const world = createBookingWorld();
    const booking = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
      expectedPrice: 1_000_000,
    });
    assert.equal(booking.status, 'draft');
  });

  describe('provider must accept orders', () => {
    const input = {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    };
    const isNotAccepting = (err: unknown) =>
      err instanceof DomainError && err.code === 'not_accepting_orders';

    it('refuses a provider that is not verified with not_accepting_orders', async () => {
      const world = createBookingWorld();
      world.providers.set('p1', { verified: false, onboardingComplete: true });
      await assert.rejects(createBookingDraft(world.deps, input), isNotAccepting);
      assert.equal(await world.store.getAvailabilityDay('p1', '2026-10-15'), null);
      assert.equal(await world.store.getCustomerDraftForDay('c1', 'p1', '2026-10-15'), null);
    });

    it('refuses a verified provider that has not finished setup with not_accepting_orders', async () => {
      const world = createBookingWorld();
      world.providers.set('p1', { verified: true, onboardingComplete: false });
      await assert.rejects(createBookingDraft(world.deps, input), isNotAccepting);
      assert.equal(await world.store.getAvailabilityDay('p1', '2026-10-15'), null);
    });

    it('checks the service before the provider', async () => {
      const world = createBookingWorld();
      world.providers.set('p1', {});
      await assert.rejects(
        createBookingDraft(world.deps, { ...input, serviceId: 'srv_missing' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_found',
      );
    });

    it('checks the provider before price and phone', async () => {
      const world = createBookingWorld();
      world.providers.set('p1', {});
      await assert.rejects(
        createBookingDraft(world.deps, { ...input, customerId: 'c_nophone', expectedPrice: 1 }),
        isNotAccepting,
      );
    });
  });

  describe('buildBookingDraft', () => {
    const world = createBookingWorld();
    const serviceRecord = world.services.get('srv_01');
    assert.ok(serviceRecord, 'service srv_01 must exist');
    const BASE: BookingDraftInput = {
      id: 'b_x',
      customerId: 'c1',
      photographerId: 'p1',
      service: serviceRecord,
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
      note: 'Chụp áo dài',
      now: new Date('2026-10-10T10:00:00.000Z'),
    };

    it('builds the draft from the core input', () => {
      const draft = buildBookingDraft(BASE);
      assert.equal(draft.id, 'b_x');
      assert.equal(draft.customerId, 'c1');
      assert.equal(draft.photographerId, 'p1');
      assert.equal(draft.status, 'draft');
      assert.equal(draft.serviceId, 'srv_01');
      assert.deepEqual(draft.serviceSnapshot, {
        name: serviceRecord.name,
        price: 1_000_000,
        durationMinutes: 120,
      });
      assert.equal(draft.day, '2026-10-15');
      assert.equal(draft.start, '14:00');
      assert.equal(draft.end, '16:00');
      assert.deepEqual(draft.place, { name: 'Nhà thờ Lớn' });
      assert.equal(draft.note, 'Chụp áo dài');
      assert.equal(draft.deposit, 1_000_000);
      assert.equal(draft.remaining, 0);
      assert.equal(draft.payableUntil, '2026-10-10T10:30:00.000Z');
      assert.equal(draft.version, 1);
      assert.equal(draft.createdAt, '2026-10-10T10:00:00.000Z');
      assert.equal(draft.updatedAt, '2026-10-10T10:00:00.000Z');
    });

    it('is pure', () => {
      const inputCopy = structuredClone(BASE);
      const res1 = buildBookingDraft(BASE);
      const res2 = buildBookingDraft(BASE);
      assert.deepEqual(res1, res2);
      assert.deepEqual(BASE, inputCopy);
    });

    it('a plain draft has exactly the core keys', () => {
      const draft = buildBookingDraft(BASE);
      const expectedKeys = [
        'createdAt',
        'customerId',
        'day',
        'deposit',
        'end',
        'id',
        'note',
        'payableUntil',
        'photographerId',
        'place',
        'remaining',
        'revisionsIncluded',
        'serviceId',
        'serviceSnapshot',
        'start',
        'status',
        'updatedAt',
        'version',
      ].sort();

      const actualKeys = Object.keys(draft).sort();
      assert.deepEqual(actualKeys, expectedKeys);
      for (const k of actualKeys) {
        assert.notEqual((draft as Record<string, unknown>)[k], undefined);
      }
    });

    it('snapshots revisionsIncluded from service.revisions, default 1', () => {
      const draftDefault = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, revisions: undefined },
      });
      assert.equal(draftDefault.revisionsIncluded, 1);

      const draft3 = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, revisions: 3 },
      });
      assert.equal(draft3.revisionsIncluded, 3);

      const draft9 = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, revisions: 9 },
      });
      assert.equal(draft9.revisionsIncluded, 5);
    });

    it('deposit comes from draftTotal', () => {
      assert.equal(draftTotal(BASE), 1_000_000);
      assert.equal(
        buildBookingDraft(BASE).deposit,
        computeDeposit(draftTotal(BASE)).deposit,
      );
    });

    it('a quote-style synthetic service works', () => {
      const quoteService = {
        id: '',
        photographerId: 'p1',
        name: 'Gói báo giá',
        price: 2_500_000,
        durationMinutes: 180,
        active: true,
        revisions: 0,
      };
      const draft = buildBookingDraft({
        ...BASE,
        service: quoteService,
      });
      assert.equal(draft.serviceId, '');
      assert.equal(draft.deposit, 2_500_000);
      assert.equal(draft.end, '17:00');
      assert.equal(draft.revisionsIncluded, 0);
    });
  });

  it('createBookingDraft writes exactly buildBookingDraft(...)', async () => {
    const world = createBookingWorld();
    const serviceRecord = world.services.get('srv_01');
    assert.ok(serviceRecord, 'service srv_01 must exist');
    const booking = await newDraft(world, { note: 'Chụp áo dài' });
    const stored = await world.store.getBooking(booking.id);
    const expected = buildBookingDraft({
      id: booking.id,
      customerId: 'c1',
      photographerId: 'p1',
      service: serviceRecord,
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
      note: 'Chụp áo dài',
      now: world.clock.now(),
    });
    assert.deepEqual(stored, expected);
  });
});
