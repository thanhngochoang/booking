import type { EarningItem, EarningSubject, EarningsSummary } from './earnings.js';
import type { EarningsStore, EarningsTx } from './earnings_ports.js';
import { isEscrowRefund, isSettledPayment } from './escrow.js';
import type { MemoryBookingStore } from './memory_booking_store.js';
import type { MemoryPayoutStore } from './memory_payout_store.js';

/** In-memory reference store. Reads payments, bookings and payouts from the stores it wraps. */
export class MemoryEarningsStore implements EarningsStore {
  /** key `${payeeId}/${paymentId}` */
  readonly items = new Map<string, EarningItem>();
  readonly summaries = new Map<string, EarningsSummary>();
  /** bookingId → released / all milestones (written by the delivery flow); missing → null. */
  readonly milestones = new Map<string, { done: number; total: number }>();
  /** Counts of committed writes, by kind. */
  itemWrites = 0;
  itemDeletes = 0;
  summaryWrites = 0;
  private queue: Promise<unknown> = Promise.resolve();

  constructor(
    private readonly booking: MemoryBookingStore,
    private readonly payouts: MemoryPayoutStore,
    /** uid → display name of customers. */
    readonly names: Map<string, string> = new Map(),
  ) {}

  async runTransaction<T>(fn: (tx: EarningsTx) => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => {
      const staged: Array<() => void> = [];
      let hasWritten = false;
      const read = (name: string): void => {
        if (hasWritten) throw new Error(`Transaction read after write: ${name}`);
      };
      const stage = (apply: () => void): void => {
        hasWritten = true;
        staged.push(apply);
      };
      const tx: EarningsTx = {
        getPayment: async (id) => {
          read('getPayment');
          const p = this.booking.payments.get(id);
          return p ? { ...p } : null;
        },
        getPayeeType: async (uid) => {
          read('getPayeeType');
          return this.payouts.payeeTypeOf(uid);
        },
        refundedTotal: async (paymentId) => {
          read('refundedTotal');
          let sum = 0;
          for (const r of this.booking.refunds.values()) if (r.paymentId === paymentId && isEscrowRefund(r)) sum += r.amount;
          return sum;
        },
        getSubject: async (p): Promise<EarningSubject | null> => {
          read('getSubject');
          if (p.subjectType !== 'booking') return null;
          if (!isSettledPayment(p) && p.status !== 'refunded') return null;
          const b = this.booking.bookings.get(p.subjectId);
          if (!b) return null;
          return {
            counterpartName: this.names.get(b.customerId) ?? '',
            label: b.serviceSnapshot.name,
            day: b.day,
            milestones: this.milestones.get(b.id) ?? null,
          };
        },
        getPayout: async (id) => {
          read('getPayout');
          return this.payouts.payouts.get(id) ?? null;
        },
        latestPayout: async (payeeId) => {
          read('latestPayout');
          const mine = [...this.payouts.payouts.values()].filter((p) => p.payeeId === payeeId);
          mine.sort((a, b) => (a.createdAt === b.createdAt ? a.id.localeCompare(b.id) : a.createdAt.localeCompare(b.createdAt)));
          return mine.at(-1) ?? null;
        },
        listItems: async (payeeId) => {
          read('listItems');
          return [...this.items.values()].filter((i) => i.payeeId === payeeId);
        },
        putItem: (i) =>
          stage(() => {
            this.items.set(`${i.payeeId}/${i.id}`, i);
            this.itemWrites += 1;
          }),
        deleteItem: (payeeId, id) =>
          stage(() => {
            this.items.delete(`${payeeId}/${id}`);
            this.itemDeletes += 1;
          }),
        putSummary: (s) =>
          stage(() => {
            this.summaries.set(s.payeeId, s);
            this.summaryWrites += 1;
          }),
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
