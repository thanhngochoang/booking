import type {
  AccountNameLookup,
  OtpCrypto,
  OtpPhoneReader,
  OtpSender,
  PayoutNotices,
  VerifiedNameReader,
} from './account_lookup.js';
import type { LedgerEntry, Payment } from './escrow.js';
import type { Payout, PayoutStatus } from './payout.js';
import type { PayoutAccount, PayoutAccountView } from './payout_account.js';
import type { OtpChallenge } from './payout_otp.js';
import type { PayoutPolicy } from './payout_policy.js';
import type { Clock, IdGenerator } from './ports.js';
import type { ProviderType } from './provider_type.js';

export type {
  AccountNameLookup,
  NameLookupResult,
  OtpCrypto,
  OtpPhoneReader,
  OtpSender,
  PayoutNotices,
  VerifiedNameReader,
} from './account_lookup.js';

/** Encrypts the account number at rest; the adapter owns the key (AES-256-GCM in Functions). */
export interface AccountCipher {
  encrypt(plain: string): Promise<string>;
  decrypt(enc: string): Promise<string>;
}

export interface PayoutTx {
  getUserRole(uid: string): Promise<string | null>;
  /** `organizers/{uid}.status` (S30); null when the user is not an organizer. */
  getOrganizerStatus(uid: string): Promise<'active' | 'suspended' | null>;
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
  /** `organizers/{uid}.payoutAccountOk` (S30, Decision 3), written with the account. */
  setOrganizerPayoutOk(uid: string, ok: boolean): void;
  putPayout(p: Payout): void;
  /** Escrow `released` and not in any batch (`payoutId` empty). */
  listPayablePayments(payeeId: string): Promise<Payment[]>;
  getPayments(ids: readonly string[]): Promise<(Payment | null)[]>;
  refundedTotal(paymentId: string): Promise<number>;
  getPayout(id: string): Promise<Payout | null>;
  setPayment(p: Payment): void;
  addLedgerEntry(e: LedgerEntry): void;
  /** `otp_challenges/{uid}_payout_account` (server-only). */
  getOtpChallenge(uid: string): Promise<OtpChallenge | null>;
  putOtpChallenge(c: OtpChallenge): void;
  /** `payout_lookups/{uid}` (server-only): name lookups on one Vietnam day. */
  getLookupQuota(uid: string): Promise<{ day: string; count: number } | null>;
  putLookupQuota(uid: string, q: { day: string; count: number }): void;
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

/** What every payout use case needs. */
export interface PayoutCoreDeps {
  readonly store: PayoutStore;
  readonly cipher: AccountCipher;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

/** The photographer's account use cases (S06.06): lookup, OTP, save. */
export interface PayoutAccountDeps extends PayoutCoreDeps {
  readonly lookup: AccountNameLookup;
  readonly names: VerifiedNameReader;
  /**
   * An active organizer's verified business legal name (S21.04 approved, subject `organizer`); null when it has
   * none. Missing: organizers have no verified name (staff compare before the first payout).
   */
  readonly businessNames?: VerifiedNameReader;
  readonly otp: { readonly sender: OtpSender; readonly phones: OtpPhoneReader; readonly crypto: OtpCrypto };
  readonly notices: PayoutNotices;
}

/** Staff and daily payout use cases. */
export interface PayoutDeps extends PayoutCoreDeps {
  readonly gateway: PayoutGateway;
  readonly policy: PayoutPolicy;
  readonly notices: PayoutNotices;
}
