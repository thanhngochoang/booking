import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  handleOpenInquiry,
  handleSendMessage,
  handleProposeReschedule,
  handleAnswerReschedule,
} from '../../src/callables/chat.js';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryBookingStore, MemoryChatStore, type BookingStore, type ChatDeps } from '@photobooking/domain';
import { openInquiry } from '@photobooking/domain';
import type { CallableInput } from '../../src/callables/get_contact_link.js';

describe('chat callables unit tests', () => {
  function createTestDeps() {
    const memoryChats = new MemoryChatStore();
    const memoryBookings = new MemoryBookingStore();
    const fakeDeps: ChatDeps & { bookings: BookingStore } = {
      chats: memoryChats,
      bookings: memoryBookings,
      photographers: { acceptsInquiries: async () => true },
      clock: { now: () => new Date('2026-10-01T12:00:00.000Z') },
      ids: { newId: () => 'id_1' },
    };
    return { memoryChats, memoryBookings, fakeDeps };
  }

  const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
    e instanceof HttpsError &&
    e.code === code &&
    (detailsCode === undefined || (e.details as { code?: string } | undefined)?.code === detailsCode);

  it('unauthenticated is refused before any read', async () => {
    const { fakeDeps } = createTestDeps();
    const unauthRequest: CallableInput = { data: {}, auth: undefined };

    await assert.rejects(
      handleOpenInquiry(unauthRequest, fakeDeps),
      httpsError('unauthenticated', 'permission_denied'),
    );

    await assert.rejects(
      handleSendMessage(unauthRequest, fakeDeps),
      httpsError('unauthenticated', 'permission_denied'),
    );

    await assert.rejects(
      handleProposeReschedule(unauthRequest, fakeDeps),
      httpsError('unauthenticated', 'permission_denied'),
    );

    await assert.rejects(
      handleAnswerReschedule(unauthRequest, fakeDeps),
      httpsError('unauthenticated', 'permission_denied'),
    );
  });

  it('sendMessage maps limit_exceeded to resource-exhausted with details.code', async () => {
    const { fakeDeps } = createTestDeps();

    // Open inquiry
    const { chatId } = await openInquiry(fakeDeps, {
      customerId: 'cust1',
      photographerId: 'phot1',
    });

    const requestAuth = { uid: 'cust1' };

    // Send 3 customer messages
    for (let i = 1; i <= 3; i++) {
      const res = await handleSendMessage(
        {
          auth: requestAuth,
          data: {
            chatId,
            message: { type: 'text', body: `Hello ${i}`, clientId: `client_${i}` },
          },
        },
        fakeDeps,
      );
      assert.equal(res.id, `client_${i}`);
    }

    // 4th message should throw HttpsError with code 'resource-exhausted' and details.code 'limit_exceeded'
    await assert.rejects(
      handleSendMessage(
        {
          auth: requestAuth,
          data: {
            chatId,
            message: { type: 'text', body: 'Hello 4', clientId: 'client_4' },
          },
        },
        fakeDeps,
      ),
      httpsError('resource-exhausted', 'limit_exceeded'),
    );
  });

  it('sendMessage into a closed inquiry with inquiries off is failed-precondition with details.code not_eligible', async () => {
    const { memoryChats, fakeDeps } = createTestDeps();
    const { chatId } = await openInquiry(fakeDeps, { customerId: 'cust1', photographerId: 'phot1' });
    await handleSendMessage(
      {
        auth: { uid: 'cust1' },
        data: { chatId, message: { type: 'text', body: 'Hello', clientId: 'client_1' } },
      },
      fakeDeps,
    );

    // 15 days later (past INQUIRY_CLOSE_DAYS) and the photographer no longer takes inquiries.
    const later: ChatDeps & { bookings: BookingStore } = {
      ...fakeDeps,
      chats: memoryChats,
      photographers: { acceptsInquiries: async () => false },
      clock: { now: () => new Date('2026-10-16T12:00:00.000Z') },
    };
    await assert.rejects(
      handleSendMessage(
        {
          auth: { uid: 'cust1' },
          data: { chatId, message: { type: 'text', body: 'Still there?', clientId: 'client_2' } },
        },
        later,
      ),
      httpsError('failed-precondition', 'not_eligible'),
    );
  });

  it('openInquiry on a read-only booking chat returns the same chatId', async () => {
    const { memoryChats, fakeDeps } = createTestDeps();
    const { chatId } = await openInquiry(fakeDeps, { customerId: 'cust1', photographerId: 'phot1' });
    const chat = await memoryChats.runTransaction((tx) => tx.getChat(chatId));
    assert.ok(chat);
    await memoryChats.runTransaction(async (tx) => {
      tx.setChat({
        ...chat,
        kind: 'booking',
        bookingId: 'book_1',
        bookingStatus: 'completed',
        readOnlyAt: new Date('2026-10-01T00:00:00.000Z'),
      });
    });

    const res = await handleOpenInquiry({ auth: { uid: 'cust1' }, data: { photographerId: 'phot1' } }, fakeDeps);
    assert.equal(res.chatId, chatId);
  });
});
