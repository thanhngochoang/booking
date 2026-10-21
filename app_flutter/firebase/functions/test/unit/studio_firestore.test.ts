import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  CLOSED_BOOKING_STATUSES,
  inviteMember,
  isOpenBookingStatus,
  respondInvite,
  type SpotSchedule,
  type StudioDeps,
  type StudioRelation,
} from '@photobooking/domain';
import {
  FirestoreMemberDayReader,
  FirestoreNameKeys,
  FirestoreStudioRoster,
  FirestoreStudioStore,
  relationFromFirestore,
  relationToFirestore,
} from '../../src/infra/studio_firestore.js';
import {
  recomputeStudioDay,
  recomputeStudioDays,
  refreshAssignableMembers,
} from '../../src/infra/studio_capacity_firestore.js';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import { FirestoreProviderOrderGate } from '../../src/infra/booking_readers.js';
import { studioRelationBlockers } from '../../src/infra/account_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { NOW, STUDIO, seedBooking, seedPerson, seedStudio, studioBooking } from './support/studio_fixtures.js';
import { scheduleToFirestore } from '../../src/infra/spot_firestore.js';

const SPOT_SCHEDULE: SpotSchedule = {
  id: 'sched',
  providerId: STUDIO,
  assigneeId: 'm1',
  spotId: 'spot_1',
  days: ['2026-10-12'],
  window: { start: '06:00', end: '11:00' },
  serviceIds: ['srv_1'],
  priceFrom: 1_000_000,
  status: 'open',
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-01T00:00:00.000Z',
};

const DAY_MS = 86_400_000;

function relation(over: Partial<StudioRelation> = {}): StudioRelation {
  return {
    id: `${STUDIO}_m1_${NOW.getTime()}`,
    studioId: STUDIO,
    memberId: 'm1',
    status: 'invited',
    initiatedBy: 'studio',
    createdAt: NOW.toISOString(),
    expiresAt: new Date(NOW.getTime() + 7 * DAY_MS).toISOString(),
    respondedAt: null,
    joinedAt: null,
    endedAt: null,
    endedBy: null,
    expiringNotifiedAt: null,
    studioName: 'Cúc Studio',
    studioAvatarUrl: null,
    memberName: 'Thợ 1',
    memberAvatarUrl: 'https://img.test/m1.jpg',
    version: 1,
    ...over,
  };
}

function seedRelation(db: MemoryFirestore, r: StudioRelation): void {
  db.seed(`studio_members/${r.id}`, relationToFirestore(r));
}

describe('studio_firestore mapping', () => {
  it('a relation round-trips and writes expiringNotifiedAt as an explicit null', () => {
    const r = relation({ status: 'active', respondedAt: NOW.toISOString(), joinedAt: NOW.toISOString() });
    const d = relationToFirestore(r);
    assert.ok(d.createdAt instanceof Timestamp);
    assert.ok(d.expiresAt instanceof Timestamp);
    assert.equal('expiringNotifiedAt' in d && d.expiringNotifiedAt === null, true);
    assert.equal('id' in d, false);
    assert.deepEqual(relationFromFirestore(r.id, d), r);
    const ended = relation({ status: 'removed', endedAt: NOW.toISOString(), endedBy: 'studio', expiringNotifiedAt: NOW.toISOString() });
    assert.deepEqual(relationFromFirestore(ended.id, relationToFirestore(ended)), ended);
    assert.equal(relationFromFirestore('x', { status: 'weird', studioId: 's', memberId: 'm' }), null);
  });

  it('CLOSED_BOOKING_STATUSES are exactly the statuses isOpenBookingStatus closes', () => {
    for (const s of CLOSED_BOOKING_STATUSES) assert.equal(isOpenBookingStatus(s), false, s);
    for (const s of ['draft', 'requested', 'accepted', 'upcoming', 'shot', 'delivered', 'revision_requested', 'approved']) {
      assert.equal(isOpenBookingStatus(s), true, s);
    }
  });
});

