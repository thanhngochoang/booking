import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import {
  memberDayReleasable,
  studioDayCapacity,
  studioDayLoadWith,
  studioDayMark,
  type StudioDayFacts,
} from '../src/studio_capacity.js';
import { assignBooking } from '../src/studio_assignment.js';
import { transitionBooking } from '../src/transition_booking.js';
import {
  acceptedStudioBooking,
  createBookingWorld,
  newDraft,
  withStudio,
  type BookingWorld,
} from './support/booking_world.js';

const DAY = '2026-10-15';

const facts = (over: Partial<StudioDayFacts> = {}): StudioDayFacts => ({
  studioOff: false,
  memberDays: [
    { uid: 'm1', verified: true, free: true },
    { uid: 'm2', verified: true, free: true },
    { uid: 'm3', verified: true, free: true },
  ],
  unassignedIds: [],
  assignedIds: [],
  ...over,
});

const rejectsWith = (p: Promise<unknown>, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);

function studioWorld(members: readonly string[] = ['m1', 'm2', 'm3'], unverified: readonly string[] = []): BookingWorld {
  const world = withStudio(createBookingWorld(), 's1', members, { unverified });
  for (const c of ['c3', 'c4', 'c5']) world.contacts.set(c, { phone: '+84903000111', name: c });
  return world;
}

const studioDraft = (world: BookingWorld, customerId: string) =>
  newDraft(world, { customerId, photographerId: 's1', serviceId: 'srv_s1' });

describe('studioDayCapacity (Decision 26)', () => {
  it('counts verified free members, assigned bookings and the load', () => {
    assert.deepEqual(studioDayCapacity(facts()), { freeMembers: 3, capacity: 3, load: 0, bookable: true, full: false });
    const busy = facts({
      memberDays: [
        { uid: 'm1', verified: true, free: false },
        { uid: 'm2', verified: true, free: true },
        { uid: 'm3', verified: false, free: true },
      ],
      unassignedIds: ['b2'],
      assignedIds: ['b1'],
    });
    assert.deepEqual(studioDayCapacity(busy), { freeMembers: 1, capacity: 2, load: 2, bookable: false, full: true });
  });

  it('an off day is full and takes nothing', () => {
    const c = studioDayCapacity(facts({ studioOff: true }));
    assert.equal(c.bookable, false);
    assert.equal(c.full, true);
  });

  it('a studio without members is full', () => {
    assert.equal(studioDayCapacity(facts({ memberDays: [] })).full, true);
  });

  it('memberDayReleasable keeps one free member per unassigned booking', () => {
    assert.equal(memberDayReleasable(facts({ unassignedIds: ['a', 'b'] }), 'm1'), true);
    assert.equal(memberDayReleasable(facts({ unassignedIds: ['a', 'b', 'c'] }), 'm1'), false);
    const alone = facts({ memberDays: [{ uid: 'm1', verified: true, free: true }] });
    assert.equal(memberDayReleasable(alone, 'm1'), true);
    assert.equal(memberDayReleasable({ ...alone, unassignedIds: ['a'] }, 'm1'), false);
    // unverified or unknown members never hold the studio's capacity
    const unverified = facts({ memberDays: [{ uid: 'm1', verified: false, free: true }], unassignedIds: ['a'] });
    assert.equal(memberDayReleasable(unverified, 'm1'), true);
    assert.equal(memberDayReleasable(facts({ unassignedIds: ['a', 'b', 'c'] }), 'x9'), true);
  });

  it('studioDayMark sets and clears the derived full day, never touching an off day', () => {
    const full = facts({ unassignedIds: ['a', 'b', 'c'] });
    assert.equal(studioDayMark(null, full), 'set_full');
    assert.equal(studioDayMark({ state: 'full' }, full), null);
    assert.equal(studioDayMark({ state: 'full' }, facts()), 'clear_full');
    assert.equal(studioDayMark(null, facts()), null);
    assert.equal(studioDayMark({ state: 'off' }, full), null);
  });

  it('studioDayLoadWith moves an id between the lists', () => {
    const key = { studioId: 's1', day: DAY };
    const a = studioDayLoadWith(null, key, 'b1', 'unassigned', 't0');
    assert.deepEqual(a, { studioId: 's1', day: DAY, unassignedIds: ['b1'], assignedIds: [], updatedAt: 't0' });
    const b = studioDayLoadWith({ unassignedIds: ['b0', 'b1'], assignedIds: [] }, key, 'b1', 'assigned', 't1');
    assert.deepEqual([b.unassignedIds, b.assignedIds], [['b0'], ['b1']]);
    const c = studioDayLoadWith(b, key, 'b1', null, 't2');
    assert.deepEqual([c.unassignedIds, c.assignedIds], [['b0'], []]);
  });
});

