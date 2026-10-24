import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  cancelCollabInvite,
  endCollaboration,
  expireCollabInvite,
  inviteCollaborator,
  respondCollabInvite,
  setCollabDefaultFee,
} from '../src/collab_use_cases.js';
import { newCollabJob, type CollabJob } from '../src/collab_jobs.js';
import { DomainError } from '../src/errors.js';
import { applyToRecruitPost, respondRecruitApplication } from '../src/recruit_use_cases.js';
import { createRecruitWorld, openPost, seedCollaboration, type RecruitWorld } from './support/recruit_world.js';

const DAY_MS = 24 * 60 * 60 * 1000;

async function refusal(p: Promise<unknown>): Promise<{ code: string; field: string | undefined }> {
  try {
    await p;
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return { code: e.code, field: e.field };
  }
  assert.fail('expected a DomainError');
}

const code = async (p: Promise<unknown>): Promise<string> => (await refusal(p)).code;

const invite = (w: RecruitWorld, studioId: string, collaboratorId: string, over: Record<string, unknown> = {}) =>
  inviteCollaborator(w.deps, studioId, { collaboratorId, ...over });

const respond = (w: RecruitWorld, uid: string, studioId: string, accept: boolean, acceptTerms = true) =>
  respondCollabInvite(w.deps, uid, { studioId, accept, acceptTerms });

const counters = (w: RecruitWorld, uid: string) => w.store.countersOf(uid);
const collab = (w: RecruitWorld, studioId: string, uid: string) => w.store.collaborations.get(`${studioId}_${uid}`);
const rowsOfType = (w: RecruitWorld, uid: string, type: string) => w.rowsOf(uid).filter((r) => r.type === type);

/** A collab job of s1 and p1 on booking b1 (pending unless `over` says otherwise). */
function collabJob(w: RecruitWorld, over: Partial<CollabJob> = {}): CollabJob {
  const now = w.clock.now();
  const job = newCollabJob({
    booking: {
      id: 'b1', photographerId: 's1', customerId: 'c1', day: '2026-10-15', start: '14:00', end: '16:00',
      serviceSnapshot: { name: 'Gói Studio', price: 1_000_000, durationMinutes: 120 }, place: { name: 'Nhà thờ Lớn' },
    },
    collaboratorId: 'p1',
    studioName: 'Studio Mây',
    collaboratorName: 'Minh Trí',
    shootEndsAt: new Date('2026-10-15T09:00:00.000Z'),
    agreedFee: 800_000,
    offerExpiresAt: new Date(now.getTime() + 6 * 60 * 60 * 1000),
    now,
  });
  return { ...job, ...over };
}

