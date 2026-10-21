import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryStudioStore,
  MemoryUserDirectory,
  type Booking,
  type NotifyDeps,
  type StudioBookingDeps,
  type StudioDeps,
  type StudioProfile,
} from '@photobooking/domain';
import {
  handleAssignBooking,
  handleAssignmentOptions,
  handleCancelInvite,
  handleCancelJoinRequest,
  handleDeclineAssigneeChange,
  handleInviteMember,
  handleLeaveStudio,
  handleRemoveMember,
  handleRequestAssigneeChange,
  handleRequestToJoin,
  handleRespondInvite,
  handleRespondJoinRequest,
  handleReturnAssignment,
  handleSearchPhotographersToInvite,
  sendMembershipNotices,
} from '../../src/callables/studio.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import { liveAssignmentOptionsDeps, liveStudioBookingDeps, liveStudioClockExtras } from '../../src/infra/live_studio.js';
import { FirestoreMemberDayReader } from '../../src/infra/studio_firestore.js';
import { paymentWorld, captureLogs } from './support/payment_world.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { NOW, STUDIO, seedPerson, seedStudio, studioBooking } from './support/studio_fixtures.js';

const DAY_MS = 86_400_000;

function profile(uid: string, over: Partial<StudioProfile> = {}): StudioProfile {
  return {
    uid,
    providerType: 'individual',
    onboardingComplete: true,
    businessVerified: false,
    memberCount: 0,
    studioId: null,
    studioCooldownUntil: null,
    name: uid,
    avatarUrl: null,
    ...over,
  };
}

function notifyDeps(): { deps: NotifyDeps; store: MemoryNotificationStore } {
  const store = new MemoryNotificationStore();
  return {
    store,
    deps: { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => NOW } },
  };
}

const asCaller = (uid: string, data: unknown = {}) => ({ auth: { uid }, data });
const refused = (code: string, detail?: string) => (e: unknown) =>
  e instanceof HttpsError && e.code === code && (detail === undefined || (e.details as { code?: string })?.code === detail);

