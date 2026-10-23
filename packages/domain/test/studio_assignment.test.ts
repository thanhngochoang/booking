import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { Booking } from '../src/booking.js';
import type { StudioBookingTx } from '../src/booking_ports.js';
import { DomainError } from '../src/errors.js';
import {
  assignBooking,
  assignDeadlineFor,
  assignmentOptions,
  declineAssigneeChange,
  requestAssigneeChange,
  returnAssignment,
  studioDraftFields,
  studioFaultOf,
  type MemberDayReader,
} from '../src/studio_assignment.js';
import { EMPTY_SPOT_STATS, type Spot } from '../src/spot.js';
import type { SpotSchedule } from '../src/spot_schedule.js';
import { transitionBooking } from '../src/transition_booking.js';
import { makeTestBooking } from './support/booking_fixtures.js';
import {
  acceptedStudioBooking,
  createBookingWorld,
  newDraft,
  payDraft,
  withSchedule,
  withSpot,
  withStudio,
  type BookingWorld,
} from './support/booking_world.js';

const DAY = '2026-10-15';
// 2026-10-15 14:00 VN = 07:00Z; deadline 2026-10-14T07:00Z; the world clock starts 2026-10-10T10:00Z.
const START = new Date('2026-10-15T07:00:00.000Z');
const DEADLINE = new Date('2026-10-14T07:00:00.000Z');

const rejectsWith = (p: Promise<unknown>, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);

function world(members: readonly string[] = ['m1', 'm2', 'm3'], unverified: readonly string[] = []): BookingWorld {
  return withStudio(createBookingWorld(), 's1', members, { unverified });
}

const assign = (w: BookingWorld, bookingId: string, assigneeId: string, caller = 's1') =>
  assignBooking(w.studioDeps, caller, { bookingId, assigneeId });

async function assigned(w: BookingWorld, assigneeId = 'm1'): Promise<Booking> {
  const b = await acceptedStudioBooking(w);
  return assign(w, b.id, assigneeId);
}

describe('studio fields and faults', () => {
  it('assignDeadlineFor: 24 h before, at least 2 h from now, never after the start', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    assert.equal(assignDeadlineFor(START, now).toISOString(), DEADLINE.toISOString());
    assert.equal(assignDeadlineFor(new Date('2026-10-10T20:00:00.000Z'), now).toISOString(), '2026-10-10T12:00:00.000Z');
    assert.equal(assignDeadlineFor(new Date('2026-10-10T11:00:00.000Z'), now).toISOString(), '2026-10-10T11:00:00.000Z');
  });

  it('studioDraftFields is empty unless the provider is a studio', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const core = { day: DAY, start: '14:00' };
    assert.deepEqual(studioDraftFields({ now }, core), {});
    assert.deepEqual(studioDraftFields({ now, providerType: null }, core), {});
    assert.deepEqual(studioDraftFields({ now, providerType: 'individual' }, core), {});
    assert.equal(studioDraftFields({ now, providerType: 'studio' }, core).isStudio, true);
  });

  it('studioFaultOf: overdue before the sweep, recorded faults until the start, nothing for individual bookings', () => {
    const b = makeTestBooking({
      status: 'accepted',
      day: DAY,
      start: '14:00',
      ...studioDraftFields({ now: new Date('2026-10-10T10:00:00.000Z'), providerType: 'studio' }, { day: DAY, start: '14:00' }),
    });
    assert.equal(studioFaultOf(b, new Date('2026-10-14T06:59:00.000Z')), null);
    assert.equal(studioFaultOf(b, DEADLINE), 'assign_overdue');
    assert.equal(studioFaultOf({ ...b, assignStatus: 'assigned', assigneeId: 'm1' }, DEADLINE), null);
    const declined = { ...b, assignStatus: 'assigned' as const, studioFault: { kind: 'change_declined' as const, at: 'x' } };
    assert.equal(studioFaultOf(declined, new Date('2026-10-15T06:59:00.000Z')), 'change_declined');
    assert.equal(studioFaultOf(declined, START), null);
    assert.equal(studioFaultOf(makeTestBooking({ status: 'accepted' }), DEADLINE), null);
  });
});

