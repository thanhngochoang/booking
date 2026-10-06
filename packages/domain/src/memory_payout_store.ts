import { MemoryBookingStore } from './memory_booking_store.js';
import type { Payout, PayoutStatus } from './payout.js';
import type { Payment } from './escrow.js';
import type { PayoutAccount, PayoutAccountView } from './payout_account.js';
import type { PayoutStore, PayoutTx } from './payout_ports.js';

/**
 * In-memory reference store. Transactions run one at a time and apply their writes on success.
 * Payments, refunds and ledger entries live in the booking store it wraps.
 */
export class MemoryPayoutStore implements PayoutStore {
  constructor(readonly booking: MemoryBookingStore = new MemoryBookingStore()) {}

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

  private payable(payeeId: string): Payment[] {
    return [...this.booking.payments.values()]
      .filter((p) => p.payeeId === payeeId && p.escrowStatus === 'released' && !p.payoutId)
      .map((p) => ({ ...p }));
  }

  private refunded(paymentId: string): number {
    let sum = 0;
    for (const r of this.booking.refunds.values()) if (r.paymentId === paymentId) sum += r.amount;
    return sum;
  }

  async listDuePayees(): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]> {
    const totals = new Map<string, number>();
    for (const p of this.booking.payments.values()) {
      if (p.escrowStatus !== 'released' || p.payoutId) continue;
      const net = p.amount - this.refunded(p.id);
      if (net > 0) totals.set(p.payeeId, (totals.get(p.payeeId) ?? 0) + net);
    }
    return [...totals.entries()].map(([payeeId, amount]) => ({
      payeeId,
      amount,
      hasAccount: [...this.accounts.values()].some((a) => a.userId === payeeId && a.active),
    }));
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
        listPayablePayments: async (payeeId) => {
          read('listPayablePayments');
          return this.payable(payeeId);
        },
        getPayments: async (ids) => {
          read('getPayments');
          return ids.map((id) => {
            const p = this.booking.payments.get(id);
            return p ? { ...p } : null;
          });
        },
        refundedTotal: async (paymentId) => {
          read('refundedTotal');
          return this.refunded(paymentId);
        },
        getPayout: async (id) => {
          read('getPayout');
          return this.payouts.get(id) ?? null;
        },
        setPayment: (p) => stage(() => void this.booking.payments.set(p.id, { ...p })),
        addLedgerEntry: (e) => stage(() => void this.booking.ledgerEntries.set(e.id, { ...e })),
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
