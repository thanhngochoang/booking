import type { GroupChat, GroupMember, GroupMessage, GroupPin } from './event_chat.js';
import type { EventChatStore, EventChatTx, PaidRegistration } from './event_chat_ports.js';

export class MemoryEventChatStore implements EventChatStore {
  readonly chats = new Map<string, GroupChat>();
  readonly members = new Map<string, GroupMember>(); // `${chatId}/${uid}`
  readonly messages = new Map<string, GroupMessage[]>(); // chatId -> in order
  readonly pins = new Map<string, GroupPin>(); // `${chatId}/${messageId}`
  /** Paid registrations now, by `${eventId}/${uid}/${registrationId}` (membership is derived from them). */
  readonly paid = new Map<string, PaidRegistration>();
  /** Committed write count. */
  writes = 0;

  private lock: Promise<void> = Promise.resolve();

  seedChat(c: GroupChat): void {
    this.chats.set(c.id, c);
  }

  seedMember(chatId: string, m: GroupMember): void {
    this.members.set(`${chatId}/${m.uid}`, m);
  }

  seedPaid(eventId: string, uid: string, registrationId: string, over: Partial<PaidRegistration> = {}): void {
    this.paid.set(`${eventId}/${uid}/${registrationId}`, {
      id: registrationId, createdAt: new Date(0), userName: `Tên ${uid}`, userAvatarUrl: null, ...over,
    });
  }

  /** The registration is no longer `paid` (cancelled, refunded or expired). */
  unpay(eventId: string, uid: string, registrationId: string): void {
    this.paid.delete(`${eventId}/${uid}/${registrationId}`);
  }

  messagesOf(chatId: string): GroupMessage[] {
    return this.messages.get(chatId) ?? [];
  }

  pinsOf(chatId: string): GroupPin[] {
    return [...this.pins.entries()].filter(([k]) => k.startsWith(`${chatId}/`)).map(([, v]) => v);
  }

  async runTransaction<T>(fn: (tx: EventChatTx) => Promise<T>): Promise<T> {
    const run = this.lock.then(async () => {
      const staged: Array<() => void> = [];
      let hasWritten = false;
      const read = (name: string): void => {
        if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
      };
      const write = (apply: () => void): void => {
        hasWritten = true;
        staged.push(() => {
          apply();
          this.writes += 1;
        });
      };
      const tx: EventChatTx = {
        getChat: async (id) => {
          read('getChat');
          return this.chats.get(id) ?? null;
        },
        getMember: async (chatId, uid) => {
          read('getMember');
          return this.members.get(`${chatId}/${uid}`) ?? null;
        },
        getMessage: async (chatId, id) => {
          read('getMessage');
          return this.messagesOf(chatId).find((m) => m.id === id) ?? null;
        },
        paidRegistrations: async (eventId, uid) => {
          read('paidRegistrations');
          return [...this.paid.entries()].filter(([k]) => k.startsWith(`${eventId}/${uid}/`)).map(([, v]) => v);
        },
        putChat: (c) => write(() => { this.chats.set(c.id, c); }),
        putMember: (chatId, m) => write(() => { this.members.set(`${chatId}/${m.uid}`, m); }),
        addMessage: (m) => write(() => { this.messages.set(m.chatId, [...this.messagesOf(m.chatId), m]); }),
        updateMessage: (m) =>
          write(() => {
            this.messages.set(m.chatId, this.messagesOf(m.chatId).map((x) => (x.id === m.id ? m : x)));
          }),
        putPin: (chatId, p) => write(() => { this.pins.set(`${chatId}/${p.messageId}`, p); }),
        deletePin: (chatId, messageId) => write(() => { this.pins.delete(`${chatId}/${messageId}`); }),
      };
      const result = await fn(tx);
      for (const apply of staged) apply();
      return result;
    });
    this.lock = run.then(() => undefined, () => undefined);
    return run;
  }
}
