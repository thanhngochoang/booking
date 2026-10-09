import type { EarningItem, EarningSubject, EarningsSummary } from './earnings.js';
import type { Payment } from './escrow.js';
import type { Payout } from './payout.js';
import type { PayoutPolicy } from './payout_policy.js';
import type { Clock } from './ports.js';
import type { ProviderType } from './provider_type.js';

export interface EarningsTx {
  getPayment(id: string): Promise<Payment | null>;
  /** The payee's provider type (decides the tax estimate); missing or unknown → 'individual'. */
  getPayeeType(uid: string): Promise<ProviderType>;
  refundedTotal(paymentId: string): Promise<number>;
  /** Null when the booking is gone. */
  getSubject(p: Payment): Promise<EarningSubject | null>;
  getPayout(id: string): Promise<Payout | null>;
  /** Newest `createdAt`. */
  latestPayout(payeeId: string): Promise<Payout | null>;
  listItems(payeeId: string): Promise<EarningItem[]>;
  putItem(i: EarningItem): void;
  deleteItem(payeeId: string, id: string): void;
  putSummary(s: EarningsSummary): void;
}

export interface EarningsStore {
  runTransaction<T>(fn: (tx: EarningsTx) => Promise<T>): Promise<T>;
}

export interface EarningsDeps {
  readonly store: EarningsStore;
  readonly clock: Clock;
  readonly policy: PayoutPolicy;
}
