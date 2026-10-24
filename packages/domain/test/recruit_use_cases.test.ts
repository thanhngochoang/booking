import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { RetryableConflict } from '../src/event_ports.js';
import { recruitFilterKeys } from '../src/recruit.js';
import {
  applyToRecruitPost,
  closeRecruitPost,
  createRecruitPost,
  expireRecruitApplication,
  expireRecruitPost,
  renewRecruitPost,
  respondRecruitApplication,
  updateRecruitPost,
  withdrawRecruitApplication,
} from '../src/recruit_use_cases.js';
import { createRecruitWorld, openPost, seedCollaboration, VALID_POST, type RecruitWorld } from './support/recruit_world.js';

const DAY_MS = 24 * 60 * 60 * 1000;

async function code(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return e.code;
  }
  assert.fail('expected a DomainError');
}

const apply = (w: RecruitWorld, uid: string, postId: string, over: Record<string, unknown> = {}) =>
  applyToRecruitPost(w.deps, uid, { postId, message: 'Em đã chụp cưới 3 năm.', samplePostIds: [], acceptTerms: true, ...over });

const counters = (w: RecruitWorld, uid: string) => w.store.countersOf(uid);

describe('createRecruitPost', () => {
  it('a verified studio creates an open post with expiresAt +30 d, counters 1 open and 1 action', async () => {
    const w = createRecruitWorld();
    const now = w.clock.now();
    const { postId } = await createRecruitPost(w.deps, 's1', VALID_POST);
    const post = w.store.posts.get(postId);
    assert.ok(post);
    assert.equal(post.status, 'open');
    assert.equal(post.studioId, 's1');
    assert.equal(post.renewed, false);
    assert.equal(post.applicationCount, 0);
    assert.equal(post.closedAt, null);
    assert.deepEqual(post.createdAt, now);
    assert.equal(post.expiresAt.getTime(), now.getTime() + 30 * DAY_MS);
    const c = counters(w, 's1');
    assert.equal(c.openPostCount, 1);
    assert.deepEqual(c.postActions, { day: '2026-10-10', count: 1 });
  });

  it('an unverified studio gets not_accepting_orders', async () => {
    const w = createRecruitWorld();
    assert.equal(await code(createRecruitPost(w.deps, 's3', VALID_POST)), 'not_accepting_orders');
  });

  it('an individual photographer gets invalid_argument', async () => {
    const w = createRecruitWorld();
    assert.equal(await code(createRecruitPost(w.deps, 'p1', VALID_POST)), 'invalid_argument');
    assert.equal(await code(createRecruitPost(w.deps, 'a1', VALID_POST)), 'invalid_argument');
    assert.equal(await code(createRecruitPost(w.deps, 'c1', VALID_POST)), 'invalid_argument');
    assert.equal(w.store.posts.size, 0);
  });

  it('the fourth open post gets limit_exceeded', async () => {
    const w = createRecruitWorld();
    for (let i = 0; i < 3; i++) await openPost(w, 's1');
    assert.equal(await code(createRecruitPost(w.deps, 's1', VALID_POST)), 'limit_exceeded');
    assert.equal(counters(w, 's1').openPostCount, 3);
  });

  it('the sixth create or close of the VN day gets rate_limited', async () => {
    const w = createRecruitWorld();
    const a = await openPost(w, 's1');
    const b = await openPost(w, 's1');
    await closeRecruitPost(w.deps, 's1', { postId: a });
    await closeRecruitPost(w.deps, 's1', { postId: b });
    await openPost(w, 's1'); // 5th action
    assert.equal(await code(createRecruitPost(w.deps, 's1', VALID_POST)), 'rate_limited');
    w.clock.advanceHours(7); // 17:00Z = VN midnight
    await openPost(w, 's1');
    assert.deepEqual(counters(w, 's1').postActions, { day: '2026-10-11', count: 1 });
  });

  it('a blocked studio gets recruit_blocked', async () => {
    const w = createRecruitWorld();
    w.store.seedCounters('s1', { recruitBlockedUntil: new Date(w.clock.now().getTime() + DAY_MS) });
    assert.equal(await code(createRecruitPost(w.deps, 's1', VALID_POST)), 'recruit_blocked');
    w.clock.advanceHours(25);
    await openPost(w, 's1');
  });

  it('the post carries the studio snapshot, matchKeys and filterKeys', async () => {
    const w = createRecruitWorld();
    const post = w.store.posts.get(await openPost(w, 's1'));
    assert.ok(post);
    assert.deepEqual(post.studio, { name: 'Studio Mây', avatarUrl: 'https://img/s1.jpg', businessVerified: true });
    assert.deepEqual(post.matchKeys, ['a=hcm-q1|s=wedding', 'a=hcm-q1|s=family', 'a=hcm-q3|s=wedding', 'a=hcm-q3|s=family']);
    assert.deepEqual(post.filterKeys, recruitFilterKeys({ kind: 'collaborator', areas: ['hcm-q1', 'hcm-q3'], specialties: ['wedding', 'family'] }));
    assert.equal(post.title, VALID_POST.title);
    assert.deepEqual(post.feeHint, { type: 'per_shoot', amount: 800_000 });
  });
});

