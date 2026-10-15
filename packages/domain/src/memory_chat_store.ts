import type { Chat, Message, SystemPayload } from './chat.js';
import type { ChatStore, ChatTx } from './chat_ports.js';

export class MemoryChatStore implements ChatStore {
  readonly chats = new Map<string, Chat>();
  readonly messages = new Map<string, Message[]>(); // chatId -> Message[]
  readonly unread = new Map<string, Map<string, number>>(); // chatId -> uid -> count

  private lock: Promise<void> = Promise.resolve();

  async runTransaction<T>(fn: (tx: ChatTx) => Promise<T>): Promise<T> {
    const nextLock = this.lock.then(async () => {
      let hasWritten = false;
      const stagedChats = new Map<string, Chat>();
      const stagedMessages: Message[] = [];
      const stagedSystemUpdates: Array<{ chatId: string; id: string; system: SystemPayload }> = [];
      const stagedUnreadIncrements: Array<{ chatId: string; uid: string; by: number }> = [];

      const tx: ChatTx = {
        getChat: async (id: string): Promise<Chat | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const chat = this.chats.get(id);
          return chat ? { ...chat } : null;
        },
        getMessage: async (chatId: string, id: string): Promise<Message | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const msgs = this.messages.get(chatId) ?? [];
          const found = msgs.find((m) => m.id === id);
          return found ? { ...found } : null;
        },
        setChat: (chat: Chat): void => {
          hasWritten = true;
          stagedChats.set(chat.id, { ...chat });
        },
        addMessage: (m: Message): void => {
          hasWritten = true;
          stagedMessages.push({ ...m });
        },
        updateMessageSystem: (chatId: string, id: string, system: SystemPayload): void => {
          hasWritten = true;
          stagedSystemUpdates.push({ chatId, id, system: { ...system } });
        },
        incrementUnread: (chatId: string, uid: string, by: number): void => {
          hasWritten = true;
          stagedUnreadIncrements.push({ chatId, uid, by });
        },
      };

      const result = await fn(tx);

      // Commit staged writes
      for (const [id, chat] of stagedChats) {
        this.chats.set(id, chat);
      }
      for (const m of stagedMessages) {
        const msgs = this.messages.get(m.chatId) ?? [];
        msgs.push(m);
        this.messages.set(m.chatId, msgs);
      }
      for (const u of stagedSystemUpdates) {
        const msgs = this.messages.get(u.chatId) ?? [];
        const idx = msgs.findIndex((m) => m.id === u.id);
        const existing = msgs[idx];
        if (idx !== -1 && existing) {
          msgs[idx] = { ...existing, system: u.system };
        }
      }
      for (const inc of stagedUnreadIncrements) {
        let chatUnread = this.unread.get(inc.chatId);
        if (!chatUnread) {
          chatUnread = new Map();
          this.unread.set(inc.chatId, chatUnread);
        }
        const curr = chatUnread.get(inc.uid) ?? 0;
        chatUnread.set(inc.uid, Math.max(0, curr + inc.by));
      }

      return result;
    });

    this.lock = nextLock.then(
      () => {},
      () => {},
    );
    return nextLock;
  }

  async pendingProposal(chatId: string): Promise<Message | null> {
    const msgs = this.messages.get(chatId) ?? [];
    for (let i = msgs.length - 1; i >= 0; i--) {
      const m = msgs[i];
      if (
        m &&
        m.type === 'system' &&
        m.system?.kind === 'reschedule_proposal' &&
        !m.system.answer
      ) {
        return { ...m };
      }
    }
    return null;
  }
}
