import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  toFirestoreChat,
  fromFirestoreChat,
  toFirestoreMessage,
  fromFirestoreMessage,
} from '../../src/infra/chat_firestore.js';
import { handleBookingWrite } from '../../src/triggers/booking_write.js';
import type { Chat, ChatDeps, Message } from '@photobooking/domain';
import { MemoryChatStore } from '@photobooking/domain';
import { GeoPoint, Timestamp } from 'firebase-admin/firestore';

describe('chat_firestore mapping and trigger unit tests', () => {
  it('Chat and Message survive a Firestore round trip (Timestamp, GeoPoint, nulls)', () => {
    const chat: Chat = {
      id: 'cust1_phot1',
      kind: 'booking',
      customerId: 'cust1',
      photographerId: 'phot1',
      bookingId: 'book_123',
      photographerRepliedAt: new Date('2026-10-01T12:00:00.000Z'),
      customerMessagesBeforeReply: 2,
      lastMessageAt: new Date('2026-10-01T12:05:00.000Z'),
      lastMessagePreview: 'Xin chào',
      lastSenderId: 'cust1',
      readOnlyAt: new Date('2026-10-08T12:00:00.000Z'),
      rescheduleUsed: true,
      createdAt: new Date('2026-10-01T10:00:00.000Z'),
      updatedAt: new Date('2026-10-01T12:05:00.000Z'),
    };

    const firestoreChat = toFirestoreChat(chat);
    assert.ok(firestoreChat.createdAt instanceof Timestamp);
    assert.ok(firestoreChat.photographerRepliedAt instanceof Timestamp);
    assert.deepEqual(firestoreChat.members, ['cust1', 'phot1']);

    const restoredChat = fromFirestoreChat('cust1_phot1', firestoreChat);
    assert.deepEqual(restoredChat, chat);

    // Message with GeoPoint and system proposal
    const msg: Message = {
      id: 'msg_01',
      chatId: 'cust1_phot1',
      senderId: 'cust1',
      type: 'location',
      body: null,
      imagePath: null,
      point: { lat: 10.762622, lng: 106.660172 },
      system: null,
      createdAt: new Date('2026-10-01T12:00:00.000Z'),
    };

    const firestoreMsg = toFirestoreMessage(msg);
    assert.ok(firestoreMsg.point instanceof GeoPoint);
    assert.ok(firestoreMsg.createdAt instanceof Timestamp);

    const restoredMsg = fromFirestoreMessage('cust1_phot1', 'msg_01', firestoreMsg);
    assert.deepEqual(restoredMsg, msg);

    // System proposal message
    const sysMsg: Message = {
      id: 'msg_sys_01',
      chatId: 'cust1_phot1',
      senderId: null,
      type: 'system',
      body: null,
      imagePath: null,
      point: null,
      system: {
        kind: 'reschedule_proposal',
        proposal: {
          day: '2026-10-15',
          start: '14:00',
          end: '15:00',
          byRole: 'customer',
        },
        answer: 'accepted',
        answeredBy: 'phot1',
        answeredAt: new Date('2026-10-02T08:00:00.000Z'),
      },
      createdAt: new Date('2026-10-01T12:00:00.000Z'),
    };

    const firestoreSysMsg = toFirestoreMessage(sysMsg);
    assert.equal(firestoreSysMsg.senderId, null);
    const restoredSysMsg = fromFirestoreMessage('cust1_phot1', 'msg_sys_01', firestoreSysMsg);
    assert.deepEqual(restoredSysMsg, sysMsg);
  });

  it('the trigger writes chatId only when it changed', async () => {
    const memoryChats = new MemoryChatStore();
    const fakeDeps: ChatDeps = {
      chats: memoryChats,
      photographers: { acceptsInquiries: async () => true },
      clock: { now: () => new Date('2026-10-01T12:00:00.000Z') },
      ids: { newId: () => 'id_1' },
    };

    const bookingData = {
      customerId: 'cust1',
      photographerId: 'phot1',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1000000, durationMinutes: 60 },
      day: '2026-10-15',
      start: '10:00',
      end: '11:00',
      place: { name: 'Studio' },
      status: 'requested',
      deposit: 300000,
      remaining: 700000,
      acceptDeadline: Timestamp.fromDate(new Date('2026-10-02T12:00:00.000Z')),
      version: 1,
      createdAt: Timestamp.fromDate(new Date('2026-10-01T12:00:00.000Z')),
      updatedAt: Timestamp.fromDate(new Date('2026-10-01T12:00:00.000Z')),
    };

    let updatedBookingId: string | null = null;
    let updatedChatId: string | null = null;
    const updateChatId = async (bId: string, cId: string) => {
      updatedBookingId = bId;
      updatedChatId = cId;
    };

    // First write: booking without chatId
    const res1 = await handleBookingWrite(
      { id: 'book_1', before: undefined, after: bookingData },
      fakeDeps,
      updateChatId,
    );

    assert.equal(res1.setBookingChatId, true);
    assert.equal(updatedBookingId, 'book_1');
    assert.equal(updatedChatId, 'cust1_phot1');

    // Second write: booking now already has chatId === 'cust1_phot1'
    updatedBookingId = null;
    updatedChatId = null;
    const res2 = await handleBookingWrite(
      {
        id: 'book_1',
        before: bookingData,
        after: { ...bookingData, chatId: 'cust1_phot1' },
      },
      fakeDeps,
      updateChatId,
    );

    assert.equal(res2.setBookingChatId, false);
    assert.equal(updatedBookingId, null);
    assert.equal(updatedChatId, null);
  });
});
