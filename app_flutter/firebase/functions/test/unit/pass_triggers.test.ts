import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryChatStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  chatIdFor,
  type BadgeDeps,
  type ChatDeps,
  type NotifyDeps,
} from '@photobooking/domain';
import { bookingToFirestore } from '../../src/infra/booking_firestore.js';
import { passToFirestore } from '../../src/infra/pass_firestore.js';
import { handleBookingWrite } from '../../src/triggers/booking_write.js';
import { handlePassCreated } from '../../src/triggers/pass_write.js';
import { NOW, studioBooking } from './support/studio_fixtures.js';

function notifyDeps(): { deps: NotifyDeps; store: MemoryNotificationStore } {
  const store = new MemoryNotificationStore();
  return { store, deps: { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => NOW } } };
}

describe('S30 pass and shooting triggers', () => {
  it('a new pass of a booking tells the customer once (pass_ready, opens the booking, never the code)', async () => {
    const n = notifyDeps();
    const data = passToFirestore({
      code8: '7K2Q4M9P', customerId: 'c1', day: '2026-10-20', bookingId: 'b1', eventId: null, registrationIds: [], createdAt: NOW.toISOString(),
    });
    await handlePassCreated('7K2Q4M9P', data, n.deps);
    await handlePassCreated('7K2Q4M9P', data, n.deps);
    const rows = n.store.rowsOf('c1');
    assert.deepEqual(rows.map((r) => [r.type, r.target]), [['pass_ready', '/b/b1']]);
    assert.equal(JSON.stringify(rows).includes('7K2Q4M9P'), false);
  });

  it('a lone entry ticket\'s pass opens the event', async () => {
    const n = notifyDeps();
    await handlePassCreated('TKTS2345', passToFirestore({
      code8: 'TKTS2345', customerId: 'c2', day: '2026-10-20', bookingId: null, eventId: 'en1', registrationIds: ['r1'], createdAt: NOW.toISOString(),
    }), n.deps);
    assert.deepEqual(n.store.rowsOf('c2').map((r) => [r.type, r.target]), [['pass_ready', '/e/en1']]);
    // A malformed document sends nothing.
    await handlePassCreated('BAD', { day: 1 }, n.deps);
    assert.equal(n.store.rowsOf('c2').length, 1);
  });

  it('upcoming → shooting mirrors the status on the chat and sends no booking notice', async () => {
    const chats = new MemoryChatStore();
    const chatDeps: ChatDeps = {
      chats,
      photographers: { acceptsInquiries: async () => true },
      blocks: { isBlockedEitherWay: async () => false },
      clock: { now: () => NOW },
      ids: { newId: () => 'id_1' },
    };
    const base = { ...studioBooking({ status: 'upcoming' }), isStudio: undefined };
    const chatId = chatIdFor(base.customerId, base.photographerId);
    chats.chats.set(chatId, {
      id: chatId, kind: 'booking', customerId: base.customerId, photographerId: base.photographerId, assigneeId: null,
      bookingId: base.id, bookingStatus: 'upcoming', photographerRepliedAt: null, customerMessagesBeforeReply: 0,
      lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null, blockedAt: null,
      rescheduleUsed: false, createdAt: NOW, updatedAt: NOW,
    });
    const n = notifyDeps();
    const after = { ...base, status: 'shooting' as const, checkedInAt: NOW.toISOString(), version: base.version + 1 };
    await handleBookingWrite(
      { id: base.id, before: bookingToFirestore(base), after: bookingToFirestore(after) },
      chatDeps,
      async () => undefined,
      { notify: n.deps, badges: {} as BadgeDeps },
    );
    assert.equal(chats.chats.get(chatId)?.bookingStatus, 'shooting');
    assert.deepEqual([...n.store.rowsOf(base.customerId), ...n.store.rowsOf(base.photographerId)], []);
  });
});
