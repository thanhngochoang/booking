import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { Award, AwardStatus } from '../src/award.js';
import type { AwardDeps } from '../src/award_ports.js';
import { createAward, deleteAward, reviewAward, updateAward } from '../src/award_use_cases.js';
import { DomainError } from '../src/errors.js';
import { MemoryAwardStore } from '../src/memory_award_store.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');
const OLD = new Date('2026-10-01T00:00:00.000Z');

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

describe('award use cases', () => {
  let store: MemoryAwardStore;
  let deps: AwardDeps;
  let deleted: string[][];
  let reviewed: Array<[string, string, AwardStatus]>;

  const input = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
    awardId: 'a1',
    competition: 'Vietnam Photo Awards',
    year: 2024,
    category: null,
    result: 'gold',
    workPostId: null,
    proofFiles: ['awardProofs/u1/a1/0.jpg'],
    proofLinks: [],
    ...over,
  });
  const award = (id: string, status: AwardStatus, over: Partial<Award> = {}): Award => ({
    id,
    photographerId: 'u1',
    competition: 'Vietnam Photo Awards',
    year: 2024,
    category: null,
    result: 'gold',
    workPostId: null,
    status,
    reviewNote: null,
    reviewedBy: null,
    reviewedAt: null,
    createdAt: OLD,
    updatedAt: OLD,
    ...over,
  });
  const seed = (id: string, status: AwardStatus): void => {
    store.seedAward(award(id, status));
    store.seedProof({
      awardId: id,
      photographerId: 'u1',
      files: [`awardProofs/u1/${id}/0.jpg`],
      links: [],
      purgeAfter: null,
    });
  };

  beforeEach(() => {
    store = new MemoryAwardStore();
    deleted = [];
    reviewed = [];
    store.seedTier('u1', { providerType: 'individual', artistSince: null, approvedAwardCount: 0 });
    deps = {
      awards: store,
      tiers: store.tiers,
      files: { delete: async (p) => void deleted.push([...p]) },
      notify: {
        tierChanged: async () => undefined,
        awardReviewed: async (u, a, s) => void reviewed.push([u, a, s]),
      },
      clock: { now: () => NOW },
    };
  });

  it('create stores a pending award and its proof', async () => {
    assert.deepEqual(await createAward(deps, 'u1', input()), { awardId: 'a1' });
    const a = store.awards.get('a1');
    assert.equal(a?.status, 'pending');
    assert.equal(a?.photographerId, 'u1');
    assert.deepEqual(store.proofs.get('a1')?.files, ['awardProofs/u1/a1/0.jpg']);
    assert.equal(store.proofs.get('a1')?.purgeAfter, null);
  });

  it('the 51st award is limit_exceeded', async () => {
    for (let i = 0; i < 50; i++) seed(`x${i}`, 'pending');
    await refused(createAward(deps, 'u1', input()), 'limit_exceeded');
    assert.equal(store.awards.has('a1'), false);
  });

  it('a work post of someone else is invalid', async () => {
    await refused(createAward(deps, 'u1', input({ workPostId: 'p1' })), 'invalid_argument');
    store.seedOwnPost('u1', 'p1');
    await createAward(deps, 'u1', input({ workPostId: 'p1' }));
    assert.equal(store.awards.get('a1')?.workPostId, 'p1');
  });

  it('editing an approved award re-queues it and recounts', async () => {
    for (const id of ['a1', 'a2', 'a3']) seed(id, 'approved');
    store.seedTier('u1', { providerType: 'artist', artistSince: OLD, approvedAwardCount: 3 });
    await updateAward(deps, 'u1', input({ year: 2023 }));
    assert.equal(store.awards.get('a1')?.status, 'pending');
    assert.equal(store.awards.get('a1')?.year, 2023);
    assert.equal(store.tierStates.get('u1')?.approvedAwardCount, 2);
    assert.equal(store.tierStates.get('u1')?.providerType, 'individual');
  });

  it('an approved award saved unchanged stays approved', async () => {
    seed('a1', 'approved');
    await updateAward(deps, 'u1', input());
    assert.equal(store.awards.get('a1')?.status, 'approved');
    assert.equal(store.writes, 0);
  });

  it('needs_info goes back to pending when the owner saves', async () => {
    store.seedAward(award('a1', 'needs_info', { reviewNote: 'thiếu ảnh' }));
    store.seedProof({ awardId: 'a1', photographerId: 'u1', files: ['awardProofs/u1/a1/0.jpg'], links: [], purgeAfter: null });
    await updateAward(deps, 'u1', input({ proofLinks: ['https://a.vn/x'] }));
    assert.equal(store.awards.get('a1')?.status, 'pending');
    assert.equal(store.awards.get('a1')?.reviewNote, null);
  });

  it('a revoked award cannot be edited', async () => {
    seed('a1', 'revoked');
    await refused(updateAward(deps, 'u1', input({ year: 2023 })), 'conflict');
  });

  it('someone else cannot edit or delete an award', async () => {
    seed('a1', 'pending');
    await refused(updateAward(deps, 'u2', input({ proofFiles: ['awardProofs/u2/a1/0.jpg'] })), 'permission_denied');
    await refused(deleteAward(deps, 'u2', { awardId: 'a1' }), 'permission_denied');
  });

  it('delete removes the award, proof doc and files', async () => {
    seed('a1', 'pending');
    await deleteAward(deps, 'u1', { awardId: 'a1' });
    assert.equal(store.awards.has('a1'), false);
    assert.equal(store.proofs.has('a1'), false);
    assert.deepEqual(deleted, [['awardProofs/u1/a1/0.jpg']]);
  });

  it('only admins review', async () => {
    seed('a1', 'pending');
    await refused(reviewAward(deps, 'u9', false, { awardId: 'a1', action: 'approve' }), 'permission_denied');
    assert.equal(store.awards.get('a1')?.status, 'pending');
  });

  it('needs_info without a note is invalid', async () => {
    seed('a1', 'pending');
    await refused(reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'needs_info' }), 'invalid_argument');
    await refused(reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'reject', note: 'ngắn' }), 'invalid_argument');
    await refused(reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'reject', note: 'x'.repeat(501) }), 'invalid_argument');
  });

  it('approve writes an audit row and a purge date', async () => {
    seed('a1', 'pending');
    assert.deepEqual(await reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'approve' }), { status: 'approved' });
    assert.deepEqual(store.audit, [{ awardId: 'a1', actorId: 'adm', action: 'approve', note: null, at: NOW }]);
    assert.equal(store.proofs.get('a1')?.purgeAfter?.toISOString(), '2026-11-04T10:00:00.000Z');
    assert.equal(store.awards.get('a1')?.reviewedBy, 'adm');
  });

  it('needs_info keeps proofs (no purge date) and stores the note', async () => {
    seed('a1', 'pending');
    await reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'needs_info', note: 'Thiếu giấy chứng nhận' });
    assert.equal(store.proofs.get('a1')?.purgeAfter, null);
    assert.equal(store.awards.get('a1')?.reviewNote, 'Thiếu giấy chứng nhận');
  });

  it('an illegal review move is a conflict and writes nothing', async () => {
    seed('a1', 'approved');
    await refused(reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'approve' }), 'conflict');
    assert.equal(store.audit.length, 0);
  });

  it('review notifies the owner', async () => {
    seed('a1', 'pending');
    await reviewAward(deps, 'adm', true, { awardId: 'a1', action: 'reject', note: 'Không đọc được ảnh' });
    assert.deepEqual(reviewed, [['u1', 'a1', 'rejected']]);
  });
});