describe('inviteCollaborator', () => {
  it('a verified studio invites a verified individual: status invited, expiresAt +7 d, pendingInviteCount 1, one studio action, collab_invite sent', async () => {
    const w = createRecruitWorld();
    const now = w.clock.now();
    await invite(w, 's1', 'p1', { defaultFee: 500_000 });
    const c = collab(w, 's1', 'p1');
    assert.ok(c);
    assert.equal(c.id, 's1_p1');
    assert.equal(c.status, 'invited');
    assert.equal(c.initiatedBy, 'studio');
    assert.equal(c.applicationId, null);
    assert.equal(c.defaultFee, 500_000);
    assert.deepEqual(c.studio, { name: 'Studio Mây', avatarUrl: 'https://img/s1.jpg' });
    assert.deepEqual(c.collaborator, { name: 'Minh Trí', avatarUrl: null });
    assert.deepEqual(c.createdAt, now);
    assert.equal(c.expiresAt.getTime(), now.getTime() + 7 * DAY_MS);
    assert.equal(c.activeAt, null);
    assert.equal(c.termsAcceptedAt, null);
    assert.equal(counters(w, 's1').pendingInviteCount, 1);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });
    const rows = rowsOfType(w, 'p1', 'collab_invite');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.target, '/collab');
  });

  it('an artist can be invited', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'a1');
    assert.equal(collab(w, 's1', 'a1')?.status, 'invited');
  });

  it('a studio cannot be invited (invalid_argument)', async () => {
    const w = createRecruitWorld();
    assert.equal(await code(invite(w, 's1', 's2')), 'invalid_argument');
    assert.equal(await code(invite(w, 's1', 'c1')), 'invalid_argument', 'a customer either');
    assert.equal(await code(invite(w, 'p2', 'p1')), 'invalid_argument', 'only a studio invites');
    assert.equal(await code(invite(w, 's1', 's1')), 'invalid_argument');
    assert.equal(w.store.collaborations.size, 0);
  });

  it('an unverified collaborator or studio gets not_accepting_orders', async () => {
    const w = createRecruitWorld();
    assert.equal(await code(invite(w, 's1', 'u1')), 'not_accepting_orders');
    assert.equal(await code(invite(w, 's3', 'p1')), 'not_accepting_orders');
    assert.equal(w.store.collaborations.size, 0);
  });

  it('a member of this studio gets membership_conflict', async () => {
    const w = createRecruitWorld();
    w.store.seedMembership('p1', 's1');
    assert.equal(await code(invite(w, 's1', 'p1')), 'membership_conflict');
  });

  it('a member of another studio can be invited', async () => {
    const w = createRecruitWorld();
    w.store.seedMembership('p1', 's2');
    await invite(w, 's1', 'p1');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
  });

  it('either side blocking the other gets blocked', async () => {
    const w = createRecruitWorld();
    w.blocks.block('p1', 's1');
    assert.equal(await code(invite(w, 's1', 'p1')), 'blocked');
  });

  it('the sixth pending invite gets collab_full', async () => {
    const w = createRecruitWorld();
    for (const uid of ['p1', 'p2', 'p3', 'p4', 'a1']) await invite(w, 's1', uid);
    w.people.set('p5', { ...(w.people.get('p1') ?? assert.fail()), uid: 'p5', name: 'Thu Hà' });
    assert.equal(await code(invite(w, 's1', 'p5')), 'collab_full');
    assert.equal(counters(w, 's1').pendingInviteCount, 5);
  });

  it('invited or active already → conflict', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    assert.equal(await code(invite(w, 's1', 'p1')), 'conflict');
    seedCollaboration(w, 's1', 'p2');
    assert.equal(await code(invite(w, 's1', 'p2')), 'conflict');
    assert.equal(counters(w, 's1').pendingInviteCount, 1);
  });

  it('re-invite within 3 days of ended → cooldown; at exactly 3 days → ok', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1', { status: 'ended', endedAt: w.clock.now(), endedBy: 'collaborator' });
    assert.equal(await code(invite(w, 's1', 'p1')), 'cooldown');
    w.clock.advanceHours(72);
    w.clock.advanceMinutes(-1);
    assert.equal(await code(invite(w, 's1', 'p1')), 'cooldown');
    w.clock.advanceMinutes(1);
    await invite(w, 's1', 'p1');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
  });

  it('a declined invite has no cooldown', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1', { status: 'declined', endedAt: w.clock.now(), endedBy: 'collaborator' });
    await invite(w, 's1', 'p1');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
  });

  it('re-invite archives the old record to history and overwrites the main one', async () => {
    const w = createRecruitWorld();
    const old = seedCollaboration(w, 's1', 'p1', {
      status: 'ended',
      endedAt: new Date(w.clock.now().getTime() - 10 * DAY_MS),
      endedBy: 'studio',
      createdAt: new Date(w.clock.now().getTime() - 40 * DAY_MS),
      defaultFee: 700_000,
    });
    await invite(w, 's1', 'p1');
    const history = w.store.collabHistory.get('s1_p1');
    assert.equal(history?.length, 1);
    assert.deepEqual(history?.[0]?.collaboration, old);
    assert.ok(history?.[0]?.historyId);
    const main = collab(w, 's1', 'p1');
    assert.equal(main?.status, 'invited');
    assert.deepEqual(main?.createdAt, w.clock.now());
    assert.equal(main?.endedAt, null);
    assert.equal(main?.defaultFee, null);
  });

  it('an invite past expiresAt that the sweep has not reached is expired and replaced', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.clock.advanceHours(7 * 24);
    await invite(w, 's1', 'p1');
    assert.equal(w.store.collabHistory.get('s1_p1')?.[0]?.collaboration.status, 'expired');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
    assert.equal(counters(w, 's1').pendingInviteCount, 1, 'the stale invite freed its slot');
  });

  it('the eleventh studio action of the VN day gets rate_limited', async () => {
    const w = createRecruitWorld();
    w.store.seedCounters('s1', { collabActions: { day: '2026-10-10', count: 10 } });
    assert.equal(await code(invite(w, 's1', 'p1')), 'rate_limited');
    w.clock.advanceHours(7); // VN midnight
    await invite(w, 's1', 'p1');
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-11', count: 1 });
  });

  it('a blocked studio gets recruit_blocked', async () => {
    const w = createRecruitWorld();
    w.store.seedCounters('s1', { recruitBlockedUntil: new Date(w.clock.now().getTime() + DAY_MS) });
    assert.equal(await code(invite(w, 's1', 'p1')), 'recruit_blocked');
  });

  it('defaultFee must be 1.000–100.000.000 and a multiple of 1.000', async () => {
    const w = createRecruitWorld();
    for (const defaultFee of [0, 999, 1_500, 100_001_000, 800_000.5, '800000']) {
      assert.deepEqual(await refusal(invite(w, 's1', 'p1', { defaultFee })), { code: 'invalid_argument', field: 'defaultFee' },
        String(defaultFee));
    }
    await invite(w, 's1', 'p1', { defaultFee: 1_000 });
    await invite(w, 's1', 'p2', { defaultFee: 100_000_000 });
    await invite(w, 's1', 'p3', { defaultFee: null });
    assert.equal(collab(w, 's1', 'p3')?.defaultFee, null);
  });
});

