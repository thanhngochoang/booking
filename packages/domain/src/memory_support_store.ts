import type { SupportMessage, SupportThread } from './support_thread.js';
import type { SupportStore, SupportTx } from './support_use_cases.js';

export class MemorySupportStore implements SupportStore {
  readonly threads = new Map<string, SupportThread>();
  // threadId -> Map<messageId, SupportMessage>
  readonly messages = new Map<string, Map<string, SupportMessage>>();

  async runTransaction<T>(fn: (tx: SupportTx) => Promise<T>): Promise<T> {
    const stagedThreads = new Map<string, SupportThread>();
    const stagedMessages = new Map<string, Map<string, SupportMessage>>();
    let hasWritten = false;

    const tx: SupportTx = {
      getThread: async (id) => {
        if (hasWritten) {
          throw new Error('Read after write in transaction');
        }
        return this.threads.get(id) ?? null;
      },

      getMessage: async (threadId, id) => {
        if (hasWritten) {
          throw new Error('Read after write in transaction');
        }
        return this.messages.get(threadId)?.get(id) ?? null;
      },

      // A support-only store has no disputes (MemoryDisputeStore has).
      getDispute: async () => {
        if (hasWritten) {
          throw new Error('Read after write in transaction');
        }
        return null;
      },

      putThread: (t) => {
        hasWritten = true;
        stagedThreads.set(t.id, t);
      },

      addMessage: (m) => {
        hasWritten = true;
        let threadMsgs = stagedMessages.get(m.threadId);
        if (!threadMsgs) {
          threadMsgs = new Map();
          stagedMessages.set(m.threadId, threadMsgs);
        }
        threadMsgs.set(m.id, m);
      },
    };

    const result = await fn(tx);

    for (const [id, t] of stagedThreads) {
      this.threads.set(id, t);
    }
    for (const [tId, msgs] of stagedMessages) {
      let existing = this.messages.get(tId);
      if (!existing) {
        existing = new Map();
        this.messages.set(tId, existing);
      }
      for (const [mId, m] of msgs) {
        existing.set(mId, m);
      }
    }

    return result;
  }

  async listAwaitingStaff(limit: number): Promise<readonly SupportThread[]> {
    const list = Array.from(this.threads.values())
      .filter((t) => t.awaitingStaff)
      .sort((a, b) => {
        const timeA = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0;
        const timeB = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0;
        return timeA - timeB; // oldest first
      });
    return list.slice(0, limit);
  }

  async listMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]> {
    const threadMsgs = this.messages.get(threadId);
    if (!threadMsgs) return [];
    const list = Array.from(threadMsgs.values())
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()); // newest first
    return list.slice(0, limit);
  }
}
