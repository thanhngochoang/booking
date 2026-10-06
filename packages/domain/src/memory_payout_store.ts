import type { Payout, PayoutStatus } from './payout.js';
import type { PayoutAccount, PayoutAccountView } from './payout_account.js';
import type { PayoutStore, PayoutTx } from './payout_ports.js';

/** In-memory reference store. Transactions run one at a time and apply their writes on success. */
export class MemoryPayoutStore implements PayoutStore {
  readonly roles = new Map<string, string>();
  /** key `${userId}/${accountId}` */
  readonly accounts = new Map<string, PayoutAccount>();
  readonly accountViews = new Map<string, PayoutAccountView>();
  readonly payouts = new Map<string, Payout>();
  /** Committed write count. */
  writes = 0;
  private queue: Promise<unknown> = Promise.resolve();

  seedRole(uid: string, role: string): void {
    this.roles.set(uid, role);
  }

  seedPayout(p: Payout): void {
    this.payouts.set(p.id, p);
  }

  async runTransaction<T>(fn: (tx: PayoutTx) => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => {
      const staged: Array<() => void> = [];
      let hasWritten = false;
      const read = (name: string): void => {
        if (hasWritten) throw new Error(`Transaction read after write: ${name}`);
      };
      const stage = (apply: () => void): void => {
        hasWritten = true;
        staged.push(() => {
          apply();
          this.writes += 1;
        });
      };
      const tx: PayoutTx = {
        getUserRole: async (uid) => {
          read('getUserRole');
          return this.roles.get(uid) ?? null;
        },
        getActiveAccount: async (userId) => {
          read('getActiveAccount');
          return [...this.accounts.values()].find((a) => a.userId === userId && a.active) ?? null;
        },
        getAccount: async (userId, accountId) => {
          read('getAccount');
          return this.accounts.get(`${userId}/${accountId}`) ?? null;
        },
        listPayouts: async (payeeId, statuses: readonly PayoutStatus[]) => {
          read('listPayouts');
          return [...this.payouts.values()].filter(
            (p) => p.payeeId === payeeId && statuses.includes(p.status),
          );
        },
        putAccount: (a) => stage(() => void this.accounts.set(`${a.userId}/${a.id}`, a)),
        putAccountView: (userId, v) => stage(() => void this.accountViews.set(userId, v)),
        putPayout: (p) => stage(() => void this.payouts.set(p.id, p)),
      };
      const result = await fn(tx);
      for (const apply of staged) apply();
      return result;
    };
    const next = this.queue.then(run, run);
    this.queue = next.catch(() => undefined);
    return next;
  }
}
