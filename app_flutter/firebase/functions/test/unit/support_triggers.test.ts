import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemorySupportStore,
  MemoryUserDirectory,
  type NotifyDeps,
  type SupportThread,
} from '@photobooking/domain';
import { handleSupportMessageCreated } from '../../src/triggers/support_message_created.js';

describe('support triggers', () => {
  let notifStore: MemoryNotificationStore;
  let supportStore: MemorySupportStore;
  let users: MemoryUserDirectory;
  let now: Date;

  function mockNotifyDeps(): NotifyDeps {
    return {
      store: notifStore,
      push: new MemoryPushSender(),
      users,
      clock: { now: () => now },
    };
  }

  beforeEach(() => {
    notifStore = new MemoryNotificationStore();
    supportStore = new MemorySupportStore();
    users = new MemoryUserDirectory();
    users.users.set('u1', { name: 'User One', avatarUrl: null });
    users.users.set('staff_1', { name: 'Hỗ trợ', avatarUrl: null });
    now = new Date('2026-10-10T12:00:00.000Z');
  });

  it('support_reply for a staff message, nothing for a user or system message', async () => {
    const thread: SupportThread = {
      id: 'help_u1',
      kind: 'help',
      ownerId: 'u1',
      disputeId: null,
      participants: ['u1'],
      status: 'open',
      awaitingStaff: false,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Reply from staff',
      lastSenderRole: 'staff',
      rate: {},
      createdAt: '2026-10-10T11:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };
    await supportStore.runTransaction(async (tx) => {
      tx.putThread(thread);
    });

    const notifyDeps = mockNotifyDeps();

    // 1. User message -> skipped, no notify
    const resUser = await handleSupportMessageCreated(
      {
        threadId: 'help_u1',
        messageId: 'msg_u',
        messageData: {
          senderId: 'u1',
          senderRole: 'user',
          senderName: 'User One',
          body: 'Hello support',
          createdAt: '2026-10-10T11:59:00.000Z',
        },
      },
      { notify: notifyDeps, store: supportStore },
    );
    assert.equal(resUser, 'skipped');
    assert.equal(notifStore.rowsOf('u1').length, 0);

    // 2. System message -> skipped, no notify
    const resSys = await handleSupportMessageCreated(
      {
        threadId: 'help_u1',
        messageId: 'msg_s',
        messageData: {
          senderId: null,
          senderRole: 'system',
          senderName: 'System',
          body: 'System update',
          createdAt: '2026-10-10T11:59:30.000Z',
        },
      },
      { notify: notifyDeps, store: supportStore },
    );
    assert.equal(resSys, 'skipped');
    assert.equal(notifStore.rowsOf('u1').length, 0);

    // 3. Staff message -> sent, notifies owner u1
    const resStaff = await handleSupportMessageCreated(
      {
        threadId: 'help_u1',
        messageId: 'msg_staff',
        messageData: {
          senderId: 'staff_1',
          senderRole: 'staff',
          senderName: 'Hỗ trợ',
          body: 'Chung toi da kiem tra va xu ly',
          createdAt: '2026-10-10T12:00:00.000Z',
        },
      },
      { notify: notifyDeps, store: supportStore },
    );
    assert.equal(resStaff, 'sent');
    const rows = notifStore.rowsOf('u1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'support_reply');
    assert.equal(rows[0]?.target, '/help/chat');
    assert.equal(rows[0]?.id, 'n_support_reply_msg_staff');
  });

  it('dispute_message for a party message in a dispute thread', async () => {
    users.users.set('c1', { name: 'An', avatarUrl: null });
    users.users.set('p1', { name: 'Minh Trí', avatarUrl: null });
    const thread: SupportThread = {
      id: 'dispute_d1',
      kind: 'dispute',
      ownerId: null,
      disputeId: 'd1',
      participants: ['c1', 'p1'],
      status: 'open',
      awaitingStaff: true,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Tôi đã gửi lại link',
      lastSenderRole: 'provider',
      rate: {},
      createdAt: '2026-10-10T11:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };
    await supportStore.runTransaction(async (tx) => {
      tx.putThread(thread);
    });

    const res = await handleSupportMessageCreated(
      {
        threadId: 'dispute_d1',
        messageId: 'msg_p1',
        messageData: {
          senderId: 'p1',
          senderRole: 'provider',
          senderName: 'Minh Trí',
          body: 'Tôi đã gửi lại link',
          createdAt: '2026-10-10T12:00:00.000Z',
        },
      },
      { notify: mockNotifyDeps(), store: supportStore },
    );

    assert.equal(res, 'sent');
    const rows = notifStore.rowsOf('c1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'dispute_message');
    assert.equal(rows[0]?.target, '/disputes/d1');
    assert.equal(rows[0]?.title, 'Minh Trí nhắn trong khiếu nại');
    // The sender hears nothing about their own message.
    assert.equal(notifStore.rowsOf('p1').length, 0);
  });

  it('a retry of the same event writes no second row (dedupe)', async () => {
    const thread: SupportThread = {
      id: 'help_u1',
      kind: 'help',
      ownerId: 'u1',
      disputeId: null,
      participants: ['u1'],
      status: 'open',
      awaitingStaff: false,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Reply from staff',
      lastSenderRole: 'staff',
      rate: {},
      createdAt: '2026-10-10T11:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };
    await supportStore.runTransaction(async (tx) => {
      tx.putThread(thread);
    });

    const notifyDeps = mockNotifyDeps();

    const event = {
      threadId: 'help_u1',
      messageId: 'msg_staff_1',
      messageData: {
        senderId: 'staff_1',
        senderRole: 'staff',
        senderName: 'Hỗ trợ',
        body: 'Tra loi ho tro',
        createdAt: '2026-10-10T12:00:00.000Z',
      },
    };

    await handleSupportMessageCreated(event, { notify: notifyDeps, store: supportStore });
    assert.equal(notifStore.rowsOf('u1').length, 1);

    await handleSupportMessageCreated(event, { notify: notifyDeps, store: supportStore });
    assert.equal(notifStore.rowsOf('u1').length, 1); // Dedupe prevents second notification
  });
});
