import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryAwardStore, type Award, type AwardDeps } from '@photobooking/domain';
import {
  handleCreateAward,
  handleDeleteAward,
  handleReviewAward,
  handleUpdateAward,
} from '../../src/callables/award.js';

const AWARD = '01ARZ3NDEKTSV4RRFFQ69G5F01';
const NOW = new Date('2026-10-10T12:00:00.000Z');

describe('award callables', () => {
  let store: MemoryAwardStore;
  let notified: string[];

  const roles = new Map<string, string>([['p1', 'photographer']]);

  function deps(): AwardDeps & { userRole(uid: string): Promise<string | null> } {
    return {
      userRole: async (uid) => roles.get(uid) ?? null,
      awards: store,
      tiers: store.tiers,
      files: { delete: async () => {} },
      notify: {
        tierChanged: async () => {},
        awardReviewed: async (uid, id, status) => void notified.push(`${uid}/${id}/${status}`),
      },
      clock: { now: () => NOW },
    };
  }

  const pending: Award = {
    id: AWARD,
    photographerId: 'p1',
    competition: 'Sony World Photography',
    year: 2025,
    category: null,
    result: 'gold',
    workPostId: null,
    status: 'pending',
    reviewNote: null,
    reviewedBy: null,
    reviewedAt: null,
    createdAt: NOW,
    updatedAt: NOW,
  };

  const input = {
    awardId: AWARD,
    competition: 'Sony World Photography',
    year: 2025,
    result: 'gold',
    proofLinks: ['https://example.com/win'],
  };

  beforeEach(() => {
    store = new MemoryAwardStore();
    notified = [];
    store.seedTier('p1', { providerType: 'individual', artistSince: null, approvedAwardCount: 0 });
  });

  it('unauthenticated is refused', async () => {
    const handlers = [handleCreateAward, handleUpdateAward, handleDeleteAward, handleReviewAward];
    for (const h of handlers) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) =>
          e instanceof HttpsError &&
          e.code === 'unauthenticated' &&
          (e.details as { code?: string } | undefined)?.code === 'permission_denied',
      );
    }
  });

  it('createAward returns the id; a caller without a photographer profile is refused', async () => {
    const res = await handleCreateAward({ auth: { uid: 'p1' }, data: input }, deps());
    assert.deepEqual(res, { awardId: AWARD });
    assert.equal(store.awards.get(AWARD)?.status, 'pending');
    await assert.rejects(
      () => handleCreateAward({ auth: { uid: 'c1' }, data: input }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
  });

  it('a customer is refused even with a photographers doc', async () => {
    roles.set('c2', 'customer');
    store.seedTier('c2', { providerType: 'individual', artistSince: null, approvedAwardCount: 0 });
    await assert.rejects(
      () => handleCreateAward({ auth: { uid: 'c2' }, data: input }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    assert.equal(store.awards.size, 0);
  });

  it('domain errors map to HttpsError', async () => {
    await assert.rejects(
      () => handleCreateAward({ auth: { uid: 'p1' }, data: { ...input, competition: '' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
    await assert.rejects(
      () => handleDeleteAward({ auth: { uid: 'p1' }, data: { awardId: AWARD } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });

  it('a non-admin reviewAward is permission-denied', async () => {
    store.seedAward(pending);
    await assert.rejects(
      () => handleReviewAward({ auth: { uid: 'p1', token: {} }, data: { awardId: AWARD, action: 'approve' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    await assert.rejects(
      () =>
        handleReviewAward(
          { auth: { uid: 'p1', token: { staffRole: 'support' } }, data: { awardId: AWARD, action: 'approve' } },
          deps(),
        ),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    assert.equal(store.awards.get(AWARD)?.status, 'pending');
  });

  it('the admin claim reaches the use case as isAdmin', async () => {
    store.seedAward(pending);
    const res = await handleReviewAward(
      { auth: { uid: 'staff1', token: { staffRole: 'admin' } }, data: { awardId: AWARD, action: 'approve' } },
      deps(),
    );
    assert.deepEqual(res, { status: 'approved' });
    assert.equal(store.audit[0]?.actorId, 'staff1');
    assert.deepEqual(notified, [`p1/${AWARD}/approved`]);
  });
});