describe('FirestoreStudioStore', () => {
  let db: MemoryFirestore;
  let deps: StudioDeps;
  let now: Date;

  beforeEach(() => {
    db = new MemoryFirestore();
    now = NOW;
    deps = { studios: new FirestoreStudioStore(db.asFirestore()), clock: { now: () => now }, ids: { newId: () => 'id1' } };
    seedStudio(db);
    seedPerson(db, 'm1', 'Thợ 1');
  });

  it('invite then accept: the member document is the lock, memberCount and the quota are written', async () => {
    const invited = await inviteMember(deps, STUDIO, { memberId: 'm1' });
    const stored = db.data(`studio_members/${invited.after.id}`);
    assert.equal(stored?.status, 'invited');
    assert.equal(stored?.expiringNotifiedAt, null);
    assert.equal(db.data(`studio_quota/${STUDIO}`)?.studioActions, 1);

    now = new Date(NOW.getTime() + 3_600_000);
    const accepted = await respondInvite(deps, 'm1', { relationId: invited.after.id, accept: true });
    assert.equal(accepted.after.status, 'active');
    const member = db.data('photographers/m1');
    assert.equal(member?.studioId, STUDIO);
    assert.ok(member?.studioJoinedAt instanceof Timestamp);
    assert.equal(db.data(`photographers/${STUDIO}`)?.memberCount, 1);
    assert.equal(db.data(`studio_members/${invited.after.id}`)?.status, 'active');
  });

  it('countOpenInvites leaves out invites past expiresAt', async () => {
    seedRelation(db, relation({ id: 'r_open_1' }));
    seedRelation(db, relation({ id: 'r_stale_1', memberId: 'm2', expiresAt: NOW.toISOString() }));
    seedRelation(db, relation({ id: 'r_req_1', memberId: 'm3', status: 'requested', initiatedBy: 'member' }));
    const n = await deps.studios.runTransaction((tx) => tx.countOpenInvites(STUDIO, NOW));
    assert.equal(n, 1);
  });

  it('openRelationOf finds the pair only in invited | requested | active', async () => {
    seedRelation(db, relation({ id: 'r_old_1', status: 'declined' }));
    assert.equal(await deps.studios.runTransaction((tx) => tx.openRelationOf(STUDIO, 'm1')), null);
    seedRelation(db, relation({ id: 'r_new_2', status: 'requested' }));
    assert.equal((await deps.studios.runTransaction((tx) => tx.openRelationOf(STUDIO, 'm1')))?.id, 'r_new_2');
  });

  it('countOpenAssignments counts the studio bookings still open for the member', async () => {
    seedBooking(db, studioBooking({ id: 'b1', assigneeId: 'm1', assignStatus: 'assigned', status: 'upcoming' }));
    seedBooking(db, studioBooking({ id: 'b2', assigneeId: 'm1', assignStatus: 'assigned', status: 'shot' }));
    seedBooking(db, studioBooking({ id: 'b3', assigneeId: 'm1', assignStatus: 'assigned', status: 'completed' }));
    seedBooking(db, studioBooking({ id: 'b4', assigneeId: 'm2', assignStatus: 'assigned', status: 'upcoming' }));
    seedBooking(db, studioBooking({ id: 'b5', photographerId: 'other', assigneeId: 'm1', status: 'upcoming' }));
    const n = await deps.studios.runTransaction((tx) => tx.countOpenAssignments(STUDIO, 'm1'));
    assert.equal(n, 2);
  });

  it('countOpenSpotSchedules counts the studio\'s open spot schedules naming the member with a day ahead (#194)', async () => {
    const sched = (id: string, over: Partial<SpotSchedule>) =>
      db.seed(`spot_schedules/${id}`, scheduleToFirestore({ ...SPOT_SCHEDULE, id, ...over }));
    sched('s_ahead', { days: ['2026-10-09', '2026-10-12'] });
    sched('s_past', { days: ['2026-10-09'] });
    sched('s_cancelled', { status: 'cancelled', days: ['2026-10-12'] });
    sched('s_other_member', { assigneeId: 'm2', days: ['2026-10-12'] });
    sched('s_other_studio', { providerId: 'other', days: ['2026-10-12'] });
    const n = await deps.studios.runTransaction((tx) => tx.countOpenSpotSchedules(STUDIO, 'm1', '2026-10-10'));
    assert.equal(n, 1);
  });

  it('dueRelations merges the expire and announce queries, soonest first, once each', async () => {
    const at = (h: number) => new Date(NOW.getTime() + h * 3_600_000).toISOString();
    seedRelation(db, relation({ id: 'r_expired_1', expiresAt: at(-1) }));
    seedRelation(db, relation({ id: 'r_req_expired_1', status: 'requested', expiresAt: at(-2) }));
    seedRelation(db, relation({ id: 'r_soon_1', expiresAt: at(5) }));
    seedRelation(db, relation({ id: 'r_soon_told_1', expiresAt: at(6), expiringNotifiedAt: at(-1) }));
    seedRelation(db, relation({ id: 'r_req_soon_1', status: 'requested', expiresAt: at(3) }));
    seedRelation(db, relation({ id: 'r_later_1', expiresAt: at(30) }));
    seedRelation(db, relation({ id: 'r_active_1', status: 'active', expiresAt: at(-5) }));
    const due = await deps.studios.dueRelations(NOW, 10);
    assert.deepEqual(due.map((r) => r.id), ['r_req_expired_1', 'r_expired_1', 'r_soon_1']);
  });
});