describe('assignBooking', () => {
  it('the studio assigns a free verified member: booking assigned, member day booked, assignment logged', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    const after = await assign(w, b.id, 'm1');
    assert.equal(after.assigneeId, 'm1');
    assert.equal(after.assigneeKind, 'member');
    assert.equal(after.assignStatus, 'assigned');
    assert.equal(after.assignedAt, '2026-10-10T10:00:00.000Z');
    assert.deepEqual(after.assignments, [
      { assigneeId: 'm1', assigneeKind: 'member', at: '2026-10-10T10:00:00.000Z', by: 's1', reason: null, late: false },
    ]);
    assert.equal(after.status, 'accepted');
    assert.equal(after.version, b.version + 1);
    assert.deepEqual(await w.store.getBooking(b.id), after);
    assert.deepEqual(await w.store.getAvailabilityDay('m1', DAY), { state: 'booked', bookingId: b.id });
  });

  it('a member busy that day is day_taken and nothing is written', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.store.availability.set(`m1_${DAY}`, { state: 'booked', bookingId: 'other' });
    await rejectsWith(assign(w, b.id, 'm1'), 'day_taken');
    assert.deepEqual(await w.store.getBooking(b.id), b);
    assert.deepEqual(await w.store.getAvailabilityDay('m1', DAY), { state: 'booked', bookingId: 'other' });
    assert.deepEqual(w.store.getStudioDayLoad('s1', DAY)?.unassignedIds, [b.id]);
  });

  it('an off member is day_taken', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.store.availability.set(`m1_${DAY}`, { state: 'off' });
    await rejectsWith(assign(w, b.id, 'm1'), 'day_taken');
  });

  it('an unverified member is not_accepting_orders', async () => {
    const w = world(['m1', 'm2'], ['m2']);
    const b = await acceptedStudioBooking(w);
    await rejectsWith(assign(w, b.id, 'm2'), 'not_accepting_orders');
    assert.equal(await w.store.getAvailabilityDay('m2', DAY), null);
  });

  it('a studio that stopped taking orders cannot assign', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.providers.set('s1', { verified: false, onboardingComplete: true });
    await rejectsWith(assign(w, b.id, 'm1'), 'not_accepting_orders');
  });

  it('a member blocked by the customer (either way) is blocked', async () => {
    for (const [blocker, blocked] of [
      ['c1', 'm1'],
      ['m1', 'c1'],
    ] as const) {
      const w = world();
      const b = await acceptedStudioBooking(w);
      w.blocks.block(blocker, blocked);
      await rejectsWith(assign(w, b.id, 'm1'), 'blocked');
      assert.equal(await w.store.getAvailabilityDay('m1', DAY), null);
    }
  });

  it('a non-member is permission_denied', async () => {
    const w = world();
    w.providers.set('x1', { verified: true, onboardingComplete: true });
    const b = await acceptedStudioBooking(w);
    await rejectsWith(assign(w, b.id, 'x1'), 'permission_denied');
  });

  it('only the studio owner assigns', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    await rejectsWith(assign(w, b.id, 'm1', 'c1'), 'permission_denied');
    await rejectsWith(assign(w, b.id, 'm1', 'm2'), 'permission_denied');
  });

  it('an individual or unknown booking is not_found; bad input is invalid_argument', async () => {
    const w = world();
    await rejectsWith(assign(w, 'nope', 'm1'), 'not_found');
    w.store.bookings.set('b_ind', makeTestBooking({ id: 'b_ind', photographerId: 's1', status: 'accepted' }));
    await rejectsWith(assign(w, 'b_ind', 'm1'), 'not_found');
    await rejectsWith(assignBooking(w.studioDeps, 's1', { bookingId: 'b/1', assigneeId: 'm1' }), 'invalid_argument');
    await rejectsWith(assignBooking(w.studioDeps, 's1', null), 'invalid_argument');
  });

  it('a requested or cancelled booking is not_eligible', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.store.bookings.set(b.id, { ...b, status: 'requested' });
    await rejectsWith(assign(w, b.id, 'm1'), 'not_eligible');
    w.store.bookings.set(b.id, { ...b, status: 'cancelled' });
    await rejectsWith(assign(w, b.id, 'm1'), 'not_eligible');
  });

  it('after the start is not_eligible', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.store.bookings.set(b.id, { ...b, status: 'upcoming' });
    w.clock.setTime(START);
    await rejectsWith(assign(w, b.id, 'm1'), 'not_eligible');
  });

  it('the same assignee again is conflict', async () => {
    const w = world();
    const b = await assigned(w, 'm1');
    await rejectsWith(assign(w, b.id, 'm1'), 'conflict');
  });

  it("reassign frees the old member's day and books the new one", async () => {
    const w = world();
    const b = await assigned(w, 'm1');
    w.clock.advanceHours(1);
    const after = await assign(w, b.id, 'm2');
    assert.equal(after.assigneeId, 'm2');
    assert.equal(await w.store.getAvailabilityDay('m1', DAY), null);
    assert.deepEqual(await w.store.getAvailabilityDay('m2', DAY), { state: 'booked', bookingId: b.id });
    assert.deepEqual(after.assignments?.map((a) => [a.assigneeId, a.late]), [
      ['m1', false],
      ['m2', false],
    ]);
    assert.equal(after.studioFault, null);
    assert.equal(w.store.counterOf('s1', 'lateReassignCount'), 0);
    assert.deepEqual(w.store.getStudioDayLoad('s1', DAY)?.assignedIds, [b.id]);
  });

  it('reassign after the deadline sets late_reassign and lateReassignCount', async () => {
    const w = world();
    const b = await assigned(w, 'm1');
    w.clock.setTime(new Date('2026-10-14T08:00:00.000Z'));
    const after = await assign(w, b.id, 'm2');
    assert.deepEqual(after.studioFault, { kind: 'late_reassign', at: '2026-10-14T08:00:00.000Z' });
    assert.equal(after.assignments?.[1]?.late, true);
    assert.equal(w.store.counterOf('s1', 'lateReassignCount'), 1);
    assert.equal(studioFaultOf(after, w.clock.now()), 'late_reassign');
  });

  it('assigning an overdue booking clears assign_overdue but keeps assignOverdue history', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(new Date('2026-10-14T08:00:00.000Z'));
    w.store.bookings.set(b.id, { ...b, assignOverdue: true, studioFault: { kind: 'assign_overdue', at: 'x' } });
    const after = await assign(w, b.id, 'm1');
    assert.equal(after.studioFault, null);
    assert.equal(after.assignOverdue, true);
    assert.equal(after.assignments?.[0]?.late, false);
    assert.equal(w.store.counterOf('s1', 'lateReassignCount'), 0);
    assert.equal(studioFaultOf(after, w.clock.now()), null);
  });

  it('assigning an accepted booking inside 24 h makes it upcoming', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(new Date('2026-10-14T08:00:00.000Z'));
    const after = await assign(w, b.id, 'm1');
    assert.equal(after.status, 'upcoming');
    assert.ok(w.store.events.some((e) => e.bookingId === b.id && e.status === 'upcoming' && e.actorId === 's1'));
  });

  it('a member removed between the roster check and the transaction is permission_denied', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    const original = w.store.runTransaction.bind(w.store);
    w.store.runTransaction = async <T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> => {
      // removeMember commits here: the member document no longer names the studio
      w.store.studioMembers.set('s1', ['m2', 'm3']);
      w.memberships.delete('m1');
      return original(fn);
    };
    await rejectsWith(assign(w, b.id, 'm1'), 'permission_denied');
    assert.equal(await w.store.getAvailabilityDay('m1', DAY), null);
    assert.deepEqual(await w.store.getBooking(b.id), b);
  });

  it('a stale version is conflict', async () => {
    const w = world();
    const b = await acceptedStudioBooking(w);
    const original = w.store.runTransaction.bind(w.store);
    w.store.runTransaction = async <T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> => {
      w.store.bookings.set(b.id, { ...b, version: b.version + 1 });
      return original(fn);
    };
    await rejectsWith(assign(w, b.id, 'm1'), 'conflict');
  });
});

