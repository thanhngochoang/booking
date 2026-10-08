import { formatVnDate } from './booking_policy.js';
import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { isValidHashtag } from './event_hashtag.js';
import type { RefundStatus } from './escrow.js';
import type { UserContactRecord } from './ports.js';

export const EVENT_TYPES = ['photo_walk', 'mini_session', 'workshop', 'cosplay', 'other'] as const;
export const EVENT_STATUSES = ['draft', 'open', 'full', 'closed', 'cancelled', 'completed'] as const;
export const REGISTRATION_STATUSES = ['held', 'paid', 'cancelled', 'refunded'] as const;
export const HOST_CONSENTS = ['not_required', 'pending', 'accepted', 'declined', 'expired'] as const;

export type EventType = (typeof EVENT_TYPES)[number];
export type EventStatus = (typeof EVENT_STATUSES)[number];
export type RegistrationStatus = (typeof REGISTRATION_STATUSES)[number];
export type HostConsent = (typeof HOST_CONSENTS)[number];

export const EVENT_TITLE_MAX = 80;
export const EVENT_DESC_MAX = 1000;
export const EVENT_CAPACITY_MAX = 500;
export const EVENT_PRICE_MAX = 100_000_000;
export const EVENT_PRICE_STEP = 1000;
export const TICKETS_PER_REGISTRATION = 4;
export const HOLD_MINUTES = 10;
export const PUBLISH_LEAD_HOURS = 2;
export const DEFAULT_DEADLINE_HOURS = 12;
export const FREE_CANCEL_HOURS = 48;
export const CHECKIN_GRACE_HOURS = 2;
export const TIMELINE_OPEN_DAYS = 30;
/** O1: a photographer has 24 hours to accept an event staff created for them. */
export const HOST_CONSENT_HOURS = 24;
export const LOCATION_NAME_MAX = 120;
export const MEETING_POINT_MAX = 120;
/** O2: staff-entered Q&A on platform-hosted events. */
export const EVENT_FAQ_MAX = 10;
export const FAQ_QUESTION_MAX = 120;
export const FAQ_ANSWER_MAX = 500;

const HOUR_MS = 3_600_000;

export type StaffRole = 'admin' | 'sales';

/** Who calls an event use case. (Not `Caller`: that name is the payout use case's.) */
export interface EventCaller {
  readonly uid: string;
  readonly staffRole: StaffRole | null;
}

export interface EventHost {
  readonly type: 'photographer' | 'platform';
  readonly id: string | null;
  readonly name: string | null;
  readonly avatarUrl: string | null;
  readonly verified: boolean;
}

export interface EventLocation {
  readonly name: string;
  readonly meetingPoint: string | null;
  readonly lat: number;
  readonly lng: number;
  readonly geohash: string;
  readonly areaId: string | null;
}

export interface EventFaq {
  readonly question: string;
  readonly answer: string;
}

