/**
 * OTP for a payout account change (payments spec M6, S06.06): 6 digits, valid 5 minutes, 5 wrong
 * tries per code, resend after 60 s, 5 sends per Vietnam day. Bound to the account being saved and
 * single-use. Only salted SHA-256 hashes are stored (`otp_challenges/{uid}_payout_account`,
 * server-only), never the code or the account number.
 */

export const OTP_TTL_SECONDS = 300;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_SECONDS = 60;
export const OTP_MAX_SENDS_PER_DAY = 5;
/** Random bytes for the salt (hex-encoded, 32 characters). */
export const OTP_SALT_BYTES = 16;

export interface OtpChallenge {
  readonly uid: string;
  readonly purpose: 'payout_account';
  /** sha256Hex(`${salt}:${code}`). */
  readonly codeHash: string;
  readonly salt: string;
  /** sha256Hex(`${salt}:${bankCode}:${accountNumber}`): the account this code may save. */
  readonly targetHash: string;
  readonly expiresAt: string;
  /** Wrong tries against this code. */
  readonly attempts: number;
  readonly sentAt: string;
  /** Vietnam day (`yyyy-MM-dd`) of `sendsToday`. */
  readonly sendDay: string;
  readonly sendsToday: number;
  readonly consumedAt: string | null;
}

/** 6 digits from 4 random bytes (big-endian u32 % 1e6, zero-padded). */
export function otpCodeFrom(bytes: Uint8Array): string {
  if (bytes.length < 4) throw new Error('otpCodeFrom needs 4 bytes');
  const u32 = (((bytes[0] ?? 0) << 24) >>> 0) + ((bytes[1] ?? 0) << 16) + ((bytes[2] ?? 0) << 8) + (bytes[3] ?? 0);
  return String(u32 % 1_000_000).padStart(6, '0');
}

export function hexOf(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export const otpCodeHashInput = (salt: string, code: string): string => `${salt}:${code}`;
export const otpTargetHashInput = (salt: string, bankCode: string, accountNumber: string): string =>
  `${salt}:${bankCode}:${accountNumber}`;

export type OtpVerdict = 'ok' | 'required' | 'expired' | 'too_many' | 'wrong';

/** required = missing, consumed or bound to another account. */
export function checkOtp(c: OtpChallenge | null, given: { codeHash: string; targetHash: string }, now: Date): OtpVerdict {
  if (c === null || c.consumedAt !== null) return 'required';
  if (c.targetHash !== given.targetHash) return 'required';
  if (!(now.getTime() < Date.parse(c.expiresAt))) return 'expired';
  if (c.attempts >= OTP_MAX_ATTEMPTS) return 'too_many';
  if (c.codeHash !== given.codeHash) return 'wrong';
  return 'ok';
}