describe('assignmentOptions', () => {
  it('marks free, busy with the occupying times, off day, unverified and current', async () => {
    const w = world(['m1', 'm2', 'm3', 'm4', 'm5'], ['m4']);
    const b = await assigned(w, 'm5');
    const days: Record<string, { state: 'off' | 'booked' | 'pending'; start: string | null; end: string | null }> = {
      m2: { state: 'booked', start: '15:00', end: '18:00' },
      m3: { state: 'off', start: null, end: null },
      m5: { state: 'booked', start: '14:00', end: '16:00' },
    };
    const reader: MemberDayReader = {
      members: async (studioId) => (studioId === 's1' ? ['m1', 'm2', 'm3', 'm4', 'm5'] : []),
      day: async (uid, day) => (day === DAY ? (days[uid] ?? null) : null),
      stats: async (uid) => (uid === 'm1' ? { tomatoPct: 92, reviewCount: 12 } : { tomatoPct: null, reviewCount: 0 }),
    };
    const options = await assignmentOptions({ ...w.studioDeps, availability: reader }, 's1', { bookingId: b.id });
    assert.deepEqual(
      options.map((o) => [o.uid, o.state, o.busyStart, o.busyEnd]),
      [
        ['m1', 'free', null, null],
        ['m2', 'busy', '15:00', '18:00'],
        ['m3', 'off', null, null],
        ['m4', 'unverified', null, null],
        ['m5', 'current', null, null],
      ],
    );
    assert.deepEqual(options[0], {
      uid: 'm1',
      name: 'Thợ m1',
      avatarUrl: null,
      tomatoPct: 92,
      reviewCount: 12,
      state: 'free',
      busyStart: null,
      busyEnd: null,
    });
    await rejectsWith(assignmentOptions({ ...w.studioDeps, availability: reader }, 'm1', { bookingId: b.id }), 'permission_denied');
  });
});