describe('studio booking sweep queries', () => {
  it('findUnassignedStudioBookingsDue: unassigned, not overdue, requested | accepted, deadline within 24 h', async () => {
    const db = new MemoryFirestore();
    const at = (h: number) => new Date(NOW.getTime() + h * 3_600_000).toISOString();
    seedBooking(db, studioBooking({ id: 'due_2', assignDeadline: at(20) }));
    seedBooking(db, studioBooking({ id: 'due_1', assignDeadline: at(-1), status: 'requested' }));
    seedBooking(db, studioBooking({ id: 'later', assignDeadline: at(30) }));
    seedBooking(db, studioBooking({ id: 'overdue', assignDeadline: at(-3), assignOverdue: true }));
    seedBooking(db, studioBooking({ id: 'expired', assignDeadline: at(-3), status: 'expired' }));
    seedBooking(db, studioBooking({ id: 'assigned', assignDeadline: at(-3), assignStatus: 'assigned', assigneeId: 'm1' }));
    const store = new FirestoreBookingStore(db.asFirestore());
    assert.deepEqual((await store.findUnassignedStudioBookingsDue(NOW, 10)).map((b) => b.id), ['due_1', 'due_2']);
  });

  it('findUnassignedStudioBookingsStarted: unassigned, requested | accepted, start passed, oldest first', async () => {
    const db = new MemoryFirestore();
    // NOW = 2026-10-10 10:00 in Vietnam
    seedBooking(db, studioBooking({ id: 'today_started', day: '2026-10-10', start: '10:00' }));
    seedBooking(db, studioBooking({ id: 'yesterday', day: '2026-10-09', start: '18:00', status: 'requested', assignOverdue: true }));
    seedBooking(db, studioBooking({ id: 'today_later', day: '2026-10-10', start: '10:30' }));
    seedBooking(db, studioBooking({ id: 'tomorrow', day: '2026-10-11', start: '08:00' }));
    seedBooking(db, studioBooking({ id: 'cancelled', day: '2026-10-09', status: 'cancelled' }));
    seedBooking(db, studioBooking({ id: 'assigned', day: '2026-10-09', assignStatus: 'assigned', assigneeId: 'm1' }));
    const store = new FirestoreBookingStore(db.asFirestore());
    assert.deepEqual(
      (await store.findUnassignedStudioBookingsStarted(NOW, 10)).map((b) => b.id),
      ['yesterday', 'today_started'],
    );
  });

  it('findAutoCompletions leaves out studio bookings without an assignee', async () => {
    const db = new MemoryFirestore();
    seedBooking(db, studioBooking({ id: 'unassigned', day: '2026-10-01' }));
    seedBooking(db, studioBooking({ id: 'assigned', day: '2026-10-01', assignStatus: 'assigned', assigneeId: 'm1', status: 'upcoming' }));
    const store = new FirestoreBookingStore(db.asFirestore());
    assert.deepEqual((await store.findAutoCompletions(NOW)).map((b) => b.id), ['assigned']);
  });

  it('findDueChangeRequests: pending and past respondBy, oldest first', async () => {
    const db = new MemoryFirestore();
    const cr = (respondBy: string, status: 'pending' | 'declined' = 'pending') => ({
      at: NOW.toISOString(), note: null, respondBy, status, declineReason: null, answeredAt: null,
    });
    const at = (h: number) => new Date(NOW.getTime() + h * 3_600_000).toISOString();
    seedBooking(db, studioBooking({ id: 'late_2', assigneeId: 'm1', changeRequest: cr(at(-1)) }));
    seedBooking(db, studioBooking({ id: 'late_1', assigneeId: 'm1', changeRequest: cr(at(-2)) }));
    seedBooking(db, studioBooking({ id: 'open', assigneeId: 'm1', changeRequest: cr(at(2)) }));
    seedBooking(db, studioBooking({ id: 'answered', assigneeId: 'm1', changeRequest: cr(at(-3), 'declined') }));
    const store = new FirestoreBookingStore(db.asFirestore());
    assert.deepEqual((await store.findDueChangeRequests(NOW, 10)).map((b) => b.id), ['late_1', 'late_2']);
  });
});