describe('updateRecruitPost, renewRecruitPost, closeRecruitPost', () => {
  it('update only by the owner (permission_denied) and only while open (deadline_passed)', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(updateRecruitPost(w.deps, 's2', { ...VALID_POST, postId })), 'permission_denied');
    await updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId, title: 'Tuyển CTV chụp kỷ yếu', areas: ['hue'] });
    const post = w.store.posts.get(postId);
    assert.equal(post?.title, 'Tuyển CTV chụp kỷ yếu');
    assert.deepEqual(post?.matchKeys, ['a=hue|s=wedding', 'a=hue|s=family']);
    assert.ok(post?.filterKeys.includes('k=collaborator|a=hue|s=family'));
    assert.equal(await code(updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId: 'missing' })), 'not_found');
    await closeRecruitPost(w.deps, 's1', { postId });
    assert.equal(await code(updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId })), 'deadline_passed');
    const other = await openPost(w, 's1');
    w.clock.advanceHours(31 * 24);
    assert.equal(await code(updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId: other })), 'deadline_passed');
  });

  it('kind cannot change (invalid_argument)', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId, kind: 'member' })), 'invalid_argument');
    await updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId, kind: undefined });
    assert.equal(w.store.posts.get(postId)?.kind, 'collaborator');
  });

  it('renew once adds 30 days, a second renew is conflict, an expired post cannot be renewed', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    const before = w.store.posts.get(postId)?.expiresAt.getTime() ?? 0;
    assert.equal(await code(renewRecruitPost(w.deps, 's2', { postId })), 'permission_denied');
    const { expiresAt } = await renewRecruitPost(w.deps, 's1', { postId });
    assert.equal(expiresAt.getTime(), before + 30 * DAY_MS);
    assert.equal(w.store.posts.get(postId)?.renewed, true);
    assert.equal(await code(renewRecruitPost(w.deps, 's1', { postId })), 'conflict');
    const late = await openPost(w, 's1');
    w.clock.advanceHours(30 * 24);
    assert.equal(await code(renewRecruitPost(w.deps, 's1', { postId: late })), 'deadline_passed');
    assert.equal(counters(w, 's1').postActions?.count, 2, 'renew is not a counted action');
  });

  it("close declines every applied application, decrements each applicant's openApplicationCount once and openPostCount once, and notifies each applicant", async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    for (const uid of ['p1', 'p2', 'p3']) await apply(w, uid, postId);
    await withdrawRecruitApplication(w.deps, 'p3', { postId });
    assert.equal(await code(closeRecruitPost(w.deps, 's2', { postId })), 'permission_denied');
    await closeRecruitPost(w.deps, 's1', { postId });
    const post = w.store.posts.get(postId);
    assert.equal(post?.status, 'closed');
    assert.deepEqual(post?.closedAt, w.clock.now());
    assert.equal(counters(w, 's1').openPostCount, 0);
    assert.equal(counters(w, 's1').postActions?.count, 2);
    for (const uid of ['p1', 'p2']) {
      assert.equal(w.store.applications.get(`${postId}_${uid}`)?.status, 'declined');
      assert.deepEqual(w.store.applications.get(`${postId}_${uid}`)?.respondedAt, w.clock.now());
      assert.equal(counters(w, uid).openApplicationCount, 0);
      const rows = w.rowsOf(uid).filter((r) => r.type === 'recruit_application_result');
      assert.equal(rows.length, 1, uid);
    }
    assert.equal(w.store.applications.get(`${postId}_p3`)?.status, 'withdrawn');
    assert.equal(counters(w, 'p3').openApplicationCount, 0);
    assert.equal(w.rowsOf('p3').filter((r) => r.type === 'recruit_application_result').length, 0);
    assert.equal(await code(closeRecruitPost(w.deps, 's1', { postId })), 'deadline_passed');
    assert.equal(counters(w, 's1').openPostCount, 0);
  });

  it('an expired post cascades its applications to expired, once', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    assert.equal(await expireRecruitPost(w.deps, postId), false, 'not due yet');
    w.clock.advanceHours(30 * 24);
    assert.equal(await expireRecruitPost(w.deps, postId), true);
    assert.equal(await expireRecruitPost(w.deps, postId), false);
    assert.equal(w.store.posts.get(postId)?.status, 'expired');
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'expired');
    assert.equal(counters(w, 's1').openPostCount, 0);
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
  });
});

