import type {
  NotificationRow,
  NotificationStore,
  NotificationTx,
  PushMessage,
  PushSender,
  UserDirectory,
} from './notification_ports.js';

export class MemoryNotificationStore implements NotificationStore {
  readonly rows = new Map<string, NotificationRow>();
  readonly prefs = new Map<string, unknown>();
  readonly unread = new Map<string, { count: number; at: Date }>();
  /** Committed row write count. */
  writes = 0;

  private key(uid: string, id: string): string {
    return `${uid}/${id}`;
  }

  rowsOf(uid: string): NotificationRow[] {
    return [...this.rows.values()].filter((r) => r.userId === uid);
  }

  async runTransaction<T>(fn: (tx: NotificationTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const tx: NotificationTx = {
      getRow: async (uid, id) => {
        if (hasWritten) throw new Error('Transaction read after write: getRow');
        return this.rows.get(this.key(uid, id)) ?? null;
      },
      putRow: (r) => {
        hasWritten = true;
        staged.push(() => {
          this.rows.set(this.key(r.userId, r.id), r);
          this.writes += 1;
        });
      },
    };
    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }

  async getPrefs(uid: string): Promise<unknown> {
    return this.prefs.get(uid) ?? null;
  }

  async listUnreadIds(uid: string, limit: number): Promise<string[]> {
    return this.rowsOf(uid)
      .filter((r) => r.readAt === null)
      .slice(0, limit)
      .map((r) => r.id);
  }

  async markRead(uid: string, ids: readonly string[], at: Date): Promise<void> {
    for (const id of ids) {
      const r = this.rows.get(this.key(uid, id));
      if (r && r.readAt === null) this.rows.set(this.key(uid, id), { ...r, readAt: at });
    }
  }

  async countUnread(uid: string): Promise<number> {
    return this.rowsOf(uid).filter((r) => r.readAt === null).length;
  }

  async setUnreadCount(uid: string, count: number, at: Date): Promise<boolean> {
    const cur = this.unread.get(uid);
    if (cur && cur.at.getTime() > at.getTime()) return false;
    this.unread.set(uid, { count, at });
    return true;
  }

  async deleteReadBefore(cutoff: Date, limit: number): Promise<number> {
    let n = 0;
    for (const [k, r] of [...this.rows]) {
      if (n >= limit) break;
      if (r.readAt !== null && r.createdAt.getTime() < cutoff.getTime()) {
        this.rows.delete(k);
        n += 1;
      }
    }
    return n;
  }
}

export class MemoryPushSender implements PushSender {
  readonly sent: Array<{ uid: string; msg: PushMessage }> = [];
  /** When set, `send` rejects with it. */
  failWith: Error | null = null;

  async send(uid: string, msg: PushMessage): Promise<void> {
    if (this.failWith) throw this.failWith;
    this.sent.push({ uid, msg });
  }
}

export class MemoryUserDirectory implements UserDirectory {
  readonly users = new Map<string, { name: string; avatarUrl: string | null }>();

  async get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
    return this.users.get(uid) ?? null;
  }
}
