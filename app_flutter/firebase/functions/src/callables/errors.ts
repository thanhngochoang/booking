import { HttpsError, type FunctionsErrorCode } from 'firebase-functions/v2/https';
import { isDomainError, type ErrorCode } from '@photobooking/domain';

const TRANSPORT_CODE: Record<ErrorCode, FunctionsErrorCode> = {
  invalid_argument: 'invalid-argument',
  permission_denied: 'permission-denied',
  not_found: 'not-found',
  contact_locked: 'failed-precondition',
  phone_required: 'failed-precondition',
  day_taken: 'already-exists',
  sold_out: 'resource-exhausted',
  deadline_passed: 'failed-precondition',
  limit_exceeded: 'resource-exhausted',
  conflict: 'aborted',
  price_changed: 'failed-precondition',
  not_eligible: 'failed-precondition',
  // A fresh sign-in is needed; the client re-authenticates and retries once.
  reauth_required: 'failed-precondition',
  // The provider has not finished verification or setup; createBooking refuses (S03.01 "Chưa nhận đơn").
  not_accepting_orders: 'failed-precondition',
  // The customer and the provider blocked each other (either way); new orders and payments are refused.
  blocked: 'failed-precondition',
  // "Tạo QR mới" was used MAX_PAYMENT_ATTEMPTS times; the app asks to book again from the start.
  payment_attempts_exceeded: 'failed-precondition',
  // S06.06 payout account v2 (name check and OTP): the client shows the matching message.
  name_mismatch: 'failed-precondition',
  otp_required: 'failed-precondition',
  otp_invalid: 'failed-precondition',
  otp_expired: 'failed-precondition',
  // S21 verification
  identity_in_use: 'already-exists',
  underage: 'failed-precondition',
  rate_limited: 'resource-exhausted',
};

/**
 * Domain refusal → callable error. The client reads `details.code` (falling back to the message),
 * so both carry the stable code. Anything unexpected becomes `internal` and says nothing more.
 */
export function toHttpsError(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  if (isDomainError(e)) return new HttpsError(TRANSPORT_CODE[e.code], e.code, { code: e.code });
  return new HttpsError('internal', 'internal', { code: 'internal' });
}