/** `events/{id}`. */
export interface EventRecord {
  readonly id: string;
  readonly host: EventHost;
  readonly createdBy: string;
  readonly createdByRole: 'photographer' | StaffRole;
  /** O1: `pending` while a photographer has not answered an event staff created for them. */
  readonly hostConsent: HostConsent;
  readonly hostConsentExpiresAt: Date | null;
  readonly title: string;
  readonly description: string;
  readonly type: EventType;
  readonly coverUrl: string | null;
  readonly coverPath: string | null;
  readonly startAt: Date | null;
  readonly endAt: Date | null;
  readonly dayKey: string | null;
  readonly location: EventLocation | null;
  readonly capacity: number | null;
  readonly price: number | null;
  readonly registrationDeadline: Date | null;
  readonly faq: readonly EventFaq[];
  readonly hashtag: string;
  readonly hashtagKey: string;
  readonly hashtagLocked: boolean;
  readonly status: EventStatus;
  readonly registeredCount: number;
  readonly heldCount: number;
  readonly chatId: string | null;
  readonly postCount: number;
  readonly version: number;
  readonly publishedAt: Date | null;
  readonly completedAt: Date | null;
  readonly cancelledAt: Date | null;
  /**
   * S17: when the 48-hour `event_soon` reminders went out (server marker, set by the event clock
   * only after every paid ticket was notified). Optional so records built before it compile; the
   * Firestore adapter writes null when absent.
   */
  readonly soonNoticeAt?: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** `events/{id}/registrations/{regId}`. */
export interface RegistrationDoc {
  readonly id: string;
  readonly eventId: string;
  readonly userId: string;
  readonly userName: string;
  readonly userAvatarUrl: string | null;
  readonly quantity: number;
  readonly amount: number;
  readonly status: RegistrationStatus;
  readonly holdExpiresAt: Date | null;
  readonly ticketCode: string;
  readonly paymentId: string | null;
  /** O3: true only for a paid ticket after payment; a free registration never unlocks contact. */
  readonly contactEligible: boolean;
  readonly checkedInAt: Date | null;
  readonly cancelledAt: Date | null;
  readonly refundPercent: number | null;
  /**
   * The event was cancelled while this ticket's money was held: a 100% refund is still to run
   * (cleared when it lands; the event clock retries leftovers). Absent means false.
   */
  readonly refundDue?: boolean;
  /**
   * The refund of this ticket's money (customer cancel ≥ 48 h, host cancel, or a payment that came
   * after the hold ended) and its gateway state: the app says "Đang hoàn" until it is `done`;
   * `failed` stays with staff (manual), like bookings. Absent or null: no refund.
   */
  readonly refundId?: string | null;
  readonly refundStatus?: RefundStatus | null;
  readonly event: {
    readonly title: string;
    readonly type: EventType;
    readonly startAt: Date;
    readonly endAt: Date;
    readonly locationName: string;
    readonly lat: number;
    readonly lng: number;
    readonly coverUrl: string | null;
  };
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** `registrations/{regId}/private/contact`; written only for tickets that unlock contact (O3). */
export interface RegistrationContact {
  readonly name: string;
  readonly phone: string;
  readonly allowZalo: boolean;
  readonly allowWhatsApp: boolean;
}

/**
 * The private contact snapshot of a ticket that unlocks contact (a paid ticket after payment, O3).
 * Written when the payment lands; free registrations never get one.
 */
export function registrationContactOf(name: string, phone: string, record: UserContactRecord | null): RegistrationContact {
  const r = (record ?? {}) as { allowZalo?: unknown; allowWhatsApp?: unknown };
  return { name, phone, allowZalo: r.allowZalo === true, allowWhatsApp: r.allowWhatsApp === true };
}

export const isFreeEvent = (e: Pick<EventRecord, 'price'>): boolean => (e.price ?? 0) === 0;

export function isEventManager(e: Pick<EventRecord, 'host' | 'createdBy'>, c: EventCaller): boolean {
  if (e.host.type === 'photographer' && e.host.id === c.uid) return true;
  if (c.staffRole === 'admin') return true;
  return c.staffRole === 'sales' && e.createdBy === c.uid;
}

export function seatsLeft(e: Pick<EventRecord, 'capacity' | 'registeredCount' | 'heldCount'>): number {
  if (e.capacity === null) return 0;
  return Math.max(0, e.capacity - e.registeredCount - e.heldCount);
}

/** `open ↔ full` by free seats; every other status is kept. A full event reopens only before the deadline. */
export function statusAfterSeats(e: EventRecord, now: Date): EventStatus {
  const left = seatsLeft(e);
  if (e.status === 'open' && left === 0) return 'full';
  if (e.status === 'full' && left > 0) {
    const d = e.registrationDeadline;
    return d !== null && now.getTime() >= d.getTime() ? 'closed' : 'open';
  }
  return e.status;
}

/** Day the event takes place (Vietnam time), for ticket codes. */
export function eventDay(e: Pick<EventRecord, 'startAt' | 'createdAt'>): Date {
  return e.startAt ?? e.createdAt;
}

// ---- field validation ----------------------------------------------------------------------

/** Effective event fields after applying a request on top of the stored event. */
export interface EventFields {
  readonly title: string;
  readonly description: string;
  readonly type: EventType;
  readonly coverUrl: string | null;
  readonly coverPath: string | null;
  readonly startAt: Date | null;
  readonly endAt: Date | null;
  readonly dayKey: string | null;
  readonly location: EventLocation | null;
  readonly capacity: number | null;
  readonly price: number | null;
  readonly registrationDeadline: Date | null;
  readonly faq: readonly EventFaq[];
  /** Only when the request carried one. */
  readonly hashtag: string | undefined;
  /** Keys the request carried. */
  readonly touched: ReadonlySet<string>;
}

const bad = (): never => {
  throw new DomainError('invalid_argument');
};

function clean(v: unknown, max: number, min: number): string {
  if (typeof v !== 'string') return bad();
  const t = v.normalize('NFC').trim();
  const n = graphemeCount(t);
  if (n < min || n > max) return bad();
  return t;
}

function parseDate(v: unknown): Date {
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return bad();
    return new Date(v.getTime());
  }
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}T[\d:.]+(Z|[+-]\d{2}:\d{2})$/.test(v)) return bad();
  const t = Date.parse(v);
  if (Number.isNaN(t)) return bad();
  return new Date(t);
}

