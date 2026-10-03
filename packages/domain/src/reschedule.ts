import {
  addMinutesToTime,
  computeDaySlots,
  isDateString,
  isTimeString,
  MAX_BOOKING_DAYS_AHEAD,
  parseVnDateTime,
} from './booking_policy.js';
import type { BookingStore } from './booking_ports.js';
import { afterMessage, chatIdFor, type Message, type SystemPayload } from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import { DomainError } from './errors.js';

export async function proposeReschedule(
  deps: ChatDeps & { bookings: BookingStore },
  input: {
    actorId: string;
    bookingId: string;
    day: string;
    start: string;
    clientId: string;
  },
): Promise<Message> {
  const booking = await deps.bookings.getBooking(input.bookingId);
  if (!booking) {
    throw new DomainError('not_found');
  }
  if (booking.customerId !== input.actorId && booking.photographerId !== input.actorId) {
    throw new DomainError('permission_denied');
  }
  if (booking.status !== 'accepted' && booking.status !== 'upcoming') {
    throw new DomainError('not_eligible');
  }

  const chatId = chatIdFor(booking.customerId, booking.photographerId);
  const pending = await deps.chats.pendingProposal(chatId);
  if (pending !== null) {
    throw new DomainError('conflict');
  }

  // Validate day and start
  if (!isDateString(input.day) || !isTimeString(input.start)) {
    throw new DomainError('invalid_argument');
  }
  if (typeof input.clientId !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(input.clientId)) {
    throw new DomainError('invalid_argument');
  }
  if (input.day === booking.day && input.start === booking.start) {
    throw new DomainError('invalid_argument');
  }

  const duration = booking.serviceSnapshot.durationMinutes;
  const validSlots = computeDaySlots(duration);
  if (!validSlots.includes(input.start)) {
    throw new DomainError('invalid_argument');
  }

  const newStartDt = parseVnDateTime(input.day, input.start);
  const now = deps.clock.now();
  if (newStartDt.getTime() <= now.getTime()) {
    throw new DomainError('invalid_argument');
  }
  if (newStartDt.getTime() > now.getTime() + MAX_BOOKING_DAYS_AHEAD * 24 * 60 * 60 * 1000) {
    throw new DomainError('invalid_argument');
  }

  const end = addMinutesToTime(input.start, duration);
  const byRole = input.actorId === booking.customerId ? 'customer' : 'photographer';

  const systemPayload: SystemPayload = {
    kind: 'reschedule_proposal',
    proposal: {
      day: input.day,
      start: input.start,
      end,
      byRole,
    },
  };

  return deps.chats.runTransaction(async (tx) => {
    const chat = await tx.getChat(chatId);
    if (!chat || chat.bookingId !== booking.id) {
      throw new DomainError('not_eligible');
    }
    if (chat.rescheduleUsed) {
      throw new DomainError('limit_exceeded');
    }

    const existingMessage = await tx.getMessage(chatId, input.clientId);
    if (existingMessage) {
      return existingMessage;
    }

    const message: Message = {
      id: input.clientId,
      chatId,
      senderId: null,
      type: 'system',
      body: null,
      imagePath: null,
      point: null,
      system: systemPayload,
      createdAt: now,
    };

    tx.addMessage(message);
    const nextChat = afterMessage(chat, message, now);
    tx.setChat(nextChat);

    const recipientId =
      input.actorId === booking.customerId ? booking.photographerId : booking.customerId;
    tx.incrementUnread(chatId, recipientId, 1);

    return message;
  });
}

export async function answerReschedule(
  deps: ChatDeps & { bookings: BookingStore },
  input: {
    actorId: string;
    chatId: string;
    messageId: string;
    accept: boolean;
  },
): Promise<{ answer: 'accepted' | 'declined' }> {
  const now = deps.clock.now();

  return deps.chats.runTransaction(async (cTx) => {
    const chat = await cTx.getChat(input.chatId);
    if (!chat) {
      throw new DomainError('not_found');
    }

    const message = await cTx.getMessage(input.chatId, input.messageId);
    if (!message || message.type !== 'system' || message.system?.kind !== 'reschedule_proposal') {
      throw new DomainError('not_found');
    }

    const system = message.system;
    if (system.answer) {
      if (system.answer === 'expired') {
        throw new DomainError('not_eligible');
      }
      return { answer: system.answer as 'accepted' | 'declined' };
    }

    const proposal = system.proposal;
    if (!proposal) {
      throw new DomainError('invalid_argument');
    }

    // Role check: proposer cannot answer their own proposal
    if (proposal.byRole === 'customer') {
      if (input.actorId !== chat.photographerId) {
        throw new DomainError('permission_denied');
      }
    } else {
      if (input.actorId !== chat.customerId) {
        throw new DomainError('permission_denied');
      }
    }

    if (!input.accept) {
      cTx.updateMessageSystem(input.chatId, input.messageId, {
        ...system,
        answer: 'declined',
        answeredBy: input.actorId,
        answeredAt: now,
      });
      return { answer: 'declined' };
    }

    const bookingId = chat.bookingId;
    if (!bookingId) {
      throw new DomainError('not_found');
    }

    await deps.bookings.runTransaction(async (bTx) => {
      const booking = await bTx.getBooking(bookingId);
      if (!booking) {
        throw new DomainError('not_found');
      }
      if (booking.status !== 'accepted' && booking.status !== 'upcoming') {
        cTx.updateMessageSystem(input.chatId, input.messageId, {
          ...system,
          answer: 'expired',
          answeredBy: input.actorId,
          answeredAt: now,
        });
        throw new DomainError('not_eligible');
      }

      // Check day hold
      const newDayHold = await bTx.getAvailabilityDay(booking.photographerId, proposal.day);
      if (newDayHold !== null && newDayHold.bookingId !== booking.id) {
        throw new DomainError('day_taken');
      }

      // Free old day
      const oldDayHold = await bTx.getAvailabilityDay(booking.photographerId, booking.day);
      if (oldDayHold && oldDayHold.bookingId === booking.id) {
        await bTx.deleteAvailabilityDay(booking.photographerId, booking.day);
      }

      // Hold new day
      await bTx.setAvailabilityDay(booking.photographerId, proposal.day, {
        state: 'booked',
        bookingId: booking.id,
      });

      // Update booking
      await bTx.setBooking({
        ...booking,
        day: proposal.day,
        start: proposal.start,
        end: proposal.end,
        version: booking.version + 1,
        updatedAt: now.toISOString(),
      });

      // Add booking event
      await bTx.addBookingEvent({
        id: deps.ids.newId(),
        bookingId: booking.id,
        status: booking.status,
        actorId: input.actorId,
        at: now.toISOString(),
      });
    });

    cTx.updateMessageSystem(input.chatId, input.messageId, {
      ...system,
      answer: 'accepted',
      answeredBy: input.actorId,
      answeredAt: now,
    });
    cTx.setChat({
      ...chat,
      rescheduleUsed: true,
      updatedAt: now,
    });

    return { answer: 'accepted' };
  });
}

export async function expirePendingProposal(deps: ChatDeps, chatId: string): Promise<void> {
  const pending = await deps.chats.pendingProposal(chatId);
  const system = pending?.system;
  if (pending && system) {
    const now = deps.clock.now();
    await deps.chats.runTransaction(async (tx) => {
      tx.updateMessageSystem(chatId, pending.id, {
        ...system,
        answer: 'expired',
        answeredAt: now,
      });
    });
  }
}