describe('applyToRecruitPost', () => {
  it('an unverified photographer gets not_accepting_orders', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(apply(w, 'u1', postId)), 'not_accepting_orders');
  });

  it('a studio cannot apply (invalid_argument)', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(apply(w, 's2', postId)), 'invalid_argument');
    assert.equal(await code(apply(w, 'c1', postId)), 'invalid_argument');
  });

  it('a member of the posting studio gets membership_conflict', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    w.store.seedMembership('p1', 's1');
    w.store.seedMembership('p2', 's2');
    assert.equal(await code(apply(w, 'p1', postId)), 'membership_conflict');
    await apply(w, 'p2', postId); // a member of another studio may apply (R6)
  });

  it('a provider blocked either way with the studio gets blocked, nothing written', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    w.blocks.block('p1', 's1');
    w.blocks.block('s1', 'p2');
    assert.equal(await code(apply(w, 'p1', postId)), 'blocked');
    assert.equal(await code(apply(w, 'p2', postId)), 'blocked');
    assert.equal(w.store.posts.get(postId)?.applicationCount, 0);
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
  });

  it('collaborator kind without acceptTerms is invalid_argument', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(apply(w, 'p1', postId, { acceptTerms: false })), 'invalid_argument');
    const memberPost = await openPost(w, 's1', { kind: 'member' });
    await apply(w, 'p1', memberPost, { acceptTerms: false });
    assert.equal(w.store.applications.get(`${memberPost}_p1`)?.termsAcceptedAt, null);
    await apply(w, 'p1', postId);
    assert.deepEqual(w.store.applications.get(`${postId}_p1`)?.termsAcceptedAt, w.clock.now());
  });

  it("sample posts must be the applicant's own (invalid_argument) and at most 3", async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    for (const id of ['w1', 'w2', 'w3', 'w4']) w.ownedPosts.add(`p1/${id}`);
    w.ownedPosts.add('p2/x1');
    assert.equal(await code(apply(w, 'p1', postId, { samplePostIds: ['w1', 'x1'] })), 'invalid_argument');
    assert.equal(await code(apply(w, 'p1', postId, { samplePostIds: ['w1', 'w2', 'w3', 'w4'] })), 'invalid_argument');
    await apply(w, 'p1', postId, { samplePostIds: ['w1', 'w2', 'w3'] });
    assert.deepEqual(w.store.applications.get(`${postId}_p1`)?.samplePostIds, ['w1', 'w2', 'w3']);
  });

  it('a message with a phone number gets invalid_argument with field message.contact', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    try {
      await apply(w, 'p1', postId, { message: 'Gọi em 0912 345 678 nhé' });
      assert.fail('expected a refusal');
    } catch (e) {
      assert.ok(e instanceof DomainError);
      assert.equal(e.code, 'invalid_argument');
      assert.equal(e.field, 'message.contact');
    }
    assert.equal(await code(apply(w, 'p1', postId, { message: 'a'.repeat(401) })), 'invalid_argument');
  });

  it('a second application to the same post is conflict, also after withdraw', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    assert.equal(await code(apply(w, 'p1', postId)), 'conflict');
    await withdrawRecruitApplication(w.deps, 'p1', { postId });
    assert.equal(await code(apply(w, 'p1', postId)), 'conflict');
  });

  it('the eleventh open application gets limit_exceeded', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    w.store.seedCounters('p1', { openApplicationCount: 10 });
    assert.equal(await code(apply(w, 'p1', postId)), 'limit_exceeded');
    w.store.seedCounters('p1', { openApplicationCount: 9 });
    await apply(w, 'p1', postId);
    assert.equal(counters(w, 'p1').openApplicationCount, 10);
  });

  it('the fourth apply of the VN day gets rate_limited', async () => {
    const w = createRecruitWorld();
    const posts = [await openPost(w, 's1'), await openPost(w, 's1'), await openPost(w, 's1'), await openPost(w, 's2')];
    for (const postId of posts.slice(0, 3)) await apply(w, 'p1', postId);
    assert.equal(await code(apply(w, 'p1', posts[3] ?? '')), 'rate_limited');
    await withdrawRecruitApplication(w.deps, 'p1', { postId: posts[0] ?? '' });
    assert.equal(await code(apply(w, 'p1', posts[3] ?? '')), 'rate_limited', 'withdraw does not refund the quota');
    w.clock.advanceHours(7);
    await apply(w, 'p1', posts[3] ?? '');
  });

  it('applying to a closed or expired post is deadline_passed', async () => {
    const w = createRecruitWorld();
    const closed = await openPost(w, 's1');
    await closeRecruitPost(w.deps, 's1', { postId: closed });
    assert.equal(await code(apply(w, 'p1', closed)), 'deadline_passed');
    const late = await openPost(w, 's1');
    w.clock.advanceHours(30 * 24);
    assert.equal(await code(apply(w, 'p1', late)), 'deadline_passed', 'past expiresAt before the sweep ran');
    assert.equal(await code(apply(w, 'p1', 'missing')), 'not_found');
  });

  it('apply increments applicationCount and sends one grouped recruit_application_new to the studio', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    const { applicationId } = await apply(w, 'p1', postId);
    assert.equal(applicationId, `${postId}_p1`);
    const app = w.store.applications.get(applicationId);
    assert.equal(app?.status, 'applied');
    assert.equal(app?.studioId, 's1');
    assert.equal(app?.kind, 'collaborator');
    assert.equal(app?.postTitle, VALID_POST.title);
    assert.deepEqual(app?.applicant, { name: 'Minh Trí', avatarUrl: null });
    assert.equal(app?.expiresAt.getTime(), w.clock.now().getTime() + 7 * DAY_MS);
    assert.equal(app?.respondedAt, null);
    assert.equal(w.store.posts.get(postId)?.applicationCount, 1);
    assert.equal(counters(w, 'p1').openApplicationCount, 1);
    assert.deepEqual(counters(w, 'p1').applyActions, { day: '2026-10-10', count: 1 });
    await apply(w, 'p2', postId);
    assert.equal(w.store.posts.get(postId)?.applicationCount, 2);
    const rows = w.rowsOf('s1').filter((r) => r.type === 'recruit_application_new');
    assert.equal(rows.length, 1, 'one grouped row per post');
    assert.equal(rows[0]?.count, 2);
    assert.equal(rows[0]?.target, `/studio/recruit?post=${postId}`);
  });

  it('a failing notification never fails the use case', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    w.notify.store.runTransaction = async () => {
      throw new Error('inbox down');
    };
    await apply(w, 'p1', postId);
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'applied');
    assert.equal(w.notify.pushErrors.length, 1);
  });
});

