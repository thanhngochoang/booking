import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import { isInquiryClosed } from '../src/chat.js';
import { openInquiry } from '../src/open_inquiry.js';
import { sendMessage } from '../src/send_message.js';
import { createChatWorld } from './support/chat_world.js';

describe('sendMessage (Task 2)', () => {
  it('sends text, image and location messages and moves the preview', async () => {
    const { deps, clock } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    // Text
    const m1 = await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Gói chụp bao gồm những gì?', clientId: 'client_msg_1' },
    });
    assert.equal(m1.id, 'client_msg_1');
    assert.equal(m1.type, 'text');
    assert.equal(m1.body, 'Gói chụp bao gồm những gì?');

    let chat = await deps.chats.runTransaction(async (tx) => tx.getChat(chatId));
    assert.ok(chat);
    assert.equal(chat.lastMessagePreview, 'Gói chụp bao gồm những gì?');
    assert.equal(chat.lastSenderId, 'cust1');

    // Image from photographer
    clock.advance(1000);
    const m2 = await sendMessage(deps, {
      senderId: 'phot1',
      chatId,
      message: {
        type: 'image',
        imagePath: 'chats/cust1_phot1/phot1/sample.webp',
        clientId: 'client_msg_2',
      },
    });
    assert.equal(m2.id, 'client_msg_2');
    assert.equal(m2.type, 'image');
    assert.equal(m2.imagePath, 'chats/cust1_phot1/phot1/sample.webp');

    chat = await deps.chats.runTransaction(async (tx) => tx.getChat(chatId));
    assert.ok(chat);
    assert.equal(chat.lastMessagePreview, 'Ảnh');
    assert.equal(chat.lastSenderId, 'phot1');

    // Location from customer
    clock.advance(1000);
    const m3 = await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: {
        type: 'location',
        point: { lat: 10.76, lng: 106.66 },
        clientId: 'client_msg_3',
      },
    });
    assert.equal(m3.id, 'client_msg_3');
    assert.equal(m3.type, 'location');
    assert.deepEqual(m3.point, { lat: 10.76, lng: 106.66 });

    chat = await deps.chats.runTransaction(async (tx) => tx.getChat(chatId));
    assert.ok(chat);
    assert.equal(chat.lastMessagePreview, 'Vị trí');
    assert.equal(chat.lastSenderId, 'cust1');
  });

  it('the other member\'s unread count goes up by one per message', async () => {
    const { deps, chats } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    assert.equal(chats.unread.get(chatId)?.get('cust1'), 0);
    assert.equal(chats.unread.get(chatId)?.get('phot1'), 0);

    // Customer sends message -> photographer unread = 1, customer unread = 0
    await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 1', clientId: 'c_1' },
    });
    assert.equal(chats.unread.get(chatId)?.get('phot1'), 1);
    assert.equal(chats.unread.get(chatId)?.get('cust1'), 0);

    // Customer sends another -> photographer unread = 2
    await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 2', clientId: 'c_2' },
    });
    assert.equal(chats.unread.get(chatId)?.get('phot1'), 2);
    assert.equal(chats.unread.get(chatId)?.get('cust1'), 0);

    // Photographer sends message -> customer unread = 1, photographer unread = 2
    await sendMessage(deps, {
      senderId: 'phot1',
      chatId,
      message: { type: 'text', body: 'Photographer reply', clientId: 'p_1' },
    });
    assert.equal(chats.unread.get(chatId)?.get('cust1'), 1);
    assert.equal(chats.unread.get(chatId)?.get('phot1'), 2);
  });

  it('the fourth customer message before a reply is refused, also when two arrive together', async () => {
    const { deps } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    // Customer sends 1, 2, 3
    await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 1', clientId: 'c_1' },
    });
    await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 2', clientId: 'c_2' },
    });

    // Currently at counter = 2
    // Send two concurrent messages (c_3 and c_4)
    const p1 = sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 3a', clientId: 'c_3a' },
    });
    const p2 = sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Msg 3b', clientId: 'c_3b' },
    });

    const results = await Promise.allSettled([p1, p2]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');

    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    const reason = (rejected[0] as PromiseRejectedResult).reason;
    assert.ok(reason instanceof DomainError && reason.code === 'limit_exceeded');

    // A further 4th attempt is consistently refused
    await assert.rejects(
      () =>
        sendMessage(deps, {
          senderId: 'cust1',
          chatId,
          message: { type: 'text', body: 'Msg 4', clientId: 'c_4' },
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'limit_exceeded',
    );
  });

  it('a photographer reply lifts the limit for good', async () => {
    const { deps } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    for (let i = 1; i <= 3; i++) {
      await sendMessage(deps, {
        senderId: 'cust1',
        chatId,
        message: { type: 'text', body: `Msg ${i}`, clientId: `c_${i}` },
      });
    }

    // Photographer replies
    await sendMessage(deps, {
      senderId: 'phot1',
      chatId,
      message: { type: 'text', body: 'Chào bạn, mình đã xem câu hỏi', clientId: 'p_1' },
    });

    // Customer can now send messages 4, 5, 6 freely
    for (let i = 4; i <= 6; i++) {
      const msg = await sendMessage(deps, {
        senderId: 'cust1',
        chatId,
        message: { type: 'text', body: `Msg ${i}`, clientId: `c_${i}` },
      });
      assert.equal(msg.id, `c_${i}`);
    }
  });

  it('a retried clientId returns the existing message', async () => {
    const { deps, chats } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    const m1 = await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'First attempt', clientId: 'retry_c_1' },
    });

    const unreadBefore = chats.unread.get(chatId)?.get('phot1');
    assert.equal(unreadBefore, 1);

    // Retry with the same clientId (e.g. after network timeout)
    const m2 = await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'First attempt', clientId: 'retry_c_1' },
    });

    assert.equal(m2.id, m1.id);
    assert.equal(m2.body, m1.body);
    // Unread count was NOT incremented again
    assert.equal(chats.unread.get(chatId)?.get('phot1'), 1);
  });

  it('an outsider cannot send', async () => {
    const { deps } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    await assert.rejects(
      () =>
        sendMessage(deps, {
          senderId: 'stranger',
          chatId,
          message: { type: 'text', body: 'Spam', clientId: 'stranger_1' },
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );
  });

  it('sending into a read-only booking chat is refused', async () => {
    const { deps, clock } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    // Mark chat readOnlyAt
    const now = clock.now();
    await deps.chats.runTransaction(async (tx) => {
      const c = await tx.getChat(chatId);
      assert.ok(c);
      tx.setChat({
        ...c,
        kind: 'booking',
        bookingId: 'b_123',
        readOnlyAt: now,
      });
    });

    await assert.rejects(
      () =>
        sendMessage(deps, {
          senderId: 'cust1',
          chatId,
          message: { type: 'text', body: 'Hello?', clientId: 'c_after_ro' },
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );
  });

  it('sending reopens a closed inquiry', async () => {
    const { deps, clock } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    await sendMessage(deps, {
      senderId: 'cust1',
      chatId,
      message: { type: 'text', body: 'Hello', clientId: 'c_1' },
    });

    // Advance clock 15 days (> 14 days)
    clock.advance(15 * 24 * 60 * 60 * 1000);

    let chat = await deps.chats.runTransaction(async (tx) => tx.getChat(chatId));
    assert.ok(chat);
    assert.equal(isInquiryClosed(chat, clock.now()), true);

    // Photographer or customer sends a message -> reopens the chat
    await sendMessage(deps, {
      senderId: 'phot1',
      chatId,
      message: { type: 'text', body: 'Hi, I was away', clientId: 'p_reopen' },
    });

    chat = await deps.chats.runTransaction(async (tx) => tx.getChat(chatId));
    assert.ok(chat);
    assert.equal(isInquiryClosed(chat, clock.now()), false);
  });
});
