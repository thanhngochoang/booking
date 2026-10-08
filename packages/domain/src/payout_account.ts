/** Payout account rules (S06.06): input normalisation and the stored/view shapes. */

export const ACCOUNT_NUMBER_MIN = 6;
export const ACCOUNT_NUMBER_MAX = 20;
export const HOLDER_NAME_MIN = 2;
export const HOLDER_NAME_MAX = 50;
/** A change of account needs a sign-in at most this many seconds old. */
export const REAUTH_MAX_AGE_SECONDS = 300;

/** Digits only after dropping spaces, dots and dashes; 6–20 of them, else null. */
export function normalizeAccountNumber(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const digits = raw.replace(/[ .-]/g, '');
  return /^[0-9]{6,20}$/.test(digits) ? digits : null;
}

/** Upper-case ASCII without diacritics, `Đ` → `D`, single spaces, 2–50 letters/spaces; else null. */
export function normalizeHolderName(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const ascii = raw
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toUpperCase()
    .replace(/\s+/g, ' ')
    .trim();
  if (!/^[A-Z ]+$/.test(ascii)) return null;
  if (ascii.length < HOLDER_NAME_MIN || ascii.length > HOLDER_NAME_MAX) return null;
  return ascii;
}

export function accountLast4(n: string): string {
  return n.slice(-4);
}

/**
 * `matched`: the bank's holder name equals the verified name; `pending_review`: staff compare it
 * before the first payout; `staff_confirmed`: staff did.
 */
export const NAME_STATUSES = ['matched', 'pending_review', 'staff_confirmed'] as const;
export type NameStatus = (typeof NAME_STATUSES)[number];

/** Money may move to the account: it is the active one and its activeFrom has come. */
export function isAccountActiveAt(a: Pick<PayoutAccount, 'active' | 'activeFrom'>, now: Date): boolean {
  return a.active && !isAccountWaitingAt(a, now);
}

/** The account's activeFrom is still ahead (the wait after a change); an unreadable one waits too. */
export function isAccountWaitingAt(a: Pick<PayoutAccount, 'activeFrom'>, now: Date): boolean {
  return !(Date.parse(a.activeFrom) <= now.getTime());
}

/** Server-only history document: the number is ciphertext, never plain. */
export interface PayoutAccount {
  readonly id: string;
  readonly userId: string;
  readonly bankCode: string;
  readonly accountNumberEnc: string;
  readonly accountLast4: string;
  readonly holderName: string;
  readonly active: boolean;
  readonly createdAt: string;
  readonly deactivatedAt?: string;
  readonly nameStatus: NameStatus;
  /** No payout is created or sent before this instant. */
  readonly activeFrom: string;
}

/** Owner-readable masked view of the active account. */
export interface PayoutAccountView {
  readonly accountId: string;
  readonly bankCode: string;
  readonly accountLast4: string;
  readonly holderName: string;
  readonly updatedAt: string;
  readonly nameStatus: NameStatus;
  readonly activeFrom: string;
}
