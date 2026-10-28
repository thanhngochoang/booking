import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { INSTANT } from './instant.js';
import { isInternationalE164, isVnE164 } from './phone.js';

/** Contact channel codes (domain-model.md §4 `ContactChannel`). */
export const CONTACT_CHANNELS = ['in_app', 'call', 'zalo', 'whatsapp'] as const;
export type ContactChannel = (typeof CONTACT_CHANNELS)[number];

/** Channels that leave the app; only these get a server-built URL. */
export type ExternalChannel = Exclude<ContactChannel, 'in_app'>;
export const EXTERNAL_CHANNELS: readonly ExternalChannel[] = ['call', 'zalo', 'whatsapp'];

export const isExternalChannel = (v: unknown): v is ExternalChannel =>
  typeof v === 'string' && (EXTERNAL_CHANNELS as readonly string[]).includes(v);

/** Public on/off flags (`photographers/{uid}.contactChannels`). */
export interface ContactChannels {
  readonly call: boolean;
  readonly zalo: boolean;
  readonly whatsapp: boolean;
}

/** Private numbers (`photographers/{uid}/private/contact`), E.164. */
export interface ContactNumbers {
  readonly phone: string;
  readonly zaloPhone?: string | null;
  readonly whatsappPhone?: string | null;
}

/** The number a channel dials: the own Zalo/WhatsApp number, else the main phone. */
export function numberFor(channel: ExternalChannel, numbers: ContactNumbers): string {
  switch (channel) {
    case 'call':
      return numbers.phone;
    case 'zalo':
      return numbers.zaloPhone ?? numbers.phone;
    case 'whatsapp':
      return numbers.whatsappPhone ?? numbers.phone;
  }
}

/**
 * The one URL the app opens, exactly what the client's `contactUriFor` builds (plan 2b, Task 4):
 * `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/<digits>` (no plus). Null when the stored number
 * is not valid for the channel, so a bad record never becomes a URL.
 */
export function contactUrlFor(channel: ExternalChannel, numbers: ContactNumbers): string | null {
  const number = numberFor(channel, numbers);
  const valid = channel === 'whatsapp' ? isInternationalE164(number) : isVnE164(number);
  if (!valid) return null;
  const digits = number.slice(1);
  switch (channel) {
    case 'call':
      return `tel:${number}`;
    case 'zalo':
      return `https://zalo.me/${digits}`;
    case 'whatsapp':
      return `https://wa.me/${digits}`;
  }
}

export const BOOKING_CONTACT_DAYS = 30;
export const TICKET_CONTACT_DAYS = 7;
const DAY_MS = 86_400_000;

/**
 * `contact_unlocked` for a booking (domain-model.md §5): `requested | accepted | upcoming | shooting` (S30)
 * through `approved`, or
 * `completed | reviewed` for 30 days after completion (inclusive; unknown completion time stays
 * locked). Same boundaries as the client's `contactAccessForBooking` (plan 2b, Task 7).
 */
export function bookingContactUnlocked(
  booking: { readonly status: string; readonly completedAt: Date | null },
  now: Date,
): boolean {
  switch (booking.status) {
    case 'requested':
    case 'accepted':
    case 'upcoming':
    case 'shooting':
    case 'shot':
    case 'delivered':
    case 'revision_requested':
    case 'approved':
      return true;
    case 'completed':
    case 'reviewed':
      return booking.completedAt !== null
        && now.getTime() - booking.completedAt.getTime() <= BOOKING_CONTACT_DAYS * DAY_MS;
    default:
      return false;
  }
}

/**
 * `contact_unlocked` for an event ticket: `paid`, until 7 days after the event ends (inclusive).
 * Owner decision O3: only a paid ticket (`contactEligible`) unlocks; a free registration gives the
 * group chat and in-app chat only, so a missing flag counts as locked.
 */
export function ticketContactUnlocked(
  registration: { readonly status: string; readonly eventEndsAt: Date | null; readonly contactEligible?: boolean },
  now: Date,
): boolean {
  return registration.status === 'paid'
    && registration.contactEligible === true
    && registration.eventEndsAt !== null
    && now.getTime() - registration.eventEndsAt.getTime() <= TICKET_CONTACT_DAYS * DAY_MS;
}

/** Statuses of a Chụp ngay request with a photographer on the job. */
const INSTANT_JOB_STATUSES: readonly string[] = ['assigned', 'en_route', 'arrived', 'in_progress', 'finished'];

/**
 * `contact_unlocked` for a Chụp ngay request (#140 Decision 22): only once paid (`paidAt`; never in
 * #140, the money is #202's), while a photographer is on the job, and for 7 days after completion
 * (inclusive; an unknown completion time stays locked).
 */
export function instantContactUnlocked(
  request: { readonly status: string; readonly photographerId: string | null; readonly paidAt: Date | null; readonly completedAt: Date | null },
  now: Date,
): boolean {
  if (request.paidAt === null || request.photographerId === null) return false;
  if (INSTANT_JOB_STATUSES.includes(request.status)) return true;
  return request.status === 'completed' && request.completedAt !== null
    && now.getTime() - request.completedAt.getTime() <= INSTANT.CONTACT_DAYS * DAY_MS;
}

/** What a contact link is for. `event_registration` and `instant_request` are `PaymentSubject` codes. */
export type ContactSubject =
  | { readonly type: 'booking'; readonly id: string }
  | { readonly type: 'event_registration'; readonly id: string }
  | { readonly type: 'instant_request'; readonly id: string };

export interface ContactLinkRequest {
  readonly subject: ContactSubject;
  readonly channel: ExternalChannel;
}

/** Request key → subject type; exactly one per request. */
const SUBJECT_KEYS = [
  ['bookingId', 'booking'],
  ['registrationId', 'event_registration'],
  ['instantRequestId', 'instant_request'],
] as const;
const REQUEST_KEYS = new Set<string>([...SUBJECT_KEYS.map(([k]) => k), 'channel']);

/**
 * Wire payload of `getContactLink`: `{bookingId | registrationId | instantRequestId, channel}`,
 * exactly one id, no other key. Anything else is `invalid_argument`.
 */
export function parseContactLinkRequest(data: unknown): ContactLinkRequest {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new DomainError('invalid_argument');
  }
  const d = data as Record<string, unknown>;
  if (!Object.keys(d).every((k) => REQUEST_KEYS.has(k))) throw new DomainError('invalid_argument');
  const present = SUBJECT_KEYS.filter(([key]) => key in d);
  const only = present.length === 1 ? present[0] : undefined;
  if (only === undefined) throw new DomainError('invalid_argument');
  const [key, type] = only;
  const id = d[key];
  const channel = d.channel;
  if (!isId(id) || !isExternalChannel(channel)) throw new DomainError('invalid_argument');
  return { subject: { type, id }, channel };
}
