import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import { type NotificationRow } from '@photobooking/domain';
import { notificationRowFromFirestore, notificationRowToFirestore } from '../../src/infra/notification_firestore.js';

const row: NotificationRow = {
  id: 'g_chat_c1',
  userId: 'u1',
  type: 'chat_message',
  tab: 'system',
  category: 'chat',
  title: 'An',
  body: '2 tin nhắn mới',
  target: '/chat/c1',
  groupKey: 'chat:c1',
  actors: [{ id: 'a', name: 'An', avatarUrl: null }],
  count: 2,
  thumbUrl: null,
  lastEventId: 'm2',
  createdAt: new Date('2026-10-10T10:00:00.000Z'),
  readAt: null,
};

describe('notification row mapping', () => {
  it('row doc maps to NotificationRow and back', () => {
    const doc = notificationRowToFirestore(row);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.equal(doc.readAt, null);
    assert.equal('userId' in doc, false);
    assert.deepEqual(notificationRowFromFirestore('u1', row.id, doc), row);

    const read = { ...row, readAt: new Date('2026-10-11T01:00:00.000Z') };
    assert.deepEqual(notificationRowFromFirestore('u1', row.id, notificationRowToFirestore(read)), read);
  });

  it('a doc without createdAt is not a row', () => {
    assert.equal(notificationRowFromFirestore('u1', 'x', { title: 't' }), null);
    assert.equal(notificationRowFromFirestore('u1', 'x', undefined), null);
  });
});
