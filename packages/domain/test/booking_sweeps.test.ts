import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { createBookingWorld, newDraft, payDraft } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { createBookingDraft } from '../src/create_booking.js';
import { transitionBooking } from '../src/transition_booking.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { freezeBookingPayment } from './support/dispute_world.js';
import { newTicketPayment } from '../src/event_payments.js';

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
  it('an unpaid entry-ticket payment (releaseAfter set at creation, S30) is never released', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const intent = newTicketPayment({
      id: 'pay_entry', event: { id: 'en1', host: { type: 'organizer', id: 'org1', name: null, avatarUrl: null, verified: true } },
      registrationId: 'rg1', payerId: 'c1', method: 'bank_qr', provider: 'fake', amount: 70_000,
      now: world.clock.now(), expiresAt: new Date('2026-10-10T10:15:00.000Z'),
      lineKind: 'entry_ticket', releaseAfter: new Date('2026-10-12T10:00:00.000Z'),
    });
    world.store.payments.set(intent.id, intent);
    world.clock.setTime(new Date('2026-10-13T10:00:00.000Z'));
    assert.equal((await runBookingSweeps(world.deps)).releasedEscrows, 0);
    assert.equal(world.store.payments.get(intent.id)?.escrowStatus, 'held');
    assert.equal(world.store.payments.get(intent.id)?.status, 'created');
  });

  it('a disputed payment is not released by runBookingSweeps even after releaseAfter', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const legacy = await newDraft(world);
    const { paymentId: legacyPay } = await payDraft(world, legacy.id);
    await transitionBooking(world.deps, { bookingId: legacy.id, action: 'accept', actorId: 'p1' });
    const split = await newDraft(world, { day: '2026-10-16' });
    const { paymentId: splitPay } = await payDraft(world, split.id);
    await transitionBooking(world.deps, { bookingId: split.id, action: 'accept', actorId: 'p1' });

    // Legacy: a payment without milestones scheduled for release (as completion did before #152);
    // split: marked shot, its shoot milestone releases at shotAt + 24 h.
    world.clock.setTime(new Date('2026-10-16T09:30:00.000Z'));
    const lp = world.store.payments.get(legacyPay);
    assert.ok(lp && lp.milestones === undefined);
    world.store.payments.set(legacyPay, { ...lp, releaseAfter: '2026-10-17T09:30:00.000Z' });
    await transitionBooking(world.deps, { bookingId: split.id, action: 'mark_shot', actorId: 'p1' });
    freezeBookingPayment(world.store, legacy.id, world.clock.now());
    freezeBookingPayment(world.store, split.id, world.clock.now(), 'shoot');

    world.clock.setTime(new Date('2026-10-18T10:00:00.000Z'));
    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.releasedEscrows, 0);
    assert.equal(world.store.payments.get(legacyPay)?.escrowStatus, 'disputed');
    const shoot = world.store.payments.get(splitPay)?.milestones?.find((m) => m.kind === 'shoot');
    assert.equal(shoot?.status, 'disputed');
    assert.equal(world.store.payments.get(splitPay)?.escrowStatus, 'disputed');
    assert.equal([...world.store.ledgerEntries.values()].filter((e) => e.type === 'escrow_released').length, 0);
  });

  it('a delivery dispute does not hold the shoot milestone: the due shoot milestone is released, the disputed one never', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const b = await newDraft(world);
    const { paymentId } = await payDraft(world, b.id);
    await transitionBooking(world.deps, { bookingId: b.id, action: 'accept', actorId: 'p1' });
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'p1' });
    freezeBookingPayment(world.store, b.id, world.clock.now(), 'delivery');
    assert.equal((await world.store.findReleasableEscrows(world.clock.now())).length, 0);

    world.clock.setTime(new Date('2026-10-16T10:00:00.000Z'));
    assert.deepEqual((await world.store.findReleasableEscrows(world.clock.now())).map((p) => p.id), [paymentId]);
    const sweeps = await runBookingSweeps(world.deps);
    assert.equal(sweeps.releasedEscrows, 1);
    const p = world.store.payments.get(paymentId);
    const status = (k: string) => p?.milestones?.find((m) => m.kind === k)?.status;
    assert.equal(status('shoot'), 'released');
    assert.equal(status('delivery'), 'disputed');
    assert.equal(p?.escrowStatus, 'disputed');
    assert.equal((await world.store.getBooking(b.id))?.escrowStatus, 'disputed');
    const released = [...world.store.ledgerEntries.values()].filter((e) => e.type === 'escrow_released');
    assert.deepEqual(released.map((e) => e.amount), [PAID / 2]);

    // Nothing else is due: a second run releases nothing (the disputed milestone has no releaseAfter).
    assert.equal((await runBookingSweeps(world.deps)).releasedEscrows, 0);
  });

  it('the escrow release reads everything before its first write (Firestore refuses a read after a write)', async () => {
    const world = createBookingWorld(new Date('2026-10-10T10:00:00.000Z'));
    const b = await newDraft(world);
    const { paymentId } = await payDraft(world, b.id);
    await transitionBooking(world.deps, { bookingId: b.id, action: 'accept', actorId: 'p1' });
    world.clock.setTime(new Date('2026-10-15T09:30:00.000Z'));
    await transitionBooking(world.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'p1' });
    world.clock.setTime(new Date('2026-10-16T10:00:00.000Z'));

    // A store whose transactions throw on any read made after a write, like the Admin SDK.
    const store = world.deps.store;
    const strict = Object.create(store) as typeof store;
    strict.runTransaction = (fn) =>
      store.runTransaction((tx) => {
        let wrote = false;
        const guarded = new Proxy(tx, {
          get(target, key, receiver) {
            const value = Reflect.get(target, key, receiver);
            if (typeof value !== 'function') return value;
            const name = String(key);
            return (...args: unknown[]) => {
              if (/^(get|find)/.test(name) && wrote) throw new Error(`read after write: ${name}`);
              if (/^(set|add|put|delete|increment)/.test(name)) wrote = true;
              return value.apply(target, args);
            };
          },
        });
        return fn(guarded);
      });
    const sweeps = await runBookingSweeps({ ...world.deps, store: strict });
    assert.equal(sweeps.releasedEscrows, 1);
    const shoot = world.store.payments.get(paymentId)?.milestones?.find((m) => m.kind === 'shoot');
    assert.equal(shoot?.status, 'released');
  });
});
