import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import type { Firestore } from 'firebase-admin/firestore';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';

/** A Firestore whose `blocks/*` documents are exactly the paths in `existing`; records every getAll. */
function fakeFirestore(existing: string[]): { firestore: Firestore; getAllCalls: string[][] } {
  const present = new Set(existing);
  const getAllCalls: string[][] = [];
  const firestore = {
    doc: (path: string) => ({ path }),
    getAll: async (...refs: { path: string }[]) => {
      getAllCalls.push(refs.map((r) => r.path));
      return refs.map((r) => ({ exists: present.has(r.path) }));
    },
  } as unknown as Firestore;
  return { firestore, getAllCalls };
}

describe('FirestoreBlockGate', () => {
  test('FirestoreBlockGate is false when neither document exists', async () => {
    const { firestore } = fakeFirestore([]);
    assert.equal(await new FirestoreBlockGate(firestore).isBlockedEitherWay('c1', 'p1'), false);
  });

  test('FirestoreBlockGate is true for either document', async () => {
    const a = fakeFirestore(['blocks/c1_p1']);
    assert.equal(await new FirestoreBlockGate(a.firestore).isBlockedEitherWay('c1', 'p1'), true);
    const b = fakeFirestore(['blocks/p1_c1']);
    assert.equal(await new FirestoreBlockGate(b.firestore).isBlockedEitherWay('c1', 'p1'), true);
  });

  test('FirestoreBlockGate reads both documents in one getAll', async () => {
    const { firestore, getAllCalls } = fakeFirestore([]);
    await new FirestoreBlockGate(firestore).isBlockedEitherWay('c1', 'p1');
    assert.deepEqual(getAllCalls, [['blocks/c1_p1', 'blocks/p1_c1']]);
  });
});