const GEOHASH = '0123456789bcdefghjkmnpqrstuvwxyz';

/** Standard geohash (base32, interleaved longitude/latitude bits). */
export function encodeGeohash(lat: number, lng: number, precision = 9): string {
  let latLo = -90, latHi = 90, lngLo = -180, lngHi = 180;
  let hash = '';
  let bit = 0, ch = 0, even = true;
  while (hash.length < precision) {
    if (even) {
      const mid = (lngLo + lngHi) / 2;
      if (lng >= mid) { ch = (ch << 1) | 1; lngLo = mid; } else { ch <<= 1; lngHi = mid; }
    } else {
      const mid = (latLo + latHi) / 2;
      if (lat >= mid) { ch = (ch << 1) | 1; latLo = mid; } else { ch <<= 1; latHi = mid; }
    }
    even = !even;
    if (++bit === 5) {
      hash += GEOHASH.charAt(ch);
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

function parseLocation(v: unknown): EventLocation {
  if (typeof v !== 'object' || v === null || Array.isArray(v)) return bad();
  const r = v as Record<string, unknown>;
  const name = clean(r.name, LOCATION_NAME_MAX, 1);
  const meetingPoint = r.meetingPoint === undefined || r.meetingPoint === null
    ? null
    : clean(r.meetingPoint, MEETING_POINT_MAX, 0) || null;
  const { lat, lng } = r;
  if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng)) return bad();
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return bad();
  const areaId = r.areaId === undefined || r.areaId === null ? null : r.areaId;
  if (areaId !== null && !isId(areaId)) return bad();
  return { name, meetingPoint, lat, lng, geohash: encodeGeohash(lat, lng), areaId };
}

function parseFaq(v: unknown): EventFaq[] {
  if (!Array.isArray(v) || v.length > EVENT_FAQ_MAX) return bad();
  return v.map((item): EventFaq => {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) return bad();
    const r = item as Record<string, unknown>;
    return { question: clean(r.question, FAQ_QUESTION_MAX, 1), answer: clean(r.answer, FAQ_ANSWER_MAX, 1) };
  });
}

export const sameInstant = (a: Date | null, b: Date | null): boolean =>
  a === null || b === null ? a === b : a.getTime() === b.getTime();

function nullable<T>(v: unknown, parse: (x: unknown) => T): T | null {
  return v === null ? null : parse(v);
}

/**
 * Validates a save/publish request on top of `existing` and returns the effective fields.
 * `draft`: only the fields present are checked, the schedule may be missing.
 * `publish`: the effective event must be complete (cover, schedule, place, capacity, price).
 */
