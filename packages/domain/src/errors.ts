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
  /** The add-on or total the app showed is out of date (S04: the provider changed it); reload. */
  'addon_changed',
  /** An add-on does not apply to the chosen package (a missing or inactive one is `addon_changed`). */
  'addon_not_applicable',
  /** A transport add-on needs a pickup address. */
  'pickup_required',
  /** A provider already has the maximum number of active add-ons. */
  'addon_limit',
  /** Free text contains a phone number, e-mail or link (contact stays inside the app). */
  'contact_leak',
  /** A delivery sample is missing, failed, or still processing. */
  'not_ready',
  /** Studio membership (#136): the photographer is active in another studio, or a provider type change is blocked by members or an open relation. */
  'membership_conflict',
  /** Studio membership (#136): within 7 days of leaving or being removed from a studio. */
  'cooldown',
  /** Studio membership (#136): the member still has an open studio booking assigned. */
  'member_busy',
  /** Studio membership (#136): members + open invites reached the cap (3, or 30 business-verified), or 5 open invites. */
  'studio_full',
  'outside_schedule',
  'slot_taken',
  'day_conflict',
  'schedule_limit',
  'spot_archived',
  'schedule_has_bookings',
  /** Chụp ngay (#140): the search window ended without a match (spec §6). */
  'no_match',
  /** Chụp ngay (#140): the offer's 60 seconds passed by server time, or it was withdrawn. */
  'offer_expired',
  /** Chụp ngay (#140): another photographer took the request first, or the photographer already has a job. */
  'already_assigned',
  /** Chụp ngay (#140): the point is outside every open city. */
  'outside_service_area',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/**
 * A refused use case. The message is the code itself, so nothing else can leak. `field` names the
 * offending input field for form errors (never user text); `details` carries structured, non-user
 * data the caller needs to explain the refusal (e.g. the conflicting days of a spot schedule).
 */
export class DomainError extends Error {
  constructor(
    readonly code: ErrorCode,
    readonly field?: string,
    readonly details?: Readonly<Record<string, unknown>>,
  ) {
    super(code);
    this.name = 'DomainError';
  }
}

export const isDomainError = (e: unknown): e is DomainError => e instanceof DomainError;
