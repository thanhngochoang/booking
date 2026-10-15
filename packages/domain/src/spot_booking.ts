/**
 * Spot interval operations, booking checks and availability lock helpers (spec S29).
 */

import { DomainError } from './errors.js';
import { formatVnDate } from './booking_policy.js';
import { minutesOf, timeOf, type SpotSchedule, type SpotWindow } from './spot_schedule.js';
import { slotsFor, type SlotOffer } from './spot_slots.js';
import type { Spot } from './spot.js';
import type { AvailabilityDayRecord, BookingTx } from './booking_ports.js';
import type { Booking } from './booking.js';

export const SPOT_BOOKING_GAP_MINUTES = 15;

export interface SpotInterval {
  readonly start: string;
  readonly end: string;
  readonly offerId?: string;
}

export interface SpotDay {
  readonly scheduleId: string;
  readonly spotId: string;
  readonly providerId: string;
  readonly day: string;
  readonly taken: readonly SpotInterval[];
  readonly updatedAt: string;
}

export const spotDayId = (scheduleId: string, day: string): string => `${scheduleId}_${day}`;

/** 0 for the same offerId, else 15 minutes. */
export function requiredGap(a: SpotInterval, b: SpotInterval): number {
  if (a.offerId !== undefined && a.offerId === b.offerId) {
    return 0;
  }
  return SPOT_BOOKING_GAP_MINUTES;
}

/** Returns true if interval c clashes with any interval in taken. */
export function clashes(c: SpotInterval, taken: readonly SpotInterval[]): boolean {
  const cStart = minutesOf(c.start);
  const cEnd = minutesOf(c.end);

  for (const t of taken) {
    const tStart = minutesOf(t.start);
    const tEnd = minutesOf(t.end);
    const gap = requiredGap(c, t);

    if (cEnd <= tStart) {
      if (tStart - cEnd < gap) return true;
    } else if (tEnd <= cStart) {
      if (cStart - tEnd < gap) return true;
    } else {
      // Overlapping
      return true;
    }
  }
  return false;
}

/**
 * Returns candidate start times for a package booking within window.
 * Step stepMinutes (default 30).
 */
export function freeStartTimes(
  window: SpotWindow,
  durationMinutes: number,
  taken: readonly SpotInterval[],
  stepMinutes = 30,
): string[] {
  const wStart = minutesOf(window.start);
  const wEnd = minutesOf(window.end);
  const result: string[] = [];

  for (let cursor = wStart; cursor + durationMinutes <= wEnd; cursor += stepMinutes) {
    const startStr = timeOf(cursor);
    const endStr = timeOf(cursor + durationMinutes);
    const candidate: SpotInterval = { start: startStr, end: endStr };
    if (!clashes(candidate, taken)) {
      result.push(startStr);
    }
  }
  return result;
}

export function freeSlots(
  window: SpotWindow,
  offer: Pick<SlotOffer, 'id' | 'slotMinutes' | 'gapMinutes'>,
  taken: readonly SpotInterval[],
): { start: string; end: string; free: boolean }[] {
  const slots = slotsFor(window, offer.slotMinutes, offer.gapMinutes);
  return slots.map((s) => {
    const iv: SpotInterval = { start: s.start, end: s.end, offerId: offer.id };
    return {
      start: s.start,
      end: s.end,
      free: !clashes(iv, taken),
    };
  });
}

export interface SpotBookingCheck {
  readonly spot: Spot;
  readonly schedule: SpotSchedule;
  readonly offer: SlotOffer | null;
  readonly serviceId: string;
  readonly day: string;
  readonly start: string;
  readonly end: string;
  readonly taken: readonly SpotInterval[];
}

/**
 * Validates a spot booking attempt.
 * Throws: spot_archived · outside_schedule · slot_taken.
 */
export function assertSpotBooking(c: SpotBookingCheck): void {
  if (c.spot.status !== 'active') {
    throw new DomainError('spot_archived');
  }

  if (c.schedule.status !== 'open') {
    throw new DomainError('outside_schedule');
  }

  if (!c.schedule.days.includes(c.day)) {
    throw new DomainError('outside_schedule');
  }

  if (c.offer !== null) {
    if (c.offer.status !== 'open' || c.offer.scheduleId !== c.schedule.id) {
      throw new DomainError('outside_schedule');
    }
    const slots = slotsFor(c.schedule.window, c.offer.slotMinutes, c.offer.gapMinutes);
    const matchesSlot = slots.some((s) => s.start === c.start && s.end === c.end);
    if (!matchesSlot) {
      throw new DomainError('outside_schedule');
    }
  } else {
    if (c.schedule.serviceIds.length > 0 && !c.schedule.serviceIds.includes(c.serviceId)) {
      throw new DomainError('outside_schedule');
    }
    const cStart = minutesOf(c.start);
    const cEnd = minutesOf(c.end);
    const wStart = minutesOf(c.schedule.window.start);
    const wEnd = minutesOf(c.schedule.window.end);
    if (cStart < wStart || cEnd > wEnd || cEnd <= cStart) {
      throw new DomainError('outside_schedule');
    }
  }

  const candidate: SpotInterval = {
    start: c.start,
    end: c.end,
    offerId: c.offer?.id,
  };

  if (clashes(candidate, c.taken)) {
    throw new DomainError('slot_taken');
  }
}

export function withInterval(
  day: SpotDay | null,
  base: Omit<SpotDay, 'taken' | 'updatedAt'>,
  iv: SpotInterval,
  now: string,
): SpotDay {
  const existingTaken = day ? day.taken : [];
  const nextTaken = [...existingTaken, iv].sort((a, b) => a.start.localeCompare(b.start));
  return {
    ...(day ?? base),
    taken: nextTaken,
    updatedAt: now,
  };
}

export function withoutInterval(
  day: SpotDay,
  iv: Pick<SpotInterval, 'start' | 'end'>,
  now: string,
): SpotDay {
  const nextTaken = day.taken.filter((t) => !(t.start === iv.start && t.end === iv.end));
  if (nextTaken.length === day.taken.length) {
    return day;
  }
  return {
    ...day,
    taken: nextTaken,
    updatedAt: now,
  };
}

/**
 * Checks whether a provider is busy with a spot schedule at `now` (Decision 17).
 */
export function spotBusyAt(
  rec: AvailabilityDayRecord | null,
  schedule: SpotSchedule | null,
  now: Date,
): boolean {
  if (!rec || rec.state !== 'spot' || !schedule || schedule.status !== 'open') {
    return false;
  }

  const today = formatVnDate(now);
  if (!schedule.days.includes(today)) {
    return false;
  }

  // Convert now to VN minutes
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(now);

  const hh = parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10);
  const mm = parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10);
  const nowMin = hh * 60 + mm;

  const wStart = minutesOf(schedule.window.start);
  const wEnd = minutesOf(schedule.window.end);

  return nowMin >= wStart && nowMin < wEnd;
}

export async function releaseSpotInterval(
  tx: BookingTx,
  booking: Pick<Booking, 'spotScheduleId' | 'day' | 'start' | 'end'>,
  now: Date,
): Promise<void> {
  if (!booking.spotScheduleId) return;
  const spotDay = await tx.getSpotDay(booking.spotScheduleId, booking.day);
  if (spotDay) {
    await tx.setSpotDay(withoutInterval(spotDay, booking, now.toISOString()));
  }
}
