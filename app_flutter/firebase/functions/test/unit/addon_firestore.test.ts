import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { saveAddon, deleteAddon, type ServiceAddon } from '@photobooking/domain';
import { addonFromFirestore, addonToFirestore, FirestoreAddonStore } from '../../src/infra/addon_firestore.js';

const full: ServiceAddon = {
  id: '01ARZ3NDEKTSV4RRFFQ69G5FA1',
  providerId: 'p1',
  kind: 'makeup',
  name: 'Trang điểm',
  description: 'Trang điểm tự nhiên, làm tóc cơ bản',
  price: 800_000,
  unit: 'per_person',
  maxQty: 4,
  serviceIds: ['s1', 's2'],
  active: true,
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-02T00:00:00.000Z',
};

describe('addon Firestore conversion', () => {
  it('addon round-trips through Firestore conversion', () => {
    const d = addonToFirestore(full);
    assert.equal('providerId' in d, false);
    assert.ok(d.createdAt instanceof Timestamp);
    assert.ok(d.updatedAt instanceof Timestamp);
    assert.deepEqual(addonFromFirestore('p1', full.id, d), full);
  });

  it('a description that is absent stays absent', () => {
    const { description: _d, ...bare } = full;
    const d = addonToFirestore(bare);
    assert.equal('description' in d, false);
    const back = addonFromFirestore('p1', full.id, d);
    assert.ok(back);
    assert.equal('description' in back, false);
  });

  it('a document with an unknown kind or unit maps to null', () => {
    const d = addonToFirestore(full);
    assert.equal(addonFromFirestore('p1', full.id, { ...d, kind: 'spa' }), null);
    assert.equal(addonFromFirestore('p1', full.id, { ...d, unit: 'per_hour' }), null);
    assert.equal(addonFromFirestore('p1', full.id, undefined), null);
  });
});

/** A tiny Firestore: documents by path, transactions record every get and write in order. */
function fakeFirestore(docs: Record<string, Record<string, unknown>>): { firestore: Firestore; log: string[] } {
  const log: string[] = [];
  const ref = (path: string): Record<string, unknown> => ({
    path,
    collection: (n: string) => ref(`${path}/${n}`),
    doc: (id: string) => ref(`${path}/${id}`),
  });
  const firestore = {
    collection: (n: string) => ref(n),
    runTransaction: async (fn: (tx: unknown) => Promise<unknown>) => {
      const tx = {
        get: async (r: { path: string }) => {
          log.push(`get ${r.path}`);
          if (r.path.endsWith('/addons') && r.path.split('/').length === 3) {
            const prefix = `${r.path}/`;
            return {
              docs: Object.entries(docs)
                .filter(([p]) => p.startsWith(prefix))
                .map(([p, data]) => ({ id: p.slice(prefix.length), data: () => data })),
            };
          }
          const data = docs[r.path];
          return { exists: data !== undefined, id: r.path.split('/').pop(), data: () => data };
        },
        set: (r: { path: string }) => {
          log.push(`set ${r.path}`);
        },
        delete: (r: { path: string }) => {
          log.push(`delete ${r.path}`);
        },
      };
      return fn(tx);
    },
  } as unknown as Firestore;
  return { firestore, log };
}

describe('FirestoreAddonStore', () => {
  const docs = {
    'photographers/p1': { onboardingComplete: true },
    'users/p1': { role: 'photographer' },
    'photographers/p1/addons/01ARZ3NDEKTSV4RRFFQ69G5FA1': addonToFirestore(full),
  };
  const deps = (firestore: Firestore) => ({
    addons: new FirestoreAddonStore(firestore),
    services: { getService: async (_p: string, id: string) => ({ id, photographerId: 'p1', name: 'x', price: 1, durationMinutes: 60, active: true }) },
    clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
    ids: { newId: () => '01ARZ3NDEKTSV4RRFFQ69G5FA9' },
  });
  const input = { kind: 'outfit', name: 'Thuê áo dài', price: 250_000, unit: 'per_item', maxQty: 4, serviceIds: [], active: true };

  it('FirestoreAddonStore reads and writes private/addons in every transaction', async () => {
    const save = fakeFirestore(docs);
    await saveAddon(deps(save.firestore), 'p1', input);
    const lock = 'photographers/p1/private/addons';
    assert.ok(save.log.includes(`get ${lock}`));
    assert.ok(save.log.includes(`set ${lock}`));
    assert.ok(save.log.includes('set photographers/p1/addons/01ARZ3NDEKTSV4RRFFQ69G5FA9'));
    // every read comes before the first write
    const firstWrite = save.log.findIndex((l) => l.startsWith('set ') || l.startsWith('delete '));
    assert.ok(save.log.slice(firstWrite).every((l) => !l.startsWith('get ')));

    const del = fakeFirestore(docs);
    await deleteAddon(deps(del.firestore), 'p1', { addonId: full.id });
    assert.ok(del.log.includes(`get ${lock}`));
    assert.ok(del.log.includes(`set ${lock}`));
    assert.ok(del.log.includes(`delete photographers/p1/addons/${full.id}`));
  });

  it('a user that is not a photographer is not a provider', async () => {
    const f = fakeFirestore({ ...docs, 'users/p1': { role: 'customer' } });
    await assert.rejects(() => saveAddon(deps(f.firestore), 'p1', input), (e: unknown) => (e as Error).message === 'permission_denied');
    assert.equal(f.log.some((l) => l.startsWith('set ')), false);
  });
});