describe('studio capacity through the order paths', () => {
  it('a studio with 3 free members takes 3 bookings that day', async () => {
    const world = studioWorld();
    for (const c of ['c1', 'c2', 'c3']) await studioDraft(world, c);
    assert.equal(world.store.getStudioDayLoad('s1', DAY)?.unassignedIds.length, 3);
  });

  it('the 4th is refused (day_taken)', async () => {
    const world = studioWorld();
    for (const c of ['c1', 'c2', 'c3']) await studioDraft(world, c);
    await rejectsWith(studioDraft(world, 'c4'), 'day_taken');
    assert.equal(world.store.getStudioDayLoad('s1', DAY)?.unassignedIds.length, 3);
  });

  it("a member's personal booking reduces the studio's capacity", async () => {
    const world = studioWorld();
    await newDraft(world, { customerId: 'c5', photographerId: 'm1', serviceId: 'srv_m1' });
    await studioDraft(world, 'c1');
    await studioDraft(world, 'c2');
    await rejectsWith(studioDraft(world, 'c3'), 'day_taken');
  });

  it("a member's personal booking is refused when the studio needs that member that day", async () => {
    const world = studioWorld();
    for (const c of ['c1', 'c2', 'c3']) await studioDraft(world, c);
    await rejectsWith(newDraft(world, { customerId: 'c5', photographerId: 'm1', serviceId: 'srv_m1' }), 'day_taken');
    assert.equal(await world.store.getAvailabilityDay('m1', DAY), null);
    // another day is free
    await newDraft(world, { customerId: 'c5', photographerId: 'm1', serviceId: 'srv_m1', day: '2026-10-16' });
  });

  it("assigning blocks the member's day and keeps the studio's capacity", async () => {
    const world = studioWorld();
    const b = await acceptedStudioBooking(world);
    await assignBooking(world.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm1' });
    assert.deepEqual(await world.store.getAvailabilityDay('m1', DAY), { state: 'booked', bookingId: b.id });
    assert.deepEqual(world.store.getStudioDayLoad('s1', DAY)?.assignedIds, [b.id]);
    assert.deepEqual(world.store.getStudioDayLoad('s1', DAY)?.unassignedIds, []);
    await studioDraft(world, 'c2');
    await studioDraft(world, 'c3');
    await rejectsWith(studioDraft(world, 'c4'), 'day_taken');
  });

  it('an unverified member adds no capacity', async () => {
    const world = studioWorld(['m1', 'm2', 'm3'], ['m3']);
    await studioDraft(world, 'c1');
    await studioDraft(world, 'c2');
    await rejectsWith(studioDraft(world, 'c3'), 'day_taken');
  });

  it('a studio off day takes nothing', async () => {
    const world = studioWorld();
    world.store.availability.set(`s1_${DAY}`, { state: 'off' });
    await rejectsWith(studioDraft(world, 'c1'), 'day_taken');
  });

  it('cancelling an unassigned studio booking frees a place', async () => {
    const world = studioWorld(['m1']);
    const b = await acceptedStudioBooking(world);
    await rejectsWith(studioDraft(world, 'c2'), 'day_taken');
    await transitionBooking(world.deps, { bookingId: b.id, action: 'cancel', actorId: 'c1' });
    assert.deepEqual(world.store.getStudioDayLoad('s1', DAY)?.unassignedIds, []);
    await studioDraft(world, 'c2');
  });

  it('an expired studio draft leaves the load', async () => {
    const world = studioWorld(['m1']);
    await studioDraft(world, 'c1');
    world.clock.advanceMinutes(31);
    const { runBookingSweeps } = await import('../src/booking_sweeps.js');
    await runBookingSweeps(world.deps);
    assert.deepEqual(world.store.getStudioDayLoad('s1', DAY)?.unassignedIds, []);
  });

  it('accepting a studio booking does not book the studio day', async () => {
    const world = studioWorld();
    await acceptedStudioBooking(world);
    assert.equal(await world.store.getAvailabilityDay('s1', DAY), null);
  });
});
