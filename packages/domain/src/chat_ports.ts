import type { Chat, Message, SystemPayload } from './chat.js';
import type { Clock, IdGenerator } from './ports.js';

export interface ChatTx {
  getChat(id: string): Promise<Chat | null>;
  getMessage(chatId: string, id: string): Promise<Message | null>;
  setChat(chat: Chat): void;
  addMessage(m: Message): void;
  updateMessageSystem(chatId: string, id: string, system: SystemPayload): void;
  incrementUnread(chatId: string, uid: string, by: number): void; // members/{uid}.unreadCount
}

export interface ChatStore {
  runTransaction<T>(fn: (tx: ChatTx) => Promise<T>): Promise<T>;
  pendingProposal(chatId: string): Promise<Message | null>; // latest reschedule_proposal without answer
}

export interface PhotographerInquiryReader {
  acceptsInquiries(photographerId: string): Promise<boolean>;
}

export interface ChatDeps {
  readonly chats: ChatStore;
  readonly photographers: PhotographerInquiryReader;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
