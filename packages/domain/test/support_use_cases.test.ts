import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { sendSupportMessage, staffReply } from '../src/support_use_cases.js';
import { createSupportWorld } from './support/support_world.js';
import { isDomainError } from '../src/errors.js';

describe('support_use_cases', () => {
  it('first help message creates help_{uid} with the sender as participant and awaitingStaff true', async () => {
    const world = createSupportWorld();
    const res = await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c1',
      text: 'Tôi cần hỗ trợ',
    });

    assert.equal(res.threadId, 'help_u1');
    assert.equal(res.messageId, 'c1');

    const thread = world.store.threads.get('help_u1');
    assert.ok(thread);
    assert.equal(thread.kind, 'help');
    assert.equal(thread.ownerId, 'u1');
    assert.deepEqual(thread.participants, ['u1']);
    assert.equal(thread.status, 'open');
    assert.equal(thread.awaitingStaff, true);
    assert.equal(thread.lastMessagePreview, 'Tôi cần hỗ trợ');
    assert.equal(thread.lastSenderRole, 'user');

    const msgs = await world.store.listMessages('help_u1', 10);
    assert.equal(msgs.length, 1);
    const firstMsg = msgs[0];
    assert.ok(firstMsg);
    assert.equal(firstMsg.id, 'c1');
    assert.equal(firstMsg.senderId, 'u1');
    assert.equal(firstMsg.senderRole, 'user');
    assert.equal(firstMsg.senderName, 'Người Dùng Một');
    assert.equal(firstMsg.body, 'Tôi cần hỗ trợ');
  });

  it('same clientId twice writes one message', async () => {
    const world = createSupportWorld();
    const res1 = await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c1',
      text: 'Lần 1',
    });
    const res2 = await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c1',
      text: 'Lần 1 gửi lại',
    });

    assert.equal(res1.messageId, 'c1');
    assert.equal(res2.messageId, 'c1');

    const msgs = await world.store.listMessages('help_u1', 10);
    assert.equal(msgs.length, 1);
    const firstMsg = msgs[0];
    assert.ok(firstMsg);
    assert.equal(firstMsg.body, 'Lần 1');
  });

  it('another user\'s help thread → permission_denied', async () => {
    const world = createSupportWorld();
    await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c1',
      text: 'u1 nhắn',
    });

    await assert.rejects(
      async () => {
        await sendSupportMessage(world.deps, 'u2', {
          threadId: 'help_u1',
          clientId: 'c2',
          text: 'u2 cố tình nhắn vào thread của u1',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'permission_denied',
    );
  });

  it('11th message in 10 minutes → limit_exceeded, the window restarts after 10 minutes', async () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const world = createSupportWorld(now);

    // Send 10 messages within 10 minutes
    for (let i = 1; i <= 10; i++) {
      await sendSupportMessage(world.deps, 'u1', {
        clientId: `c_${i}`,
        text: `Tin nhắn ${i}`,
      });
    }

    // 11th message within the same window throws limit_exceeded
    await assert.rejects(
      async () => {
        await sendSupportMessage(world.deps, 'u1', {
          clientId: 'c_11',
          text: 'Tin nhắn 11',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'limit_exceeded',
    );

    // Advance clock past 10 minutes
    world.clock.advanceMinutes(11);

    // Now send succeeds again
    const res = await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c_after_window',
      text: 'Tin nhắn sau 10 phút',
    });
    assert.equal(res.messageId, 'c_after_window');
  });

  it('staffReply writes senderName Hỗ trợ, role staff, awaitingStaff false', async () => {
    const world = createSupportWorld();
    await sendSupportMessage(world.deps, 'u1', {
      clientId: 'c1',
      text: 'Cần hỗ trợ',
    });

    const threadBefore = world.store.threads.get('help_u1');
    assert.ok(threadBefore);
    assert.equal(threadBefore.awaitingStaff, true);

    world.clock.advanceMinutes(1);

    const replyRes = await staffReply(world.deps, 'staff1', {
      threadId: 'help_u1',
      text: 'Chào bạn, chúng tôi có thể giúp gì?',
    });

    assert.equal(replyRes.threadId, 'help_u1');
    const threadAfter = world.store.threads.get('help_u1');
    assert.ok(threadAfter);
    assert.equal(threadAfter.awaitingStaff, false);
    assert.equal(threadAfter.lastSenderRole, 'staff');
    assert.equal(threadAfter.lastMessagePreview, 'Chào bạn, chúng tôi có thể giúp gì?');

    const msgs = await world.store.listMessages('help_u1', 10);
    assert.equal(msgs.length, 2);
    // newest first
    const staffMsg = msgs[0];
    assert.ok(staffMsg);
    assert.equal(staffMsg.id, replyRes.messageId);
    assert.equal(staffMsg.senderRole, 'staff');
    assert.equal(staffMsg.senderName, 'Hỗ trợ');
    assert.equal(staffMsg.body, 'Chào bạn, chúng tôi có thể giúp gì?');
  });

  it('text over 1000 graphemes or blank → invalid_argument', async () => {
    const world = createSupportWorld();

    await assert.rejects(
      async () => {
        await sendSupportMessage(world.deps, 'u1', {
          clientId: 'c_empty',
          text: '   ',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );

    const tooLong = 'a'.repeat(1001);
    await assert.rejects(
      async () => {
        await sendSupportMessage(world.deps, 'u1', {
          clientId: 'c_too_long',
          text: tooLong,
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'invalid_argument',
    );
  });

  it('a dispute thread id → not_found (no dispute support yet)', async () => {
    const world = createSupportWorld();
    // Simulate an existing dispute thread in the store
    world.store.threads.set('dispute_123', {
      id: 'dispute_123',
      kind: 'dispute',
      ownerId: 'u1',
      disputeId: '123',
      participants: ['u1', 'p1'],
      status: 'open',
      awaitingStaff: true,
      lastMessageAt: null,
      lastMessagePreview: null,
      lastSenderRole: null,
      rate: {},
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    await assert.rejects(
      async () => {
        await sendSupportMessage(world.deps, 'u1', {
          threadId: 'dispute_123',
          clientId: 'c_disp',
          text: 'Nhắn vào dispute',
        });
      },
      (err: unknown) => isDomainError(err) && err.code === 'not_found',
    );
  });
});
