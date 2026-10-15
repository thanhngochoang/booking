/** Stable business error codes (data-model/domain-model.md §4 `ErrorCode`). */
export const ERROR_CODES = [
  'day_taken',
  'phone_required',
  'contact_locked',
  'sold_out',
  'deadline_passed',
  'limit_exceeded',
  'invalid_argument',
  'permission_denied',
  'not_found',
  'conflict',
  'price_changed',
  'not_eligible',
  'reauth_required',
  'not_accepting_orders',
  /** The customer and the provider blocked each other in either direction; no new order between them. */
  'blocked',
  /** A booking already had MAX_PAYMENT_ATTEMPTS payments ("Tạo QR mới" cannot hold the day forever). */
  'payment_attempts_exceeded',
  /** The bank's holder name is not the verified name (S06.06); only accounts in your own name. */
  'name_mismatch',
  /** A payout account change needs an OTP for this account (missing, used or for another account). */
  'otp_required',
  /** Wrong OTP; the try is counted. */
  'otp_invalid',
  /** The OTP is older than 5 minutes; request a new one. */
  'otp_expired',
  /** Identity verification: the id number is already registered to another account (#135). */
  'identity_in_use',
  /** Identity verification: provider must be at least 18 years old (#135). */
  'underage',
  /** Identity verification: maximum attempts exceeded for today (VN calendar day) (#135). */
  'rate_limited',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/** A refused use case. The message is the code itself, so nothing else can leak. */
export class DomainError extends Error {
  constructor(readonly code: ErrorCode) {
    super(code);
    this.name = 'DomainError';
  }
}

export const isDomainError = (e: unknown): e is DomainError => e instanceof DomainError;
