import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { beforeEach, describe, it } from 'node:test';
import { MemoryAwardStore, type Award, type AwardDeps } from '@photobooking/domain';
import {
  bucketNameFromEnv,
  formatWaiting,
  guardEnv,
  parseArgs,
  proofFileLines,
  proofModeFromEnv,
  runCli,
} from '../../tools/awards.js';

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
  let admin = true;
  const io = {
    isAdmin: async () => admin,
    print: (s: string) => void out.push(s),
    now: () => NOW,
    // Memory dry run: the queue comes from the store.
    listPending: async () => [...store.awards.values()].filter((a) => a.status === 'pending'),
    show: async (id: string) => {
      const a = store.awards.get(id) ?? null;
      return a === null
        ? null
        : { award: a, proof: store.proofs.get(id) ?? null, urls: showUrls, files: showFiles };
    },
  };
  let showFiles: string[] = [];
  let showUrls: string[] = [];

  beforeEach(() => {
    store = new MemoryAwardStore();
    out = [];
    admin = true;
    showFiles = [];
    showUrls = [];
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

  it('a non-admin actor is refused', async () => {
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    admin = false;
    await assert.rejects(() => runCli(['approve', A1, '--actor', 'p1'], deps(), io), /admin claim/);
    assert.equal(store.awards.get(A1)?.status, 'pending');
    assert.equal(store.audit.length, 0);
  });

  it('show without a bucket name explains how to set it', () => {
    assert.throws(() => bucketNameFromEnv({}), /set STORAGE_BUCKET/);
    assert.equal(bucketNameFromEnv({ FIREBASE_STORAGE_BUCKET: 'b' }), 'b');
    assert.equal(bucketNameFromEnv({ STORAGE_BUCKET: 'a', FIREBASE_STORAGE_BUCKET: 'b' }), 'a');
  });

  it('proofModeFromEnv: emulator only when FIREBASE_STORAGE_EMULATOR_HOST is set', () => {
    assert.equal(proofModeFromEnv({}), 'project');
    assert.equal(proofModeFromEnv({ FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199' }), 'emulator');
  });

  it('formatWaiting', () => {
    const at = (ms: number) => new Date(NOW.getTime() - ms);
    const min = 60_000;
    const h = 60 * min;
    assert.equal(formatWaiting(at(12 * min), NOW), 'waiting 12m');
    assert.equal(formatWaiting(at(5 * h + 3 * min), NOW), 'waiting 5h');
    assert.equal(formatWaiting(at(3 * 24 * h + 4 * h), NOW), 'waiting 3d 4h');
    assert.equal(formatWaiting(new Date(NOW.getTime() + h), NOW), 'waiting 0m');
  });

  it('list prints the waiting time after the timestamp', async () => {
    store.seedAward(award(A1, '2026-10-07T08:00:00.000Z'));
    await runCli(['list'], deps(), io);
    assert.equal(out[0], `${A1}  2026-10-07T08:00:00.000Z  waiting 3d 4h  p1  gold  2025  Sony World Photography`);
  });

  it('show prints project signed urls', async () => {
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    showUrls = ['https://signed/0'];
    await runCli(['show', A1], deps(), io);
    assert.ok(out.includes('file (15 min): https://signed/0'));
  });

  it('emulator show downloads files instead of signing', async () => {
    store.seedAward(award(A1, '2026-10-01T00:00:00Z'));
    showFiles = ['/tmp/x/0.jpg'];
    await runCli(['show', A1], deps(), io);
    assert.ok(out.includes('file: /tmp/x/0.jpg'));
    assert.ok(!out.some((l) => l.includes('(15 min)')));
  });

  const fakeBucket = (calls: string[]) => ({
    file: (name: string) => ({
      getSignedUrl: async () => (calls.push(`sign ${name}`), [`https://signed/${name}`] as [string]),
      download: async ({ destination }: { destination: string }) => void calls.push(`download ${name} -> ${destination}`),
    }),
  });

  it('proofFileLines signs in project mode and downloads (index-prefixed) in emulator mode', async () => {
    const calls: string[] = [];
    const dir = mkdtempSync(join(tmpdir(), 'awards-test-'));
    const d = { getBucket: () => fakeBucket(calls), downloadDir: join(dir, 'x'), now: () => 0 };
    assert.deepEqual(await proofFileLines('project', ['a/one.jpg'], d), ['file (15 min): https://signed/a/one.jpg']);
    assert.deepEqual(await proofFileLines('emulator', ['a/one.jpg', 'b/one.jpg'], d), [
      `file: ${join(dir, 'x', '0-one.jpg')}`,
      `file: ${join(dir, 'x', '1-one.jpg')}`,
    ]);
    assert.equal(calls.length, 3);
  });

  it('show without files needs no bucket', async () => {
    const d = {
      getBucket: (): never => assert.fail('the bucket must not be resolved without files'),
      downloadDir: join(tmpdir(), 'awards-never'),
      now: () => 0,
    };
    assert.deepEqual(await proofFileLines('emulator', [], d), []);
    assert.deepEqual(await proofFileLines('project', [], d), []);
  });

  it('emulator env with a remote host is refused', () => {
    assert.throws(
      () =>
        guardEnv({
          FIRESTORE_EMULATOR_HOST: '10.0.0.5:8080',
          FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
          GCLOUD_PROJECT: 'p',
        }),
      /must point at a local emulator/,
    );
    assert.throws(
      () =>
        guardEnv({
          FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
          FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
          FIREBASE_STORAGE_EMULATOR_HOST: 'storage.example.com:9199',
          GCLOUD_PROJECT: 'p',
        }),
      /must point at a local emulator/,
    );
    // Firestore and Auth local but no Storage emulator: mixed mode, refused.
    assert.throws(
      () => guardEnv({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', GCLOUD_PROJECT: 'p' }),
      /FIREBASE_STORAGE_EMULATOR_HOST must point at a local emulator/,
    );
    // A storage host alone also triggers the guard (Firestore and Auth then missing).
    assert.throws(() => guardEnv({ FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199', GCLOUD_PROJECT: 'p' }), /must point/);
  });

  it('guardEnv accepts local emulators and plain project env', () => {
    assert.doesNotThrow(() => guardEnv({}));
    assert.doesNotThrow(() => guardEnv({ GOOGLE_APPLICATION_CREDENTIALS: '/k.json', GCLOUD_PROJECT: 'real' }));
    assert.doesNotThrow(() =>
      guardEnv({
        FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
        FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
        FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
        GCLOUD_PROJECT: 'booking-c1922',
      }),
    );
  });
});