describe('cancelCollabInvite', () => {
  it('cancel an invite: cancelled, pending slot freed, one action', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.clock.advanceMinutes(5);
    await cancelCollabInvite(w.deps, 's1', { collaboratorId: 'p1' });
    const c = collab(w, 's1', 'p1');
    assert.equal(c?.status, 'cancelled');
    assert.deepEqual(c?.endedAt, w.clock.now());
    assert.equal(c?.endedBy, 'studio');
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    assert.equal(counters(w, 's1').collabActions?.count, 2);
    assert.equal(await code(cancelCollabInvite(w.deps, 's1', { collaboratorId: 'p1' })), 'not_found');
    assert.equal(await code(cancelCollabInvite(w.deps, 's1', { collaboratorId: 'p2' })), 'not_found');
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
  });
});

describe('respondCollabInvite', () => {
  it('accept without acceptTerms → invalid_argument', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    assert.deepEqual(await refusal(respond(w, 'p1', 's1', true, false)), { code: 'invalid_argument', field: 'acceptTerms' });
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
  });

  it('accept: active, activeAt, termsAcceptedAt, counters (studio activeCollabCount +1, pendingInviteCount −1, collaborator activeCollabCount +1), collab_invite_result accepted', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1', { defaultFee: 600_000 });
    const invitedAt = w.clock.now();
    w.clock.advanceHours(2);
    const r = await respond(w, 'p1', 's1', true);
    assert.deepEqual(r, { status: 'active' });
    const c = collab(w, 's1', 'p1');
    assert.equal(c?.status, 'active');
    assert.deepEqual(c?.activeAt, w.clock.now());
    assert.deepEqual(c?.termsAcceptedAt, w.clock.now());
    assert.deepEqual(c?.createdAt, invitedAt, 'the invite record is kept');
    assert.equal(c?.defaultFee, 600_000);
    assert.equal(c?.initiatedBy, 'studio');
    assert.equal(w.store.collabHistory.get('s1_p1'), undefined, 'an answered invite is not archived');
    assert.equal(counters(w, 's1').activeCollabCount, 1);
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    assert.equal(counters(w, 'p1').activeCollabCount, 1);
    const rows = rowsOfType(w, 's1', 'collab_invite_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.body, 'Minh Trí đã nhận lời cộng tác.');
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'not_found', 'nothing left to answer');
  });

  it('accept when the studio already has 5 (or 50) active → collab_full', async () => {
    const w = createRecruitWorld();
    await invite(w, 's2', 'p1'); // s2: business not verified
    w.store.seedCounters('s2', { activeCollabCount: 5 });
    assert.equal(await code(respond(w, 'p1', 's2', true)), 'collab_full');
    await invite(w, 's1', 'p2'); // s1: business verified
    w.store.seedCounters('s1', { activeCollabCount: 5 });
    await respond(w, 'p2', 's1', true);
    assert.equal(counters(w, 's1').activeCollabCount, 6);
    await invite(w, 's1', 'p3');
    w.store.seedCounters('s1', { activeCollabCount: 50 });
    assert.equal(await code(respond(w, 'p3', 's1', true)), 'collab_full');
    assert.equal(collab(w, 's1', 'p3')?.status, 'invited');
  });

  it('accept when the collaborator has 5 active → collab_full', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.store.seedCounters('p1', { activeCollabCount: 5 });
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'collab_full');
  });

  it('accept by a photographer who became a member of the studio meanwhile → membership_conflict', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.store.seedMembership('p1', 's1');
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'membership_conflict');
  });

  it('accept after expiresAt → deadline_passed', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.clock.advanceHours(7 * 24);
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'deadline_passed');
    assert.equal(collab(w, 's1', 'p1')?.status, 'expired');
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    assert.equal(counters(w, 'p1').activeCollabCount, 0);
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'deadline_passed');
  });

  it('decline: declined, pending slot freed, result declined', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    const r = await respond(w, 'p1', 's1', false, false);
    assert.deepEqual(r, { status: 'declined' });
    const c = collab(w, 's1', 'p1');
    assert.equal(c?.status, 'declined');
    assert.deepEqual(c?.endedAt, w.clock.now());
    assert.equal(c?.endedBy, 'collaborator');
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    assert.equal(counters(w, 's1').activeCollabCount, 0);
    const rows = rowsOfType(w, 's1', 'collab_invite_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.body, 'Minh Trí đã từ chối lời mời cộng tác.');
  });

  it('responding does not count as an action', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    await invite(w, 's1', 'p2');
    w.store.seedCounters('p1', { collabActions: { day: '2026-10-10', count: 5 } });
    await respond(w, 'p1', 's1', true);
    await respond(w, 'p2', 's1', false);
    assert.deepEqual(counters(w, 'p1').collabActions, { day: '2026-10-10', count: 5 });
    assert.equal(counters(w, 'p2').collabActions, null);
    assert.equal(counters(w, 's1').collabActions?.count, 2);
  });

  it('an unverified side or a block refuses the accept', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    w.blocks.block('s1', 'p1');
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'blocked');
    w.blocks.unblock('s1', 'p1');
    w.people.set('p1', { ...(w.people.get('p1') ?? assert.fail()), acceptsOrders: false });
    assert.equal(await code(respond(w, 'p1', 's1', true)), 'not_accepting_orders');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
  });
});

