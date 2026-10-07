import type { GroupChat, GroupMember, GroupMessage, GroupPin } from './event_chat.js';
import type { Clock, IdGenerator } from './ports.js';

/** Every read must come before the first write (Firestore transactions; the memory store enforces it). */
export interface EventChatTx {
  getChat(chatId: string): Promise<GroupChat | null>;
  getMember(chatId: string, uid: string): Promise<GroupMember | null>;
  getMessage(chatId: string, messageId: string): Promise<GroupMessage | null>;
  /** A `paid` registration of the user for the event other than `exceptRegistrationId`. */
  hasOtherPaidRegistration(eventId: string, uid: string, exceptRegistrationId: string): Promise<boolean>;
  putChat(chat: GroupChat): void;
  putMember(chatId: string, member: GroupMember): void;
  addMessage(message: GroupMessage): void;
  updateMessage(message: GroupMessage): void;
  putPin(chatId: string, pin: GroupPin): void;
  deletePin(chatId: string, messageId: string): void;
}

export interface EventChatStore {
  runTransaction<T>(fn: (tx: EventChatTx) => Promise<T>): Promise<T>;
}

export interface EventChatDeps {
  readonly chats: EventChatStore;
  /** Display name and avatar only; never a phone or an email. */
  readonly people: { user(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> };
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
