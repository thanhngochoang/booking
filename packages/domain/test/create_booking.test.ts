import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { createBookingWorld, newDraft, withAddons, withStudio } from './support/booking_world.js';
import type { ServiceAddon } from '../src/addon.js';
import { addonDraftFields } from '../src/addon_pricing.js';
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

    it('refuses a blocked pair with blocked and holds nothing', async () => {
      const world = createBookingWorld();
      world.blocks.block('p1', 'c1');
      await assert.rejects(
        createBookingDraft(world.deps, input),
        (err: unknown) => err instanceof DomainError && err.code === 'blocked',
      );
      assert.equal(await world.store.getAvailabilityDay('p1', '2026-10-15'), null);
      assert.equal(await world.store.getCustomerDraftForDay('c1', 'p1', '2026-10-15'), null);
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
        'deliveryDays',
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
        assert.notEqual((draft as unknown as Record<string, unknown>)[k], undefined);
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

    it('copies deliveryDays from the service (5 → 5; absent → 7; 120 → 90)', () => {
      const draft5 = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, deliveryDays: 5 },
      });
      assert.equal(draft5.deliveryDays, 5);

      const draftAbsent = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, deliveryDays: undefined },
      });
      assert.equal(draftAbsent.deliveryDays, 7);

      const draft120 = buildBookingDraft({
        ...BASE,
        service: { ...serviceRecord, deliveryDays: 120 },
      });
      assert.equal(draft120.deliveryDays, 90);
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

  describe('add-ons (#190)', () => {
    const T = '2026-10-01T00:00:00.000Z';
    const mk = (id: string, over: Partial<ServiceAddon>): ServiceAddon => ({
      id, providerId: 'p1', kind: 'makeup', name: id, price: 800_000, unit: 'per_person', maxQty: 4,
      serviceIds: [], active: true, createdAt: T, updatedAt: T, ...over,
    });
    const worldWithAddons = () =>
      withAddons(createBookingWorld(), 'p1', [
        mk('makeup', {}),
        mk('transport', { kind: 'transport', unit: 'per_booking', price: 300_000, maxQty: 1 }),
      ]);
    const rejectsWith = async (p: Promise<unknown>, c: string): Promise<void> => {
      await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === c);
    };
    const BASE_DRAFT: BookingDraftInput = {
      id: 'b1', customerId: 'c1', photographerId: 'p1',
      service: { id: 'srv_01', photographerId: 'p1', name: 'Gói', price: 1_000_000, durationMinutes: 120, active: true },
      day: '2026-10-15', start: '14:00', place: { name: 'Nhà thờ Lớn' }, now: new Date('2026-10-10T10:00:00.000Z'),
    };
    const LINE = {
      addonId: 'makeup', kind: 'makeup', name: 'makeup', unit: 'per_person', unitPrice: 800_000, qty: 2, amount: 1_600_000,
    } as const;

    it('buildBookingDraft with addons sets deposit to the total and remaining 0', () => {
      const d = buildBookingDraft({ ...BASE_DRAFT, addons: [LINE] });
      assert.equal(d.deposit, 2_600_000);
      assert.equal(d.remaining, 0);
      assert.deepEqual(d.addons, [LINE]);
    });

    it('buildBookingDraft without addons writes no addons field and no pickup', () => {
      for (const d of [buildBookingDraft(BASE_DRAFT), buildBookingDraft({ ...BASE_DRAFT, addons: [] })]) {
        assert.equal('addons' in d, false);
        assert.equal('pickup' in d, false);
      }
    });

    it('addonDraftFields returns {} without add-ons and pickup', () => {
      assert.deepEqual(addonDraftFields({}), {});
    });

    it('draftTotal is the package price without add-ons and the total with them', () => {
      assert.equal(draftTotal(BASE_DRAFT), 1_000_000);
      assert.equal(draftTotal({ ...BASE_DRAFT, addons: [LINE] }), 2_600_000);
    });

    it('createBookingDraft prices picks from the catalogue and stores the lines', async () => {
      const world = worldWithAddons();
      const b = await newDraft(world, { addons: [{ addonId: 'transport', qty: 1 }, { addonId: 'makeup', qty: 2 }], pickup: { name: '12 Lê Lợi' } });
      assert.deepEqual(b.addons?.map((l) => [l.addonId, l.amount]), [['makeup', 1_600_000], ['transport', 300_000]]);
      assert.equal(b.deposit, 2_900_000);
      assert.deepEqual(await world.store.getBooking(b.id), b);
    });

    it('createBookingDraft charges the server total whatever expectedTotal says', async () => {
      const world = worldWithAddons();
      await rejectsWith(newDraft(world, { addons: [{ addonId: 'makeup', qty: 2 }], expectedTotal: 1_000_000 }), 'addon_changed');
      assert.equal(world.store.bookings.size, 0);
      assert.equal(await world.store.getAvailabilityDay('p1', '2026-10-15'), null);
    });

    it('matching expectedTotal succeeds', async () => {
      const world = worldWithAddons();
      const b = await newDraft(world, { addons: [{ addonId: 'makeup', qty: 2 }], expectedTotal: 2_600_000 });
      assert.equal(b.deposit, 2_600_000);
    });

    it('a changed package price is still price_changed before any add-on check', async () => {
      const world = worldWithAddons();
      await rejectsWith(
        newDraft(world, { expectedPrice: 900_000, addons: [{ addonId: 'nope', qty: 1 }], expectedTotal: 1 }),
        'price_changed',
      );
    });

    it('pickup_required without pickup when transport is picked', async () => {
      await rejectsWith(newDraft(worldWithAddons(), { addons: [{ addonId: 'transport', qty: 1 }] }), 'pickup_required');
    });

    it('the pickup is stored when transport is picked; dropped otherwise', async () => {
      const world = worldWithAddons();
      const b = await newDraft(world, { addons: [{ addonId: 'transport', qty: 1 }], pickup: { name: '12 Lê Lợi' } });
      assert.deepEqual(b.pickup, { name: '12 Lê Lợi' });
      const other = createBookingWorld();
      const c = await newDraft(other, { pickup: { name: '12 Lê Lợi' } });
      assert.equal('pickup' in c, false);
    });

    it('a closed provider is still refused before add-ons are read', async () => {
      const world = worldWithAddons();
      world.providers.set('p1', { verified: false, onboardingComplete: false });
      let reads = 0;
      const real = world.addons.listAddons.bind(world.addons);
      world.addons.listAddons = async (id) => {
        reads += 1;
        return real(id);
      };
      await rejectsWith(newDraft(world, { addons: [{ addonId: 'nope', qty: 1 }] }), 'not_accepting_orders');
      assert.equal(reads, 0);
    });
  });

  describe('studio bookings (#136)', () => {
    const rejectsWith = (p: Promise<unknown>, code: string) =>
      assert.rejects(p, (err: unknown) => err instanceof DomainError && err.code === code);
    const studioDraft = (world: ReturnType<typeof createBookingWorld>, over: Record<string, unknown> = {}) =>
      newDraft(world, { photographerId: 's1', serviceId: 'srv_s1', ...over });

    it('a booking with a studio is isStudio, unassigned, deadline 24 h before start', async () => {
      const world = withStudio(createBookingWorld());
      const b = await studioDraft(world);
      // 2026-10-15 14:00 VN = 07:00Z
      assert.equal(b.isStudio, true);
      assert.equal(b.assignStatus, 'unassigned');
      assert.equal(b.assigneeId, null);
      assert.equal(b.assigneeKind, null);
      assert.equal(b.assignDeadline, '2026-10-14T07:00:00.000Z');
      assert.equal(b.assignOverdue, false);
      assert.deepEqual(b.assignments, []);
      assert.deepEqual(b.assignRemindersSent, []);
      assert.equal(b.changeRequest, null);
      assert.equal(b.studioFault, null);
      assert.equal(b.assignmentReturned, null);
      assert.deepEqual(await world.store.getBooking(b.id), b);
    });

    it('a studio booking starting in 10 h gets a deadline 2 h from now', async () => {
      // 2026-10-10T10:00Z = 17:00 VN; 03:00 VN on the 11th is 10 h later
      const world = withStudio(createBookingWorld());
      const b = await studioDraft(world, { day: '2026-10-11', start: '03:00' });
      assert.equal(b.assignDeadline, '2026-10-10T12:00:00.000Z');
    });

    it('a deadline never falls after the start', async () => {
      const world = withStudio(createBookingWorld());
      const b = await studioDraft(world, { day: '2026-10-10', start: '18:00' }); // 1 h ahead
      assert.equal(b.assignDeadline, '2026-10-10T11:00:00.000Z');
    });

    it('an individual booking carries no studio fields', async () => {
      const world = withStudio(createBookingWorld());
      const b = await newDraft(world);
      for (const key of ['isStudio', 'assigneeId', 'assignStatus', 'assignDeadline', 'assignments', 'changeRequest', 'studioFault']) {
        assert.equal(key in b, false, key);
      }
    });

    it('a studio draft is held on the studio day load, not on the studio day', async () => {
      const world = withStudio(createBookingWorld());
      const b = await studioDraft(world);
      assert.equal(await world.store.getAvailabilityDay('s1', '2026-10-15'), null);
      assert.deepEqual(world.store.getStudioDayLoad('s1', '2026-10-15')?.unassignedIds, [b.id]);
    });

    it("the customer's new draft replaces their earlier one on the load", async () => {
      const world = withStudio(createBookingWorld(), 's1', ['m1']);
      const first = await studioDraft(world);
      const second = await studioDraft(world, { start: '15:00' });
      assert.equal(await world.store.getBooking(first.id), null);
      assert.deepEqual(world.store.getStudioDayLoad('s1', '2026-10-15')?.unassignedIds, [second.id]);
    });

    it('orderProfile closed is not_accepting_orders', async () => {
      const world = withStudio(createBookingWorld());
      world.providers.set('s1', { verified: false, onboardingComplete: true });
      await rejectsWith(studioDraft(world), 'not_accepting_orders');
      assert.equal(world.store.getStudioDayLoad('s1', '2026-10-15'), null);
    });

    it('a missing provider profile is not_accepting_orders', async () => {
      const world = withStudio(createBookingWorld());
      world.providers.delete('s1');
      await rejectsWith(studioDraft(world), 'not_accepting_orders');
    });

    it('a quote booking of a studio (built through buildBookingDraft) carries the studio fields', () => {
      const quoteService = { id: 'quote_q1', photographerId: 's1', name: 'Báo giá', price: 2_500_000, durationMinutes: 180, active: true };
      const draft = buildBookingDraft({
        id: 'b_q',
        customerId: 'c1',
        photographerId: 's1',
        service: quoteService,
        day: '2026-10-15',
        start: '14:00',
        place: { name: 'Hồ Gươm' },
        providerType: 'studio',
        now: new Date('2026-10-10T10:00:00.000Z'),
      });
      assert.equal(draft.isStudio, true);
      assert.equal(draft.assignStatus, 'unassigned');
      assert.equal(draft.assignDeadline, '2026-10-14T07:00:00.000Z');
      assert.equal(draft.deposit, 2_500_000);
      const individual = buildBookingDraft({ ...{ id: 'b_i', customerId: 'c1', photographerId: 'p1', service: quoteService, day: '2026-10-15', start: '14:00', place: { name: 'Hồ Gươm' }, now: new Date('2026-10-10T10:00:00.000Z') }, providerType: 'artist' });
      assert.equal('isStudio' in individual, false);
    });
  });
});
