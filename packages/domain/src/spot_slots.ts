/**
 * Slot offer and slot grid logic (spec S29).
 */

import { DomainError } from './errors.js';
import { findContactLeak } from './contact_filter.js';
import { isId } from './ids.js';
import type { SpotWindow } from './spot_schedule.js';

export const SLOT_MINUTES_MIN = 15;
export const SLOT_MINUTES_MAX = 90;
export const SLOT_GAP_MAX = 30;
export const MAX_OFFERS_PER_SCHEDULE = 2;
export const SLOT_NAME_MIN = 3;
export const SLOT_NAME_MAX = 60;
export const SLOT_PRICE_MIN = 10_000;
export const SLOT_PRICE_MAX = 100_000_000;
export const SLOT_PHOTOS_MAX = 500;
export const SLOT_DELIVERY_DAYS_MAX = 30;

export interface SlotOffer {
  readonly id: string;
  readonly providerId: string;
  readonly scheduleId: string;
  readonly spotId: string;
  readonly name: string;
  readonly price: number;
  readonly slotMinutes: number;
  readonly gapMinutes: number;
  readonly photoCount: number;
  readonly editedCount: number;
  readonly deliveryDays: number;
  readonly status: 'open' | 'closed';
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface SlotOfferInput {
  readonly offerId?: string;
  readonly scheduleId: string;
  readonly name: string;
  readonly price: number;
  readonly slotMinutes: number;
  readonly gapMinutes: number;
  readonly photoCount: number;
  readonly editedCount: number;
  readonly deliveryDays: number;
}

function graphemeCount(s: string): number {
  if (typeof Intl !== 'undefined' && 'Segmenter' in Intl) {
    const segmenter = new Intl.Segmenter('vi', { granularity: 'grapheme' });
    return Array.from(segmenter.segment(s)).length;
  }
  return Array.from(s).length;
}

function minutesOfTime(t: string): number {
  const parts = t.split(':');
  return parseInt(parts[0] ?? '0', 10) * 60 + parseInt(parts[1] ?? '0', 10);
}

function timeOfMinutes(m: number): string {
  const hh = Math.floor(m / 60);
  const mm = m % 60;
  return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}

export function validateSlotOfferInput(raw: unknown): SlotOfferInput {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (typeof r.scheduleId !== 'string' || !isId(r.scheduleId)) {
    throw new DomainError('invalid_argument', 'scheduleId');
  }

  let offerId: string | undefined;
  if (r.offerId !== undefined) {
    if (typeof r.offerId !== 'string' || !isId(r.offerId)) {
      throw new DomainError('invalid_argument', 'offerId');
    }
    offerId = r.offerId;
  }

  if (typeof r.name !== 'string') {
    throw new DomainError('invalid_argument', 'name');
  }
  const name = r.name.trim();
  const nameLen = graphemeCount(name);
  if (nameLen < SLOT_NAME_MIN || nameLen > SLOT_NAME_MAX) {
    throw new DomainError('invalid_argument', 'name');
  }

  const leak = findContactLeak(name);
  if (leak !== null) {
    throw new DomainError('contact_leak', 'name');
  }

  if (
    typeof r.price !== 'number' ||
    !Number.isInteger(r.price) ||
    r.price < SLOT_PRICE_MIN ||
    r.price > SLOT_PRICE_MAX
  ) {
    throw new DomainError('invalid_argument', 'price');
  }

  if (
    typeof r.slotMinutes !== 'number' ||
    !Number.isInteger(r.slotMinutes) ||
    r.slotMinutes < SLOT_MINUTES_MIN ||
    r.slotMinutes > SLOT_MINUTES_MAX
  ) {
    throw new DomainError('invalid_argument', 'slotMinutes');
  }

  if (
    typeof r.gapMinutes !== 'number' ||
    !Number.isInteger(r.gapMinutes) ||
    r.gapMinutes < 0 ||
    r.gapMinutes > SLOT_GAP_MAX
  ) {
    throw new DomainError('invalid_argument', 'gapMinutes');
  }

  if (
    typeof r.photoCount !== 'number' ||
    !Number.isInteger(r.photoCount) ||
    r.photoCount < 1 ||
    r.photoCount > SLOT_PHOTOS_MAX
  ) {
    throw new DomainError('invalid_argument', 'photoCount');
  }

  if (
    typeof r.editedCount !== 'number' ||
    !Number.isInteger(r.editedCount) ||
    r.editedCount < 0 ||
    r.editedCount > r.photoCount
  ) {
    throw new DomainError('invalid_argument', 'editedCount');
  }

  if (
    typeof r.deliveryDays !== 'number' ||
    !Number.isInteger(r.deliveryDays) ||
    r.deliveryDays < 1 ||
    r.deliveryDays > SLOT_DELIVERY_DAYS_MAX
  ) {
    throw new DomainError('invalid_argument', 'deliveryDays');
  }

  return {
    offerId,
    scheduleId: r.scheduleId,
    name,
    price: r.price,
    slotMinutes: r.slotMinutes,
    gapMinutes: r.gapMinutes,
    photoCount: r.photoCount,
    editedCount: r.editedCount,
    deliveryDays: r.deliveryDays,
  };
}

/**
 * Returns slots [start, start + slotMinutes] every slotMinutes + gapMinutes
 * from window.start while slot ends <= window.end.
 */
export function slotsFor(
  window: SpotWindow,
  slotMinutes: number,
  gapMinutes: number,
): { start: string; end: string }[] {
  const wStart = minutesOfTime(window.start);
  const wEnd = minutesOfTime(window.end);
  const slots: { start: string; end: string }[] = [];

  let cursor = wStart;
  while (cursor + slotMinutes <= wEnd) {
    slots.push({
      start: timeOfMinutes(cursor),
      end: timeOfMinutes(cursor + slotMinutes),
    });
    cursor += slotMinutes + gapMinutes;
  }
  return slots;
}
