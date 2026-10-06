import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { MemoryAwardStore, type Award, type AwardDeps } from '@photobooking/domain';
import { parseArgs, runCli } from '../../tools/awards.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');
const A1 = '01ARZ3NDEKTSV4RRFFQ69G5F01';
const A2 = '01ARZ3NDEKTSV4RRFFQ69G5F02';

const award = (id: string, createdAt: string, over: Partial<Award> = {}): Award => ({
  id,
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
  createdAt: new Date(createdAt),
  updatedAt: new Date(createdAt),
  ...over,
});

describe('awards staff CLI', () => {
  let store: MemoryAwardStore;
  let out: string[];

  const deps = (): AwardDeps => ({
    awards: store,
    tiers: store.tiers,
    files: { delete: async () => {} },
    notify: { tierChanged: async () => {}, awardReviewed: async () => {} },
    clock: { now: () => NOW },
  });
  const io = {
    print: (s: string) => void out.push(s),
    // Memory dry run: the queue comes from the store.
    listPending: async () => [...store.awards.values()].filter((a) => a.status === 'pending'),
    show: async (id: string) => {
      const a = store.awards.get(id) ?? null;
      return a === null ? null : { award: a, proof: store.proofs.get(id) ?? null, urls: [] as string[] };
    },
  };

  beforeEach(() => {
    store = new MemoryAwardStore();
    out = [];
    store.seedTier('p1', { providerType: 'individual', artistSince: null, approvedAwardCount: 0 });
  });

  it('parses a decision with its note and actor', () => {
    assert.deepEqual(parseArgs(['reject', A1, 'Không đủ minh chứng', '--actor', 'staff1']), {
      command: 'reject',
      awardId: A1,
      note: 'Không đủ minh chứng',
      actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['list']), { command: 'list', awardId: null, note: null, actor: null });
  });

  it('rejects unknown commands and missing ids or notes', () => {
    assert.throws(() => parseArgs(['frobnicate']), /usage/i);
    assert.throws(() => parseArgs(['show']), /usage/i);
    assert.throws(() => parseArgs(['reject', A1, '--actor', 'staff1']), /note/i);
  });

  it('approve needs --actor', async () => {
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    await assert.rejects(() => runCli(['approve', A1], deps(), io), /--actor/);
    assert.equal(store.awards.get(A1)?.status, 'pending');
  });

  it('list prints pending awards oldest first', async () => {
    store.seedAward(award(A2, '2026-10-05T00:00:00Z'));
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    store.seedAward(award('01ARZ3NDEKTSV4RRFFQ69G5F03', '2026-09-01T00:00:00Z', { status: 'approved' }));
    await runCli(['list'], deps(), io);
    assert.equal(out.length, 2);
    assert.ok(out[0]?.includes(A1));
    assert.ok(out[1]?.includes(A2));
  });

  it('dry run: approve goes through the same use case', async () => {
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    await runCli(['approve', A1, '--actor', 'staff1'], deps(), io);
    assert.equal(store.awards.get(A1)?.status, 'approved');
    assert.equal(store.audit[0]?.actorId, 'staff1');
    assert.equal(store.tierStates.get('p1')?.approvedAwardCount, 1);
  });
});