describe('studio membership callables', () => {
  let store: MemoryStudioStore;
  let deps: StudioDeps;

  beforeEach(() => {
    store = new MemoryStudioStore();
    store.seedProfile(profile(STUDIO, { providerType: 'studio', name: 'Cúc Studio' }));
    store.seedProfile(profile('studio_2', { providerType: 'studio', name: 'Mây Studio' }));
    for (const m of ['m1', 'm2', 'm3', 'm4']) store.seedProfile(profile(m, { name: `Thợ ${m}` }));
    deps = { studios: store, clock: { now: () => NOW }, ids: { newId: () => 'unused' } };
  });

  it('unauthenticated is refused by all 14 callables', async () => {
    const noAuth = { auth: undefined, data: {} };
    const bookingDeps = {} as StudioBookingDeps;
    const calls: (() => Promise<unknown>)[] = [
      () => handleInviteMember(noAuth, deps),
      () => handleCancelInvite(noAuth, deps),
      () => handleRequestToJoin(noAuth, deps),
      () => handleCancelJoinRequest(noAuth, deps),
      () => handleRespondInvite(noAuth, deps),
      () => handleRespondJoinRequest(noAuth, deps),
      () => handleLeaveStudio(noAuth, deps),
      () => handleRemoveMember(noAuth, deps),
      () => handleSearchPhotographersToInvite(noAuth, { firestore: new MemoryFirestore().asFirestore(), clock: { now: () => NOW } }),
      () => handleAssignmentOptions(noAuth, bookingDeps as StudioBookingDeps & { availability: FirestoreMemberDayReader }),
      () => handleAssignBooking(noAuth, bookingDeps),
      () => handleRequestAssigneeChange(noAuth, bookingDeps),
      () => handleDeclineAssigneeChange(noAuth, bookingDeps),
      () => handleReturnAssignment(noAuth, bookingDeps),
    ];
    for (const call of calls) await assert.rejects(call, refused('unauthenticated', 'permission_denied'));
  });

  it('each membership callable passes the caller uid as the right party', async () => {
    // The studio invites; the invited photographer (not the studio) answers.
    const { relationId } = await handleInviteMember(asCaller(STUDIO, { memberId: 'm1' }), deps);
    assert.equal(store.relations.get(relationId)?.studioId, STUDIO);
    await assert.rejects(
      handleRespondInvite(asCaller(STUDIO, { relationId, accept: true }), deps),
      refused('permission-denied'),
    );
    assert.deepEqual(await handleRespondInvite(asCaller('m1', { relationId, accept: true }), deps), { status: 'active' });

    // A photographer asks; only the studio answers.
    const asked = await handleRequestToJoin(asCaller('m2', { studioId: STUDIO }), deps);
    assert.equal(store.relations.get(asked.relationId)?.memberId, 'm2');
    await assert.rejects(
      handleRespondJoinRequest(asCaller('m2', { relationId: asked.relationId, accept: true }), deps),
      refused('permission-denied'),
    );
    assert.deepEqual(
      await handleRespondJoinRequest(asCaller(STUDIO, { relationId: asked.relationId, accept: false }), deps),
      { status: 'declined' },
    );

    // Cancel: each side only its own.
    const inv = await handleInviteMember(asCaller(STUDIO, { memberId: 'm3' }), deps);
    await assert.rejects(handleCancelInvite(asCaller('m3', { relationId: inv.relationId }), deps), refused('permission-denied'));
    assert.deepEqual(await handleCancelInvite(asCaller(STUDIO, { relationId: inv.relationId }), deps), {});
    const req = await handleRequestToJoin(asCaller('m4', { studioId: STUDIO }), deps);
    await assert.rejects(
      handleCancelJoinRequest(asCaller(STUDIO, { relationId: req.relationId }), deps),
      refused('permission-denied'),
    );
    assert.deepEqual(await handleCancelJoinRequest(asCaller('m4', { relationId: req.relationId }), deps), {});

    // Leave is the member's, remove the studio's.
    assert.deepEqual(await handleLeaveStudio(asCaller('m1'), deps), {});
    assert.equal(store.profiles.get('m1')?.studioId, null);
    await assert.rejects(handleRemoveMember(asCaller('m1', { memberId: 'm1' }), deps), (e: unknown) => e instanceof HttpsError);
  });

  it('new codes map to failed-precondition / resource-exhausted', async () => {
    store.seedProfile(profile('m9', { studioId: 'studio_2' }));
    await assert.rejects(
      handleInviteMember(asCaller(STUDIO, { memberId: 'm9' }), deps),
      refused('failed-precondition', 'membership_conflict'),
    );
    store.seedProfile(profile('m8', { studioCooldownUntil: new Date(NOW.getTime() + DAY_MS).toISOString() }));
    await assert.rejects(handleInviteMember(asCaller(STUDIO, { memberId: 'm8' }), deps), refused('failed-precondition', 'cooldown'));
    for (const m of ['m1', 'm2', 'm3']) await handleInviteMember(asCaller(STUDIO, { memberId: m }), deps);
    await assert.rejects(handleInviteMember(asCaller(STUDIO, { memberId: 'm4' }), deps), refused('resource-exhausted', 'studio_full'));
  });

  it('membership notices go out after the commit, to the right party', async () => {
    const n = notifyDeps();
    const { relationId } = await handleInviteMember(asCaller(STUDIO, { memberId: 'm1' }), deps, n.deps);
    await handleRespondInvite(asCaller('m1', { relationId, accept: true }), deps, n.deps);
    const types = (uid: string) => n.store.rowsOf(uid).map((r) => r.type);
    assert.deepEqual(types('m1'), ['studio_invite']);
    assert.deepEqual(types(STUDIO), ['studio_invite_accepted']);
  });

  it('a failing notice is logged and never undoes the committed change', async (t) => {
    const broken = { ...notifyDeps().deps, store: { runTransaction: async () => { throw new Error('down'); } } } as unknown as NotifyDeps;
    let out: { relationId: string } | undefined;
    const lines = await captureLogs(t, async () => {
      out = await handleInviteMember(asCaller(STUDIO, { memberId: 'm1' }), deps, broken);
    });
    assert.ok(out && store.relations.get(out.relationId)?.status === 'invited');
    assert.ok(lines.some((l) => l.includes('studio membership notice failed')));
  });

  it('sendMembershipNotices sends nothing for a change without a notice', async () => {
    const n = notifyDeps();
    const { relationId } = await handleInviteMember(asCaller(STUDIO, { memberId: 'm1' }), deps);
    const rel = store.relations.get(relationId);
    assert.ok(rel);
    await sendMembershipNotices(n.deps, { before: rel, after: { ...rel, status: 'cancelled' } });
    assert.equal(n.store.rows.size, 0);
  });
});

