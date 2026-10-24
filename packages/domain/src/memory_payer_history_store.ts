import type { Payment, Refund } from './escrow.js';
import type {
  PayerHistoryStore,
  PayerHistoryTx,
  PayerPaymentRow,
  PayerSubjectView,
  PayerTotals,
} from './payer_history.js';

const FALLBACK_SUBJECT: PayerSubjectView = { title: '', day: null, eventId: null, searching: false, cancelled: false };

/**
 * In-memory reference store for S22.01. Like Firestore, a transaction refuses a read after its
 * first write; writes apply when the transaction function resolves.
 */
export class MemoryPayerHistoryStore implements PayerHistoryStore {
  readonly payments = new Map<string, Payment>();
  /** By refund id. */
  readonly refunds = new Map<string, Refund>();
  /** By payment id; a payment without one reads an empty title. */
  readonly subjects = new Map<string, PayerSubjectView>();
  /** Key `${payerId}/${paymentId}`. */
  readonly rows = new Map<string, PayerPaymentRow>();
  readonly totals = new Map<string, PayerTotals & { readonly updatedAt: string }>();
  rowWrites = 0;
  private queue: Promise<unknown> = Promise.resolve();

  async runTransaction<T>(fn: (tx: PayerHistoryTx) => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => {
      const staged: Array<() => void> = [];
      let wrote = false;
      const read = (name: string): void => {
        if (wrote) throw new Error(`Transaction read after write: ${name}`);
      };
      const stage = (apply: () => void): void => {
        wrote = true;
        staged.push(apply);
      };
      const tx: PayerHistoryTx = {
        payment: async (id) => {
          read('payment');
          return this.payments.get(id) ?? null;
        },
        refundsOf: async (paymentId) => {
          read('refundsOf');
          return [...this.refunds.values()].filter((r) => r.paymentId === paymentId);
        },
        subjectOf: async (p) => {
          read('subjectOf');
          return this.subjects.get(p.id) ?? FALLBACK_SUBJECT;
        },
        openRows: async (payerId) => {
          read('openRows');
          return [...this.rows.values()].filter((r) => r.payerId === payerId && r.open);
        },
        putRow: (row) =>
          stage(() => {
            this.rows.set(`${row.payerId}/${row.paymentId}`, row);
            this.rowWrites += 1;
          }),
        deleteRow: (payerId, paymentId) => stage(() => this.rows.delete(`${payerId}/${paymentId}`)),
        putTotals: (payerId, totals, at) =>
          stage(() => this.totals.set(payerId, { held: totals.held, refunding: totals.refunding, updatedAt: at.toISOString() })),
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