describe('studio readers', () => {
  it('orderProfile reads providerType and studioId with the gate in one read', async () => {
    const db = new MemoryFirestore();
    seedStudio(db, ['m1']);
    const gate = new FirestoreProviderOrderGate(db.asFirestore());
    db.reads = 0;
    assert.deepEqual(await gate.orderProfile(STUDIO), { acceptsOrders: true, providerType: 'studio', studioId: null });
    assert.equal(db.reads, 1);
    assert.deepEqual(await gate.orderProfile('m1'), { acceptsOrders: true, providerType: 'individual', studioId: STUDIO });
  });

  it('the roster answers member only for an active member of that studio', async () => {
    const db = new MemoryFirestore();
    seedStudio(db, ['m1']);
    seedPerson(db, 'x1', 'Người ngoài');
    const roster = new FirestoreStudioRoster(db.asFirestore());
    assert.equal(await roster.relationOf(STUDIO, 'm1'), 'member');
    assert.equal(await roster.relationOf(STUDIO, 'x1'), null);
    assert.equal(await roster.relationOf('studio_other', 'm1'), null);
    assert.deepEqual(await roster.person('m1'), { name: 'Thợ 1', avatarUrl: 'https://img.test/m1.jpg' });
  });

  it('the member day reader lists members by join date and reads busy times from the occupying booking', async () => {
    const db = new MemoryFirestore();
    seedStudio(db, ['m1', 'm2']);
    db.seed('photographers/m2', { ...db.data('photographers/m2'), studioJoinedAt: Timestamp.fromDate(new Date(NOW.getTime() - 60 * DAY_MS)) });
    seedBooking(db, studioBooking({ id: 'personal', photographerId: 'm1', isStudio: undefined, start: '15:00', end: '18:00' }));
    db.seed('availability/m1/days/2026-10-14', { state: 'booked', bookingId: 'personal' });
    db.seed('availability/m2/days/2026-10-14', { state: 'off' });
    const reader = new FirestoreMemberDayReader(db.asFirestore());
    assert.deepEqual(await reader.members(STUDIO), ['m2', 'm1']);
    assert.deepEqual(await reader.day('m1', '2026-10-14'), { state: 'booked', start: '15:00', end: '18:00' });
    assert.deepEqual(await reader.day('m2', '2026-10-14'), { state: 'off', start: null, end: null });
    assert.equal(await reader.day('m1', '2026-10-15'), null);
    assert.deepEqual(await reader.stats('m1'), { tomatoPct: 90, reviewCount: 10 });
  });

  it('the member day reader reads a spot day as busy with the schedule window (#194 Decision 6)', async () => {
    const db = new MemoryFirestore();
    seedStudio(db, ['m1']);
    db.seed('spot_schedules/sched_1', scheduleToFirestore({ ...SPOT_SCHEDULE, id: 'sched_1' }));
    db.seed('availability/m1/days/2026-10-12', { state: 'spot', scheduleId: 'sched_1', spotId: 'spot_1' });
    db.seed('availability/m1/days/2026-10-13', { state: 'spot' });
    const reader = new FirestoreMemberDayReader(db.asFirestore());
    assert.deepEqual(await reader.day('m1', '2026-10-12'), { state: 'spot', start: '06:00', end: '11:00' });
    assert.deepEqual(await reader.day('m1', '2026-10-13'), { state: 'spot', start: null, end: null });
  });

  it('nameKeys: update only, a deleted photographer document is not recreated', async () => {
    const db = new MemoryFirestore();
    seedPerson(db, 'p1', 'Hồng Nhung');
    const keys = new FirestoreNameKeys(db.asFirestore());
    await keys.setNameKey('p1', 'hong nhung');
    assert.equal(db.data('photographers/p1')?.nameKey, 'hong nhung');
    await keys.setNameKey('ghost', 'x');
    assert.equal(db.data('photographers/ghost'), undefined);
    assert.equal(await keys.displayName('p1'), 'Hồng Nhung');
  });

  it('account deletion finds active studio relations on both sides (#205: memberId and studioId, no userId)', async () => {
    const db = new MemoryFirestore();
    seedRelation(db, relation({ id: 'r_a_1', status: 'active', studioName: 'Cúc Studio' }));
    seedRelation(db, relation({ id: 'r_b_1', status: 'left', studioName: 'Cúc Studio' }));
    seedRelation(db, relation({ id: 'r_c_1', studioId: 'm1', memberId: 'm9', status: 'active', memberName: 'Thợ 9' }));
    const items = await studioRelationBlockers(db.asFirestore(), 'm1');
    assert.deepEqual(items, [
      { id: 'r_a_1', title: 'Cúc Studio', day: null },
      { id: 'r_c_1', title: 'Thợ 9', day: null },
    ]);
  });
});