export function validateEventFields(
  raw: unknown,
  mode: 'draft' | 'publish',
  now: Date,
  existing: EventRecord | null,
): EventFields {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return bad();
  const r = raw as Record<string, unknown>;
  const touched = new Set<string>();
  for (const k of ['title', 'description', 'type', 'coverUrl', 'coverPath', 'startAt', 'endAt', 'location',
    'capacity', 'price', 'registrationDeadline', 'faq', 'hashtag']) {
    if (r[k] !== undefined) touched.add(k);
  }
  const has = (k: string): boolean => touched.has(k);

  let title = existing?.title;
  if (has('title')) title = clean(r.title, EVENT_TITLE_MAX, 1);
  if (title === undefined) return bad();

  let type = existing?.type;
  if (has('type')) {
    if (typeof r.type !== 'string' || !(EVENT_TYPES as readonly string[]).includes(r.type)) return bad();
    type = r.type as EventType;
  }
  if (type === undefined) return bad();

  const description = has('description') ? clean(r.description, EVENT_DESC_MAX, 0) : (existing?.description ?? '');

  const coverUrl = has('coverUrl')
    ? nullable(r.coverUrl, (x) => clean(x, 2048, 1))
    : (existing?.coverUrl ?? null);
  const coverPath = has('coverPath')
    ? nullable(r.coverPath, (x) => clean(x, 512, 1))
    : (existing?.coverPath ?? null);
  if ((coverUrl === null) !== (coverPath === null)) return bad();

  const startAt = has('startAt') ? nullable(r.startAt, parseDate) : (existing?.startAt ?? null);
  const endAt = has('endAt') ? nullable(r.endAt, parseDate) : (existing?.endAt ?? null);
  if (startAt !== null && endAt !== null) {
    if (endAt.getTime() <= startAt.getTime()) return bad();
    if (formatVnDate(startAt) !== formatVnDate(endAt)) return bad();
  }

  const location = has('location') ? nullable(r.location, parseLocation) : (existing?.location ?? null);

  const capacity = has('capacity')
    ? nullable(r.capacity, (x) => {
      if (typeof x !== 'number' || !Number.isInteger(x) || x < 1 || x > EVENT_CAPACITY_MAX) return bad();
      return x;
    })
    : (existing?.capacity ?? null);

  const price = has('price')
    ? nullable(r.price, (x) => {
      if (typeof x !== 'number' || !Number.isInteger(x) || x < 0 || x > EVENT_PRICE_MAX) return bad();
      if (x % EVENT_PRICE_STEP !== 0) return bad();
      return x;
    })
    : (existing?.price ?? null);

  const startChanged = has('startAt') && !sameInstant(startAt, existing?.startAt ?? null);
  let deadline = has('registrationDeadline')
    ? nullable(r.registrationDeadline, parseDate)
    : (existing?.registrationDeadline ?? null);
  // A moved start without a new deadline re-derives it (the old one may now lie after the start).
  if (!has('registrationDeadline') && startChanged) deadline = null;
  if (deadline !== null && startAt !== null && deadline.getTime() > startAt.getTime()) return bad();

  const faq = has('faq') ? parseFaq(r.faq) : (existing?.faq ?? []);

  let hashtag: string | undefined;
  if (has('hashtag')) {
    if (typeof r.hashtag !== 'string' || !isValidHashtag(r.hashtag)) return bad();
    hashtag = r.hashtag;
  }

  if (mode === 'publish') {
    if (coverUrl === null || coverPath === null) return bad();
    if (startAt === null || endAt === null || location === null || capacity === null || price === null) return bad();
    const mustBeAhead = existing === null || existing.status === 'draft' || startChanged;
    if (mustBeAhead && startAt.getTime() < now.getTime() + PUBLISH_LEAD_HOURS * HOUR_MS) return bad();
    if (deadline === null) {
      const early = startAt.getTime() - DEFAULT_DEADLINE_HOURS * HOUR_MS;
      deadline = early >= now.getTime() + HOUR_MS ? new Date(early) : new Date(startAt.getTime());
    }
  }

  return {
    title, description, type, coverUrl, coverPath, startAt, endAt,
    dayKey: startAt === null ? null : formatVnDate(startAt),
    location, capacity, price, registrationDeadline: deadline, faq, hashtag, touched,
  };
}