describe('endCollaboration', () => {
  it('either side ends an active collaboration: ended, endedAt, endedBy, counters −1 on both sides', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1');
    seedCollaboration(w, 's1', 'p2');
    w.store.seedCounters('s1', { activeCollabCount: 2 });
    w.store.seedCounters('p1', { activeCollabCount: 1 });
    w.store.seedCounters('p2', { activeCollabCount: 3 });
    w.clock.advanceHours(1);

    const byCollaborator = await endCollaboration(w.deps, 'p1', { studioId: 's1' });
    assert.deepEqual(byCollaborator, { chatId: 'collab_s1_p1' });
    assert.equal(collab(w, 's1', 'p1')?.status, 'ended');
    assert.deepEqual(collab(w, 's1', 'p1')?.endedAt, w.clock.now());
    assert.equal(collab(w, 's1', 'p1')?.endedBy, 'collaborator');
    assert.deepEqual(counters(w, 'p1').collabActions, { day: '2026-10-10', count: 1 });

    const byStudio = await endCollaboration(w.deps, 's1', { collaboratorId: 'p2' });
    assert.deepEqual(byStudio, { chatId: 'collab_s1_p2' });
    assert.equal(collab(w, 's1', 'p2')?.endedBy, 'studio');
    assert.equal(counters(w, 's1').activeCollabCount, 0);
    assert.equal(counters(w, 'p1').activeCollabCount, 0);
    assert.equal(counters(w, 'p2').activeCollabCount, 2);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });

    assert.equal(await code(endCollaboration(w.deps, 'p1', { studioId: 's1' })), 'not_found');
    assert.equal(await code(endCollaboration(w.deps, 's1', { collaboratorId: 'p3' })), 'not_found');
    assert.equal(await code(endCollaboration(w.deps, 's1', {})), 'invalid_argument');
    assert.equal(counters(w, 's1').activeCollabCount, 0);
  });

  it('end with an open job → member_busy', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1');
    w.store.seedCollabJob(collabJob(w, { offerStatus: 'pending' }));
    assert.equal(await code(endCollaboration(w.deps, 's1', { collaboratorId: 'p1' })), 'member_busy');
    assert.equal(await code(endCollaboration(w.deps, 'p1', { studioId: 's1' })), 'member_busy');
    assert.equal(collab(w, 's1', 'p1')?.status, 'active');
  });

  it('open jobs are computed from the collab jobs: live and not closed, or a disputed pay record ("đang khiếu nại")', async () => {
    const cases: Array<[string, Partial<CollabJob>, number]> = [
      ['pending offer', { offerStatus: 'pending' }, 1],
      ['accepted, booking not finished', { offerStatus: 'accepted' }, 1],
      ['accepted, booking completed', { offerStatus: 'accepted', closedAt: new Date() }, 0],
      ['accepted, completed, pay due', { offerStatus: 'accepted', closedAt: new Date(), payStatus: 'due' }, 0],
      ['accepted, completed, pay disputed', { offerStatus: 'accepted', closedAt: new Date(), payStatus: 'disputed' }, 1],
      ['declined', { offerStatus: 'declined' }, 0],
      ['replaced', { offerStatus: 'replaced' }, 0],
      ['returned', { offerStatus: 'returned' }, 0],
      ['cancelled with the booking', { offerStatus: 'cancelled', closedAt: new Date() }, 0],
    ];
    for (const [name, over, n] of cases) {
      const w = createRecruitWorld();
      seedCollaboration(w, 's1', 'p1');
      w.store.seedCollabJob(collabJob(w, over));
      w.store.seedCollabJob(collabJob(w, { id: 'b9_p2', bookingId: 'b9', collaboratorId: 'p2' }));
      assert.equal(await w.store.openJobCount('s1', 'p1'), n, name);
      if (n === 0) await endCollaboration(w.deps, 's1', { collaboratorId: 'p1' });
      else assert.equal(await code(endCollaboration(w.deps, 'p1', { studioId: 's1' })), 'member_busy', name);
    }
  });

  it('the sixth end of the day by a collaborator → rate_limited', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1');
    w.store.seedCounters('p1', { activeCollabCount: 1, collabActions: { day: '2026-10-10', count: 5 } });
    assert.equal(await code(endCollaboration(w.deps, 'p1', { studioId: 's1' })), 'rate_limited');
    assert.equal(collab(w, 's1', 'p1')?.status, 'active');
  });
});

