import { chatIdFor, type Chat } from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import { DomainError } from './errors.js';

export async function openInquiry(
  deps: ChatDeps,
  input: { customerId: string; photographerId: string },
): Promise<{ chatId: string; created: boolean }> {
  if (
    !input.customerId ||
    !input.photographerId ||
    input.customerId === input.photographerId
  ) {
    throw new DomainError('invalid_argument');
  }

  const chatId = chatIdFor(input.customerId, input.photographerId);

  return deps.chats.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const existing = await tx.getChat(chatId);
    if (existing) {
      // A past customer's booking chat, read-only since readOnlyAt, becomes an inquiry again
      // (same thread, history kept). They already talked during the booking, so the
      // 3-message cap does not apply: photographerRepliedAt is kept, or set to now when the
      // booking chat never recorded one (afterMessage only tracks it for inquiries).
      if (
        existing.kind === 'booking' &&
        existing.readOnlyAt !== null &&
        now.getTime() >= existing.readOnlyAt.getTime()
      ) {
        if (!(await deps.photographers.acceptsInquiries(input.photographerId))) {
          throw new DomainError('not_eligible');
        }
        tx.setChat({
          ...existing,
          kind: 'inquiry',
          bookingId: null,
          bookingStatus: null,
          readOnlyAt: null,
          photographerRepliedAt: existing.photographerRepliedAt ?? now,
          updatedAt: now,
        });
      }
      return { chatId, created: false };
    }

    const accepts = await deps.photographers.acceptsInquiries(input.photographerId);
    if (!accepts) {
      throw new DomainError('not_eligible');
    }

    const newChat: Chat = {
      id: chatId,
      kind: 'inquiry',
      customerId: input.customerId,
      photographerId: input.photographerId,
      bookingId: null,
      bookingStatus: null,
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

    tx.setChat(newChat);
    tx.incrementUnread(chatId, input.customerId, 0);
    tx.incrementUnread(chatId, input.photographerId, 0);

    return { chatId, created: true };
  });
}
