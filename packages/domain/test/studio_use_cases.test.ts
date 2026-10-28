import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import type { StudioProfile, StudioRelation } from '../src/studio_membership.js';
import {
  cancelInvite,
  cancelJoinRequest,
  inviteMember,
  leaveStudio,
  membershipNotices,
  removeMember,
  requestToJoin,
  respondInvite,
  respondJoinRequest,
  runMembershipSweeps,
} from '../src/studio_use_cases.js';
import type { NotifyDeps } from '../src/notification_ports.js';
import { createNotifyWorld } from './support/notify_world.js';
import { createStudioWorld, type StudioWorld } from './support/studio_world.js';

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

const NOW_ISO = '2026-10-10T10:00:00.000Z';
const IN_7_DAYS = '2026-10-17T10:00:00.000Z';

describe('studio membership use cases', () => {
  let w: StudioWorld;

  beforeEach(() => {
    w = createStudioWorld();
  });

  function patchProfile(uid: string, over: Partial<StudioProfile>): void {
    const p = w.store.profiles.get(uid);
    assert.ok(p, uid);
    w.store.seedProfile({ ...p, ...over });
  }

  /** Advance one minute so every relation gets its own creation time. */
  const tick = (): void => w.clock.advanceMinutes(1);

  async function joinByInvite(studioId: string, memberId: string): Promise<StudioRelation> {
    const inv = await inviteMember(w.deps, studioId, { memberId });
    tick();
    return (await respondInvite(w.deps, memberId, { relationId: inv.after.id, accept: true })).after;
  }

  describe('inviteMember', () => {
    it('invite creates an invited relation expiring in 7 days and counts a studio action', async () => {
      const c = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      assert.equal(c.before, null);
      assert.deepEqual(c.after, {
        id: 's1_m1_1791626400000',
        studioId: 's1',
        memberId: 'm1',
        status: 'invited',
        initiatedBy: 'studio',
        createdAt: NOW_ISO,
        expiresAt: IN_7_DAYS,
        respondedAt: null,
        joinedAt: null,
        endedAt: null,
        endedBy: null,
        expiringNotifiedAt: null,
        studioName: 'Studio Mây',
        studioAvatarUrl: 'https://img/s1.jpg',
        memberName: 'Minh Trí',
        memberAvatarUrl: null,
        version: 1,
      });
      assert.deepEqual(w.store.relations.get(c.after.id), c.after);
      assert.deepEqual(w.store.quotas.get('s1'), { dayKey: '2026-10-10', studioActions: 1, memberActions: 0 });
    });

    it('invite of a member active elsewhere is membership_conflict', async () => {
      await joinByInvite('s2', 'm1');
      tick();
      await refused(inviteMember(w.deps, 's1', { memberId: 'm1' }), 'membership_conflict');
    });

    it('invite during cooldown is cooldown', async () => {
      patchProfile('m1', { studioCooldownUntil: '2026-10-12T00:00:00.000Z' });
      await refused(inviteMember(w.deps, 's1', { memberId: 'm1' }), 'cooldown');
      w.clock.setTime(new Date('2026-10-12T00:00:00.000Z'));
      const c = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      assert.equal(c.after.status, 'invited');
    });

    it('a sixth open invite is studio_full', async () => {
      patchProfile('s1', { businessVerified: true });
      for (const m of ['m1', 'm2', 'm3', 'm4', 'm5']) {
        await inviteMember(w.deps, 's1', { memberId: m });
        tick();
      }
      w.clock.setTime(new Date('2026-10-11T02:00:00.000Z')); // next VN day: quota is not the reason
      await refused(inviteMember(w.deps, 's1', { memberId: 'a1' }), 'studio_full');
    });

    it('members + invites over 3 is studio_full, 30 when verified', async () => {
      await joinByInvite('s1', 'm1');
      tick();
      await inviteMember(w.deps, 's1', { memberId: 'm2' });
      tick();
      await inviteMember(w.deps, 's1', { memberId: 'm3' });
      tick();
      await refused(inviteMember(w.deps, 's1', { memberId: 'm4' }), 'studio_full');
      patchProfile('s1', { businessVerified: true });
      const c = await inviteMember(w.deps, 's1', { memberId: 'm4' });
      assert.equal(c.after.status, 'invited');
    });

    it('a second open relation of the same pair is conflict', async () => {
      await inviteMember(w.deps, 's1', { memberId: 'm1' });
      tick();
      await refused(inviteMember(w.deps, 's1', { memberId: 'm1' }), 'conflict');
      await refused(requestToJoin(w.deps, 'm1', { studioId: 's1' }), 'conflict');
    });

    it('the sixth studio action of the VN day is rate_limited; the next day works', async () => {
      // invite + cancel, twice (4), then invite (5): the sixth action is refused.
      for (let i = 0; i < 2; i++) {
        const c = await inviteMember(w.deps, 's1', { memberId: 'm1' });
        tick();
        await cancelInvite(w.deps, 's1', { relationId: c.after.id });
        tick();
      }
      await inviteMember(w.deps, 's1', { memberId: 'm2' });
      tick();
      await refused(inviteMember(w.deps, 's1', { memberId: 'm3' }), 'rate_limited');
      assert.equal(w.store.quotas.get('s1')?.studioActions, 5);
      w.clock.setTime(new Date('2026-10-10T17:00:00.000Z')); // 00:00 VN
      const c = await inviteMember(w.deps, 's1', { memberId: 'm3' });
      assert.equal(c.after.status, 'invited');
      assert.deepEqual(w.store.quotas.get('s1'), { dayKey: '2026-10-11', studioActions: 1, memberActions: 0 });
    });

    it('an invite past expiresAt frees its seat before the sweep runs', async () => {
      for (const m of ['m1', 'm2', 'm3']) {
        await inviteMember(w.deps, 's1', { memberId: m });
        tick();
      }
      await refused(inviteMember(w.deps, 's1', { memberId: 'm4' }), 'studio_full');
      // 17/10 10:01: the invites of m1 (10:00) and m2 (10:01) are past expiresAt but not swept; m3's (10:02) is open.
      w.clock.setTime(new Date('2026-10-17T10:01:00.000Z'));
      assert.equal(w.store.relations.get('s1_m1_1791626400000')?.status, 'invited');
      assert.equal((await inviteMember(w.deps, 's1', { memberId: 'm4' })).after.status, 'invited');
      assert.equal((await inviteMember(w.deps, 's1', { memberId: 'm5' })).after.status, 'invited');
      // m3, m4, m5 hold the three seats
      await refused(inviteMember(w.deps, 's1', { memberId: 'a1' }), 'studio_full');
    });

    it('a studio cannot invite itself or another studio (invalid_argument)', async () => {
      await refused(inviteMember(w.deps, 's1', { memberId: 's1' }), 'invalid_argument');
      await refused(inviteMember(w.deps, 's1', { memberId: 's2' }), 'invalid_argument');
      await refused(inviteMember(w.deps, 's1', { memberId: 'u1' }), 'invalid_argument');
      await refused(inviteMember(w.deps, 'm2', { memberId: 'm1' }), 'invalid_argument');
      await refused(inviteMember(w.deps, 's1', {}), 'invalid_argument');
      await refused(inviteMember(w.deps, 's1', { memberId: 'ghost' }), 'not_found');
      assert.equal(w.store.writes, 0);
    });

    it('an artist can be invited', async () => {
      const c = await inviteMember(w.deps, 's1', { memberId: 'a1' });
      assert.equal(c.after.memberName, 'Anh Tú');
    });
  });

  describe('cancelInvite', () => {
    it('cancelInvite only by its studio and only while invited', async () => {
      const c = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      tick();
      await refused(cancelInvite(w.deps, 's2', { relationId: c.after.id }), 'permission_denied');
      await refused(cancelInvite(w.deps, 's1', { relationId: 's1_m9_1791626400000' }), 'not_found');
      const done = await cancelInvite(w.deps, 's1', { relationId: c.after.id });
      assert.equal(done.before?.status, 'invited');
      assert.equal(done.after.status, 'cancelled');
      assert.equal(done.after.endedBy, 'studio');
      assert.equal(done.after.version, 2);
      await refused(cancelInvite(w.deps, 's1', { relationId: c.after.id }), 'conflict');
      assert.equal(w.store.quotas.get('s1')?.studioActions, 2);
    });

    it('relation ids must have the {studio}_{member}_{ms} shape', async () => {
      for (const relationId of ['__x__', 's1_m1', 'nope', '', 's1/m1_1', `${'a'.repeat(161)}_1`]) {
        await refused(cancelInvite(w.deps, 's1', { relationId }), 'invalid_argument');
        await refused(respondInvite(w.deps, 'm1', { relationId, accept: true }), 'invalid_argument');
      }
      assert.equal(w.store.transactions, 0);
    });

    it('a join request cannot be cancelled as an invite', async () => {
      const r = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      await refused(cancelInvite(w.deps, 's1', { relationId: r.after.id }), 'conflict');
    });
  });

  describe('requestToJoin / cancelJoinRequest', () => {
    it('requestToJoin counts a member action; the fourth is rate_limited', async () => {
      const r = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      assert.equal(r.after.status, 'requested');
      assert.equal(r.after.initiatedBy, 'member');
      assert.equal(r.after.expiresAt, IN_7_DAYS);
      tick();
      await cancelJoinRequest(w.deps, 'm1', { relationId: r.after.id });
      tick();
      await requestToJoin(w.deps, 'm1', { studioId: 's2' });
      tick();
      assert.deepEqual(w.store.quotas.get('m1'), { dayKey: '2026-10-10', studioActions: 0, memberActions: 3 });
      await refused(requestToJoin(w.deps, 'm1', { studioId: 's1' }), 'rate_limited');
    });

    it('requesting needs a studio and a joinable photographer', async () => {
      await refused(requestToJoin(w.deps, 'm1', { studioId: 'm2' }), 'invalid_argument');
      await refused(requestToJoin(w.deps, 's2', { studioId: 's1' }), 'invalid_argument');
      await refused(requestToJoin(w.deps, 'u1', { studioId: 's1' }), 'invalid_argument');
      await refused(requestToJoin(w.deps, 'm1', { studioId: 'ghost' }), 'not_found');
    });

    it('requesting while a member elsewhere or in cooldown is refused', async () => {
      await joinByInvite('s2', 'm1');
      tick();
      await refused(requestToJoin(w.deps, 'm1', { studioId: 's1' }), 'membership_conflict');
      patchProfile('m2', { studioCooldownUntil: '2026-10-11T00:00:00.000Z' });
      await refused(requestToJoin(w.deps, 'm2', { studioId: 's1' }), 'cooldown');
    });

    it('cancelJoinRequest only by its member and only while requested', async () => {
      const r = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      tick();
      await refused(cancelJoinRequest(w.deps, 'm2', { relationId: r.after.id }), 'permission_denied');
      const c = await cancelJoinRequest(w.deps, 'm1', { relationId: r.after.id });
      assert.equal(c.after.status, 'cancelled');
      assert.equal(c.after.endedBy, 'member');
      await refused(cancelJoinRequest(w.deps, 'm1', { relationId: r.after.id }), 'conflict');
    });
  });

  describe('respondInvite', () => {
    it('respondInvite accept makes the member active, sets studioId and memberCount', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      tick();
      const c = await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true });
      assert.equal(c.before?.status, 'invited');
      assert.equal(c.after.status, 'active');
      assert.equal(c.after.joinedAt, '2026-10-10T10:01:00.000Z');
      assert.equal(c.after.respondedAt, '2026-10-10T10:01:00.000Z');
      assert.equal(w.store.profiles.get('m1')?.studioId, 's1');
      assert.equal(w.store.studioJoinedAt.get('m1'), '2026-10-10T10:01:00.000Z');
      assert.equal(w.store.profiles.get('s1')?.memberCount, 1);
      // accepting is free of the member's daily quota
      assert.equal(w.store.quotas.get('m1'), undefined);
    });

    it('only the invited photographer answers, and only once', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      await refused(respondInvite(w.deps, 'm2', { relationId: inv.after.id, accept: true }), 'permission_denied');
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id }), 'invalid_argument');
      await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: false });
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }), 'conflict');
    });

    it('accepting after expiresAt records expired and answers deadline_passed', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      w.clock.setTime(new Date(IN_7_DAYS));
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }), 'deadline_passed');
      const rel = w.store.relations.get(inv.after.id);
      assert.equal(rel?.status, 'expired');
      assert.equal(rel?.endedBy, 'system');
      assert.equal(rel?.version, 2);
      assert.equal(w.store.profiles.get('m1')?.studioId, null);
      assert.equal(w.store.profiles.get('s1')?.memberCount, 0);
    });

    it('answering an invite the sweep already expired is deadline_passed', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      w.clock.setTime(new Date(IN_7_DAYS));
      assert.equal((await runMembershipSweeps(w.deps)).expired.length, 1);
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }), 'deadline_passed');
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: false }), 'deadline_passed');
      assert.equal(w.store.relations.get(inv.after.id)?.version, 2);
    });

    it('decline is free of quota', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      tick();
      const c = await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: false });
      assert.equal(c.after.status, 'declined');
      assert.equal(c.after.respondedAt, '2026-10-10T10:01:00.000Z');
      assert.equal(c.after.endedBy, 'member');
      assert.equal(w.store.quotas.get('m1'), undefined);
      assert.equal(w.store.quotas.get('s1')?.studioActions, 1);
      assert.equal(w.store.profiles.get('m1')?.studioId, null);
    });

    it('parallel accepts of two invites: one active, the other membership_conflict', async () => {
      const a = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      const b = await inviteMember(w.deps, 's2', { memberId: 'm1' });
      tick();
      const results = await Promise.allSettled([
        respondInvite(w.deps, 'm1', { relationId: a.after.id, accept: true }),
        respondInvite(w.deps, 'm1', { relationId: b.after.id, accept: true }),
      ]);
      const ok = results.filter((r) => r.status === 'fulfilled');
      const bad = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
      assert.equal(ok.length, 1);
      assert.equal(bad.length, 1);
      assert.ok(bad[0]?.reason instanceof DomainError && bad[0].reason.code === 'membership_conflict');
      const joined = w.store.profiles.get('m1')?.studioId;
      assert.ok(joined === 's1' || joined === 's2');
      const other = joined === 's1' ? 's2' : 's1';
      assert.equal(w.store.profiles.get(joined)?.memberCount, 1);
      assert.equal(w.store.profiles.get(other)?.memberCount, 0);
      const active = [...w.store.relations.values()].filter((r) => r.status === 'active');
      assert.deepEqual(active.map((r) => r.studioId), [joined]);
    });

    it('a studio approving while another studio\'s invite is accepted: one wins', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      const req = await requestToJoin(w.deps, 'm1', { studioId: 's2' });
      tick();
      const results = await Promise.allSettled([
        respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }),
        respondJoinRequest(w.deps, 's2', { relationId: req.after.id, accept: true }),
      ]);
      assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
      const memberCounts = (w.store.profiles.get('s1')?.memberCount ?? 0) + (w.store.profiles.get('s2')?.memberCount ?? 0);
      assert.equal(memberCounts, 1);
    });

    it('accepting into a studio already full is studio_full', async () => {
      // Seeded inconsistency: the studio filled up by other means since the invite.
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      patchProfile('s1', { memberCount: 3 });
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }), 'studio_full');
    });
  });

  describe('respondJoinRequest', () => {
    it('respondJoinRequest approve checks the cap and counts; decline is free', async () => {
      await joinByInvite('s1', 'm1');
      tick();
      await inviteMember(w.deps, 's1', { memberId: 'm2' });
      tick();
      const req3 = await requestToJoin(w.deps, 'm3', { studioId: 's1' });
      const req4 = await requestToJoin(w.deps, 'm4', { studioId: 's1' });
      tick();
      const ok = await respondJoinRequest(w.deps, 's1', { relationId: req3.after.id, accept: true });
      assert.equal(ok.after.status, 'active');
      assert.equal(w.store.profiles.get('m3')?.studioId, 's1');
      assert.equal(w.store.profiles.get('s1')?.memberCount, 2);
      assert.equal(w.store.quotas.get('s1')?.studioActions, 3); // invite, invite, approve
      // 2 members + 1 open invite = 3: full
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req4.after.id, accept: true }), 'studio_full');
      const no = await respondJoinRequest(w.deps, 's1', { relationId: req4.after.id, accept: false });
      assert.equal(no.after.status, 'declined');
      assert.equal(no.after.endedBy, 'studio');
      assert.equal(w.store.quotas.get('s1')?.studioActions, 3);
    });

    it('only its studio answers a request, and an expired one is deadline_passed', async () => {
      const req = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      await refused(respondJoinRequest(w.deps, 's2', { relationId: req.after.id, accept: true }), 'permission_denied');
      w.clock.setTime(new Date(IN_7_DAYS));
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: true }), 'deadline_passed');
      assert.equal(w.store.relations.get(req.after.id)?.status, 'expired');
    });

    it('answering a request the sweep already expired is deadline_passed', async () => {
      const req = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      w.clock.setTime(new Date(IN_7_DAYS));
      assert.equal((await runMembershipSweeps(w.deps)).expired.length, 1);
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: true }), 'deadline_passed');
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: false }), 'deadline_passed');
    });

    it('approving a photographer who joined elsewhere is membership_conflict', async () => {
      const req = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      tick();
      await joinByInvite('s2', 'm1');
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: true }), 'membership_conflict');
    });
  });

  describe('an active S27 collaborator of the same studio (Decision 12, S26 direction)', () => {
    it('inviteMember of an active collaborator of this studio is membership_conflict', async () => {
      w.store.seedActiveCollaboration('s1', 'm1');
      await refused(inviteMember(w.deps, 's1', { memberId: 'm1' }), 'membership_conflict');
      assert.equal(w.store.quotas.get('s1'), undefined);
    });

    it('requestToJoin by an active collaborator of that studio is membership_conflict', async () => {
      w.store.seedActiveCollaboration('s1', 'm1');
      await refused(requestToJoin(w.deps, 'm1', { studioId: 's1' }), 'membership_conflict');
    });

    it('S26 respondInvite refuses an active collaborator of this studio with membership_conflict', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      w.store.seedActiveCollaboration('s1', 'm1');
      tick();
      await refused(respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true }), 'membership_conflict');
      assert.equal(w.store.relations.get(inv.after.id)?.status, 'invited');
      // declining stays possible
      const no = await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: false });
      assert.equal(no.after.status, 'declined');
    });

    it('S26 respondJoinRequest refuses an active collaborator of this studio with membership_conflict', async () => {
      const req = await requestToJoin(w.deps, 'm1', { studioId: 's1' });
      w.store.seedActiveCollaboration('s1', 'm1');
      tick();
      await refused(respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: true }), 'membership_conflict');
      assert.equal(w.store.profiles.get('m1')?.studioId, null);
    });

    it('a collaborator of another studio may join this one (R6)', async () => {
      w.store.seedActiveCollaboration('s2', 'm1');
      const joined = await joinByInvite('s1', 'm1');
      assert.equal(joined.status, 'active');
    });
  });

  describe('leaveStudio / removeMember', () => {
    it('leave sets left, cooldown until +7 days, memberCount −1', async () => {
      await joinByInvite('s1', 'm1');
      w.clock.setTime(new Date('2026-10-12T08:00:00.000Z'));
      const c = await leaveStudio(w.deps, 'm1');
      assert.equal(c.before?.status, 'active');
      assert.equal(c.after.status, 'left');
      assert.equal(c.after.endedAt, '2026-10-12T08:00:00.000Z');
      assert.equal(c.after.endedBy, 'member');
      const m = w.store.profiles.get('m1');
      assert.equal(m?.studioId, null);
      assert.equal(w.store.studioJoinedAt.get('m1'), null);
      assert.equal(m?.studioCooldownUntil, '2026-10-19T08:00:00.000Z');
      assert.equal(w.store.profiles.get('s1')?.memberCount, 0);
      assert.equal(w.store.quotas.get('m1')?.memberActions, 1);
      // back in exactly 7 days, not before
      w.clock.setTime(new Date('2026-10-19T07:59:59.999Z'));
      await refused(requestToJoin(w.deps, 'm1', { studioId: 's1' }), 'cooldown');
      w.clock.setTime(new Date('2026-10-19T08:00:00.000Z'));
      assert.equal((await requestToJoin(w.deps, 'm1', { studioId: 's1' })).after.status, 'requested');
    });

    it('leave with an open studio booking is member_busy', async () => {
      await joinByInvite('s1', 'm1');
      w.store.setOpenAssignments('s1', 'm1', 1);
      await refused(leaveStudio(w.deps, 'm1'), 'member_busy');
      await refused(removeMember(w.deps, 's1', { memberId: 'm1' }), 'member_busy');
      assert.equal(w.store.profiles.get('m1')?.studioId, 's1');
      w.store.setOpenAssignments('s1', 'm1', 0);
      assert.equal((await leaveStudio(w.deps, 'm1')).after.status, 'left');
    });

    it('leave and remove are member_busy while the member is named on an open spot schedule with a day ahead (#194)', async () => {
      await joinByInvite('s1', 'm1');
      w.clock.setTime(new Date('2026-10-12T08:00:00.000Z')); // 15:00 VN on 2026-10-12
      w.store.addOpenSpotSchedule('s1', 'm1', ['2026-10-11', '2026-10-12']);
      await refused(leaveStudio(w.deps, 'm1'), 'member_busy');
      await refused(removeMember(w.deps, 's1', { memberId: 'm1' }), 'member_busy');
      // once its last day is past (or it is cancelled: no longer open), the member may go
      w.clock.setTime(new Date('2026-10-12T17:00:00.000Z')); // 00:00 VN on 2026-10-13
      assert.equal((await leaveStudio(w.deps, 'm1')).after.status, 'left');
    });

    it('leaving with no studio is not_found', async () => {
      await refused(leaveStudio(w.deps, 'm1'), 'not_found');
    });

    it('removeMember is the studio\'s, sets removed and notifies', async () => {
      await joinByInvite('s1', 'm1');
      tick();
      await refused(removeMember(w.deps, 's2', { memberId: 'm1' }), 'permission_denied');
      await refused(removeMember(w.deps, 's1', { memberId: 'ghost' }), 'not_found');
      const c = await removeMember(w.deps, 's1', { memberId: 'm1' });
      assert.equal(c.after.status, 'removed');
      assert.equal(c.after.endedBy, 'studio');
      assert.deepEqual(membershipNotices(c), ['removed']);
      assert.equal(w.store.profiles.get('m1')?.studioId, null);
      assert.equal(w.store.profiles.get('m1')?.studioCooldownUntil, '2026-10-17T10:02:00.000Z');
      assert.equal(w.store.profiles.get('s1')?.memberCount, 0);
      assert.equal(w.store.quotas.get('s1')?.studioActions, 2); // invite + remove
    });
  });

  describe('runMembershipSweeps', () => {
    it('runMembershipSweeps expires due relations once and lists invites expiring within 24 h without a notice yet', async () => {
      const early = await inviteMember(w.deps, 's1', { memberId: 'm1' }); // expires 17/10 10:00
      const req = await requestToJoin(w.deps, 'm2', { studioId: 's1' }); // expires 17/10 10:00
      w.clock.setTime(new Date('2026-10-11T09:00:00.000Z'));
      const late = await inviteMember(w.deps, 's1', { memberId: 'm3' }); // expires 18/10 09:00

      w.clock.setTime(new Date('2026-10-16T12:00:00.000Z'));
      const first = await runMembershipSweeps(w.deps);
      assert.deepEqual(first.expired, []);
      assert.deepEqual(first.expiring.map((r) => r.id), [early.after.id]); // requests get no expiring notice
      assert.equal(w.store.relations.get(early.after.id)?.expiringNotifiedAt, '2026-10-16T12:00:00.000Z');
      const opened = w.store.transactions;
      assert.deepEqual(await runMembershipSweeps(w.deps), { expired: [], expiring: [], notifyFailed: 0, failed: 0 });
      // the notified invite and the request that is not yet due open no transaction
      assert.equal(w.store.transactions, opened);

      w.clock.setTime(new Date(IN_7_DAYS));
      const second = await runMembershipSweeps(w.deps);
      assert.deepEqual(second.expired.map((c) => c.after.id).sort(), [early.after.id, req.after.id].sort());
      for (const c of second.expired) {
        assert.equal(c.after.status, 'expired');
        assert.equal(c.after.endedBy, 'system');
        assert.equal(c.after.endedAt, IN_7_DAYS);
      }
      assert.deepEqual(second.expiring.map((r) => r.id), [late.after.id]);
      const third = await runMembershipSweeps(w.deps);
      assert.deepEqual(third.expired, []);
      assert.deepEqual(third.expiring, []);
    });

    it('the expiring notice is sent before the mark: a failed notice is retried once and sent once', async () => {
      const n = createNotifyWorld(new Date('2026-10-16T12:00:00.000Z'));
      n.users.users.set('s1', { name: 'Studio Mây', avatarUrl: null });
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' }); // expires 17/10 10:00
      w.clock.setTime(new Date('2026-10-16T12:00:00.000Z'));
      let failures = 1;
      const flaky: NotifyDeps = {
        ...n.deps,
        users: {
          get: async (uid) => {
            if (failures > 0) {
              failures -= 1;
              throw new Error('directory down');
            }
            return n.users.get(uid);
          },
        },
      };
      const first = await runMembershipSweeps(w.deps, flaky);
      assert.deepEqual({ expiring: first.expiring, notifyFailed: first.notifyFailed }, { expiring: [], notifyFailed: 1 });
      assert.equal(w.store.relations.get(inv.after.id)?.expiringNotifiedAt, null, 'not marked: retried next run');

      w.clock.setTime(new Date('2026-10-16T12:15:00.000Z'));
      const second = await runMembershipSweeps(w.deps, flaky);
      assert.deepEqual(second.expiring.map((r) => r.id), [inv.after.id]);
      assert.equal(second.notifyFailed, 0);
      const third = await runMembershipSweeps(w.deps, flaky);
      assert.deepEqual(third, { expired: [], expiring: [], notifyFailed: 0, failed: 0 });
      assert.deepEqual(
        n.store.rowsOf('m1').map((r) => r.type),
        ['studio_invite_expiring'],
      );
    });

    it('a relation whose transaction fails is counted and never stops the batch', async () => {
      const a = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      const b = await inviteMember(w.deps, 's1', { memberId: 'm2' });
      w.clock.setTime(new Date(IN_7_DAYS));
      const original = w.store.runTransaction.bind(w.store);
      let calls = 0;
      w.store.runTransaction = (async (fn: Parameters<typeof original>[0]) => {
        calls += 1;
        if (calls === 1) throw new Error('store down');
        return original(fn);
      }) as typeof w.store.runTransaction;
      const r = await runMembershipSweeps(w.deps);
      assert.equal(r.failed, 1);
      assert.equal(r.expired.length, 1);
      w.store.runTransaction = original;
      const again = await runMembershipSweeps(w.deps);
      assert.deepEqual({ failed: again.failed, expired: again.expired.length }, { failed: 0, expired: 1 });
      assert.equal(w.store.relations.get(a.after.id)?.status, 'expired');
      assert.equal(w.store.relations.get(b.after.id)?.status, 'expired');
    });

    it('a sweep does not touch an answered relation', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true });
      w.clock.setTime(new Date(IN_7_DAYS));
      const r = await runMembershipSweeps(w.deps);
      assert.deepEqual(r, { expired: [], expiring: [], notifyFailed: 0, failed: 0 });
      assert.equal(w.store.relations.get(inv.after.id)?.status, 'active');
    });
  });

  describe('membershipNotices', () => {
    it('membershipNotices sends the right type to the right party', async () => {
      const inv = await inviteMember(w.deps, 's1', { memberId: 'm1' });
      assert.deepEqual(membershipNotices(inv), ['invite']); // → member
      const req = await requestToJoin(w.deps, 'm2', { studioId: 's1' });
      assert.deepEqual(membershipNotices(req), ['join_request']); // → studio
      tick();
      const acc = await respondInvite(w.deps, 'm1', { relationId: inv.after.id, accept: true });
      assert.deepEqual(membershipNotices(acc), ['invite_accepted']); // → studio
      const appr = await respondJoinRequest(w.deps, 's1', { relationId: req.after.id, accept: true });
      assert.deepEqual(membershipNotices(appr), ['join_approved']); // → member
      tick();
      const rem = await removeMember(w.deps, 's1', { memberId: 'm2' });
      assert.deepEqual(membershipNotices(rem), ['removed']); // → member

      // silent changes
      tick();
      assert.deepEqual(membershipNotices(await leaveStudio(w.deps, 'm1')), []);
      tick();
      const inv2 = await inviteMember(w.deps, 's1', { memberId: 'm3' });
      tick();
      assert.deepEqual(membershipNotices(await respondInvite(w.deps, 'm3', { relationId: inv2.after.id, accept: false })), []);
      tick();
      const inv3 = await inviteMember(w.deps, 's2', { memberId: 'm4' });
      tick();
      assert.deepEqual(membershipNotices(await cancelInvite(w.deps, 's2', { relationId: inv3.after.id })), []);
    });
  });
});
