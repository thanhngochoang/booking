import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { Booking } from '../src/booking.js';
import { chatIdFor } from '../src/chat.js';
import { syncBookingChat } from '../src/booking_chat_sync.js';
import { openInquiry } from '../src/open_inquiry.js';
import { createChatWorld } from './support/chat_world.js';
import { MemoryBookingStore } from '../src/memory_booking_store.js';
import { proposeReschedule } from '../src/reschedule.js';

describe('syncBookingChat (Task 4)', () => {
  const baseBooking: Booking = {
    id: 'book_1',
    customerId: 'cust1',
    photographerId: 'phot1',
    serviceId: 'srv_1',
    serviceSnapshot: { name: 'Gói cơ bản', price: 1000000, durationMinutes: 60 },
    day: '2026-10-15',
    start: '10:00',
    end: '11:00',
    place: { name: 'Studio' },
    status: 'requested',
    deposit: 300000,
    remaining: 700000,
    acceptDeadline: '2026-10-02T12:00:00.000Z',
    version: 1,
    createdAt: '2026-10-01T12:00:00.000Z',
    updatedAt: '2026-10-01T12:00:00.000Z',
  };

  it('paying a deposit attaches the existing inquiry and posts the requested message', async () => {
    const { deps, chats } = createChatWorld();
    const { chatId } = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });

    const inquiryChat = chats.chats.get(chatId);
    assert.ok(inquiryChat);
    assert.equal(inquiryChat.kind, 'inquiry');
    assert.equal(inquiryChat.bookingId, null);

    const res = await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    assert.equal(res.chatId, chatId);
    assert.equal(res.setBookingChatId, true); // baseBooking has no chatId property matching chatId

    const updatedChat = chats.chats.get(chatId);
    assert.ok(updatedChat);
    assert.equal(updatedChat.kind, 'booking');
    assert.equal(updatedChat.bookingId, 'book_1');

    const msg = chats.messages.get(chatId)?.find((m) => m.id === 'sys-book_1-requested');
    assert.ok(msg);
    assert.equal(msg.type, 'system');
    assert.equal(msg.system?.kind, 'booking_status');
    assert.equal(msg.system?.status, 'requested');
  });

  it('paying without any inquiry creates a booking chat', async () => {
    const { deps, chats } = createChatWorld();
    const chatId = chatIdFor('cust1', 'phot1');

    assert.equal(chats.chats.has(chatId), false);

    const res = await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    assert.equal(res.chatId, chatId);
    assert.equal(res.setBookingChatId, true);

    const chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.equal(chat.kind, 'booking');
    assert.equal(chat.bookingId, 'book_1');
    assert.equal(chat.readOnlyAt, null);
  });

  it('closing a booking sets readOnlyAt; a new booking clears it', async () => {
    const { deps, chats, clock } = createChatWorld();
    const chatId = chatIdFor('cust1', 'phot1');

    // Booking requested
    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    // Booking accepted
    const acceptedBooking: Booking = { ...baseBooking, status: 'accepted' };
    await syncBookingChat(deps, {
      before: baseBooking,
      after: acceptedBooking,
    });

    // Booking completed
    const completedBooking: Booking = { ...baseBooking, status: 'completed' };
    await syncBookingChat(deps, {
      before: acceptedBooking,
      after: completedBooking,
    });

    let chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.ok(chat.readOnlyAt);
    const expectedReadOnly = new Date(clock.now().getTime() + 7 * 24 * 60 * 60 * 1000);
    assert.deepEqual(chat.readOnlyAt, expectedReadOnly);

    // New booking created with same photographer clears readOnlyAt
    const newBooking: Booking = {
      ...baseBooking,
      id: 'book_2',
      status: 'requested',
    };
    await syncBookingChat(deps, {
      before: null,
      after: newBooking,
    });

    chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.equal(chat.bookingId, 'book_2');
    assert.equal(chat.readOnlyAt, null);
  });

  it('each status posts once even when the trigger runs twice', async () => {
    const { deps, chats } = createChatWorld();
    const chatId = chatIdFor('cust1', 'phot1');

    // Run 1
    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    // Run 2 (retry)
    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    const msgs = chats.messages.get(chatId) ?? [];
    const requestedMsgs = msgs.filter((m) => m.id === 'sys-book_1-requested');
    assert.equal(requestedMsgs.length, 1);
  });

  it('an older booking changing status does not post into a chat that moved to a newer booking', async () => {
    const { deps, chats } = createChatWorld();
    const chatId = chatIdFor('cust1', 'phot1');

    // Booking 1 requested
    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    // Booking 2 requested (newer booking attaches)
    const booking2: Booking = { ...baseBooking, id: 'book_2', status: 'requested' };
    await syncBookingChat(deps, {
      before: null,
      after: booking2,
    });

    // Old Booking 1 transitions to cancelled
    const booking1Cancelled: Booking = { ...baseBooking, status: 'cancelled' };
    await syncBookingChat(deps, {
      before: baseBooking,
      after: booking1Cancelled,
    });

    // Cancelled message for booking 1 was NOT posted because chat has moved to book_2
    const msgs = chats.messages.get(chatId) ?? [];
    assert.equal(msgs.some((m) => m.id === 'sys-book_1-cancelled'), false);
  });

  it('cancelling expires a pending reschedule proposal', async () => {
    const { deps, chats } = createChatWorld();
    const bookings = new MemoryBookingStore();
    const fullDeps = { ...deps, bookings };

    // Booking requested then accepted
    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });
    const acceptedBooking: Booking = { ...baseBooking, status: 'accepted' };
    await syncBookingChat(deps, {
      before: baseBooking,
      after: acceptedBooking,
    });

    bookings.bookings.set(acceptedBooking.id, { ...acceptedBooking });
    bookings.availability.set(`${acceptedBooking.photographerId}_${acceptedBooking.day}`, {
      state: 'booked',
      bookingId: acceptedBooking.id,
    });

    // Customer proposes reschedule
    await proposeReschedule(fullDeps, {
      actorId: acceptedBooking.customerId,
      bookingId: acceptedBooking.id,
      day: '2026-10-18',
      start: '14:00',
      clientId: 'prop_cancel_test',
    });

    const pendingBefore = await chats.pendingProposal(chatIdFor('cust1', 'phot1'));
    assert.ok(pendingBefore);
    assert.equal(pendingBefore.system?.answer, undefined);

    // Cancel booking
    const cancelledBooking: Booking = { ...acceptedBooking, status: 'cancelled' };
    await syncBookingChat(deps, {
      before: acceptedBooking,
      after: cancelledBooking,
    });

    const pendingAfter = await chats.pendingProposal(chatIdFor('cust1', 'phot1'));
    assert.equal(pendingAfter, null); // no longer pending because answer is set to 'expired'

    const msg = chats.messages
      .get(chatIdFor('cust1', 'phot1'))
      ?.find((m) => m.id === 'prop_cancel_test');
    assert.ok(msg);
    assert.equal(msg.system?.answer, 'expired');
  });

  it('upcoming posts nothing', async () => {
    const { deps, chats } = createChatWorld();
    const chatId = chatIdFor('cust1', 'phot1');

    await syncBookingChat(deps, {
      before: null,
      after: baseBooking,
    });

    const accepted: Booking = { ...baseBooking, status: 'accepted' };
    await syncBookingChat(deps, {
      before: baseBooking,
      after: accepted,
    });

    const msgsBefore = (chats.messages.get(chatId) ?? []).length;

    const upcoming: Booking = { ...accepted, status: 'upcoming' };
    const res = await syncBookingChat(deps, {
      before: accepted,
      after: upcoming,
    });

    assert.equal(res.chatId, chatId);
    assert.equal(res.setBookingChatId, false);

    const msgsAfter = (chats.messages.get(chatId) ?? []).length;
    assert.equal(msgsAfter, msgsBefore);
  });
});
