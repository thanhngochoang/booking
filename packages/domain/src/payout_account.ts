/** Payout account rules (S06.06): input normalisation, the holder-name match and the stored/view shapes. */

import type { NameLookupResult } from './account_lookup.js';
import { bankByCode, type VnBank } from './vn_banks.js';

export type { NameLookupResult } from './account_lookup.js';

export const ACCOUNT_NUMBER_MIN = 6;
export const ACCOUNT_NUMBER_MAX = 20;
export const HOLDER_NAME_MIN = 2;
export const HOLDER_NAME_MAX = 50;
/**
 * A sensitive action that still asks for a fresh sign-in (`reauth_required`, e.g. S22.02 account
 * deletion) needs one at most this many seconds old. A payout account change uses an OTP instead.
 */
export const REAUTH_MAX_AGE_SECONDS = 300;
/** A changed account receives money only this many hours after the change (payments spec M6). */
export const ACCOUNT_CHANGE_DELAY_HOURS = 72;
/** Name lookups per photographer per Vietnam day: the lookup reveals a name, it must not become an oracle. */
export const NAME_LOOKUPS_PER_DAY = 20;

/** Digits only after dropping spaces, dots and dashes; 6–20 of them, else null. */
export function normalizeAccountNumber(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const digits = raw.replace(/[ .-]/g, '');
  return /^[0-9]{6,20}$/.test(digits) ? digits : null;
}

/** Upper-case ASCII fold: no diacritics, `Đ` → `D`, single spaces, trimmed (no validation). */
function foldName(raw: string): string {
  return raw
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toUpperCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/** Upper-case ASCII without diacritics, `Đ` → `D`, single spaces, 2–50 letters/spaces; else null. */
export function normalizeHolderName(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const ascii = foldName(raw);
  if (!/^[A-Z ]+$/.test(ascii)) return null;
  if (ascii.length < HOLDER_NAME_MIN || ascii.length > HOLDER_NAME_MAX) return null;
  return ascii;
}

/** The comparable form of a name (normalised, or folded when it does not validate); '' = no name. */
export function holderNameKey(raw: string | null): string {
  if (raw === null) return '';
  return normalizeHolderName(raw) ?? foldName(raw);
}

/**
 * `matched`: the bank's name is the verified name; `mismatch`: it is someone else's (refused);
 * `review`: staff compare before the first payout (the bank gave no name but we know the verified
 * one, or the bank gave a name but nobody is verified yet); `not_found`: no such account;
 * `unverifiable`: neither name is known (refused). A blank bank name counts as no name.
 */
export type HolderNameDecision = 'matched' | 'mismatch' | 'review' | 'not_found' | 'unverifiable';

export function holderNameDecision(lookup: NameLookupResult, verifiedName: string | null): HolderNameDecision {
  if (lookup.status === 'not_found') return 'not_found';
  const verified = holderNameKey(verifiedName);
  const found = lookup.status === 'found' ? holderNameKey(lookup.holderName) : '';
  if (found === '') return verified === '' ? 'unverifiable' : 'review';
  if (verified === '') return 'review';
  return found === verified ? 'matched' : 'mismatch';
}

/** The validated target of a lookup, an OTP request or a save. */
export interface AccountTarget {
  readonly bank: VnBank;
  readonly number: string;
  readonly otpCode?: string;
}

/**
 * Exactly `{bankCode, accountNumber}` (plus `otpCode`, 6 digits, when `allowOtp`); any other key,
 * an unknown bank or a bad number is null (the caller refuses with `invalid_argument`).
 */
export function parseAccountTarget(raw: unknown, allowOtp: boolean): AccountTarget | null {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return null;
  const input = raw as Record<string, unknown>;
  const allowed = allowOtp ? ['accountNumber', 'bankCode', 'otpCode'] : ['accountNumber', 'bankCode'];
  const keys = Object.keys(input);
  if (keys.some((k) => !allowed.includes(k))) return null;
  if (!('bankCode' in input) || !('accountNumber' in input)) return null;
  const bank = bankByCode(input.bankCode);
  const number = normalizeAccountNumber(input.accountNumber);
  if (bank === null || number === null) return null;
  if (!('otpCode' in input)) return { bank, number };
  if (typeof input.otpCode !== 'string' || !/^[0-9]{6}$/.test(input.otpCode)) return null;
  return { bank, number, otpCode: input.otpCode };
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
