import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import type { Booking } from '../src/booking.js';
import { MemoryBookingStore } from '../src/memory_booking_store.js';
import { chatIdFor, type Chat } from '../src/chat.js';
import {
  answerReschedule,
  expirePendingProposal,
  proposeReschedule,
} from '../src/reschedule.js';
import { createChatWorld } from './support/chat_world.js';

describe('reschedule proposal and answer (Task 3)', () => {
  function setup() {
    const { deps: chatDeps, clock, ids, chats } = createChatWorld();
    const bookings = new MemoryBookingStore();
    const deps = { ...chatDeps, bookings };

    const booking: Booking = {
      id: 'book_1',
      customerId: 'cust1',
      photographerId: 'phot1',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1000000, durationMinutes: 60 },
      day: '2026-10-10',
      start: '10:00',
      end: '11:00',
      place: { name: 'Hồ Gươm' },
      status: 'accepted',
      deposit: 300000,
      remaining: 700000,
      acceptDeadline: '2026-10-02T12:00:00.000Z',
      version: 1,
      createdAt: '2026-10-01T12:00:00.000Z',
      updatedAt: '2026-10-01T12:00:00.000Z',
    };

    bookings.bookings.set(booking.id, { ...booking });
    bookings.availability.set(`${booking.photographerId}_${booking.day}`, {
      state: 'booked',
      bookingId: booking.id,
    });

    const chatId = chatIdFor(booking.customerId, booking.photographerId);
    const chat: Chat = {
      id: chatId,
      kind: 'booking',
      customerId: booking.customerId,
      photographerId: booking.photographerId,
      bookingId: booking.id,
      photographerRepliedAt: new Date('2026-10-01T12:00:00.000Z'),
      customerMessagesBeforeReply: 1,
      lastMessageAt: new Date('2026-10-01T12:00:00.000Z'),
      lastMessagePreview: 'OK',
      lastSenderId: booking.photographerId,
      readOnlyAt: null,
      rescheduleUsed: false,
      createdAt: new Date('2026-10-01T12:00:00.000Z'),
      updatedAt: new Date('2026-10-01T12:00:00.000Z'),
    };
    chats.chats.set(chatId, { ...chat });

    return { deps, clock, ids, chats, bookings, booking, chatId };
  }

  it('either party may propose once on an accepted booking', async () => {
    const { deps, booking, chats, chatId } = setup();

    // Customer proposes
    const m = await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    assert.equal(m.id, 'prop_1');
    assert.equal(m.type, 'system');
    assert.equal(m.system?.kind, 'reschedule_proposal');
    assert.equal(m.system?.proposal?.day, '2026-10-12');
    assert.equal(m.system?.proposal?.start, '14:00');
    assert.equal(m.system?.proposal?.end, '15:00');
    assert.equal(m.system?.proposal?.byRole, 'customer');

    const chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.equal(chat.lastMessagePreview, 'Đề nghị đổi lịch');
    assert.equal(chats.unread.get(chatId)?.get(booking.photographerId), 1);
  });

  it('proposals on requested, cancelled or completed bookings are not_eligible', async () => {
    const { deps, booking, bookings } = setup();

    for (const status of ['requested', 'cancelled', 'completed'] as const) {
      bookings.bookings.set(booking.id, { ...booking, status });
      await assert.rejects(
        () =>
          proposeReschedule(deps, {
            actorId: booking.customerId,
            bookingId: booking.id,
            day: '2026-10-12',
            start: '14:00',
            clientId: `prop_${status}`,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    }
  });

  it('a second pending proposal is a conflict; after an answer a new proposal is limit_exceeded (one free change)', async () => {
    const { deps, booking } = setup();

    // First proposal
    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    // Second proposal while first is pending -> conflict
    await assert.rejects(
      () =>
        proposeReschedule(deps, {
          actorId: booking.photographerId,
          bookingId: booking.id,
          day: '2026-10-13',
          start: '15:00',
          clientId: 'prop_2',
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'conflict',
    );

    // Answer the proposal (accept)
    await answerReschedule(deps, {
      actorId: booking.photographerId,
      chatId: chatIdFor(booking.customerId, booking.photographerId),
      messageId: 'prop_1',
      accept: true,
    });

    // Now rescheduleUsed is true -> next proposal is limit_exceeded
    await assert.rejects(
      () =>
        proposeReschedule(deps, {
          actorId: booking.customerId,
          bookingId: booking.id,
          day: '2026-10-14',
          start: '10:00',
          clientId: 'prop_3',
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'limit_exceeded',
    );
  });

  it('the proposer cannot accept their own proposal', async () => {
    const { deps, booking, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_cust',
    });

    await assert.rejects(
      () =>
        answerReschedule(deps, {
          actorId: booking.customerId,
          chatId,
          messageId: 'prop_cust',
          accept: true,
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );
  });

  it('accepting moves the booking and its calendar day', async () => {
    const { deps, booking, bookings, chats, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    const res = await answerReschedule(deps, {
      actorId: booking.photographerId,
      chatId,
      messageId: 'prop_1',
      accept: true,
    });

    assert.equal(res.answer, 'accepted');

    // Booking updated
    const updated = bookings.bookings.get(booking.id);
    assert.ok(updated);
    assert.equal(updated.day, '2026-10-12');
    assert.equal(updated.start, '14:00');
    assert.equal(updated.end, '15:00');
    assert.equal(updated.version, 2);

    // Old day freed
    assert.equal(bookings.availability.has(`${booking.photographerId}_2026-10-10`), false);

    // New day booked
    const newDay = bookings.availability.get(`${booking.photographerId}_2026-10-12`);
    assert.ok(newDay);
    assert.equal(newDay.state, 'booked');
    assert.equal(newDay.bookingId, booking.id);

    // Event added
    assert.equal(bookings.events.length, 1);
    assert.equal(bookings.events[0]?.actorId, booking.photographerId);

    // Chat marked rescheduleUsed
    const chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.equal(chat.rescheduleUsed, true);
  });

  it('accepting onto a taken day is day_taken and the proposal stays pending', async () => {
    const { deps, booking, bookings, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    // Mark 2026-10-12 as taken by another booking
    bookings.availability.set(`${booking.photographerId}_2026-10-12`, {
      state: 'booked',
      bookingId: 'other_booking',
    });

    await assert.rejects(
      () =>
        answerReschedule(deps, {
          actorId: booking.photographerId,
          chatId,
          messageId: 'prop_1',
          accept: true,
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'day_taken',
    );

    // Proposal remains pending
    const pending = await deps.chats.pendingProposal(chatId);
    assert.ok(pending);
    assert.equal(pending.id, 'prop_1');
  });

  it('declining leaves the booking unchanged and keeps the free change', async () => {
    const { deps, booking, bookings, chats, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    const res = await answerReschedule(deps, {
      actorId: booking.photographerId,
      chatId,
      messageId: 'prop_1',
      accept: false,
    });

    assert.equal(res.answer, 'declined');

    // Booking unchanged
    const b = bookings.bookings.get(booking.id);
    assert.ok(b);
    assert.equal(b.day, '2026-10-10');
    assert.equal(b.version, 1);

    // rescheduleUsed is still false!
    const chat = chats.chats.get(chatId);
    assert.ok(chat);
    assert.equal(chat.rescheduleUsed, false);

    // Can propose again
    const m2 = await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-13',
      start: '09:00',
      clientId: 'prop_2',
    });
    assert.equal(m2.id, 'prop_2');
  });

  it('accept twice applies once', async () => {
    const { deps, booking, bookings, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    const res1 = await answerReschedule(deps, {
      actorId: booking.photographerId,
      chatId,
      messageId: 'prop_1',
      accept: true,
    });
    assert.equal(res1.answer, 'accepted');

    // Second accept
    const res2 = await answerReschedule(deps, {
      actorId: booking.photographerId,
      chatId,
      messageId: 'prop_1',
      accept: true,
    });
    assert.equal(res2.answer, 'accepted');

    // Booking version incremented only once
    const b = bookings.bookings.get(booking.id);
    assert.ok(b);
    assert.equal(b.version, 2);
  });

  it('a cancelled booking expires the pending proposal', async () => {
    const { deps, booking, bookings, chatId } = setup();

    await proposeReschedule(deps, {
      actorId: booking.customerId,
      bookingId: booking.id,
      day: '2026-10-12',
      start: '14:00',
      clientId: 'prop_1',
    });

    // Trigger or workflow calls expirePendingProposal when booking cancelled
    bookings.bookings.set(booking.id, { ...booking, status: 'cancelled' });
    await expirePendingProposal(deps, chatId);

    // Now answering it throws not_eligible
    await assert.rejects(
      () =>
        answerReschedule(deps, {
          actorId: booking.photographerId,
          chatId,
          messageId: 'prop_1',
          accept: true,
        }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );
  });
});
