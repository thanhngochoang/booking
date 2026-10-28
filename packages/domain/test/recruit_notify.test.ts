import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { recruitMatchKeysOf } from '../src/recruit_areas.js';
import { notifyRecruitMatches } from '../src/recruit_notify.js';
import {
  applyToRecruitPost,
  closeRecruitPost,
  expireRecruitApplication,
  respondRecruitApplication,
} from '../src/recruit_use_cases.js';
import { createRecruitWorld, openPost, VALID_POST, type RecruitWorld } from './support/recruit_world.js';

/** An individual in TP.HCM shooting weddings: matches VALID_POST (HCM Q1/Q3 × wedding/family). */
const HCM_WEDDING = recruitMatchKeysOf({
  role: 'photographer',
  providerType: 'individual',
  serviceArea: { city: 'TP.HCM', radiusKm: 10 },
  specialties: ['wedding'],
});

const postNewRows = (w: RecruitWorld, uid: string) => w.rowsOf(uid).filter((r) => r.type === 'recruit_post_new');

describe('notifyRecruitMatches', () => {
  it('notifies matching providers except the studio', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p1', HCM_WEDDING);
    w.store.seedMatchKeys('p2', recruitMatchKeysOf({ role: 'photographer', providerType: 'individual',
      serviceArea: { city: 'Hà Nội', radiusKm: 10 }, specialties: ['wedding'] }));
    w.store.seedMatchKeys('s1', HCM_WEDDING); // never, even if a stale key matched
    const postId = await openPost(w, 's1');
    assert.deepEqual(await notifyRecruitMatches(w.deps, postId), { sent: 1, capped: 0 });
    assert.equal(postNewRows(w, 'p1').length, 1);
    assert.equal(postNewRows(w, 'p2').length, 0);
    assert.equal(postNewRows(w, 's1').length, 0);
    assert.deepEqual(w.store.countersOf('p1').notices, { day: '2026-10-10', count: 1, postIds: [postId] });
  });

  it('skips a provider blocked either way, without using their daily slot (#198)', async () => {
    const w = createRecruitWorld();
    for (const uid of ['p1', 'p2', 'p3']) w.store.seedMatchKeys(uid, HCM_WEDDING);
    w.blocks.block('p1', 's1'); // the provider blocked the studio
    w.blocks.block('s1', 'p2'); // the studio blocked the provider
    const postId = await openPost(w, 's1');
    assert.deepEqual(await notifyRecruitMatches(w.deps, postId), { sent: 1, capped: 0 });
    assert.equal(postNewRows(w, 'p1').length, 0);
    assert.equal(postNewRows(w, 'p2').length, 0);
    assert.equal(postNewRows(w, 'p3').length, 1);
    assert.equal(w.store.countersOf('p1').notices ?? null, null);
    assert.equal(w.store.countersOf('p2').notices ?? null, null);
  });

  it('a provider gets at most 3 recruit_post_new per VN day', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p1', HCM_WEDDING);
    const posts = [await openPost(w, 's1'), await openPost(w, 's1'), await openPost(w, 's1'), await openPost(w, 's2')];
    const results = [];
    for (const postId of posts) results.push(await notifyRecruitMatches(w.deps, postId));
    assert.deepEqual(results.at(-1), { sent: 0, capped: 1 });
    assert.equal(postNewRows(w, 'p1').length, 3);
    assert.equal(w.store.countersOf('p1').notices?.count, 3);
  });

  it('the cap resets the next VN day', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p1', HCM_WEDDING);
    for (let i = 0; i < 3; i++) await notifyRecruitMatches(w.deps, await openPost(w, 's1'));
    w.clock.advanceHours(7); // 17:00Z = VN midnight
    const next = await openPost(w, 's2');
    assert.deepEqual(await notifyRecruitMatches(w.deps, next), { sent: 1, capped: 0 });
    assert.deepEqual(w.store.countersOf('p1').notices, { day: '2026-10-11', count: 1, postIds: [next] });
  });

  it('stops at 200 recipients', async () => {
    const w = createRecruitWorld();
    for (let i = 0; i < 230; i++) w.store.seedMatchKeys(`x${i}`, HCM_WEDDING);
    const postId = await openPost(w, 's1');
    assert.deepEqual(await notifyRecruitMatches(w.deps, postId), { sent: 200, capped: 0 });
    assert.equal(postNewRows(w, 'x199').length, 1);
    assert.equal(postNewRows(w, 'x200').length, 0);
  });

  it('a replayed trigger sends nothing twice', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p1', HCM_WEDDING);
    const postId = await openPost(w, 's1');
    await notifyRecruitMatches(w.deps, postId);
    const pushes = w.notify.push.sent.length;
    assert.deepEqual(await notifyRecruitMatches(w.deps, postId), { sent: 0, capped: 0 });
    assert.equal(postNewRows(w, 'p1').length, 1);
    assert.equal(w.notify.push.sent.length, pushes);
    assert.equal(w.store.countersOf('p1').notices?.count, 1, 'a replay does not use up the cap');
  });

  it('sends nothing for a post that is no longer open or does not exist', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p1', HCM_WEDDING);
    const postId = await openPost(w, 's1');
    await closeRecruitPost(w.deps, 's1', { postId });
    assert.deepEqual(await notifyRecruitMatches(w.deps, postId), { sent: 0, capped: 0 });
    assert.deepEqual(await notifyRecruitMatches(w.deps, 'missing'), { sent: 0, capped: 0 });
    assert.equal(postNewRows(w, 'p1').length, 0);
  });
});

describe('#138 hooks', () => {
  it('each use case calls the matching #138 hook with the Contract fields', async () => {
    const w = createRecruitWorld();
    w.store.seedMatchKeys('p3', HCM_WEDDING);
    const postId = await openPost(w, 's1');
    const title = VALID_POST.title;

    await notifyRecruitMatches(w.deps, postId); // notifyRecruitPostNew
    const postNew = postNewRows(w, 'p3')[0];
    assert.equal(postNew?.target, `/recruit/${postId}`);
    assert.equal(postNew?.body, `Studio Mây: ${title}`);
    assert.deepEqual(postNew?.actors.map((a) => a.id), ['s1']);

    await applyToRecruitPost(w.deps, 'p1', { postId, message: '', samplePostIds: [], acceptTerms: true }); // notifyRecruitApplicationNew
    const appNew = w.rowsOf('s1').find((r) => r.type === 'recruit_application_new');
    assert.equal(appNew?.target, `/studio/recruit?post=${postId}`);
    assert.equal(appNew?.groupKey, `recruit:${postId}:apps`);
    assert.equal(appNew?.body, `Minh Trí ứng tuyển “${title}”`);
    assert.deepEqual(appNew?.actors.map((a) => a.id), ['p1']);

    await respondRecruitApplication(w.deps, 's1', { postId, applicantId: 'p1', accept: false }); // result declined
    const declined = w.rowsOf('p1').find((r) => r.type === 'recruit_application_result');
    assert.equal(declined?.target, `/recruit/${postId}`);
    assert.equal(declined?.body, `Studio Mây chưa nhận ứng tuyển “${title}”.`);

    await applyToRecruitPost(w.deps, 'p2', { postId, message: '', samplePostIds: [], acceptTerms: true });
    w.clock.advanceHours(7 * 24);
    await expireRecruitApplication(w.deps, postId, 'p2'); // result expired
    const expired = w.rowsOf('p2').find((r) => r.type === 'recruit_application_result');
    assert.equal(expired?.title, 'Ứng tuyển đã hết hạn');
    assert.equal(expired?.target, `/recruit/${postId}`);
  });
});
