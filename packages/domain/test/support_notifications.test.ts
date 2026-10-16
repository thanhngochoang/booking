import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { notifySupportMessage } from '../src/support_notifications.js';
import type { SupportMessage, SupportThread } from '../src/support_thread.js';
import { createNotifyWorld } from './support/notify_world.js';

describe('support_notifications', () => {
  const helpThread: SupportThread = {
    id: 'help_u1',
    kind: 'help',
    ownerId: 'u1',
    disputeId: null,
    participants: ['u1'],
    status: 'open',
    awaitingStaff: false,
    lastMessageAt: '2026-10-10T10:00:00.000Z',
    lastMessagePreview: 'Test',
    lastSenderRole: 'staff',
    rate: {},
    createdAt: '2026-10-10T10:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('a staff message in a help thread calls notifySupportReply for the owner', async () => {
    const world = createNotifyWorld();
    const staffMsg: SupportMessage = {
      id: 'm_staff',
      threadId: 'help_u1',
      senderId: 'staff1',
      senderRole: 'staff',
      senderName: 'Hỗ trợ',
      body: 'Chào bạn, chúng tôi đang xử lý.',
      createdAt: '2026-10-10T10:05:00.000Z',
    };

    await notifySupportMessage(world.deps, helpThread, staffMsg);

    const notifications = world.store.rowsOf('u1');
    assert.equal(notifications.length, 1);
    const n = notifications[0];
    assert.ok(n);
    assert.equal(n.target, '/help/chat');
    assert.equal(n.type, 'support_reply');
    assert.equal(n.title, 'Hỗ trợ đã trả lời');
    assert.equal(n.body, 'Chào bạn, chúng tôi đang xử lý.');
  });

  it('a user message notifies nobody', async () => {
    const world = createNotifyWorld();
    const userMsg: SupportMessage = {
      id: 'm_user',
      threadId: 'help_u1',
      senderId: 'u1',
      senderRole: 'user',
      senderName: 'Người Dùng Một',
      body: 'Tôi hỏi câu này.',
      createdAt: '2026-10-10T10:00:00.000Z',
    };

    await notifySupportMessage(world.deps, helpThread, userMsg);

    const notifications = world.store.rowsOf('u1');
    assert.equal(notifications.length, 0);
  });

  it('system messages notify nobody', async () => {
    const world = createNotifyWorld();
    const sysMsg: SupportMessage = {
      id: 'm_sys',
      threadId: 'help_u1',
      senderId: null,
      senderRole: 'system',
      senderName: 'Hệ thống',
      body: 'Hệ thống tự động.',
      createdAt: '2026-10-10T10:00:00.000Z',
    };

    await notifySupportMessage(world.deps, helpThread, sysMsg);

    const notifications = world.store.rowsOf('u1');
    assert.equal(notifications.length, 0);
  });
});