describe('withdrawRecruitApplication', () => {
  it('only applied can be withdrawn; counter decremented once; a repeat is deadline_passed', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    assert.equal(await code(withdrawRecruitApplication(w.deps, 'p1', { postId })), 'not_found');
    await apply(w, 'p1', postId);
    await withdrawRecruitApplication(w.deps, 'p1', { postId });
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'withdrawn');
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
    assert.equal(await code(withdrawRecruitApplication(w.deps, 'p1', { postId })), 'deadline_passed');
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
  });
});

describe('respondRecruitApplication (decline)', () => {
  it('decline sets declined, respondedAt, decrements counters, counts one studio action, notifies the applicant', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    w.clock.advanceMinutes(30);
    const r = await respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: false });
    assert.deepEqual(r, { status: 'declined' });
    const app = w.store.applications.get(`${postId}_p1`);
    assert.equal(app?.status, 'declined');
    assert.deepEqual(app?.respondedAt, w.clock.now());
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });
    const rows = w.rowsOf('p1').filter((x) => x.type === 'recruit_application_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.target, `/recruit/${postId}`);
    assert.equal(await code(respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: false })), 'deadline_passed');
  });

  it('respond after the application expired is deadline_passed', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    w.clock.advanceHours(7 * 24);
    assert.equal(await code(respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: false })), 'deadline_passed');
    assert.equal(counters(w, 'p1').openApplicationCount, 1);
  });

  it('only the posting studio may respond (permission_denied)', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    assert.equal(await code(respondRecruitApplication(w.deps, 's2', { postId, applicantId: 'p1', accept: false })), 'permission_denied');
    assert.equal(await code(respondRecruitApplication(w.deps, 'p1', { postId, applicantId: 'p1', accept: false })), 'permission_denied');
    assert.equal(await code(respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p2', accept: false })), 'not_found');
  });

  it('the eleventh studio action of the VN day gets rate_limited', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    w.store.seedCounters('s1', { openPostCount: 1, collabActions: { day: '2026-10-10', count: 10 } });
    assert.equal(await code(respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: false })), 'rate_limited');
  });
});

