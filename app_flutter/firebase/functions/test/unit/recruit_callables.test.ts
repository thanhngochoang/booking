import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  handleApplyToRecruitPost,
  handleCloseRecruitPost,
  handleCreateRecruitPost,
  handleRenewRecruitPost,
  handleRespondRecruitApplication,
  handleUpdateRecruitPost,
  handleWithdrawRecruitApplication,
} from '../../src/callables/recruit.js';
import { FirestoreChatStore } from '../../src/infra/chat_firestore.js';
import { liveRecruitDeps } from '../../src/infra/live_recruit.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { AN, BINH, recruitWorld, seedRecruitPeople, type RecruitTestWorld } from './support/recruit_fixtures.js';
import { STUDIO } from './support/studio_fixtures.js';

const POST_INPUT = {
  kind: 'collaborator',
  title: 'Tuyển CTV chụp cưới cuối tuần',
  specialties: ['wedding'],
  areas: ['hcm-q1'],
  frequency: 'weekly',
  feeHint: { type: 'per_shoot', amount: 800_000 },
  requirements: '',
};

const asCaller = (uid: string, data: unknown = {}) => ({ auth: { uid }, data });
const refused = (code: string, detail?: string, field?: string) => (e: unknown) =>
  e instanceof HttpsError &&
  e.code === code &&
  (detail === undefined || (e.details as { code?: string })?.code === detail) &&
  (field === undefined || (e.details as { field?: string })?.field === field);

describe('recruit callables (S27.01–S27.05)', () => {
  let db: MemoryFirestore;
  let w: RecruitTestWorld;
  let chats: FirestoreChatStore;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedRecruitPeople(db);
    w = recruitWorld(db);
    chats = new FirestoreChatStore(db.asFirestore());
  });

  async function post(): Promise<string> {
    return (await handleCreateRecruitPost(asCaller(STUDIO, POST_INPUT), w.deps)).postId;
  }

  it('unauthenticated is refused by all 7 recruit callables', async () => {
    const noAuth = { auth: undefined, data: {} };
    for (const call of [
      () => handleCreateRecruitPost(noAuth, w.deps),
      () => handleUpdateRecruitPost(noAuth, w.deps),
      () => handleCloseRecruitPost(noAuth, w.deps),
      () => handleRenewRecruitPost(noAuth, w.deps),
      () => handleApplyToRecruitPost(noAuth, w.deps),
      () => handleWithdrawRecruitApplication(noAuth, w.deps),
      () => handleRespondRecruitApplication(noAuth, w.deps, chats),
    ]) {
      await assert.rejects(call(), refused('unauthenticated', 'permission_denied'));
    }
    assert.equal(db.log.length, 0);
  });

  it('createRecruitPost: the caller is the studio; contact in the title is invalid-argument with details.field', async () => {
    const postId = await post();
    assert.equal(db.data(`recruitPosts/${postId}`)?.studioId, STUDIO);
    await assert.rejects(
      handleCreateRecruitPost(asCaller(STUDIO, { ...POST_INPUT, title: 'Gọi 0903123456 để nhận việc' }), w.deps),
      refused('invalid-argument', 'invalid_argument', 'title.contact'),
    );
  });

  it('updateRecruitPost: the caller\'s own post only (permission_denied for another)', async () => {
    const postId = await post();
    assert.deepEqual(await handleUpdateRecruitPost(asCaller(STUDIO, { ...POST_INPUT, postId, title: 'Tuyển CTV chụp cưới mùa cưới' }), w.deps), {});
    assert.equal(db.data(`recruitPosts/${postId}`)?.title, 'Tuyển CTV chụp cưới mùa cưới');
    await assert.rejects(
      handleUpdateRecruitPost(asCaller(AN, { ...POST_INPUT, postId }), w.deps),
      refused('permission-denied', 'permission_denied'),
    );
  });

  it('closeRecruitPost closes the caller\'s post; an unknown post is not_found', async () => {
    const postId = await post();
    assert.deepEqual(await handleCloseRecruitPost(asCaller(STUDIO, { postId }), w.deps), {});
    assert.equal(db.data(`recruitPosts/${postId}`)?.status, 'closed');
    await assert.rejects(handleCloseRecruitPost(asCaller(STUDIO, { postId: 'nope' }), w.deps), refused('not-found', 'not_found'));
  });

  it('renewRecruitPost returns the new expiry as an ISO string; a second renewal is conflict', async () => {
    const postId = await post();
    const { expiresAt } = await handleRenewRecruitPost(asCaller(STUDIO, { postId }), w.deps);
    assert.equal(expiresAt, new Date(w.now.getTime() + 60 * 86_400_000).toISOString());
    await assert.rejects(handleRenewRecruitPost(asCaller(STUDIO, { postId }), w.deps), refused('aborted', 'conflict'));
  });

  it('applyToRecruitPost applies as the caller; an unverified photographer is not_accepting_orders', async () => {
    const postId = await post();
    const out = await handleApplyToRecruitPost(asCaller(AN, { postId, message: 'Em chụp cưới.', samplePostIds: [], acceptTerms: true }), w.deps);
    assert.equal(out.applicationId, `${postId}_${AN}`);
    assert.equal(db.data(`recruitApplications/${postId}_${AN}`)?.applicantId, AN);
    await assert.rejects(
      handleApplyToRecruitPost(asCaller(BINH, { postId, message: '', samplePostIds: [], acceptTerms: true }), w.deps),
      refused('failed-precondition', 'not_accepting_orders'),
    );
  });

  it('withdrawRecruitApplication withdraws the caller\'s application; none is not_found', async () => {
    const postId = await post();
    await handleApplyToRecruitPost(asCaller(AN, { postId, samplePostIds: [], acceptTerms: true }), w.deps);
    assert.deepEqual(await handleWithdrawRecruitApplication(asCaller(AN, { postId }), w.deps), {});
    assert.equal(db.data(`recruitApplications/${postId}_${AN}`)?.status, 'withdrawn');
    await assert.rejects(handleWithdrawRecruitApplication(asCaller(BINH, { postId }), w.deps), refused('not-found', 'not_found'));
  });

  it('respondRecruitApplication answers as the posting studio and reopens a read-only collab chat on acceptance', async () => {
    const postId = await post();
    await handleApplyToRecruitPost(asCaller(AN, { postId, samplePostIds: [], acceptTerms: true }), w.deps);
    db.seed(`chats/collab_${STUDIO}_${AN}`, { kind: 'collab', customerId: STUDIO, photographerId: AN, readOnlyAt: new Date(0) });
    await assert.rejects(
      handleRespondRecruitApplication(asCaller(STUDIO, { postId, applicantId: BINH, accept: true }), w.deps, chats),
      refused('not-found', 'not_found'),
    );
    assert.deepEqual(
      await handleRespondRecruitApplication(asCaller(STUDIO, { postId, applicantId: AN, accept: true }), w.deps, chats),
      { status: 'accepted' },
    );
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${AN}`)?.status, 'active');
    assert.equal(db.data(`chats/collab_${STUDIO}_${AN}`)?.readOnlyAt, null);
  });

  it('liveRecruitDeps wires a BlockGate', () => {
    const deps = liveRecruitDeps();
    assert.ok(deps.blocks instanceof FirestoreBlockGate);
    assert.equal(typeof deps.store.matchingProviders, 'function');
    assert.equal(typeof deps.milestones.shootMilestone, 'function');
  });
});
