import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { SupportMessage, SupportThread } from '@photobooking/domain';
import {
  supportMessageFromFirestore,
  supportMessageToFirestore,
  supportThreadFromFirestore,
  supportThreadToFirestore,
} from '../../src/infra/support_firestore.js';

describe('support firestore mapping', () => {
  it('support message mapping keeps senderRole and senderName', () => {
    const original: SupportMessage = {
      id: 'msg_1',
      threadId: 'help_u1',
      senderId: 'u1',
      senderRole: 'customer',
      senderName: 'Nguyen Van A',
      body: 'Toi can ho tro ve thanh toan',
      createdAt: '2026-10-10T12:00:00.000Z',
    };

    const doc = supportMessageToFirestore(original);
    assert.equal(doc.id, 'msg_1');
    assert.equal(doc.senderRole, 'customer');
    assert.equal(doc.senderName, 'Nguyen Van A');
    assert.ok(doc.createdAt instanceof Timestamp);

    const roundtrip = supportMessageFromFirestore(doc);
    assert.deepEqual(roundtrip, original);
  });

  it('thread round-trips (Timestamps ↔ ISO)', () => {
    const thread: SupportThread = {
      id: 'help_u1',
      kind: 'help',
      ownerId: 'u1',
      disputeId: null,
      participants: ['u1'],
      status: 'open',
      awaitingStaff: true,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Xin chao',
      lastSenderRole: 'user',
      rate: {
        u1: {
          windowStart: '2026-10-10T12:00:00.000Z',
          count: 1,
        },
      },
      createdAt: '2026-10-10T11:50:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };

    const doc = supportThreadToFirestore(thread);
    assert.ok(doc.lastMessageAt instanceof Timestamp);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.ok(doc.rate.u1.windowStart instanceof Timestamp);

    const roundtrip = supportThreadFromFirestore(doc);
    assert.deepEqual(roundtrip, thread);
  });
});