describe('change request (S26.05)', () => {
  it('one change request per booking; a second is conflict', async () => {
    const w = world();
    const b = await assigned(w);
    const after = await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id, note: '  Muốn thợ nữ  ' });
    assert.deepEqual(after.changeRequest, {
      at: '2026-10-10T10:00:00.000Z',
      note: 'Muốn thợ nữ',
      respondBy: '2026-10-10T16:00:00.000Z',
      status: 'pending',
      declineReason: null,
      answeredAt: null,
    });
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id }), 'conflict');
    // still used after the studio answered
    await declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: 'Kín lịch' });
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id }), 'conflict');
  });

  it('respondBy is 6 h, or the start when sooner', async () => {
    const w = world();
    const b = await assigned(w);
    w.clock.setTime(new Date('2026-10-15T03:00:00.000Z')); // 4 h before the start
    const after = await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    assert.equal(after.changeRequest?.respondBy, START.toISOString());
    assert.equal(after.changeRequest?.note, null);
  });

  it('only the customer of an assigned, open booking asks; the note is at most 300 characters', async () => {
    const w = world();
    const unassigned = await acceptedStudioBooking(w);
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: unassigned.id }), 'not_eligible');
    const b = await assign(w, unassigned.id, 'm1');
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c2', { bookingId: b.id }), 'permission_denied');
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id, note: 'x'.repeat(301) }), 'invalid_argument');
    w.clock.setTime(START);
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id }), 'not_eligible');
  });

  it('declineAssigneeChange needs a reason and sets change_declined + changeDeclinedCount', async () => {
    const w = world();
    const b = await assigned(w);
    await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    await rejectsWith(declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id }), 'invalid_argument');
    await rejectsWith(declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: '   ' }), 'invalid_argument');
    await rejectsWith(declineAssigneeChange(w.studioDeps, 'm1', { bookingId: b.id, reason: 'x' }), 'permission_denied');
    w.clock.advanceHours(1);
    const after = await declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: 'Thợ nữ đã kín lịch' });
    assert.equal(after.changeRequest?.status, 'declined');
    assert.equal(after.changeRequest?.declineReason, 'Thợ nữ đã kín lịch');
    assert.equal(after.changeRequest?.answeredAt, '2026-10-10T11:00:00.000Z');
    assert.deepEqual(after.studioFault, { kind: 'change_declined', at: '2026-10-10T11:00:00.000Z' });
    assert.equal(after.assigneeId, 'm1');
    assert.equal(w.store.counterOf('s1', 'changeDeclinedCount'), 1);
    assert.equal(studioFaultOf(after, w.clock.now()), 'change_declined');
    await rejectsWith(declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: 'x' }), 'conflict');
  });

  it('declining after respondBy is deadline_passed', async () => {
    const w = world();
    const b = await assigned(w);
    await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    w.clock.advanceHours(6);
    await rejectsWith(declineAssigneeChange(w.studioDeps, 's1', { bookingId: b.id, reason: 'x' }), 'deadline_passed');
  });

  it('reassigning answers the request reassigned', async () => {
    const w = world();
    const b = await assigned(w);
    await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    w.clock.advanceHours(1);
    const after = await assign(w, b.id, 'm2');
    assert.equal(after.changeRequest?.status, 'reassigned');
    assert.equal(after.changeRequest?.answeredAt, '2026-10-10T11:00:00.000Z');
    assert.equal(after.studioFault, null);
    assert.equal(w.store.counterOf('s1', 'changeDeclinedCount'), 0);
  });
});

