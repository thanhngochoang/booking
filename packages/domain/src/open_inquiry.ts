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
    const existing = await tx.getChat(chatId);
    if (existing) {
      return { chatId, created: false };
    }

    const accepts = await deps.photographers.acceptsInquiries(input.photographerId);
    if (!accepts) {
      throw new DomainError('not_eligible');
    }

    const now = deps.clock.now();
    const newChat: Chat = {
      id: chatId,
      kind: 'inquiry',
      customerId: input.customerId,
      photographerId: input.photographerId,
      bookingId: null,
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