describe('counters under every exit', () => {
  it('every exit path from applied decrements openApplicationCount exactly once', async () => {
    const w = createRecruitWorld();
    const [p1, p2, p3] = [await openPost(w, 's1'), await openPost(w, 's1'), await openPost(w, 's1')];
    const p4 = await openPost(w, 's2');
    for (const postId of [p1, p2, p3]) await apply(w, 'a1', postId);
    w.clock.advanceHours(24);
    await apply(w, 'a1', p4);
    assert.equal(counters(w, 'a1').openApplicationCount, 4);

    await respondRecruitApplication(w.deps, 's1', { postId: p1, applicantId: 'a1', accept: false });
    assert.equal(counters(w, 'a1').openApplicationCount, 3);
    await withdrawRecruitApplication(w.deps, 'a1', { postId: p2 });
    assert.equal(counters(w, 'a1').openApplicationCount, 2);
    await closeRecruitPost(w.deps, 's1', { postId: p3 });
    assert.equal(counters(w, 'a1').openApplicationCount, 1);
    w.clock.advanceHours(7 * 24);
    assert.equal(await expireRecruitApplication(w.deps, p4, 'a1'), true);
    assert.equal(counters(w, 'a1').openApplicationCount, 0);

    // Repeats change nothing and never go negative.
    assert.equal(await expireRecruitApplication(w.deps, p4, 'a1'), false);
    assert.equal(await expireRecruitApplication(w.deps, p1, 'a1'), false);
    await code(withdrawRecruitApplication(w.deps, 'a1', { postId: p2 }));
    await code(respondRecruitApplication(w.deps, 's1', { postId: p1, applicantId: 'a1', accept: false }));
    await code(closeRecruitPost(w.deps, 's1', { postId: p3 }));
    assert.equal(counters(w, 'a1').openApplicationCount, 0);
    assert.equal(w.store.applications.get(`${p4}_a1`)?.status, 'expired');
    const results = w.rowsOf('a1').filter((r) => r.type === 'recruit_application_result');
    assert.equal(results.length, 3, 'declined (p1), declined by close (p3), expired (p4)');
  });
});

