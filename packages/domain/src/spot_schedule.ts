/**
 * Spot schedule validation, conflicts, and window calculations (spec S29).
 */

import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { isDateString, isTimeString } from './booking_policy.js';
import type { AvailabilityDayRecord, ServiceRecord } from './booking_ports.js';
import type { SpotDay } from './spot_booking.js';

export interface SpotWindow {
  readonly start: string;
  readonly end: string;
}

export const SCHEDULE_MAX_DAYS = 40;
export const SCHEDULE_DAYS_AHEAD = 60;
export const MAX_OPEN_SCHEDULES = 8;
export const WINDOW_EARLIEST = '05:00';
export const WINDOW_LATEST = '21:00';
export const WINDOW_MIN_MINUTES = 60;
export const WINDOW_MAX_MINUTES = 720;
export const WINDOW_STEP_MINUTES = 15;

export interface SpotSchedule {
  readonly id: string;
  readonly providerId: string;
  readonly assigneeId: string | null;
  readonly spotId: string;
  readonly days: readonly string[];
  readonly window: SpotWindow;
  readonly serviceIds: readonly string[];
  readonly priceFrom: number | null;
  readonly status: 'open' | 'cancelled';
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface SpotScheduleInput {
  readonly scheduleId?: string;
  readonly spotId: string;
  readonly days: readonly string[];
  readonly window: SpotWindow;
  readonly serviceIds: readonly string[];
  readonly assigneeId?: string;
}

export function minutesOf(t: string): number {
  const parts = t.split(':');
  return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
}

export function timeOf(minutes: number): string {
  const hh = Math.floor(minutes / 60);
  const mm = minutes % 60;
  return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}

export const dayHolderOf = (
  s: Pick<SpotSchedule, 'assigneeId' | 'providerId'>,
): string => s.assigneeId ?? s.providerId;

export interface DayConflict {
  readonly day: string;
  readonly reason: 'booked' | 'pending' | 'off' | 'spot' | 'full';
}

function addDaysToDateString(d: string, days: number): string {
  const dt = new Date(`${d}T00:00:00Z`);
  dt.setUTCDate(dt.getUTCDate() + days);
  return dt.toISOString().slice(0, 10);
}

export function validateScheduleInput(raw: unknown, today: string): SpotScheduleInput {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (typeof r.spotId !== 'string' || !isId(r.spotId)) {
    throw new DomainError('invalid_argument', 'spotId');
  }

  let scheduleId: string | undefined;
  if (r.scheduleId !== undefined) {
    if (typeof r.scheduleId !== 'string' || !isId(r.scheduleId)) {
      throw new DomainError('invalid_argument', 'scheduleId');
    }
    scheduleId = r.scheduleId;
  }

  let assigneeId: string | undefined;
  if (r.assigneeId !== undefined) {
    if (typeof r.assigneeId !== 'string' || !isId(r.assigneeId)) {
      throw new DomainError('invalid_argument', 'assigneeId');
    }
    assigneeId = r.assigneeId;
  }

  if (!Array.isArray(r.days)) {
    throw new DomainError('invalid_argument', 'days');
  }

  const uniqueDays = Array.from(new Set(r.days)).sort();
  if (uniqueDays.length === 0 || uniqueDays.length > SCHEDULE_MAX_DAYS) {
    throw new DomainError('invalid_argument', 'days');
  }

  const maxDay = addDaysToDateString(today, SCHEDULE_DAYS_AHEAD);
  for (const d of uniqueDays) {
    if (typeof d !== 'string' || !isDateString(d) || d < today || d > maxDay) {
      throw new DomainError('invalid_argument', 'days');
    }
  }

  if (!r.window || typeof r.window !== 'object') {
    throw new DomainError('invalid_argument', 'window');
  }
  const w = r.window as Record<string, unknown>;
  if (typeof w.start !== 'string' || typeof w.end !== 'string' || !isTimeString(w.start) || !isTimeString(w.end)) {
    throw new DomainError('invalid_argument', 'window');
  }

  const startMin = minutesOf(w.start);
  const endMin = minutesOf(w.end);
  const earliestMin = minutesOf(WINDOW_EARLIEST);
  const latestMin = minutesOf(WINDOW_LATEST);

  if (startMin % WINDOW_STEP_MINUTES !== 0 || endMin % WINDOW_STEP_MINUTES !== 0) {
    throw new DomainError('invalid_argument', 'window');
  }

  if (startMin < earliestMin || endMin > latestMin) {
    throw new DomainError('invalid_argument', 'window');
  }

  const duration = endMin - startMin;
  if (duration < WINDOW_MIN_MINUTES || duration > WINDOW_MAX_MINUTES) {
    throw new DomainError('invalid_argument', 'window');
  }

  if (!Array.isArray(r.serviceIds)) {
    throw new DomainError('invalid_argument', 'serviceIds');
  }
  for (const sid of r.serviceIds) {
    if (typeof sid !== 'string' || !isId(sid)) {
      throw new DomainError('invalid_argument', 'serviceIds');
    }
  }

  return {
    scheduleId,
    spotId: r.spotId,
    days: uniqueDays as string[],
    window: { start: w.start, end: w.end },
    serviceIds: r.serviceIds as string[],
    assigneeId,
  };
}

/**
 * A day is free when it has no record, or a `spot` record of `ownScheduleId`.
 */
export function dayConflicts(
  days: readonly string[],
  records: ReadonlyMap<string, AvailabilityDayRecord | null>,
  ownScheduleId: string | null,
): DayConflict[] {
  const conflicts: DayConflict[] = [];

  for (const day of days) {
    const rec = records.get(day);
    if (!rec) continue;

    if (rec.state === 'spot' && ownScheduleId && rec.scheduleId === ownScheduleId) {
      continue;
    }

    const reason = rec.state;
    conflicts.push({ day, reason: reason as DayConflict['reason'] });
  }

  return conflicts;
}

export function priceFromOf(
  active: readonly ServiceRecord[],
  serviceIds: readonly string[],
): number {
  const activeOnly = active.filter((s) => s.active !== false);
  if (activeOnly.length === 0) {
    throw new DomainError('invalid_argument', 'serviceIds');
  }

  if (serviceIds.length === 0) {
    return Math.min(...activeOnly.map((s) => s.price));
  }

  const activeMap = new Map(activeOnly.map((s) => [s.id, s]));
  const matchedPrices: number[] = [];
  for (const sid of serviceIds) {
    const s = activeMap.get(sid);
    if (!s) {
      throw new DomainError('invalid_argument', 'serviceIds');
    }
    matchedPrices.push(s.price);
  }

  return Math.min(...matchedPrices);
}

export function scheduleEditBlocks(
  removed: readonly string[],
  window: SpotWindow,
  spotDays: ReadonlyMap<string, SpotDay | null>,
): { day: string; count: number }[] {
  const blocks: { day: string; count: number }[] = [];
  const wStart = minutesOf(window.start);
  const wEnd = minutesOf(window.end);

  for (const day of removed) {
    const sd = spotDays.get(day);
    if (sd && sd.taken.length > 0) {
      blocks.push({ day, count: sd.taken.length });
    }
  }

  for (const [day, sd] of spotDays.entries()) {
    if (removed.includes(day) || !sd) continue;
    let count = 0;
    for (const iv of sd.taken) {
      const ivStart = minutesOf(iv.start);
      const ivEnd = minutesOf(iv.end);
      if (ivStart < wStart || ivEnd > wEnd) {
        count++;
      }
    }
    if (count > 0) {
      blocks.push({ day, count });
    }
  }

  return blocks;
}
