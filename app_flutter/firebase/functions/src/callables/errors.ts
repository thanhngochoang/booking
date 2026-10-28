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
  not_ready: 'failed-precondition',
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
  // S04 add-ons: the app reloads the block (addon_changed), or asks for the pickup address.
  addon_changed: 'failed-precondition',
  addon_not_applicable: 'failed-precondition',
  pickup_required: 'failed-precondition',
  // The provider already has the maximum number of active add-ons.
  addon_limit: 'resource-exhausted',
  // S29 trending spots & spot schedules
  outside_schedule: 'failed-precondition',
  slot_taken: 'failed-precondition',
  day_conflict: 'failed-precondition',
  schedule_limit: 'resource-exhausted',
  spot_archived: 'failed-precondition',
  schedule_has_bookings: 'failed-precondition',
  // Free text carries a phone number, e-mail or link; `details.field` names the input.
  contact_leak: 'invalid-argument',
  // S26 studio membership (#136): another studio, 7-day cooldown, open assigned bookings; caps and full studio.
  membership_conflict: 'failed-precondition',
  cooldown: 'failed-precondition',
  member_busy: 'failed-precondition',
  studio_full: 'resource-exhausted',
  // S13–S14 Chụp ngay (#140): search window over, offer past its 60 s, someone else took it, outside the open cities.
  no_match: 'failed-precondition',
  offer_expired: 'failed-precondition',
  already_assigned: 'failed-precondition',
  outside_service_area: 'failed-precondition',
  // S27 recruiting (#151): collaboration caps reached; studio temporarily blocked after unpaid-fee flags.
  collab_full: 'resource-exhausted',
  recruit_blocked: 'failed-precondition',
};

/**
 * Domain refusal → callable error. The client reads `details.code` (falling back to the message),
 * so both carry the stable code. Anything unexpected becomes `internal` and says nothing more.
 */
export function toHttpsError(e: unknown): HttpsError {
  if (e instanceof HttpsError) return e;
  if (isDomainError(e)) {
    // `field` names the offending form input (never user text), so the app can mark it.
    const details: Record<string, unknown> = { code: e.code };
    if (e.field !== undefined) details.field = e.field;
    if (e.details !== undefined) Object.assign(details, e.details);
    return new HttpsError(TRANSPORT_CODE[e.code], e.code, details);
  }
  return new HttpsError('internal', 'internal', { code: 'internal' });
}
