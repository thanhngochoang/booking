import type { LedgerEntry, Payment } from './escrow.js';
import type { Payout, PayoutStatus } from './payout.js';
import type { PayoutAccount, PayoutAccountView } from './payout_account.js';
import type { PayoutPolicy } from './payout_policy.js';
import type { Clock, IdGenerator } from './ports.js';
import type { ProviderType } from './provider_type.js';

/** Encrypts the account number at rest; the adapter owns the key (AES-256-GCM in Functions). */
export interface AccountCipher {
  encrypt(plain: string): Promise<string>;
  decrypt(enc: string): Promise<string>;
}

export interface PayoutTx {
  getUserRole(uid: string): Promise<string | null>;
  /** The payee's provider type (decides the tax); missing or unknown → 'individual'. */
  getPayeeType(uid: string): Promise<ProviderType>;
  getActiveAccount(userId: string): Promise<PayoutAccount | null>;
  getAccount(userId: string, accountId: string): Promise<PayoutAccount | null>;
  listPayouts(payeeId: string, statuses: readonly PayoutStatus[]): Promise<Payout[]>;
  /**
   * Whether staff have cleared this account: some payout to it is `paid`, or is `pending`/
   * `processing` with `approvedBy` set (`failed` never counts). Bounded read (limit 1 per query).
   */
  hasApprovedOrPaidPayout(accountId: string): Promise<boolean>;
  /** The last `limit` finished (`paid`/`failed`) payouts to this account, newest `createdAt` first. */
  lastFinishedPayouts(accountId: string, limit: number): Promise<Payout[]>;
  putAccount(a: PayoutAccount): void;
  putAccountView(userId: string, v: PayoutAccountView): void;
  putPayout(p: Payout): void;
  /** Escrow `released` and not in any batch (`payoutId` empty). */
  listPayablePayments(payeeId: string): Promise<Payment[]>;
  getPayments(ids: readonly string[]): Promise<(Payment | null)[]>;
  refundedTotal(paymentId: string): Promise<number>;
  getPayout(id: string): Promise<Payout | null>;
  setPayment(p: Payment): void;
  addLedgerEntry(e: LedgerEntry): void;
}

export interface PayoutStore {
  runTransaction<T>(fn: (tx: PayoutTx) => Promise<T>): Promise<T>;
  /**
   * Outside a transaction, for the staff CLI and the daily run: payees with payable money.
   * `hasAccount` means the payee has an account document (active from now or later).
   */
  listDuePayees(): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]>;
  /** Outside a transaction: ids of payouts in these statuses, oldest `createdAt` first, at most `limit`. */
  listPayoutIdsByStatus(statuses: readonly PayoutStatus[], limit: number): Promise<string[]>;
}

/** Notices the payout use cases send (#138 owns their copy, dedupe and targets). */
export interface PayoutNotices {
  /** Money is due but the payee has no account yet. */
  accountNeeded(payeeId: string, amount: number): Promise<void>;
  /** The payout account changed (critical; goes to the owner). */
  accountChanged(
    uid: string,
    v: { accountId: string; bankCode: string; accountLast4: string; activeFrom: string },
  ): Promise<void>;
}

export interface PayoutGateway {
  /**
   * `payoutId` is an idempotency key: the real adapter MUST send it to the bank so that a retry
   * of the same payout (after a crash between the transfer and the ledger write) never pays twice
   * and returns the first outcome.
   */
  transfer(r: {
    payoutId: string;
    amount: number;
    bankCode: string;
    accountNumber: string;
    holderName: string;
  }): Promise<{ status: 'paid' | 'failed'; reference?: string; failureReason?: string }>;
}

export interface PayoutAccountDeps {
  readonly store: PayoutStore;
  readonly cipher: AccountCipher;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

export interface PayoutDeps extends PayoutAccountDeps {
  readonly gateway: PayoutGateway;
  readonly policy: PayoutPolicy;
  readonly notices: PayoutNotices;
}
