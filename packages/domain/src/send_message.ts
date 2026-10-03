import { afterMessage, assertCanSend, validateMessageInput, type Message } from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import { DomainError } from './errors.js';

export async function sendMessage(
  deps: ChatDeps,
  input: {
    senderId: string;
    chatId: string;
    message: unknown;
  },
): Promise<Message> {
  const validated = validateMessageInput(input.message, input.senderId);

  return deps.chats.runTransaction(async (tx) => {
    const chat = await tx.getChat(input.chatId);
    if (!chat) {
      throw new DomainError('not_found');
    }

    const existingMessage = await tx.getMessage(input.chatId, validated.clientId);
    if (existingMessage) {
      return existingMessage;
    }

    const now = deps.clock.now();
    assertCanSend(chat, input.senderId, now);

    const message: Message = {
      id: validated.clientId,
      chatId: input.chatId,
      senderId: input.senderId,
      type: validated.type,
      body: validated.body,
      imagePath: validated.imagePath,
      point: validated.point,
      system: null,
      createdAt: now,
    };

    tx.addMessage(message);
    const nextChat = afterMessage(chat, message, now);
    tx.setChat(nextChat);

    const recipientId =
      input.senderId === chat.customerId ? chat.photographerId : chat.customerId;
    tx.incrementUnread(input.chatId, recipientId, 1);

    return message;
  });
}
