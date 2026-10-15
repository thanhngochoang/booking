/**
 * Booking domain policy, financial maths, time helpers and constants.
 * Pure TypeScript (no external dependencies).
 */

/** Customers pay the whole price when they book (payments spec M2); no deposit any more. */
export const UPFRONT_PERCENT = 100;
export const DISPUTE_WINDOW_HOURS = 24;
export const ACCEPT_DEADLINE_HOURS = 24;
export const DRAFT_EXPIRY_MINUTES = 30;
/** A checkout payment (QR) is valid this long after it is created. */
export const PAYMENT_EXPIRY_MINUTES = 15;
/** The reconciliation job re-checks `created` payments older than this. */
export const PAYMENT_RECONCILE_AFTER_MINUTES = 3;
/** A draft stays payable until the latest QR's expiry plus this. */
export const DRAFT_PAYMENT_GRACE_MINUTES = 5;
/** At most this many payments (QRs) per booking. */
export const MAX_PAYMENT_ATTEMPTS = 3;
export const AUTO_COMPLETE_DELAY_HOURS = 24;
export const ESCROW_RELEASE_DELAY_HOURS = 24;
export const BOOKING_CONTACT_RETENTION_DAYS = 30;

export const REFUND_RESEND_AFTER_MINUTES = 10;
export const REFUND_MAX_ATTEMPTS = 6;

export const DEFAULT_REVISIONS = 1;
export const REVISIONS_MAX = 5;

/**
 * Free revision rounds of a package or quote:
 * non-number or NaN → 1; else truncated to an integer and clamped to 0–5.
 */
export function clampRevisions(v: unknown): number {
  if (typeof v !== 'number' || Number.isNaN(v)) {
    return DEFAULT_REVISIONS;
  }
  if (!Number.isFinite(v)) {
    return v > 0 ? REVISIONS_MAX : 0;
  }
  return Math.min(REVISIONS_MAX, Math.max(0, Math.trunc(v)));
}

export const MAX_NOTE_LENGTH = 300;
export const MIN_PLACE_LENGTH = 3;
export const MAX_PLACE_LENGTH = 120;
export const MIN_DISPUTE_REASON_LENGTH = 1;
export const MAX_DISPUTE_REASON_LENGTH = 500;
export const MAX_CANCEL_REASON_LENGTH = 200;
export const MAX_BOOKING_DAYS_AHEAD = 365;

/**
 * The up-front payment for a service price: the whole price, nothing left to pay later.
 * The name and the `deposit`/`remaining` fields stay for now (Decision 1 of #129);
 * `remaining` is always 0.
 */
export function computeDeposit(price: number): { deposit: number; remaining: number } {
  if (price < 0) {
    throw new Error('Price must be non-negative');
  }
  const deposit = Math.floor((price * UPFRONT_PERCENT) / 100);
  return { deposit, remaining: price - deposit };
}

/**
 * Refund policy based on hours remaining before booking start:
 * >= 48 hours -> 100%
 * 24 - 48 hours -> 50%
 * < 24 hours -> 0%
 */
export function refundPercent(hoursBeforeStart: number): number {
  if (hoursBeforeStart >= 48) {
    return 100;
  }
  if (hoursBeforeStart >= 24) {
    return 50;
  }
  return 0;
}

/** Compute refund amount in integer VND. */
export function computeRefund(deposit: number, percent: number): number {
  if (deposit < 0 || percent < 0 || percent > 100) {
    throw new Error('Invalid deposit or percent');
  }
  return Math.floor((deposit * percent) / 100);
}

/**
 * Accept deadline for photographer: min(paidAt + 24 hours, startsAt).
 */
export function computeAcceptDeadline(paidAt: Date, startsAt: Date): Date {
  const deadline24h = new Date(paidAt.getTime() + ACCEPT_DEADLINE_HOURS * 60 * 60 * 1000);
  return deadline24h.getTime() < startsAt.getTime() ? deadline24h : startsAt;
}

/**
 * Date / time string validators for Asia/Ho_Chi_Minh.
 */
export function isDateString(v: unknown): v is string {
  if (typeof v !== 'string') return false;
  return /^\d{4}-\d{2}-\d{2}$/.test(v);
}

export function isTimeString(v: unknown): v is string {
  if (typeof v !== 'string') return false;
  const match = /^(\d{2}):(\d{2})$/.exec(v);
  if (!match || !match[1] || !match[2]) return false;
  const h = parseInt(match[1], 10);
  const m = parseInt(match[2], 10);
  return h >= 0 && h < 24 && m >= 0 && m < 60;
}

const VN_OFFSET_HOURS = 7;
const VN_OFFSET_MS = VN_OFFSET_HOURS * 60 * 60 * 1000;

/**
 * Parses `yyyy-MM-dd` and `HH:mm` as Vietnam local time (UTC+7) into a UTC Date.
 */
export function parseVnDateTime(date: string, time: string): Date {
  const [yearStr, monthStr, dayStr] = date.split('-');
  const [hourStr, minStr] = time.split(':');
  if (!yearStr || !monthStr || !dayStr || !hourStr || !minStr) {
    throw new Error(`Invalid date or time: ${date} ${time}`);
  }
  const year = parseInt(yearStr, 10);
  const month = parseInt(monthStr, 10) - 1;
  const day = parseInt(dayStr, 10);
  const hour = parseInt(hourStr, 10);
  const minute = parseInt(minStr, 10);

  // UTC timestamp for the local time, subtracted by UTC+7 offset
  const utcMs = Date.UTC(year, month, day, hour, minute) - VN_OFFSET_MS;
  return new Date(utcMs);
}

/**
 * Formats a UTC Date to `yyyy-MM-dd` in Vietnam time (UTC+7).
 */
export function formatVnDate(date: Date): string {
  const vnTime = new Date(date.getTime() + VN_OFFSET_MS);
  const y = vnTime.getUTCFullYear();
  const m = String(vnTime.getUTCMonth() + 1).padStart(2, '0');
  const d = String(vnTime.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Formats a UTC Date to `HH:mm` in Vietnam time (UTC+7).
 */
export function formatVnTime(date: Date): string {
  const vnTime = new Date(date.getTime() + VN_OFFSET_MS);
  const h = String(vnTime.getUTCHours()).padStart(2, '0');
  const m = String(vnTime.getUTCMinutes()).padStart(2, '0');
  return `${h}:${m}`;
}

/**
 * Calculates time slots every 30 minutes from 06:00 to 20:00 minus durationMinutes.
 */
export function computeDaySlots(durationMinutes: number): string[] {
  const startMinute = 6 * 60; // 06:00 = 360
  const endMinute = 20 * 60; // 20:00 = 1200
  const latestStart = endMinute - durationMinutes;

  const slots: string[] = [];
  for (let m = startMinute; m <= latestStart; m += 30) {
    const hours = Math.floor(m / 60);
    const mins = m % 60;
    slots.push(`${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`);
  }
  return slots;
}

/**
 * Adds durationMinutes to HH:mm string and returns HH:mm.
 */
export function addMinutesToTime(start: string, durationMinutes: number): string {
  const parts = start.split(':');
  if (parts.length !== 2 || !parts[0] || !parts[1]) throw new Error(`Invalid start time: ${start}`);
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  const total = h * 60 + m + durationMinutes;
  const newH = Math.floor(total / 60) % 24;
  const newM = total % 60;
  return `${String(newH).padStart(2, '0')}:${String(newM).padStart(2, '0')}`;
}
