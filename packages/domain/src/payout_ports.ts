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
}

export interface PayoutStore {
  runTransaction<T>(fn: (tx: PayoutTx) => Promise<T>): Promise<T>;
}

export interface PayoutAccountDeps {
  readonly store: PayoutStore;
  readonly cipher: AccountCipher;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
