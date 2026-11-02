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

export interface AddonPickInput {
  readonly addonId: string;
  readonly qty: number;
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
  /** Add-on picks (`addonId` + `qty`); the server prices them. Absent = []. */
  readonly addons: readonly AddonPickInput[];
  /** Transport add-on pickup address; dropped by `requirePickup` when no transport line exists. */
  readonly pickup?: { readonly name: string; readonly point?: { readonly lat: number; readonly lng: number } };
  /** Staleness check on the total (package + add-ons), never a price source. */
  readonly expectedTotal?: number;
  readonly spotScheduleId?: string;
  readonly slotOfferId?: string;
  /** S30 Decision 15: entry tickets with the booking; the items are priced by the server. */
  readonly entry?: EntryRequest;
}

export interface EntryRequest {
  readonly eventId: string;
  readonly visitDay: string;
  readonly items: readonly { readonly ticketTypeId: string; readonly qty: number }[];
}

/** The shape of `entry` (`invalid_argument` field `entry`); the items themselves are checked by `priceItems`. */
function parseEntry(raw: unknown): EntryRequest | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'object' || Array.isArray(raw)) throw new DomainError('invalid_argument', 'entry');
  const { eventId, visitDay, items } = raw as Record<string, unknown>;
  if (!isId(eventId) || !isDateString(visitDay) || !Array.isArray(items)) throw new DomainError('invalid_argument', 'entry');
  return { eventId, visitDay, items: items as EntryRequest['items'] };
}

/** A place-shaped value: `name` 3–120 graphemes (trimmed), optional `point {lat, lng}`. */
function parsePlaceLike(raw: unknown): { name: string; point?: { lat: number; lng: number } } {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const obj = raw as Record<string, unknown>;
  if (typeof obj.name !== 'string') {
    throw new DomainError('invalid_argument');
  }
  const name = obj.name.trim();
  const len = graphemeCount(name);
  if (len < MIN_PLACE_LENGTH || len > MAX_PLACE_LENGTH) {
    throw new DomainError('invalid_argument');
  }
  if (obj.point && typeof obj.point === 'object') {
    const pt = obj.point as Record<string, unknown>;
    if (typeof pt.lat === 'number' && typeof pt.lng === 'number') {
      return { name, point: { lat: pt.lat, lng: pt.lng } };
    }
  }
  return { name };
}

function parseAddonPicks(raw: unknown): AddonPickInput[] {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw.map((p: unknown) => {
    if (typeof p !== 'object' || p === null) throw new DomainError('invalid_argument');
    const { addonId, qty } = p as Record<string, unknown>;
    if (!isId(addonId) || typeof qty !== 'number') throw new DomainError('invalid_argument');
    return { addonId, qty };
  });
}

export function validateCreateBookingDraftInput(
  raw: unknown,
  now: Date,
): CreateBookingDraftInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const {
    customerId,
    photographerId,
    serviceId,
    day,
    start,
    place,
    note,
    expectedPrice,
    addons,
    pickup,
    expectedTotal,
    spotScheduleId,
    slotOfferId,
    entry,
  } = raw as Record<string, unknown>;

  if (!isId(customerId) || !isId(photographerId) || !isId(serviceId)) {
    throw new DomainError('invalid_argument');
  }

  if (customerId === photographerId) {
    throw new DomainError('invalid_argument');
  }

  if (!isDateString(day) || !isTimeString(start)) {
    throw new DomainError('invalid_argument');
  }

  const validatedPlace = parsePlaceLike(place);

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

  let validatedExpectedPrice: number | undefined;
  if (expectedPrice !== undefined && expectedPrice !== null) {
    if (typeof expectedPrice !== 'number' || !Number.isInteger(expectedPrice) || expectedPrice < 0) {
      throw new DomainError('invalid_argument');
    }
    validatedExpectedPrice = expectedPrice;
  }

  let validatedExpectedTotal: number | undefined;
  if (expectedTotal !== undefined && expectedTotal !== null) {
    if (typeof expectedTotal !== 'number' || !Number.isInteger(expectedTotal) || expectedTotal < 0) {
      throw new DomainError('invalid_argument');
    }
    validatedExpectedTotal = expectedTotal;
  }

  let validatedSpotScheduleId: string | undefined;
  if (spotScheduleId !== undefined && spotScheduleId !== null) {
    if (!isId(spotScheduleId)) {
      throw new DomainError('invalid_argument');
    }
    validatedSpotScheduleId = spotScheduleId;
  }

  let validatedSlotOfferId: string | undefined;
  if (slotOfferId !== undefined && slotOfferId !== null) {
    if (!isId(slotOfferId)) {
      throw new DomainError('invalid_argument');
    }
    if (!validatedSpotScheduleId) {
      throw new DomainError('invalid_argument');
    }
    validatedSlotOfferId = slotOfferId;

    // Slot booking does not allow addons or pickup (T6)
    const rawRecord = raw as Record<string, unknown>;
    if (rawRecord.addons !== undefined && rawRecord.addons !== null) {
      if (Array.isArray(rawRecord.addons) && rawRecord.addons.length > 0) {
        throw new DomainError('invalid_argument');
      }
    }
    if (rawRecord.pickup !== undefined && rawRecord.pickup !== null) {
      throw new DomainError('invalid_argument');
    }
  }

  return {
    customerId,
    photographerId,
    serviceId,
    day,
    start,
    place: validatedPlace,
    note: noteTrimmed,
    expectedPrice: validatedExpectedPrice,
    addons: parseAddonPicks(addons),
    pickup: pickup === undefined || pickup === null ? undefined : parsePlaceLike(pickup),
    expectedTotal: validatedExpectedTotal,
    spotScheduleId: validatedSpotScheduleId,
    slotOfferId: validatedSlotOfferId,
    entry: parseEntry(entry),
  };
}