describe('recomputeStudioDay (Decision 26)', () => {
  const DAY = '2026-10-14';
  let db: MemoryFirestore;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedStudio(db, ['m1', 'm2']);
  });

  const load = (unassignedIds: string[], assignedIds: string[] = []) =>
    db.seed(`studio_day_load/${STUDIO}_${DAY}`, { studioId: STUDIO, day: DAY, unassignedIds, assignedIds });

  it('writes full when load reaches capacity and deletes it when a place frees', async () => {
    load(['b1']);
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), null);
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`), undefined);

    load(['b1', 'b2']);
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'set_full');
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`)?.state, 'full');
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), null, 'idempotent');

    load(['b1']);
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'clear_full');
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`), undefined);
  });

  it('a member busy that day takes a place; an assigned booking holds its own member', async () => {
    load(['b1']);
    db.seed(`availability/m2/days/${DAY}`, { state: 'pending', bookingId: 'personal' });
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'set_full');
    db.docs.delete(`availability/m2/days/${DAY}`);
    load([], ['b1']);
    db.seed(`availability/m1/days/${DAY}`, { state: 'booked', bookingId: 'b1' });
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'clear_full');
  });

  it('a member holding the day for a spot schedule is busy, not free (#194 Decision 6)', async () => {
    load(['b1']);
    db.seed(`availability/m2/days/${DAY}`, { state: 'spot', scheduleId: 'sched_1', spotId: 'spot_1' });
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'set_full');
    assert.equal(db.data(`availability/m2/days/${DAY}`)?.state, 'spot', 'the member record is left alone');
  });

  it('a studio off day is never touched; a provider that is no longer a studio only loses a stale mark', async () => {
    db.seed(`availability/${STUDIO}/days/${DAY}`, { state: 'off' });
    load(['b1', 'b2', 'b3']);
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), null);
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`)?.state, 'off');

    db.seed(`photographers/${STUDIO}`, { ...db.data(`photographers/${STUDIO}`), providerType: 'individual' });
    db.seed(`availability/${STUDIO}/days/${DAY}`, { state: 'full' });
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), 'clear_full');
    db.seed(`availability/${STUDIO}/days/${DAY}`, { state: 'booked', bookingId: 'x' });
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), null);
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`)?.state, 'booked');
  });

  it('after a member leaves, a day where the remaining member is busy and nothing is booked becomes full', async () => {
    // m2 leaves; m1 is off on the 20th; Cúc has no booking that day (no load doc) → zero free members.
    db.seed('photographers/m2', { ...db.data('photographers/m2'), studioId: null });
    db.seed('availability/m1/days/2026-10-20', { state: 'off' });
    // m2's own day (the member who left) is recomputed too; with m1 free there it stays open.
    db.seed('availability/m2/days/2026-10-21', { state: 'booked', bookingId: 'own' });
    db.seed('availability/m1/days/2026-10-01', { state: 'off' });
    const n = await recomputeStudioDays(db.asFirestore(), STUDIO, NOW, ['m2']);
    assert.equal(n, 2);
    assert.equal(db.data(`availability/${STUDIO}/days/2026-10-20`)?.state, 'full');
    assert.equal(db.data(`availability/${STUDIO}/days/2026-10-21`), undefined);
    assert.equal(db.data(`availability/${STUDIO}/days/2026-10-01`), undefined, 'past days are left alone');
  });

  it("the studio's own event or old booking hold is never overwritten by full", async () => {
    db.seed(`availability/${STUDIO}/days/${DAY}`, { state: 'booked', eventId: 'ev1' });
    load(['b1', 'b2', 'b3']);
    assert.equal(await recomputeStudioDay(db.asFirestore(), STUDIO, DAY), null);
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`)?.eventId, 'ev1');
  });

  it('refreshAssignableMembers counts members that pass the gate, writes only on change, skips non-studios', async () => {
    assert.equal(await refreshAssignableMembers(db.asFirestore(), STUDIO), 2);
    assert.equal(db.data(`photographers/${STUDIO}`)?.assignableMembers, 2);
    const writes = db.log.length;
    assert.equal(await refreshAssignableMembers(db.asFirestore(), STUDIO), 2);
    assert.equal(db.log.length, writes, 'unchanged: nothing written');
    db.seed('photographers/m1', { ...db.data('photographers/m1'), verified: false });
    db.seed('photographers/m2', { ...db.data('photographers/m2'), deletionPending: true });
    assert.equal(await refreshAssignableMembers(db.asFirestore(), STUDIO), 0);
    assert.equal(db.data(`photographers/${STUDIO}`)?.assignableMembers, 0);
    assert.equal(await refreshAssignableMembers(db.asFirestore(), 'm1'), null);
    assert.equal(db.data('photographers/m1')?.assignableMembers, undefined);
  });

  it('recomputeStudioDays covers the upcoming load days and full marks, not past ones', async () => {
    // m2 leaves: one free member left for two unassigned bookings on the 14th.
    db.seed('photographers/m2', { ...db.data('photographers/m2'), studioId: null });
    load(['b1', 'b2']);
    db.seed(`studio_day_load/${STUDIO}_2026-10-01`, { studioId: STUDIO, day: '2026-10-01', unassignedIds: ['old1', 'old2'], assignedIds: [] });
    db.seed(`availability/${STUDIO}/days/2026-10-20`, { state: 'full' });
    const n = await recomputeStudioDays(db.asFirestore(), STUDIO, NOW);
    assert.equal(n, 2);
    assert.equal(db.data(`availability/${STUDIO}/days/${DAY}`)?.state, 'full');
    assert.equal(db.data(`availability/${STUDIO}/days/2026-10-20`), undefined);
    assert.equal(db.data(`availability/${STUDIO}/days/2026-10-01`), undefined);
  });
});

