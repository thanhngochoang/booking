import type { Booking } from './booking.js';

export const DEFAULT_DELIVERY_DAYS = 7;
export const DELIVERY_DAYS_MIN = 1;
export const DELIVERY_DAYS_MAX = 90;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function clampDeliveryDays(v: unknown): number {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < DELIVERY_DAYS_MIN) {
    return DEFAULT_DELIVERY_DAYS;
  }
  return v > DELIVERY_DAYS_MAX ? DELIVERY_DAYS_MAX : v;
}

export function deliveryDueAt(b: Pick<Booking, 'shotAt' | 'deliveryDays'>): Date | null {
  if (!b.shotAt) return null;
  const shotMs = Date.parse(b.shotAt);
  if (Number.isNaN(shotMs)) return null;
  const days = clampDeliveryDays(b.deliveryDays);
  return new Date(shotMs + days * MS_PER_DAY);
}

export function isDeliveryLate(
  b: Pick<Booking, 'status' | 'shotAt' | 'deliveryDays'>,
  now: Date,
): boolean {
  if (b.status !== 'shot') return false;
  const dueAt = deliveryDueAt(b);
  if (!dueAt) return false;
  return now.getTime() > dueAt.getTime();
}
