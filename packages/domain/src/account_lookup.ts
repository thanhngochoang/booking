/**
 * Ports around a payout account change (S06.06): the bank's holder-name lookup, the verified legal
 * name, the OTP channel and the notices; plus the one fake lookup of the domain (S22.04 reuses it).
 */

/** What the bank (through the payment intermediary) says about an account. */
export type NameLookupResult =
  | { readonly status: 'found'; readonly holderName: string }
  | { readonly status: 'unsupported' }
  | { readonly status: 'not_found' };

/**
 * Whose account it is (S06.06): a provider's, whose holder must match the verified identity name, or an active
 * organizer's, whose holder must match the verified business legal name (S21.04, plan #223 Decision 3).
 */
export type PayoutHolder = 'provider' | 'organizer';

export interface AccountNameLookup {
  /**
   * `accountNumber` is normalised digits; the adapter never logs it. `holder` (set by the use cases) tells a
   * fake which verified name to echo; a real bank ignores it.
   */
  lookup(r: { bankCode: string; accountNumber: string; holder?: PayoutHolder }): Promise<NameLookupResult>;
}

/** `users/{uid}/private/identity.legalName` (written by identity verification, S21). */
export interface VerifiedNameReader {
  legalName(uid: string): Promise<string | null>;
}
// An organizer's business legal name (`verifications/{uid}.business.name`, approved) is read through the
// same port (`PayoutAccountDeps.businessNames`).

export interface OtpSender {
  send(r: { phone: string; code: string; purpose: 'payout_account' }): Promise<void>;
}

/** The phone the OTP goes to (`photographers/{uid}/private/contact.phone` today). */
export interface OtpPhoneReader {
  phoneOf(uid: string): Promise<string | null>;
}

/** Hashing and randomness for the OTP; the adapter uses a CSPRNG and SHA-256. */
export interface OtpCrypto {
  sha256Hex(input: string): Promise<string>;
  random(n: number): Uint8Array;
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

/**
 * The only fake lookup of the domain (tests, emulator, dev). Echoes `echoName` (the caller's
 * verified or normalised display name) so testers can match their own account, except: a number
 * ending 4321 → found `TRAN VAN B` (the mismatch case), 9999 → unsupported, 0404 → not_found.
 * No echo name → unsupported. (0000 is the payout gateway's failure number, never a lookup rule.)
 */
export class FakeAccountNameLookup implements AccountNameLookup {
  constructor(private readonly echoName: string | null) {}

  async lookup(r: { bankCode: string; accountNumber: string }): Promise<NameLookupResult> {
    const n = r.accountNumber;
    if (n.endsWith('4321')) return { status: 'found', holderName: 'TRAN VAN B' };
    if (n.endsWith('9999')) return { status: 'unsupported' };
    if (n.endsWith('0404')) return { status: 'not_found' };
    if (this.echoName === null) return { status: 'unsupported' };
    return { status: 'found', holderName: this.echoName };
  }
}