describe('studio indexes', () => {
  it('every studio query has its composite index', () => {
    const json = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; queryScope: string; fields: { fieldPath: string; order: string }[] }[];
    };
    const shapes = json.indexes
      .filter((i) => i.queryScope === 'COLLECTION')
      .map((i) => `${i.collectionGroup}: ${i.fields.map((f) => `${f.fieldPath} ${f.order}`).join(', ')}`);
    for (const shape of [
      'bookings: assignStatus ASCENDING, assignOverdue ASCENDING, status ASCENDING, assignDeadline ASCENDING',
      'bookings: assignStatus ASCENDING, status ASCENDING, day ASCENDING',
      'bookings: changeRequest.status ASCENDING, changeRequest.respondBy ASCENDING',
      'bookings: photographerId ASCENDING, assigneeId ASCENDING, status ASCENDING',
      'bookings: assigneeId ASCENDING, createdAt DESCENDING',
      'studio_members: studioId ASCENDING, memberId ASCENDING, status ASCENDING',
      'studio_members: status ASCENDING, expiresAt ASCENDING',
      'studio_members: status ASCENDING, expiringNotifiedAt ASCENDING, expiresAt ASCENDING',
      'studio_members: studioId ASCENDING, status ASCENDING, createdAt DESCENDING',
      'studio_members: memberId ASCENDING, status ASCENDING, createdAt DESCENDING',
      'photographers: studioId ASCENDING, studioJoinedAt ASCENDING',
      'studio_day_load: studioId ASCENDING, day ASCENDING',
    ]) {
      assert.ok(shapes.includes(shape), shape);
    }
  });
});