describe('returnAssignment ("Trả việc")', () => {
  it('only the assignee returns; assigneeId stays; the studio is told', async () => {
    const w = world();
    const b = await assigned(w, 'm1');
    await rejectsWith(returnAssignment(w.studioDeps, 'm2', { bookingId: b.id }), 'permission_denied');
    await rejectsWith(returnAssignment(w.studioDeps, 's1', { bookingId: b.id }), 'permission_denied');
    const after = await returnAssignment(w.studioDeps, 'm1', { bookingId: b.id, reason: 'Ốm' });
    assert.deepEqual(after.assignmentReturned, { at: '2026-10-10T10:00:00.000Z', reason: 'Ốm' });
    assert.equal(after.assigneeId, 'm1');
    assert.deepEqual(await w.store.getAvailabilityDay('m1', DAY), { state: 'booked', bookingId: b.id });
    await rejectsWith(returnAssignment(w.studioDeps, 'm1', { bookingId: b.id }), 'conflict');
    // the studio's reassignment clears the mark
    const reassigned = await assign(w, b.id, 'm2');
    assert.equal(reassigned.assignmentReturned, null);
  });

  it('after the start nothing can be returned', async () => {
    const w = world();
    const b = await assigned(w, 'm1');
    w.clock.setTime(START);
    await rejectsWith(returnAssignment(w.studioDeps, 'm1', { bookingId: b.id }), 'not_eligible');
  });
});

