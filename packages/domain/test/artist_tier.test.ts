import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { tierFor } from '../src/artist_tier.js';
import type { Award, AwardProof, AwardStatus } from '../src/award.js';
import type { AwardDeps } from '../src/award_ports.js';
import { purgeDueProofs, recomputeTier, reviewAward } from '../src/award_use_cases.js';
import { MemoryAwardStore } from '../src/memory_award_store.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');
const OLD = new Date('2026-10-01T00:00:00.000Z');

describe('artist tier', () => {
  let store: MemoryAwardStore;
  let deps: AwardDeps;
  let tierEvents: string[];
  let deleted: string[][];

  const seed = (id: string, status: AwardStatus, uid = 'u1'): void => {
    const a: Award = {
      id, photographerId: uid, competition: 'Cuộc thi', year: 2024, category: null, result: 'gold',
      workPostId: null, status, reviewNote: null, reviewedBy: null, reviewedAt: null, createdAt: OLD, updatedAt: OLD,
    };
    store.seedAward(a);
    store.seedProof({ awardId: id, photographerId: uid, files: [`awardProofs/${uid}/${id}/0.jpg`], links: [], purgeAfter: null });
  };

  beforeEach(() => {
    store = new MemoryAwardStore();
    tierEvents = [];
    deleted = [];
    deps = {
      awards: store,
      tiers: store.tiers,
      files: { delete: async (p) => void deleted.push([...p]) },
      notify: { tierChanged: async (u, to) => void tierEvents.push(`${u}:${to}`), awardReviewed: async () => undefined },
      clock: { now: () => NOW },
    };
  });

  it('tierFor is the one rule', () => {
    assert.equal(tierFor('individual', 3), 'artist');
    assert.equal(tierFor('individual', 2), 'individual');
    assert.equal(tierFor('artist', 2), 'individual');
    assert.equal(tierFor('studio', 9), 'studio');
  });

  it('the third approval makes an artist', async () => {
    seed('a1', 'approved');
    seed('a2', 'approved');
    seed('a3', 'pending');
    store.seedTier('u1', { providerType: 'individual', artistSince: null, approvedAwardCount: 2 });
    await reviewAward(deps, 'adm', true, { awardId: 'a3', action: 'approve' });
    assert.deepEqual(store.tierStates.get('u1'), { providerType: 'artist', artistSince: NOW, approvedAwardCount: 3 });
    assert.deepEqual(tierEvents, ['u1:artist']);
  });

  it('a revocation below 3 makes an individual again', async () => {
    seed('a1', 'approved');
    seed('a2', 'approved');
    seed('a3', 'approved');
    store.seedTier('u1', { providerType: 'artist', artistSince: OLD, approvedAwardCount: 3 });
    await reviewAward(deps, 'adm', true, { awardId: 'a3', action: 'revoke', note: 'Giải không có thật' });
    assert.deepEqual(store.tierStates.get('u1'), { providerType: 'individual', artistSince: null, approvedAwardCount: 2 });
    assert.deepEqual(tierEvents, ['u1:individual']);
  });

  it('a studio never becomes an artist', async () => {
    for (const id of ['a1', 'a2', 'a3', 'a4', 'a5']) seed(id, 'approved');
    store.seedTier('u1', { providerType: 'studio', artistSince: null, approvedAwardCount: 0 });
    assert.equal(await recomputeTier(deps, 'u1'), 'count');
    assert.deepEqual(store.tierStates.get('u1'), { providerType: 'studio', artistSince: null, approvedAwardCount: 5 });
    assert.deepEqual(tierEvents, []);
  });

  it('recompute without a change writes nothing', async () => {
    seed('a1', 'approved');
    store.seedTier('u1', { providerType: 'individual', artistSince: null, approvedAwardCount: 1 });
    assert.equal(await recomputeTier(deps, 'u1'), 'unchanged');
    assert.equal(store.tierWrites, 0);
    seed('a2', 'approved');
    seed('a3', 'approved');
    assert.equal(await recomputeTier(deps, 'u1'), 'artist');
    assert.equal(await recomputeTier(deps, 'u1'), 'unchanged');
    assert.equal(store.tierWrites, 1);
    assert.deepEqual(tierEvents, ['u1:artist']);
  });

  it('recompute for an unknown user changes nothing', async () => {
    assert.equal(await recomputeTier(deps, 'ghost'), 'unchanged');
  });

  it('a failing tierChanged notify does not throw', async () => {
    for (const id of ['a1', 'a2', 'a3']) seed(id, 'approved');
    store.seedTier('u1', { providerType: 'individual', artistSince: null, approvedAwardCount: 0 });
    deps = { ...deps, notify: { tierChanged: async () => { throw new Error('boom'); }, awardReviewed: async () => undefined } };
    assert.equal(await recomputeTier(deps, 'u1'), 'artist');
    assert.equal(store.tierStates.get('u1')?.providerType, 'artist');
  });

  it('purge continues after one failure', async () => {
    const proof = (id: string): AwardProof => ({
      awardId: id, photographerId: 'u1', files: [`awardProofs/u1/${id}/0.jpg`], links: [], purgeAfter: OLD,
    });
    store.seedProof(proof('a1'));
    store.seedProof(proof('a2'));
    const n = await purgeDueProofs({
      ...deps,
      files: { delete: async (p) => { if (p[0]?.includes('/a1/')) throw new Error('boom'); deleted.push([...p]); } },
      proofsDue: async () => [...store.proofs.values()],
    });
    assert.equal(n, 1);
    assert.equal(store.proofs.has('a1'), true);
    assert.equal(store.proofs.has('a2'), false);
  });

  it('purge deletes due proofs and their files only', async () => {
    const proof = (id: string, due: Date | null): AwardProof => ({
      awardId: id, photographerId: 'u1', files: [`awardProofs/u1/${id}/0.jpg`], links: [], purgeAfter: due,
    });
    store.seedProof(proof('a1', OLD));
    store.seedProof(proof('a2', new Date('2026-12-01T00:00:00.000Z')));
    seed('a3', 'pending');
    const n = await purgeDueProofs({
      ...deps,
      proofsDue: async (now) => [...store.proofs.values()].filter((p) => p.purgeAfter !== null && p.purgeAfter <= now),
    });
    assert.equal(n, 1);
    assert.equal(store.proofs.has('a1'), false);
    assert.equal(store.proofs.has('a2'), true);
    assert.equal(store.proofs.has('a3'), true);
    assert.deepEqual(deleted, [['awardProofs/u1/a1/0.jpg']]);
  });
});