describe('searchPhotographersToInvite (S26.02)', () => {
  let db: MemoryFirestore;
  const search = (uid: string, query: unknown) =>
    handleSearchPhotographersToInvite(asCaller(uid, { query }), { firestore: db.asFirestore(), clock: { now: () => NOW } });

  beforeEach(() => {
    db = new MemoryFirestore();
    seedStudio(db, ['m_ours']);
    db.seed('photographers/m_ours', { ...db.data('photographers/m_ours'), nameKey: 'nguyen ours' });
    seedPerson(db, 'studio_may', 'Mây Studio', { providerType: 'studio', nameKey: 'nguyen studio' });
    seedPerson(db, 'm_free', 'Nguyễn Free', { nameKey: 'nguyen free', stats: { tomatoPct: 97 }, serviceArea: { city: 'Huế' } });
    seedPerson(db, 'm_else', 'Nguyễn Else', { nameKey: 'nguyen else', studioId: 'studio_may' });
    seedPerson(db, 'm_cool', 'Nguyễn Cool', {
      nameKey: 'nguyen cool',
      studioCooldownUntil: new Date(NOW.getTime() + 3 * DAY_MS),
    });
    seedPerson(db, 'm_inv', 'Nguyễn Invited', { nameKey: 'nguyen invited', verified: false });
    seedPerson(db, 'm_new', 'Nguyễn New', { nameKey: 'nguyen new', onboardingComplete: false });
    seedPerson(db, 'other', 'Trần Other', { nameKey: 'tran other' });
    db.seed(`studio_members/${STUDIO}_m_inv_1`, {
      studioId: STUDIO, memberId: 'm_inv', status: 'invited', initiatedBy: 'studio',
      createdAt: NOW, expiresAt: new Date(NOW.getTime() + 2 * DAY_MS), expiringNotifiedAt: null,
    });
  });

  it('needs 2 characters, returns ≤ 20 rows with states', async () => {
    await assert.rejects(search(STUDIO, 'N'), refused('invalid-argument', 'invalid_argument'));
    await assert.rejects(search(STUDIO, 42), refused('invalid-argument'));
    const { rows } = await search(STUDIO, 'Nguyễn');
    const byUid = Object.fromEntries(rows.map((r) => [r.uid, r]));
    assert.deepEqual(Object.keys(byUid).sort(), ['m_cool', 'm_else', 'm_free', 'm_inv', 'm_ours']);
    assert.equal(byUid.m_ours?.state, 'member');
    assert.deepEqual(
      { state: byUid.m_else?.state, studioName: byUid.m_else?.studioName },
      { state: 'in_studio', studioName: 'Mây Studio' },
    );
    assert.equal(byUid.m_cool?.state, 'cooldown');
    assert.equal(byUid.m_cool?.availableFrom, new Date(NOW.getTime() + 3 * DAY_MS).toISOString());
    assert.equal(byUid.m_inv?.state, 'invited');
    assert.equal(byUid.m_inv?.verified, false);
    assert.deepEqual(byUid.m_free, {
      uid: 'm_free', name: 'Nguyễn Free', avatarUrl: 'https://img.test/m_free.jpg', verified: true,
      tomatoPct: 97, areaLabel: 'Huế', state: 'invitable',
    });

    for (let i = 0; i < 25; i++) seedPerson(db, `bulk_${i}`, `Nguyễn ${i}`, { nameKey: `nguyen ${String(i).padStart(2, '0')}` });
    assert.ok((await search(STUDIO, 'nguyen')).rows.length <= 20);
  });

  it('only a studio searches', async () => {
    await assert.rejects(search('m_free', 'nguyen'), refused('permission-denied'));
    await assert.rejects(search('nobody', 'nguyen'), refused('not-found'));
  });
});