describe('spot bookings of a studio (#194 Decision 7)', () => {
  const spot: Spot = {
    id: 'spot-ho-tay',
    name: 'Hồ Tây',
    city: 'Hà Nội',
    areaCode: 'hn',
    point: { lat: 21.05, lng: 105.82 },
    geohash: 'w7e5q',
    radiusM: 1000,
    cover: null,
    description: '',
    tips: [],
    seasonMonths: [],
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 0,
    stats: EMPTY_SPOT_STATS,
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z',
    rankedAt: null,
    updatedBy: 'staff',
  };
  const schedule: SpotSchedule = {
    id: 'sched-s1-m1',
    providerId: 's1',
    assigneeId: 'm1',
    spotId: spot.id,
    days: [DAY],
    window: { start: '06:00', end: '11:00' },
    serviceIds: ['srv_s1'],
    priceFrom: 1_000_000,
    status: 'open',
    createdAt: '2026-10-08T00:00:00.000Z',
    updatedAt: '2026-10-08T00:00:00.000Z',
  };

  /** Studio s1 with m1 holding DAY for the schedule at Hồ Tây, and c1's paid, accepted 07:00 spot booking. */
  async function spotWorld(): Promise<{ w: BookingWorld; b: Booking }> {
    const w = withSchedule(withSpot(world(), spot), schedule);
    w.store.availability.set(`m1_${DAY}`, { state: 'spot', scheduleId: schedule.id, spotId: spot.id });
    const draft = await newDraft(w, {
      photographerId: 's1',
      serviceId: 'srv_s1',
      day: DAY,
      start: '07:00',
      spotScheduleId: schedule.id,
    });
    await payDraft(w, draft.id);
    const b = await transitionBooking(w.deps, { bookingId: draft.id, action: 'accept', actorId: 's1' });
    return { w, b };
  }

  it('is created already assigned to the schedule member and never enters the studio day load', async () => {
    const { w, b } = await spotWorld();
    assert.equal(b.status, 'accepted');
    assert.equal(b.isStudio, true);
    assert.equal(b.assigneeId, 'm1');
    assert.equal(b.assigneeKind, 'member');
    assert.equal(b.assignStatus, 'assigned');
    assert.equal(b.assignedAt, '2026-10-10T10:00:00.000Z');
    assert.deepEqual(
      b.assignments?.map((a) => [a.assigneeId, a.by, a.late]),
      [['m1', 's1', false]],
    );
    assert.equal(w.store.getStudioDayLoad('s1', DAY), null);
    // accept wrote nothing: the member's day still holds the schedule
    assert.equal((await w.store.getAvailabilityDay('m1', DAY))?.state, 'spot');
    assert.equal(await w.store.getAvailabilityDay('s1', DAY), null);
  });

  it('assignBooking, requestAssigneeChange and returnAssignment on it are not_eligible', async () => {
    const { w, b } = await spotWorld();
    await rejectsWith(assign(w, b.id, 'm2'), 'not_eligible');
    await rejectsWith(requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id }), 'not_eligible');
    await rejectsWith(returnAssignment(w.studioDeps, 'm1', { bookingId: b.id }), 'not_eligible');
  });

  it('a member on a spot day cannot be assigned another studio booking that day (day_taken)', async () => {
    const { w } = await spotWorld();
    const other = await acceptedStudioBooking(w, { customerId: 'c2', day: DAY, start: '14:00' });
    await rejectsWith(assign(w, other.id, 'm1'), 'day_taken');
    assert.equal((await assign(w, other.id, 'm2')).assigneeId, 'm2');
  });

  it('assignmentOptions shows the member busy with the schedule window', async () => {
    const { w } = await spotWorld();
    const other = await acceptedStudioBooking(w, { customerId: 'c2', day: DAY, start: '14:00' });
    const reader: MemberDayReader = {
      members: async () => ['m1', 'm2'],
      day: async (uid) => (uid === 'm1' ? { state: 'spot', start: '06:00', end: '11:00' } : null),
      stats: async () => ({ tomatoPct: null, reviewCount: 0 }),
    };
    const options = await assignmentOptions({ ...w.studioDeps, availability: reader }, 's1', { bookingId: other.id });
    assert.deepEqual(
      options.map((o) => [o.uid, o.state, o.busyStart, o.busyEnd]),
      [
        ['m1', 'busy', '06:00', '11:00'],
        ['m2', 'free', null, null],
      ],
    );
  });

  it('a cancel removes its interval and leaves the member day and the studio load alone', async () => {
    const { w, b } = await spotWorld();
    assert.equal((await w.store.getSpotDay(schedule.id, DAY))?.taken.length, 1);
    await transitionBooking(w.deps, { bookingId: b.id, action: 'cancel', actorId: 'c1' });
    assert.equal((await w.store.getSpotDay(schedule.id, DAY))?.taken.length, 0);
    assert.equal((await w.store.getAvailabilityDay('m1', DAY))?.state, 'spot');
    assert.equal(w.store.getStudioDayLoad('s1', DAY), null);
  });
});