describe('Task 2 review follow-ups', () => {
  it('a failing settle after close is reported through onPushError, never thrown; the close stands', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    await apply(w, 'p2', postId);
    const run = w.store.runTransaction.bind(w.store);
    let calls = 0;
    w.store.runTransaction = (async (fn: Parameters<typeof run>[0]) => {
      calls += 1;
      if (calls === 2) throw new Error('store down'); // the first application of the cascade
      return run(fn);
    }) as typeof w.store.runTransaction;
    await closeRecruitPost(w.deps, 's1', { postId });
    assert.equal(w.store.posts.get(postId)?.status, 'closed');
    assert.equal(counters(w, 's1').openPostCount, 0);
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'applied', 'the failed one waits for the sweep');
    assert.equal(w.store.applications.get(`${postId}_p2`)?.status, 'declined', 'the cascade continues');
    assert.equal(w.notify.pushErrors.length, 1);
    assert.match(String(w.notify.pushErrors[0]), /store down/);
  });

  it('two parallel applies at openApplicationCount 9: one succeeds, one gets limit_exceeded (retried)', async () => {
    const w = createRecruitWorld();
    const a = await openPost(w, 's1');
    const b = await openPost(w, 's2');
    w.store.seedCounters('p1', { openApplicationCount: 9 });
    const results = await Promise.allSettled([apply(w, 'p1', a), apply(w, 'p1', b)]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'limit_exceeded');
    assert.equal(counters(w, 'p1').openApplicationCount, 10);
    assert.ok(w.store.retries > 0);
  });

  it('two parallel creates at 2 open posts: one succeeds, one gets limit_exceeded (retried)', async () => {
    const w = createRecruitWorld();
    await openPost(w, 's1');
    await openPost(w, 's1');
    const results = await Promise.allSettled([
      createRecruitPost(w.deps, 's1', VALID_POST),
      createRecruitPost(w.deps, 's1', VALID_POST),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected' && rejected.reason instanceof DomainError);
    assert.equal(rejected.reason.code, 'limit_exceeded');
    assert.equal(counters(w, 's1').openPostCount, 3);
    assert.equal([...w.store.posts.values()].filter((p) => p.status === 'open').length, 3);
    assert.ok(w.store.retries > 0);
  });

  it('update and renew re-copy the studio snapshot (Decision 22)', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    const s1 = w.people.get('s1');
    assert.ok(s1);
    w.people.set('s1', { ...s1, name: 'Studio Mây Mới', avatarUrl: 'https://img/s1-new.jpg' });
    await updateRecruitPost(w.deps, 's1', { ...VALID_POST, postId });
    assert.deepEqual(w.store.posts.get(postId)?.studio,
      { name: 'Studio Mây Mới', avatarUrl: 'https://img/s1-new.jpg', businessVerified: true });
    w.people.set('s1', { ...s1, name: 'Studio Mây 2026', businessVerified: false });
    await renewRecruitPost(w.deps, 's1', { postId });
    assert.deepEqual(w.store.posts.get(postId)?.studio,
      { name: 'Studio Mây 2026', avatarUrl: 'https://img/s1.jpg', businessVerified: false });
  });
});