describe('studio booking callables', () => {
  function world(booking: Booking) {
    const w = paymentWorld(NOW);
    w.store.bookings.set(booking.id, booking);
    w.store.studioMembers.set(STUDIO, ['m1', 'm2']);
    const deps: StudioBookingDeps = {
      ...w.deps,
      store: w.store,
      roster: {
        relationOf: async (studioId, uid) => (studioId === STUDIO && ['m1', 'm2'].includes(uid) ? 'member' : null),
        person: async (uid) => ({ name: `Thợ ${uid}`, avatarUrl: null }),
      },
    };
    return { w, deps };
  }

  it('assignBooking: the caller must be the studio; the result is the booking', async () => {
    const { deps, w } = world(studioBooking());
    await assert.rejects(
      handleAssignBooking(asCaller('m1', { bookingId: 'bk_studio_1', assigneeId: 'm1' }), deps),
      refused('permission-denied'),
    );
    const b = await handleAssignBooking(asCaller(STUDIO, { bookingId: 'bk_studio_1', assigneeId: 'm1' }), deps);
    assert.equal(b.assigneeId, 'm1');
    assert.equal(w.store.availability.get('m1_2026-10-14')?.bookingId, 'bk_studio_1');
  });

  it('a block between the customer and the member refuses the assignment (BlockGate wired)', async () => {
    const { deps, w } = world(studioBooking());
    w.blocks.block(studioBooking().customerId, 'm2');
    await assert.rejects(
      handleAssignBooking(asCaller(STUDIO, { bookingId: 'bk_studio_1', assigneeId: 'm2' }), deps),
      refused('failed-precondition', 'blocked'),
    );
  });

  it('change request is the customer\'s, decline the studio\'s, "Trả việc" the assignee\'s', async () => {
    const assigned = studioBooking({ assigneeId: 'm1', assigneeKind: 'member', assignStatus: 'assigned', assignedAt: NOW.toISOString() });
    const { deps } = world(assigned);
    await assert.rejects(handleRequestAssigneeChange(asCaller(STUDIO, { bookingId: assigned.id }), deps), refused('permission-denied'));
    const asked = await handleRequestAssigneeChange(asCaller(assigned.customerId, { bookingId: assigned.id, note: 'Muốn thợ nữ' }), deps);
    assert.equal(asked.changeRequest?.status, 'pending');
    await assert.rejects(
      handleDeclineAssigneeChange(asCaller(assigned.customerId, { bookingId: assigned.id, reason: 'x' }), deps),
      refused('permission-denied'),
    );
    const declined = await handleDeclineAssigneeChange(asCaller(STUDIO, { bookingId: assigned.id, reason: 'Kín lịch' }), deps);
    assert.equal(declined.studioFault?.kind, 'change_declined');
    await assert.rejects(handleReturnAssignment(asCaller('m2', { bookingId: assigned.id }), deps), refused('permission-denied'));
    const returned = await handleReturnAssignment(asCaller('m1', { bookingId: assigned.id, reason: 'Ốm' }), deps);
    assert.equal(returned.assignmentReturned?.reason, 'Ốm');
  });

  it('assignmentOptions returns busy times from the occupying booking, with the deadline', async () => {
    const db = new MemoryFirestore();
    seedStudio(db, ['m1', 'm2']);
    db.seed('bookings/personal', { start: '15:00', end: '18:00' });
    db.seed('availability/m1/days/2026-10-14', { state: 'booked', bookingId: 'personal' });
    const { deps } = world(studioBooking());
    const out = await handleAssignmentOptions(asCaller(STUDIO, { bookingId: 'bk_studio_1' }), {
      ...deps,
      availability: new FirestoreMemberDayReader(db.asFirestore()),
    });
    assert.equal(out.deadline, studioBooking().assignDeadline);
    const byUid = Object.fromEntries(out.options.map((o) => [o.uid, o]));
    assert.deepEqual(
      { state: byUid.m1?.state, busyStart: byUid.m1?.busyStart, busyEnd: byUid.m1?.busyEnd },
      { state: 'busy', busyStart: '15:00', busyEnd: '18:00' },
    );
    assert.equal(byUid.m2?.state, 'free');
    await assert.rejects(
      handleAssignmentOptions(asCaller('m1', { bookingId: 'bk_studio_1' }), { ...deps, availability: new FirestoreMemberDayReader(db.asFirestore()) }),
      refused('permission-denied'),
    );
  });

  it('live studio deps wire a BlockGate', () => {
    for (const deps of [liveStudioBookingDeps(), liveAssignmentOptionsDeps(), liveStudioClockExtras().bookings]) {
      assert.ok(deps.blocks instanceof FirestoreBlockGate);
      assert.equal(typeof deps.roster.relationOf, 'function');
      assert.equal(typeof deps.store.findUnassignedStudioBookingsDue, 'function');
    }
  });
});
