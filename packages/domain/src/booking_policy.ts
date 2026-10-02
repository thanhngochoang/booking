/**
 * Booking domain policy, financial maths, time helpers and constants.
 * Pure TypeScript (no external dependencies).
 */

export const DEPOSIT_PERCENT = 30;
export const DISPUTE_WINDOW_HOURS = 24;
export const ACCEPT_DEADLINE_HOURS = 24;
export const DRAFT_EXPIRY_MINUTES = 30;
export const AUTO_COMPLETE_DELAY_HOURS = 24;
export const ESCROW_RELEASE_DELAY_HOURS = 24;
export const BOOKING_CONTACT_RETENTION_DAYS = 30;

export const MAX_NOTE_LENGTH = 300;
export const MIN_PLACE_LENGTH = 3;
export const MAX_PLACE_LENGTH = 120;
export const MIN_DISPUTE_REASON_LENGTH = 1;
export const MAX_DISPUTE_REASON_LENGTH = 500;
export const MAX_CANCEL_REASON_LENGTH = 200;
export const MAX_BOOKING_DAYS_AHEAD = 365;

/** Deposit calculation: floor(price * 0.30), remainder to complete price. */
export function computeDeposit(price: number): { deposit: number; remaining: number } {
  if (price < 0) {
    throw new Error('Price must be non-negative');
  }
  const deposit = Math.floor((price * DEPOSIT_PERCENT) / 100);
  const remaining = price - deposit;
  return { deposit, remaining };
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
