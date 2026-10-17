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

import {
  blockIndexFromFirestore,
  blockIndexToFirestore,
  blockRecordFromFirestore,
  blockRecordToFirestore,
  reportFromFirestore,
  reportToFirestore,
} from '../../src/infra/safety_firestore.js';

describe('safety_firestore mappings', () => {
  test('block record and index mapping', () => {
    const record = {
      blockerId: 'u1',
      blockedId: 'u2',
      blockedName: 'User Two',
      blockedAvatarUrl: 'https://img.test/u2.jpg',
      source: 'menu' as const,
      createdAt: '2026-10-07T10:00:00.000Z',
    };
    const fDoc = blockRecordToFirestore(record);
    const roundTripped = blockRecordFromFirestore(fDoc);
    assert.deepEqual(roundTripped, record);

    const index = {
      blockedIds: ['u2', 'u3'],
      blockedByIds: ['u4'],
    };
    const idxDoc = blockIndexToFirestore(index, '2026-10-07T10:00:00.000Z');
    const idxRoundTripped = blockIndexFromFirestore(idxDoc);
    assert.deepEqual(idxRoundTripped, index);
  });

  test('blockUser writes the record at the path FirestoreBlockGate reads', () => {
    assert.equal(
      `blocks/${blockRecordToFirestore({ blockerId: 'u1', blockedId: 'u2', blockedName: 'U2', blockedAvatarUrl: null, source: 'menu', createdAt: '' }).blockerId}_${blockRecordToFirestore({ blockerId: 'u1', blockedId: 'u2', blockedName: 'U2', blockedAvatarUrl: null, source: 'menu', createdAt: '' }).blockedId}`,
      'blocks/u1_u2',
    );
  });

  test('report mapping keeps the snapshot', () => {
    const report = {
      id: 'rep_1',
      reporterId: 'u1',
      targetType: 'post' as const,
      targetId: 'p1',
      chatId: null,
      targetOwnerId: 'u2',
      reason: 'scam' as const,
      text: 'Lừa đảo',
      blocked: true,
      snapshot: {
        name: null,
        excerpt: 'Chuyển khoản nhé',
        imageUrl: 'https://img.test/p1.jpg',
      },
      status: 'open' as const,
      staffNote: null,
      decidedBy: null,
      decidedAt: null,
      createdAt: '2026-10-07T10:00:00.000Z',
    };
    const fDoc = reportToFirestore(report);
    const roundTripped = reportFromFirestore(fDoc);
    assert.deepEqual(roundTripped, report);
  });
});