describe('respondRecruitApplication (accept)', () => {
  const accept = (w: RecruitWorld, studioId: string, postId: string, applicantId: string) =>
    respondRecruitApplication(w.deps, studioId, { postId, applicantId, accept: true });

  it('accepting a collaborator application creates an active collaboration with initiatedBy application and applicationId, marks the application accepted, sends recruit_application_result collaborator', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    const appliedAt = w.clock.now();
    w.clock.advanceHours(3);
    assert.deepEqual(await accept(w, 's1', postId, 'p1'), { status: 'accepted' });
    const app = w.store.applications.get(`${postId}_p1`);
    assert.equal(app?.status, 'accepted');
    assert.deepEqual(app?.respondedAt, w.clock.now());
    const c = w.store.collaborations.get('s1_p1');
    assert.equal(c?.status, 'active');
    assert.equal(c?.initiatedBy, 'application');
    assert.equal(c?.applicationId, `${postId}_p1`);
    assert.deepEqual(c?.termsAcceptedAt, appliedAt, 'the terms were accepted when applying');
    assert.deepEqual(c?.activeAt, w.clock.now());
    assert.deepEqual(c?.studio, { name: 'Studio Mây', avatarUrl: 'https://img/s1.jpg' });
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
    assert.equal(counters(w, 'p1').activeCollabCount, 1);
    assert.equal(counters(w, 's1').activeCollabCount, 1);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });
    const rows = w.rowsOf('p1').filter((r) => r.type === 'recruit_application_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.body, 'Studio Mây nhận bạn làm cộng tác viên.');
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'deadline_passed', 'answered already');
  });

  it("accepting a member application writes an active studio_members record through putMember, counts S26's counters, sends studio_join_approved and recruit_application_result member", async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    await apply(w, 'p1', postId, { acceptTerms: false });
    w.clock.advanceHours(1);
    assert.deepEqual(await accept(w, 's1', postId, 'p1'), { status: 'accepted' });
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'accepted');
    const members = [...w.store.members.values()];
    assert.equal(members.length, 1);
    const m = members[0];
    assert.equal(m?.studioId, 's1');
    assert.equal(m?.memberId, 'p1');
    assert.equal(m?.status, 'active');
    assert.equal(m?.initiatedBy, 'member');
    assert.equal(m?.applicationId, `${postId}_p1`);
    assert.equal(m?.joinedAt, w.clock.now().toISOString());
    assert.equal(m?.studioName, 'Studio Mây');
    assert.equal(m?.memberName, 'Minh Trí');
    assert.equal(w.store.memberships.get('p1'), 's1', 'the member lock');
    assert.equal(w.store.studios.get('s1')?.memberCount, 1);
    assert.deepEqual(w.store.studioQuotas.get('s1'), { dayKey: '2026-10-10', studioActions: 1, memberActions: 0 });
    assert.equal(counters(w, 'p1').openApplicationCount, 0);
    assert.equal(counters(w, 'p1').activeCollabCount, 0);
    assert.equal(w.store.collaborations.size, 0);
    assert.deepEqual(counters(w, 's1').collabActions, { day: '2026-10-10', count: 1 });
    assert.equal(w.rowsOf('p1').filter((r) => r.type === 'studio_join_approved').length, 1);
    const rows = w.rowsOf('p1').filter((r) => r.type === 'recruit_application_result');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.body, 'Studio Mây nhận bạn vào studio.');
  });

  it("member accept reports S26's errors unchanged", async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    for (const uid of ['p1', 'p2', 'p3']) await apply(w, uid, postId, { acceptTerms: false });

    w.store.seedMembership('p1', 's2');
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'membership_conflict');
    w.store.seedCooldown('p2', new Date(w.clock.now().getTime() + DAY_MS).toISOString());
    assert.equal(await code(accept(w, 's1', postId, 'p2')), 'cooldown');
    w.store.seedStudio('s1', { memberCount: 2, openInvites: 1 });
    assert.equal(await code(accept(w, 's1', postId, 'p3')), 'studio_full');
    w.store.seedStudio('s1', { openInvites: 0 });
    w.store.seedStudioQuota('s1', { dayKey: '2026-10-10', studioActions: 5, memberActions: 0 });
    assert.equal(await code(accept(w, 's1', postId, 'p3')), 'rate_limited');

    for (const uid of ['p1', 'p2', 'p3']) {
      assert.equal(w.store.applications.get(`${postId}_${uid}`)?.status, 'applied', uid);
      assert.equal(counters(w, uid).openApplicationCount, 1, uid);
    }
    assert.equal(w.store.members.size, 0);
    assert.equal(counters(w, 's1').collabActions, null, 'a refused accept is not counted');
  });

  it('member accept when the applicant is an active collaborator of this studio → membership_conflict', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    await apply(w, 'p1', postId, { acceptTerms: false });
    seedCollaboration(w, 's1', 'p1');
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'membership_conflict');
    seedCollaboration(w, 's2', 'p1'); // collaborating with another studio is fine (R6)
    seedCollaboration(w, 's1', 'p1', { status: 'ended', endedAt: w.clock.now(), endedBy: 'collaborator' });
    await accept(w, 's1', postId, 'p1');
    assert.equal(w.store.memberships.get('p1'), 's1');
  });

  it('member accept when the pair already has an S26 invite or join request → conflict', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    await apply(w, 'p1', postId, { acceptTerms: false });
    w.store.seedOpenPair('s1', 'p1');
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'conflict');
  });

  it('accepting a collaborator application when already active with this studio → conflict', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    seedCollaboration(w, 's1', 'p1');
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'conflict');
    assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'applied');
  });

  it('accepting a collaborator application consumes a pending invite of the pair', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    await apply(w, 'p1', postId);
    seedCollaboration(w, 's1', 'p1', { status: 'invited', activeAt: null, termsAcceptedAt: null, defaultFee: 650_000 });
    w.store.seedCounters('s1', { pendingInviteCount: 1 });
    await accept(w, 's1', postId, 'p1');
    const c = w.store.collaborations.get('s1_p1');
    assert.equal(c?.status, 'active');
    assert.equal(c?.initiatedBy, 'application');
    assert.equal(c?.defaultFee, 650_000);
    assert.equal(counters(w, 's1').pendingInviteCount, 0);
    assert.equal(w.store.collabHistory.get('s1_p1'), undefined);
  });

  it('collaborator accept: recruit_blocked studio, unverified applicant, collab_full, member of this studio', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    for (const uid of ['p1', 'p2', 'p3']) await apply(w, uid, postId);
    w.store.seedCounters('s1', { recruitBlockedUntil: new Date(w.clock.now().getTime() + DAY_MS) });
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'recruit_blocked');
    w.store.seedCounters('s1', { recruitBlockedUntil: null });
    w.people.set('p1', { ...(w.people.get('p1') ?? assert.fail()), acceptsOrders: false });
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'not_accepting_orders');
    w.store.seedCounters('p2', { activeCollabCount: 5 });
    assert.equal(await code(accept(w, 's1', postId, 'p2')), 'collab_full');
    w.store.seedMembership('p3', 's1');
    assert.equal(await code(accept(w, 's1', postId, 'p3')), 'membership_conflict');
    assert.equal(w.store.collaborations.size, 0);
  });
});

