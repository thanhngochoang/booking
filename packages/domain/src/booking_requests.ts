/**
 * Request parsing and string validation for booking operations.
 */

import {
  isDateString,
  isTimeString,
  parseVnDateTime,
  MAX_NOTE_LENGTH,
  MIN_PLACE_LENGTH,
  MAX_PLACE_LENGTH,
  MAX_BOOKING_DAYS_AHEAD,
} from './booking_policy.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export function graphemeCount(str: string): number {
  if (typeof Intl !== 'undefined' && Intl.Segmenter) {
    const segmenter = new Intl.Segmenter('vi', { granularity: 'grapheme' });
    return Array.from(segmenter.segment(str)).length;
  }
  return Array.from(str).length;
}

export interface CreateBookingDraftInput {
  readonly customerId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly day: string;
  readonly start: string;
  readonly place: { readonly name: string; readonly point?: { readonly lat: number; readonly lng: number } };
  readonly note?: string;
  readonly expectedPrice?: number;
}

export function validateCreateBookingDraftInput(
  raw: unknown,
  now: Date,
): CreateBookingDraftInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const { customerId, photographerId, serviceId, day, start, place, note, expectedPrice } = raw as Record<string, unknown>;

  if (!isId(customerId) || !isId(photographerId) || !isId(serviceId)) {
    throw new DomainError('invalid_argument');
  }

  if (customerId === photographerId) {
    throw new DomainError('invalid_argument');
  }

  if (!isDateString(day) || !isTimeString(start)) {
    throw new DomainError('invalid_argument');
  }

  if (typeof place !== 'object' || place === null) {
    throw new DomainError('invalid_argument');
  }

  const placeObj = place as Record<string, unknown>;
  if (typeof placeObj.name !== 'string') {
    throw new DomainError('invalid_argument');
  }

  const placeTrimmed = placeObj.name.trim();
  const placeLen = graphemeCount(placeTrimmed);
  if (placeLen < MIN_PLACE_LENGTH || placeLen > MAX_PLACE_LENGTH) {
    throw new DomainError('invalid_argument');
  }

  let noteTrimmed: string | undefined;
  if (note !== undefined && note !== null) {
    if (typeof note !== 'string') {
      throw new DomainError('invalid_argument');
    }
    noteTrimmed = note.trim();
    if (graphemeCount(noteTrimmed) > MAX_NOTE_LENGTH) {
      throw new DomainError('invalid_argument');
    }
  }

  // Validate start time is in the future
  const startsAt = parseVnDateTime(day, start);
  if (startsAt.getTime() <= now.getTime()) {
    throw new DomainError('invalid_argument');
  }

  // Validate not too far in advance
  const maxAheadMs = MAX_BOOKING_DAYS_AHEAD * 24 * 60 * 60 * 1000;
  if (startsAt.getTime() - now.getTime() > maxAheadMs) {
    throw new DomainError('invalid_argument');
  }

  let validatedPoint: { lat: number; lng: number } | undefined;
  if (placeObj.point && typeof placeObj.point === 'object') {
    const pt = placeObj.point as Record<string, unknown>;
    if (typeof pt.lat === 'number' && typeof pt.lng === 'number') {
      validatedPoint = { lat: pt.lat, lng: pt.lng };
    }
  }

  let validatedExpectedPrice: number | undefined;
  if (expectedPrice !== undefined && expectedPrice !== null) {
    if (typeof expectedPrice !== 'number' || !Number.isInteger(expectedPrice) || expectedPrice < 0) {
      throw new DomainError('invalid_argument');
    }
    validatedExpectedPrice = expectedPrice;
  }

  return {
    customerId,
    photographerId,
    serviceId,
    day,
    start,
    place: { name: placeTrimmed, point: validatedPoint },
    note: noteTrimmed,
    expectedPrice: validatedExpectedPrice,
  };
}
