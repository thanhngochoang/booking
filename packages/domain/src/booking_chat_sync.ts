import type { Booking } from './booking.js';
import {
  afterMessage,
  BOOKING_CHAT_READONLY_DAYS,
  chatIdFor,
  type Chat,
  type Message,
} from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import { expirePendingProposal } from './reschedule.js';

export async function syncBookingChat(
  deps: ChatDeps,
  change: { before: Booking | null; after: Booking | null },
): Promise<{ chatId: string | null; setBookingChatId: boolean }> {
  const { before, after } = change;
  if (!after) {
    return { chatId: null, setBookingChatId: false };
  }

  const chatId = chatIdFor(after.customerId, after.photographerId);
  const now = deps.clock.now();

  // If status is not accepted or upcoming, expire any pending reschedule proposal
  if (after.status !== 'accepted' && after.status !== 'upcoming') {
    await expirePendingProposal(deps, chatId);
  }

  return deps.chats.runTransaction(async (tx) => {
    // 1. ALL READS FIRST
    const chat = await tx.getChat(chatId);

    const isRequestedTransition =
      after.status === 'requested' && (!before || before.status !== 'requested');

    const validClosingStatuses = ['declined', 'expired', 'cancelled', 'completed'] as const;
    const postStatuses = ['accepted', ...validClosingStatuses] as const;

    let targetStatus: string | null = null;
    if (isRequestedTransition) {
      targetStatus = 'requested';
    } else if (
      chat?.bookingId === after.id &&
      (!before || before.status !== after.status) &&
      (postStatuses as readonly string[]).includes(after.status)
    ) {
      targetStatus = after.status;
    }

    const sysId = targetStatus ? `sys-${after.id}-${targetStatus}` : null;
    const existingSysMsg = sysId ? await tx.getMessage(chatId, sysId) : null;

    // 2. ALL WRITES AFTER
    let currentChat: Chat;
    if (!chat) {
      currentChat = {
        id: chatId,
        kind: 'booking',
        customerId: after.customerId,
        photographerId: after.photographerId,
        bookingId: after.id,
        photographerRepliedAt: null,
        customerMessagesBeforeReply: 0,
        lastMessageAt: null,
        lastMessagePreview: null,
        lastSenderId: null,
        readOnlyAt: null,
        rescheduleUsed: false,
        createdAt: now,
        updatedAt: now,
      };
      tx.setChat(currentChat);
      tx.incrementUnread(chatId, after.customerId, 0);
      tx.incrementUnread(chatId, after.photographerId, 0);
    } else {
      currentChat = chat;
    }

    let setBookingChatId = false;

    if (isRequestedTransition) {
      currentChat = {
        ...currentChat,
        kind: 'booking',
        bookingId: after.id,
        readOnlyAt: null,
        updatedAt: now,
      };

      if (!existingSysMsg && sysId) {
        const sysMsg: Message = {
          id: sysId,
          chatId,
          senderId: null,
          type: 'system',
          body: null,
          imagePath: null,
          point: null,
          system: {
            kind: 'booking_status',
            status: 'requested',
          },
          createdAt: now,
        };
        tx.addMessage(sysMsg);
        currentChat = afterMessage(currentChat, sysMsg, now);
      }

      tx.setChat(currentChat);
      setBookingChatId = after.chatId !== chatId;
      return { chatId, setBookingChatId };
    }

    // Status change for current attached booking
    if (currentChat.bookingId !== after.id) {
      return { chatId, setBookingChatId: false };
    }

    if (before && before.status === after.status) {
      return { chatId, setBookingChatId: false };
    }

    if (after.status === 'upcoming' || after.status === 'reviewed') {
      return { chatId, setBookingChatId: false };
    }

    let nextReadOnlyAt = currentChat.readOnlyAt;
    if ((validClosingStatuses as readonly string[]).includes(after.status)) {
      nextReadOnlyAt = new Date(now.getTime() + BOOKING_CHAT_READONLY_DAYS * 24 * 60 * 60 * 1000);
    }

    if (nextReadOnlyAt !== currentChat.readOnlyAt) {
      currentChat = {
        ...currentChat,
        readOnlyAt: nextReadOnlyAt,
        updatedAt: now,
      };
    }

    if (targetStatus && !existingSysMsg && sysId) {
      const sysMsg: Message = {
        id: sysId,
        chatId,
        senderId: null,
        type: 'system',
        body: null,
        imagePath: null,
        point: null,
        system: {
          kind: 'booking_status',
          status: targetStatus,
        },
        createdAt: now,
      };
      tx.addMessage(sysMsg);
      currentChat = afterMessage(currentChat, sysMsg, now);
    }

    tx.setChat(currentChat);
    return { chatId, setBookingChatId: false };
  });
}