describe('Task 3 review follow-ups (accept)', () => {
  const accept = (w: RecruitWorld, studioId: string, postId: string, applicantId: string) =>
    respondRecruitApplication(w.deps, studioId, { postId, applicantId, accept: true });

  it('member accept re-checks both parties: unverified applicant or studio → not_accepting_orders; applicant no longer an individual → invalid_argument', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1', { kind: 'member' });
    for (const uid of ['p1', 'p2']) await apply(w, uid, postId, { acceptTerms: false });
    const p1 = w.people.get('p1') ?? assert.fail();
    w.people.set('p1', { ...p1, acceptsOrders: false });
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'not_accepting_orders');
    w.people.set('p1', { ...p1, providerType: 'studio' });
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'invalid_argument');
    w.people.set('p1', { ...p1, role: 'customer' });
    assert.equal(await code(accept(w, 's1', postId, 'p1')), 'invalid_argument');
    const s1 = w.people.get('s1') ?? assert.fail();
    w.people.set('s1', { ...s1, acceptsOrders: false });
    assert.equal(await code(accept(w, 's1', postId, 'p2')), 'not_accepting_orders');
    assert.equal(w.store.members.size, 0);
    for (const uid of ['p1', 'p2']) assert.equal(w.store.applications.get(`${postId}_${uid}`)?.status, 'applied', uid);
  });

  it('accept reads the people and order gates once, outside the transaction, even when the transaction retries', async () => {
    for (const kind of ['collaborator', 'member'] as const) {
      const w = createRecruitWorld();
      const postId = await openPost(w, 's1', { kind });
      await apply(w, 'p1', postId, { acceptTerms: kind === 'collaborator' });
      let reads = 0;
      const people = w.deps.people;
      const orders = w.deps.orders;
      const deps = {
        ...w.deps,
        people: { provider: (uid: string) => { reads += 1; return people.provider(uid); } },
        orders: {
          acceptsOrders: (uid: string) => { reads += 1; return orders.acceptsOrders(uid); },
          orderProfile: (uid: string) => orders.orderProfile(uid),
        },
      };
      let first = true;
      const original = w.store.runTransaction.bind(w.store);
      w.store.runTransaction = <T>(fn: Parameters<typeof original<T>>[0]) => original<T>(async (tx) => {
        const result = await fn(tx);
        if (first) {
          first = false;
          throw new RetryableConflict();
        }
        return result;
      });
      await respondRecruitApplication(deps, 's1', { postId, applicantId: 'p1', accept: true });
      assert.equal(w.store.retries, 1, kind);
      assert.equal(reads, 4, `${kind}: two providers and two order gates, once`);
      assert.equal(w.store.applications.get(`${postId}_p1`)?.status, 'accepted', kind);
    }
  });
});
