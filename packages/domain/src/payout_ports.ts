import type { LedgerEntry, Payment } from './escrow.js';
import type { Payout, PayoutStatus } from './payout.js';
import type { PayoutAccount, PayoutAccountView } from './payout_account.js';
import type { Clock, IdGenerator } from './ports.js';

/** Encrypts the account number at rest; the adapter owns the key (AES-256-GCM in Functions). */
export interface AccountCipher {
  encrypt(plain: string): Promise<string>;
  decrypt(enc: string): Promise<string>;
}

export interface PayoutTx {
  getUserRole(uid: string): Promise<string | null>;
  getActiveAccount(userId: string): Promise<PayoutAccount | null>;
  getAccount(userId: string, accountId: string): Promise<PayoutAccount | null>;
  listPayouts(payeeId: string, statuses: readonly PayoutStatus[]): Promise<Payout[]>;
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
  /** Outside a transaction, for the staff CLI: payees with payable money. */
  listDuePayees(): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]>;
}

export interface PayoutGateway {
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
}
