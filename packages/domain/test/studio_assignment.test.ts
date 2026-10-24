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
  waitsForAssignee,
  type MemberDayReader,
} from '../src/studio_assignment.js';
import { syncBookingChat } from '../src/booking_chat_sync.js';
import { expireCollabOffer, respondCollabOffer } from '../src/collab_offers.js';
import { chatIdFor } from '../src/chat.js';
import { runStudioBookingSweeps } from '../src/studio_booking_sweeps.js';
import { notifyStudioBookingChange, studioBookingNotices } from '../src/studio_notifications.js';
import { createChatWorld } from './support/chat_world.js';
import {
  answer,
  COLLAB_DAY,
  COLLAB_START,
  createCollabWorld,
  offer,
  seedCollab,
  studioBooking,
  type CollabWorld,
} from './support/collab_world.js';
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

describe('collaborator offers (S27, plan #151 Decisions 13, 14, 26)', () => {
  const T0 = new Date('2026-10-10T10:00:00.000Z');
  const rows = (w: CollabWorld, uid: string, type?: string) => w.rowsOf(uid).filter((r) => type === undefined || r.type === type);
  const jobOf = (w: CollabWorld, bookingId: string, uid: string) => w.recruit.collabJobs.get(`${bookingId}_${uid}`);

  async function offered(w: CollabWorld, uid = 'p1', fee = 800_000): Promise<{ before: Booking; after: Booking }> {
    seedCollab(w, uid);
    const before = await studioBooking(w);
    const after = await offer(w, before.id, uid, fee);
    return { before, after };
  }

  it('assigning to an active collaborator creates a pending collab_job with the fee and offerExpiresAt, sets assigneeId, assigneeKind collaborator, assigneeAccepted false, and sends collab_assignment_offer', async () => {
    const w = createCollabWorld();
    const { before, after } = await offered(w);
    assert.equal(after.assigneeId, 'p1');
    assert.equal(after.assigneeKind, 'collaborator');
    assert.equal(after.assigneeAccepted, false);
    assert.equal(after.assignStatus, 'unassigned', 'a pending offer leaves the booking unassigned (Decision 26)');
    assert.equal(after.assignDeadline, before.assignDeadline);
    assert.equal(after.version, before.version + 1);
    assert.deepEqual(after.assignments, [
      { assigneeId: 'p1', assigneeKind: 'collaborator', at: T0.toISOString(), by: 's1', reason: null, late: false, offerExpiresAt: '2026-10-10T16:00:00.000Z' },
    ]);
    assert.deepEqual(await w.bw.store.getBooking(before.id), after);
    const job = jobOf(w, before.id, 'p1');
    assert.equal(job?.id, `${before.id}_p1`);
    assert.equal(job?.offerStatus, 'pending');
    assert.equal(job?.agreedFee, 800_000);
    assert.deepEqual(job?.offerAt, T0);
    assert.deepEqual(job?.offerExpiresAt, new Date('2026-10-10T16:00:00.000Z'));
    assert.equal(job?.studioId, 's1');
    assert.equal(job?.customerId, 'c1');
    assert.equal(job?.studioName, 'Studio Mây');
    assert.equal(job?.collaboratorName, 'Minh Trí');
    assert.deepEqual(job?.shoot, { day: COLLAB_DAY, start: '14:00', end: '16:00', serviceName: 'Gói Studio', placeName: 'Nhà thờ Lớn' });
    assert.deepEqual(job?.shootEndsAt, new Date('2026-10-15T09:00:00.000Z'));
    assert.equal(job?.payStatus, 'none');
    assert.equal(job?.pay.amount, 800_000);
    const offers = rows(w, 'p1', 'collab_assignment_offer');
    assert.equal(offers.length, 1);
    assert.equal(offers[0]?.target, `/collab?offer=${before.id}`);
    assert.match(offers[0]?.body ?? '', /Thù lao 800\.000.*Trả lời trước 23:00 10\/10/);
  });

  it('assigning to a collaborator writes no fee on the booking (Review Focus 2)', async () => {
    const w = createCollabWorld();
    const { before, after } = await offered(w, 'p1', 1_250_000);
    const added = Object.keys(after).filter((k) => !(k in before));
    assert.deepEqual(added.filter((k) => /fee|pay/i.test(k)), []);
    for (const entry of after.assignments ?? []) assert.deepEqual(Object.keys(entry).filter((k) => /fee|pay/i.test(k)), []);
    assert.ok(!JSON.stringify(after).includes('1250000'));
    assert.equal(jobOf(w, after.id, 'p1')?.agreedFee, 1_250_000, 'the fee lives in the collab job');
  });

  it('no calendar block, no chat member, no booking_assigned to the customer at offer time', async () => {
    const w = createCollabWorld();
    const { before, after } = await offered(w);
    assert.equal(await w.bw.store.getAvailabilityDay('p1', COLLAB_DAY), null);
    assert.deepEqual(w.bw.store.getStudioDayLoad('s1', COLLAB_DAY)?.unassignedIds, [before.id]);
    assert.deepEqual(w.bw.store.getStudioDayLoad('s1', COLLAB_DAY)?.assignedIds, []);
    assert.deepEqual(studioBookingNotices(before, after), []);
    const { deps: chatDeps, chats } = createChatWorld();
    await syncBookingChat(chatDeps, { before: null, after: { ...before, status: 'requested' } });
    await syncBookingChat(chatDeps, { before: { ...before, status: 'requested' }, after: before });
    await syncBookingChat(chatDeps, { before, after });
    assert.equal(chats.chats.get(chatIdFor('c1', 's1'))?.assigneeId, null);
    assert.equal(waitsForAssignee(after), true, 'the booking still waits for a confirmed assignee');
    assert.equal(rows(w, 'c1').length, 0);
  });

  it('refused: no active collaboration (not_found), fee missing or off-step (invalid_argument), collaborator not accepting orders (not_accepting_orders), studio blocked (recruit_blocked), less than 15 minutes left (deadline_passed), collaborator busy that day (day_taken)', async () => {
    const w = createCollabWorld();
    const b = await studioBooking(w);
    await rejectsWith(offer(w, b.id, 'p1'), 'not_found');
    seedCollab(w, 'p2', { status: 'ended', endedAt: T0, endedBy: 'studio' });
    await rejectsWith(offer(w, b.id, 'p2'), 'not_found');
    seedCollab(w, 'p1');
    const badFee = (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'agreedFee';
    await assert.rejects(assignBooking(w.assignDeps, 's1', { bookingId: b.id, assigneeId: 'p1', assigneeKind: 'collaborator' }), badFee);
    for (const fee of [null, 999, 1_500, 100_001_000, '800000', 800_000.5]) {
      await assert.rejects(offer(w, b.id, 'p1', fee), badFee, String(fee));
    }
    await assert.rejects(
      assignBooking(w.assignDeps, 's1', { bookingId: b.id, assigneeId: 'p1', assigneeKind: 'employee', agreedFee: 800_000 }),
      (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'assigneeKind',
    );
    seedCollab(w, 'u1');
    await rejectsWith(offer(w, b.id, 'u1'), 'not_accepting_orders');
    w.bw.blocks.block('s1', 'p1');
    await rejectsWith(offer(w, b.id, 'p1'), 'blocked');
    w.bw.blocks.unblock('s1', 'p1');
    w.bw.blocks.block('p1', 'c1');
    await rejectsWith(offer(w, b.id, 'p1'), 'blocked');
    w.bw.blocks.unblock('p1', 'c1');
    w.recruit.seedCounters('s1', { recruitBlockedUntil: new Date(T0.getTime() + 24 * 60 * 60 * 1000) });
    await rejectsWith(offer(w, b.id, 'p1'), 'recruit_blocked');
    w.recruit.seedCounters('s1', { recruitBlockedUntil: null });
    w.bw.clock.setTime(new Date('2026-10-14T06:50:00.000Z'));
    await rejectsWith(offer(w, b.id, 'p1'), 'deadline_passed');
    w.bw.clock.setTime(T0);
    w.bw.store.availability.set(`p1_${COLLAB_DAY}`, { state: 'booked', bookingId: 'other' });
    await rejectsWith(offer(w, b.id, 'p1'), 'day_taken');
    w.bw.store.availability.set(`p1_${COLLAB_DAY}`, { state: 'off' });
    await rejectsWith(offer(w, b.id, 'p1'), 'day_taken');
    assert.deepEqual(await w.bw.store.getBooking(b.id), b, 'nothing written');
    assert.equal(w.recruit.collabJobs.size, 0);
    assert.equal(rows(w, 'p1').length, 0);
  });

  it('an offer made after the deadline expires at the start at the latest', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    w.bw.clock.setTime(new Date('2026-10-15T03:00:00.000Z'));
    const after = await offer(w, b.id, 'p1');
    assert.equal(after.assignments?.[0]?.offerExpiresAt, COLLAB_START.toISOString());
    assert.deepEqual(jobOf(w, b.id, 'p1')?.offerExpiresAt, COLLAB_START);
  });

  it('re-assign while an offer is pending marks the old job replaced and notifies nobody but the new assignee', async () => {
    const w = createCollabWorld();
    const { after: first } = await offered(w, 'p1');
    seedCollab(w, 'p2');
    w.bw.clock.advanceHours(1);
    const before = { p1: rows(w, 'p1').length, c1: rows(w, 'c1').length, s1: rows(w, 's1').length };
    const second = await offer(w, first.id, 'p2', 900_000);
    assert.equal(second.assigneeId, 'p2');
    assert.equal(jobOf(w, first.id, 'p1')?.offerStatus, 'replaced');
    assert.equal(jobOf(w, first.id, 'p2')?.offerStatus, 'pending');
    assert.equal(second.assignments?.[1]?.late, false);
    assert.deepEqual(studioBookingNotices(first, second), []);
    assert.equal(rows(w, 'p1').length, before.p1);
    assert.equal(rows(w, 'c1').length, before.c1);
    assert.equal(rows(w, 's1').length, before.s1);
    assert.equal(rows(w, 'p2', 'collab_assignment_offer').length, 1);
    await rejectsWith(answer(w, 'p1', first.id, true), 'permission_denied');
    // a member assigned over a pending offer replaces it too
    const member = await assign(w.bw, first.id, 'm1');
    assert.equal(member.assigneeKind, 'member');
    assert.equal(member.assigneeAccepted, true);
    assert.equal(jobOf(w, first.id, 'p2')?.offerStatus, 'replaced');
    assert.deepEqual(studioBookingNotices(second, member), ['assigned']);
    assert.equal(member.assignments?.[2]?.late, false, 'a pending offer was never the assignee');
  });

  it('the same collaborator again while the offer is pending is conflict', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    await rejectsWith(offer(w, after.id, 'p1'), 'conflict');
  });

  it('accept: offerStatus accepted, acceptedAt, booking assigneeAccepted true, calendar blocked, chat member added, booking_assigned to the customer, collab_assignment_result accepted to the studio', async () => {
    const w = createCollabWorld();
    const { before, after: pending } = await offered(w);
    w.bw.clock.advanceHours(2);
    const now = w.bw.clock.now();
    assert.deepEqual(await answer(w, 'p1', pending.id, true), { offerStatus: 'accepted' });
    const job = jobOf(w, pending.id, 'p1');
    assert.equal(job?.offerStatus, 'accepted');
    assert.deepEqual(job?.acceptedAt, now);
    const b = await w.bw.store.getBooking(pending.id);
    assert.ok(b);
    assert.equal(b.assigneeId, 'p1');
    assert.equal(b.assigneeAccepted, true);
    assert.equal(b.assignStatus, 'assigned');
    assert.equal(b.assignedAt, now.toISOString());
    assert.equal(b.assignments?.[0]?.acceptedAt, now.toISOString());
    assert.equal(b.version, pending.version + 1);
    assert.deepEqual(await w.bw.store.getAvailabilityDay('p1', COLLAB_DAY), { state: 'booked', bookingId: b.id });
    assert.deepEqual(w.bw.store.getStudioDayLoad('s1', COLLAB_DAY)?.assignedIds, [b.id]);
    assert.deepEqual(w.bw.store.getStudioDayLoad('s1', COLLAB_DAY)?.unassignedIds, []);
    assert.deepEqual(studioBookingNotices(pending, b), ['assigned']);
    await notifyStudioBookingChange({ ...w.deps.notify }, pending, b);
    assert.equal(rows(w, 'c1', 'booking_assigned').length, 1);
    const { deps: chatDeps, chats } = createChatWorld();
    await syncBookingChat(chatDeps, { before: null, after: { ...before, status: 'requested' } });
    await syncBookingChat(chatDeps, { before: { ...before, status: 'requested' }, after: pending });
    await syncBookingChat(chatDeps, { before: pending, after: b });
    assert.equal(chats.chats.get(chatIdFor('c1', 's1'))?.assigneeId, 'p1');
    const results = rows(w, 's1', 'collab_assignment_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.title, 'Minh Trí đã nhận việc');
    assert.equal(waitsForAssignee(b), false);
  });

  it('accept inside 24 h of the start makes the booking upcoming and clears assign_overdue', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    w.bw.clock.setTime(new Date('2026-10-14T08:00:00.000Z'));
    w.bw.store.bookings.set(b.id, { ...b, assignOverdue: true, studioFault: { kind: 'assign_overdue', at: 'x' } });
    const pending = await offer(w, b.id, 'p1');
    assert.deepEqual(pending.studioFault, { kind: 'assign_overdue', at: 'x' }, 'still unassigned while the offer waits');
    w.bw.clock.advanceHours(1);
    await answer(w, 'p1', b.id, true);
    const after = await w.bw.store.getBooking(b.id);
    assert.equal(after?.status, 'upcoming');
    assert.equal(after?.studioFault, null);
    assert.equal(after?.assignOverdue, true);
    assert.ok(w.bw.store.events.some((e) => e.bookingId === b.id && e.status === 'upcoming' && e.actorId === 'p1'));
  });

  it('accept after offerExpiresAt → deadline_passed', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    w.bw.clock.advanceHours(6);
    await rejectsWith(answer(w, 'p1', after.id, true), 'deadline_passed');
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'pending');
  });

  it('accept by someone else → permission_denied', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    for (const uid of ['p2', 's1', 'c1', 'm1']) await rejectsWith(answer(w, uid, after.id, true), 'permission_denied');
    await rejectsWith(answer(w, 'p1', 'nope', true), 'not_found');
    await rejectsWith(respondCollabOffer(w.assignDeps, 'p1', { bookingId: after.id }), 'invalid_argument');
  });

  it('accept when the day was taken meanwhile → day_taken and the offer stays pending', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    w.bw.store.availability.set(`p1_${COLLAB_DAY}`, { state: 'booked', bookingId: 'personal' });
    await rejectsWith(answer(w, 'p1', after.id, true), 'day_taken');
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'pending');
    assert.deepEqual(await w.bw.store.getBooking(after.id), after);
    // an "off" mark does not stop the collaborator from taking the job they are answering
    w.bw.store.availability.set(`p1_${COLLAB_DAY}`, { state: 'off' });
    await answer(w, 'p1', after.id, true);
    assert.deepEqual(await w.bw.store.getAvailabilityDay('p1', COLLAB_DAY), { state: 'booked', bookingId: after.id });
  });

  it('accept after the collaborator stopped taking orders → not_accepting_orders, the offer stays pending', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    w.bw.providers.set('p1', { verified: false, onboardingComplete: true });
    await rejectsWith(answer(w, 'p1', after.id, true), 'not_accepting_orders');
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'pending');
  });

  it('decline clears assigneeId and assigneeKind, keeps assignDeadline, notifies the studio with the deadline', async () => {
    const w = createCollabWorld();
    const { before, after: pending } = await offered(w);
    w.bw.clock.advanceHours(1);
    assert.deepEqual(await answer(w, 'p1', pending.id, false), { offerStatus: 'declined' });
    const b = await w.bw.store.getBooking(pending.id);
    assert.ok(b);
    assert.equal(b.assigneeId, null);
    assert.equal(b.assigneeKind, null);
    assert.equal(b.assigneeAccepted, false);
    assert.equal(b.assignStatus, 'unassigned');
    assert.equal(b.assignDeadline, before.assignDeadline);
    assert.equal(b.assignments?.[0]?.declinedAt, w.bw.clock.now().toISOString());
    const job = jobOf(w, pending.id, 'p1');
    assert.equal(job?.offerStatus, 'declined');
    assert.deepEqual(job?.declinedAt, w.bw.clock.now());
    assert.equal(await w.bw.store.getAvailabilityDay('p1', COLLAB_DAY), null);
    const results = rows(w, 's1', 'collab_assignment_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.title, 'Minh Trí từ chối việc');
    assert.equal(results[0]?.body, 'Giao người khác trước 14:00 14/10.');
    await rejectsWith(answer(w, 'p1', pending.id, true), 'permission_denied');
    // the studio can offer it again, and the collaborator is told again (a new offer, a new key)
    await offer(w, pending.id, 'p1');
    assert.equal(jobOf(w, pending.id, 'p1')?.offerStatus, 'pending');
    assert.equal(rows(w, 'p1', 'collab_assignment_offer').length, 2);
    w.bw.clock.advanceHours(1);
    await answer(w, 'p1', pending.id, false);
    assert.equal(rows(w, 's1', 'collab_assignment_result').length, 2, 'the second decline is told too');
  });

  it('a declined or expired offer does not count as a violation (S26 counters unchanged)', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    await answer(w, 'p1', after.id, false);
    await offer(w, after.id, 'p1');
    w.bw.clock.advanceHours(7);
    assert.equal(await expireCollabOffer(w.assignDeps, after.id, 'p1'), true);
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'expired');
    for (const field of ['lateAssignCount', 'changeDeclinedCount', 'lateReassignCount', 'lateDeliveryCount'] as const) {
      assert.equal(w.bw.store.counterOf('s1', field), 0, field);
    }
    assert.equal((await w.bw.store.getBooking(after.id))?.studioFault ?? null, null);
    assert.equal(await expireCollabOffer(w.assignDeps, after.id, 'p1'), false, 'already expired');
  });

  it('an offer on a collaboration that ended meanwhile is closed on accept (not_found), the studio told of the end, and cannot be made', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    seedCollab(w, 'p1', { status: 'ended', endedAt: w.bw.clock.now(), endedBy: 'collaborator' });
    await rejectsWith(answer(w, 'p1', after.id, true), 'not_found');
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'cancelled');
    const b = await w.bw.store.getBooking(after.id);
    assert.equal(b?.assigneeId, null);
    const results = rows(w, 's1', 'collab_assignment_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.title, 'Cộng tác với Minh Trí đã kết thúc');
    await rejectsWith(offer(w, after.id, 'p1'), 'not_found');
  });

  it('a decline on a collaboration that ended meanwhile closes the offer quietly', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    seedCollab(w, 'p1', { status: 'ended', endedAt: w.bw.clock.now(), endedBy: 'studio' });
    assert.deepEqual(await answer(w, 'p1', after.id, false), { offerStatus: 'declined' });
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'cancelled');
    assert.equal((await w.bw.store.getBooking(after.id))?.assigneeId, null);
    assert.equal(rows(w, 's1', 'collab_assignment_result')[0]?.title, 'Cộng tác với Minh Trí đã kết thúc');
  });

  it('an offer over a confirmed member tells the member at once; the customer hears booking_reassigned (not assigned) when the collaborator accepts', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    const withMember = await assign(w.bw, b.id, 'm1');
    w.bw.clock.advanceHours(1);
    const pending = await offer(w, b.id, 'p1');
    assert.deepEqual(studioBookingNotices(withMember, pending), ['offer_replaced']);
    await notifyStudioBookingChange(w.deps.notify, withMember, pending);
    const told = rows(w, 'm1', 'booking_reassigned');
    assert.equal(told.length, 1);
    assert.match(told[0]?.title ?? '', /đã giao cho người khác/);
    assert.equal(rows(w, 'c1').length, 0, 'the customer hears nothing while the offer waits');
    assert.equal(rows(w, 'p1', 'booking_reassigned').length, 0);

    w.bw.clock.advanceHours(1);
    await answer(w, 'p1', b.id, true);
    const accepted = await w.bw.store.getBooking(b.id);
    assert.ok(accepted);
    assert.deepEqual(studioBookingNotices(pending, accepted), ['reassigned']);
    await notifyStudioBookingChange(w.deps.notify, pending, accepted);
    const customer = rows(w, 'c1', 'booking_reassigned');
    assert.equal(customer.length, 1);
    assert.equal(customer[0]?.title, 'Studio Mây đã đổi thợ chụp');
    assert.match(customer[0]?.body ?? '', /^Minh Trí sẽ chụp/);
    assert.equal(rows(w, 'c1', 'booking_assigned').length, 0);
    assert.equal(rows(w, 'p1', 'booking_reassigned').length, 1);
    assert.equal(rows(w, 'm1', 'booking_reassigned').length, 1, 'the member is not told twice');
  });

  it('a late offer over a confirmed member gives the customer the late_reassign right with the reassignment notice', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await assign(w.bw, b.id, 'm1');
    w.bw.clock.setTime(new Date('2026-10-14T09:00:00.000Z'));
    const pending = await offer(w, b.id, 'p1');
    w.bw.clock.advanceHours(1);
    await answer(w, 'p1', b.id, true);
    const accepted = await w.bw.store.getBooking(b.id);
    assert.ok(accepted);
    await notifyStudioBookingChange(w.deps.notify, pending, accepted);
    assert.equal(rows(w, 'c1', 'booking_reassigned').length, 1);
    assert.equal(studioFaultOf(accepted, w.bw.clock.now()), 'late_reassign');
    assert.equal(w.bw.store.counterOf('s1', 'lateReassignCount'), 1);
  });

  it('an offer over a confirmed member that is declined and the deadline then passes: S26 overdue notice to the customer; a later collaborator is announced as a reassignment', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    seedCollab(w, 'p2');
    const b = await studioBooking(w);
    await assign(w.bw, b.id, 'm1');
    w.bw.clock.setTime(new Date(COLLAB_START.getTime() - 26 * 60 * 60 * 1000)); // 2 h before the deadline
    await offer(w, b.id, 'p1');
    w.bw.clock.advanceHours(1);
    await answer(w, 'p1', b.id, false);
    w.bw.clock.advanceHours(2); // past the deadline, still unassigned
    await runStudioBookingSweeps(w.assignDeps, w.deps.notify);
    assert.equal(rows(w, 'c1', 'assign_overdue').length, 1);
    const unassigned = await w.bw.store.getBooking(b.id);
    assert.ok(unassigned);
    const pending = await offer(w, b.id, 'p2');
    assert.deepEqual(studioBookingNotices(unassigned, pending), [], 'nobody confirmed to tell');
    await answer(w, 'p2', b.id, true);
    const accepted = await w.bw.store.getBooking(b.id);
    assert.ok(accepted);
    assert.deepEqual(studioBookingNotices(pending, accepted), ['reassigned']);
    await notifyStudioBookingChange(w.deps.notify, pending, accepted);
    assert.equal(rows(w, 'c1', 'booking_reassigned').length, 1);
  });

  it('offering over an assigned member frees the member and moves the booking back to unassigned until the collaborator accepts', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await assign(w.bw, b.id, 'm1');
    const pending = await offer(w, b.id, 'p1');
    assert.equal(await w.bw.store.getAvailabilityDay('m1', COLLAB_DAY), null);
    assert.equal(pending.assignStatus, 'unassigned');
    assert.deepEqual(w.bw.store.getStudioDayLoad('s1', COLLAB_DAY)?.unassignedIds, [b.id]);
    assert.equal(waitsForAssignee(pending), true);
  });

  it('offering over the assignee of an upcoming booking returns it to accepted until the collaborator accepts', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    w.bw.clock.setTime(new Date('2026-10-14T09:00:00.000Z'));
    const withMember = await assign(w.bw, b.id, 'm1');
    assert.equal(withMember.status, 'upcoming');
    await returnAssignment(w.bw.studioDeps, 'm1', { bookingId: b.id, reason: 'Ốm' });
    const pending = await offer(w, b.id, 'p1');
    assert.equal(pending.status, 'accepted');
    assert.equal(pending.assignments?.[1]?.late, true, 'the confirmed member was replaced after the deadline');
    assert.deepEqual(pending.studioFault, { kind: 'late_reassign', at: '2026-10-14T09:00:00.000Z' });
    await answer(w, 'p1', b.id, true);
    assert.equal((await w.bw.store.getBooking(b.id))?.status, 'upcoming');
  });

  it('"Trả việc" by an accepted collaborator marks the job returned and creates no pay record', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    await rejectsWith(returnAssignment(w.bw.studioDeps, 'p1', { bookingId: after.id }), 'permission_denied');
    await answer(w, 'p1', after.id, true);
    const returned = await returnAssignment(w.bw.studioDeps, 'p1', { bookingId: after.id, reason: 'Ốm' });
    assert.deepEqual(returned.assignmentReturned, { at: T0.toISOString(), reason: 'Ốm' });
    assert.equal(returned.assigneeId, 'p1');
    const job = jobOf(w, after.id, 'p1');
    assert.equal(job?.offerStatus, 'returned');
    assert.equal(job?.payStatus, 'none');
    assert.equal(job?.pay.dueAt, null);
    // the studio reassigns: the collaborator's day is freed, the returned job stays returned
    await assign(w.bw, after.id, 'm1');
    assert.equal(await w.bw.store.getAvailabilityDay('p1', COLLAB_DAY), null);
    assert.equal(jobOf(w, after.id, 'p1')?.offerStatus, 'returned');
  });

  it('a pending collaborator cannot act on the booking or be the subject of a change request', async () => {
    const w = createCollabWorld();
    const { after } = await offered(w);
    await rejectsWith(requestAssigneeChange(w.bw.studioDeps, 'c1', { bookingId: after.id }), 'not_eligible');
    w.bw.clock.setTime(new Date('2026-10-16T10:00:00.000Z'));
    await rejectsWith(transitionBooking(w.bw.deps, { bookingId: after.id, action: 'mark_shot', actorId: 'p1' }), 'permission_denied');
  });
});