describe('expireCollabInvite and setCollabDefaultFee', () => {
  it('expiring an invite frees a pending slot', async () => {
    const w = createRecruitWorld();
    await invite(w, 's1', 'p1');
    assert.equal(await expireCollabInvite(w.deps, 's1', 'p1'), false, 'not due yet');
    w.clock.advanceHours(7 * 24);
    assert.deepEqual((await w.store.dueInvites(w.clock.now(), 10)).map((c) => c.id), ['s1_p1']);
    assert.equal(await expireCollabInvite(w.deps, 's1', 'p1'), true);
    assert.equal(await expireCollabInvite(w.deps, 's1', 'p1'), false);
    assert.equal(collab(w, 's1', 'p1')?.status, 'expired');
    assert.equal(collab(w, 's1', 'p1')?.endedBy, 'system');
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    const rows = rowsOfType(w, 's1', 'collab_invite_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.body, 'Lời mời cộng tác gửi Minh Trí đã hết hạn.');
  });

  it('the studio sets or clears the default fee of an invited or active collaborator', async () => {
    const w = createRecruitWorld();
    seedCollaboration(w, 's1', 'p1');
    await setCollabDefaultFee(w.deps, 's1', { collaboratorId: 'p1', defaultFee: 900_000 });
    assert.equal(collab(w, 's1', 'p1')?.defaultFee, 900_000);
    await setCollabDefaultFee(w.deps, 's1', { collaboratorId: 'p1', defaultFee: null });
    assert.equal(collab(w, 's1', 'p1')?.defaultFee, null);
    assert.deepEqual(await refusal(setCollabDefaultFee(w.deps, 's1', { collaboratorId: 'p1', defaultFee: 1_500 })),
      { code: 'invalid_argument', field: 'defaultFee' });
    assert.equal(await code(setCollabDefaultFee(w.deps, 's1', { collaboratorId: 'p2', defaultFee: 900_000 })), 'not_found');
    assert.equal(await code(setCollabDefaultFee(w.deps, 's2', { collaboratorId: 'p1', defaultFee: 900_000 })), 'not_found');
    assert.equal(counters(w, 's1').collabActions, null, 'not a counted action');
  });
});

describe('limits under concurrency', () => {
  it('the sixth active collaboration of a collaborator is refused (collab_full) even when two studios accept in parallel', async () => {
    const w = createRecruitWorld();
    const a = await openPost(w, 's1');
    const b = await openPost(w, 's2');
    for (const postId of [a, b]) {
      await applyToRecruitPost(w.deps, 'p1', { postId, message: '', samplePostIds: [], acceptTerms: true });
    }
    w.store.seedCounters('p1', { activeCollabCount: 4 });
    const results = await Promise.allSettled([
      respondRecruitApplication(w.deps, 's1', { postId: a, applicantId: 'p1', accept: true }),
      respondRecruitApplication(w.deps, 's2', { postId: b, applicantId: 'p1', accept: true }),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'collab_full');
    assert.equal(counters(w, 'p1').activeCollabCount, 5);
    assert.equal([...w.store.collaborations.values()].filter((c) => c.status === 'active').length, 1);
    assert.ok(w.store.retries > 0);
  });

  it('two concurrent invites of the same pair make one record (the other gets conflict)', async () => {
    const w = createRecruitWorld();
    const results = await Promise.allSettled([invite(w, 's1', 'p1'), invite(w, 's1', 'p1', { defaultFee: 500_000 })]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'conflict');
    assert.equal(collab(w, 's1', 'p1')?.status, 'invited');
    assert.equal(w.store.collabHistory.get('s1_p1'), undefined);
    assert.equal(counters(w, 's1').pendingInviteCount, 1);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });
    assert.equal(rowsOfType(w, 'p1', 'collab_invite').length, 1);
    assert.ok(w.store.retries > 0);
  });

  it('two collaborators accepting in parallel at the studio limit 5: one becomes active, the other gets collab_full', async () => {
    const w = createRecruitWorld();
    // s2 is not business-verified: 5 collaborators at most; 4 are active.
    for (const uid of ['p1', 'p2']) seedCollaboration(w, 's2', uid, { status: 'invited', activeAt: null, termsAcceptedAt: null });
    w.store.seedCounters('s2', { activeCollabCount: 4, pendingInviteCount: 2 });
    const results = await Promise.allSettled([respond(w, 'p1', 's2', true), respond(w, 'p2', 's2', true)]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'collab_full');
    assert.equal(counters(w, 's2').activeCollabCount, 5);
    assert.equal(counters(w, 's2').pendingInviteCount, 1, 'the refused invite still waits');
    assert.equal(['p1', 'p2'].filter((uid) => collab(w, 's2', uid)?.status === 'active').length, 1);
    assert.ok(w.store.retries > 0);
  });

  it('a member-kind accept racing a collaborator accept of the same pair: one wins, the other gets membership_conflict', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    await applyToRecruitPost(w.deps, 'p1', { postId, message: '', samplePostIds: [], acceptTerms: false });
    seedCollaboration(w, 's1', 'p1', { status: 'invited', activeAt: null, termsAcceptedAt: null });
    w.store.seedCounters('s1', { pendingInviteCount: 1 });
    // Both transactions start before either commits (the accept does more reads before its transaction).
    let entered = 0;
    let release: () => void = () => {};
    const bothIn = new Promise<void>((resolve) => { release = resolve; });
    const original = w.store.runTransaction.bind(w.store);
    w.store.runTransaction = <T>(fn: Parameters<typeof original<T>>[0]) => original<T>(async (tx) => {
      entered += 1;
      if (entered === 2) release();
      await bothIn;
      return fn(tx);
    });
    const results = await Promise.allSettled([
      respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: true }),
      respond(w, 'p1', 's1', true),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'membership_conflict');
    const member = w.store.memberships.get('p1') === 's1';
    const collaborator = collab(w, 's1', 'p1')?.status === 'active';
    assert.ok(member !== collaborator, 'exactly one relationship');
    assert.ok(w.store.retries > 0);
  });
});
