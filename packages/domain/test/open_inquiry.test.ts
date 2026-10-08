import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import type { Chat, Message } from '../src/chat.js';
import { openInquiry } from '../src/open_inquiry.js';
import { createChatWorld } from './support/chat_world.js';

describe('openInquiry (Task 2)', () => {
  it('opens one inquiry per pair and returns it again', async () => {
    const { deps, chats } = createChatWorld();
    const res1 = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.equal(res1.chatId, 'cust1_phot1');
    assert.equal(res1.created, true);

    const stored = chats.chats.get('cust1_phot1');
    assert.ok(stored);
    assert.equal(stored.kind, 'inquiry');
    assert.equal(stored.customerId, 'cust1');
    assert.equal(stored.photographerId, 'phot1');
    assert.equal(stored.customerMessagesBeforeReply, 0);

    // Unread counters initialized to 0
    assert.equal(chats.unread.get('cust1_phot1')?.get('cust1'), 0);
    assert.equal(chats.unread.get('cust1_phot1')?.get('phot1'), 0);

    // Call again -> returns existing chat, created: false
    const res2 = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.equal(res2.chatId, 'cust1_phot1');
    assert.equal(res2.created, false);
  });

  it('refuses a new inquiry when the photographer turned inquiries off, but returns an existing chat', async () => {
    const { deps, photographers } = createChatWorld();
    photographers.disableInquiries('phot_busy');

    // Refused when new
    await assert.rejects(
      () => openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );

    // If photographer allows temporarily and chat is created:
    photographers.enableInquiries('phot_busy');
    const created = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' });
    assert.equal(created.created, true);

    // Now photographer disables inquiries:
    photographers.disableInquiries('phot_busy');
    // But existing chat is returned!
    const existing = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' });
    assert.equal(existing.chatId, created.chatId);
    assert.equal(existing.created, false);
  });

  it('cannot open an inquiry with yourself', async () => {
    const { deps } = createChatWorld();
    await assert.rejects(
      () => openInquiry(deps, { customerId: 'same_user', photographerId: 'same_user' }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
  });

  async function readOnlyBookingChat() {
    const world = createChatWorld();
    const { deps, clock } = world;
    const chatId = 'cust1_phot1';
    const readOnlyAt = new Date(clock.now().getTime() + 7 * 24 * 60 * 60 * 1000);
    const message: Message = {
      id: 'm1',
      chatId,
      senderId: 'phot1',
      type: 'text',
      body: 'Cảm ơn bạn',
      imagePath: null,
      point: null,
      system: null,
      createdAt: clock.now(),
    };
    const chat: Chat = {
      id: chatId,
      kind: 'booking',
      customerId: 'cust1',
      photographerId: 'phot1',
      bookingId: 'book_1',
      bookingStatus: 'completed',
      photographerRepliedAt: clock.now(),
      customerMessagesBeforeReply: 2,
      lastMessageAt: clock.now(),
      lastMessagePreview: 'Cảm ơn bạn',
      lastSenderId: 'phot1',
      readOnlyAt,
      rescheduleUsed: false,
      createdAt: clock.now(),
      updatedAt: clock.now(),
    };
    await deps.chats.runTransaction(async (tx) => {
      tx.setChat(chat);
      tx.addMessage(message);
    });
    return { ...world, chatId, chat, readOnlyAt };
  }

  it('openInquiry turns a read-only booking chat back into an inquiry', async () => {
    const { deps, chats, clock, chatId, chat, readOnlyAt } = await readOnlyBookingChat();
    clock.set(readOnlyAt);
    const res = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.deepEqual(res, { chatId, created: false });
    const stored = chats.chats.get(chatId);
    assert.ok(stored);
    assert.equal(stored.kind, 'inquiry');
    assert.equal(stored.bookingId, null);
    assert.equal(stored.bookingStatus, null);
    assert.equal(stored.readOnlyAt, null);
    assert.deepEqual(stored.photographerRepliedAt, chat.photographerRepliedAt);
    assert.deepEqual(stored.updatedAt, readOnlyAt);
    assert.equal(chats.messages.get(chatId)?.length, 1);
  });

  it('a booking chat still inside its 7 days is returned unchanged', async () => {
    const { deps, chats, chatId, chat } = await readOnlyBookingChat();
    const res = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.deepEqual(res, { chatId, created: false });
    assert.deepEqual(chats.chats.get(chatId), chat);
  });

  it('reviving is refused when inquiries are off', async () => {
    const { deps, chats, clock, photographers, chatId, chat, readOnlyAt } =
      await readOnlyBookingChat();
    clock.set(readOnlyAt);
    photographers.disableInquiries('phot1');
    await assert.rejects(
      () => openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );
    assert.deepEqual(chats.chats.get(chatId), chat);
  });

  it('an existing inquiry is returned unchanged', async () => {
    const { deps, chats, photographers } = createChatWorld();
    await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    const before = chats.chats.get('cust1_phot1');
    photographers.disableInquiries('phot1');
    const res = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.deepEqual(res, { chatId: 'cust1_phot1', created: false });
    assert.deepEqual(chats.chats.get('cust1_phot1'), before);
  });
});
