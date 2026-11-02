/**
 * The venue of an event (S30, plan #223 Decision 16; spec §7): where it takes place (a managed S29 spot,
 * a paid place, a public place), whether the entry fee is included, the public-place commitment and the
 * accepted organizer terms; the spot manager's consent when the host is someone else (72 h, on the
 * `hostConsent` model); and the venue fee, the part of each ticket paid to that manager (`venue_fee`
 * line of a group payment, released with the event's tickets once it is `completed`).
 */

import type { PaymentProvider } from './booking.js';
import { DomainError } from './errors.js';
import type { Payment, PaymentMethod } from './escrow.js';
import {
  EVENT_PRICE_MAX,
  type EventCaller,
  type EventRecord,
  type HostConsent,
} from './event.js';
import type { EventDeps, EventTx } from './event_ports.js';
import {
  assertLinesSum,
  groupViewOf,
  lineOf,
  newChildPayment,
  newGroupPayment,
  type GroupLine,
  type PaymentGroupView,
} from './group_settlement.js';
import { isId } from './ids.js';
import { notifyEventVenueAnswered, notifyEventVenueRequested } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { ORGANIZER_TERMS_VERSION, canSell } from './organizer.js';
import type { Spot } from './spot.js';

export const VENUE_KINDS = ['managed_spot', 'paid_place', 'public'] as const;
export type VenueKind = (typeof VENUE_KINDS)[number];

/** §7.2: the spot manager answers within 72 hours, else the draft is cancelled. */
export const VENUE_CONSENT_HOURS = 72;

/**
 * Events created on or after this instant need a venue to publish; older ones read `venue: null`.
 * The builder moves it to the deploy date (ledgered).
 */
export const VENUE_REQUIRED_FROM = '2026-10-19T00:00:00.000Z';

/** A public-place commitment ticked a little ahead of the server clock is still accepted. */
const COMMITMENT_SKEW_MS = 5 * 60_000;
const HOUR_MS = 3_600_000;

/** `events/{id}.venue`. */
export interface Venue {
  readonly kind: VenueKind;
  /** Required for `managed_spot`; an S29 spot for `paid_place` (its `access` prefills the fee) or `public`. */
  readonly spotId: string | null;
  /** "Đã gồm" / "Chưa gồm ≈ {amountVnd}"; `amountVnd` is a reference price (VND), null when unknown. */
  readonly entryFee: { readonly included: boolean; readonly amountVnd: number | null };
  /** `public`: when the host ticked "Tôi tự chịu trách nhiệm xin phép…" (ISO instant); null otherwise. */
  readonly commitmentAt: string | null;
  /** The organizer terms the host accepted (`ORGANIZER_TERMS_VERSION`). */
  readonly termsVersion: string;
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const bad = (field: string): never => {
  throw new DomainError('invalid_argument', field);
};

const isVnd = (v: unknown): v is number => typeof v === 'number' && Number.isSafeInteger(v) && v > 0 && v <= EVENT_PRICE_MAX;

function parseEntryFee(v: unknown, kind: VenueKind): Venue['entryFee'] {
  if (v === undefined || v === null) {
    // Only a paid place must say whether its fee is included; elsewhere nothing is paid at a gate.
    return kind === 'paid_place' ? bad('entryFee') : { included: true, amountVnd: null };
  }
  if (!isRecord(v) || typeof v.included !== 'boolean') return bad('entryFee');
  const amount = v.amountVnd === undefined || v.amountVnd === null ? null : v.amountVnd;
  if (amount !== null && !isVnd(amount)) return bad('entryFee');
  if (kind === 'paid_place' && !v.included && amount === null) return bad('entryFee');
  return { included: v.included, amountVnd: amount };
}

function parseCommitment(v: unknown, now: Date): string {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}T[\d:.]+(Z|[+-]\d{2}:\d{2})$/.test(v)) return bad('commitmentAt');
  const t = Date.parse(v);
  if (Number.isNaN(t) || t > now.getTime() + COMMITMENT_SKEW_MS) return bad('commitmentAt');
  return new Date(t).toISOString();
}

/**
 * The venue block of a save or publish request. `invalid_argument` with field `kind`, `spotId` (missing
 * for `managed_spot`, or not an id), `entryFee` (a paid place that does not say whether the fee is
 * included, or not included without a reference amount), `commitmentAt` (a public place without the
 * commitment, or one in the future) or `termsVersion` (not the current organizer terms).
 */
export function validateVenue(raw: unknown, now: Date): Venue {
  if (!isRecord(raw)) return bad('venue');
  const kind = raw.kind;
  if (typeof kind !== 'string' || !(VENUE_KINDS as readonly string[]).includes(kind)) return bad('kind');
  const k = kind as VenueKind;
  const spotId = raw.spotId === undefined || raw.spotId === null ? null : raw.spotId;
  if (spotId !== null && !isId(spotId)) return bad('spotId');
  if (k === 'managed_spot' && spotId === null) return bad('spotId');
  const entryFee = parseEntryFee(raw.entryFee, k);
  const commitmentAt = k === 'public' ? parseCommitment(raw.commitmentAt, now) : null;
  if (raw.termsVersion !== ORGANIZER_TERMS_VERSION) return bad('termsVersion');
  return { kind: k, spotId, entryFee, commitmentAt, termsVersion: ORGANIZER_TERMS_VERSION };
}

/** §7.1: a paid place at an S29 spot with reference fees gets the first one when the host gave no amount. */
export function prefillVenueFee(raw: unknown, spot: Pick<Spot, 'access'> | null): unknown {
  if (!isRecord(raw) || raw.kind !== 'paid_place' || spot === null) return raw;
  const first = spot.access?.fees[0];
  if (first === undefined) return raw;
  const fee = isRecord(raw.entryFee) ? raw.entryFee : null;
  if (fee === null || (fee.amountVnd !== undefined && fee.amountVnd !== null)) return raw;
  return { ...raw, entryFee: { ...fee, amountVnd: first.amountVnd } };
}

/** The spot's manager must consent: a managed spot whose manager is not the host. */
export function venueConsentNeeded(v: Venue, hostUid: string | null, spotManagedBy: string | null): boolean {
  return v.kind === 'managed_spot' && spotManagedBy !== null && spotManagedBy !== hostUid;
}

/** Publishing needs a venue: events created on or after the cut-over, except entry events (their own spot). */
export const venueRequired = (e: Pick<EventRecord, 'type' | 'createdAt'>): boolean =>
  e.type !== 'entry' && e.createdAt.getTime() >= Date.parse(VENUE_REQUIRED_FROM);

export const venueConsentOf = (e: Pick<EventRecord, 'venueConsent'>): HostConsent => e.venueConsent ?? 'not_required';

export const venueFeeOf = (e: Pick<EventRecord, 'venueFeePerGuest'>): number => e.venueFeePerGuest ?? 0;

/**
 * Reads only: the venue's spot, if any. It must exist and be active; a `managed_spot` must have a manager
 * (`invalid_argument` spotId), and a managed spot cannot be declared a paid or public place (that would skip
 * its manager's consent: `invalid_argument` kind).
 */
export async function venueSpot(tx: Pick<EventTx, 'getSpot'>, v: Venue): Promise<Spot | null> {
  if (v.spotId === null) return null;
  const spot = await tx.getSpot(v.spotId);
  if (spot === null) throw new DomainError('not_found', 'spotId');
  if (spot.status !== 'active') throw new DomainError('spot_archived', 'spotId');
  if (v.kind === 'managed_spot' && spot.managedBy === null) throw new DomainError('invalid_argument', 'spotId');
  if (v.kind !== 'managed_spot' && spot.managedBy !== null) throw new DomainError('invalid_argument', 'kind');
  return spot;
}

/**
 * Reads only: a request's `venue` key. Undefined → no change; null → none; otherwise the block (a paid
 * place's fee prefilled from its spot) and its spot, checked.
 */
export async function readVenue(
  tx: Pick<EventTx, 'getSpot'>,
  raw: unknown,
  now: Date,
): Promise<{ readonly venue: Venue | null; readonly spot: Spot | null } | undefined> {
  if (raw === undefined) return undefined;
  if (raw === null) return { venue: null, spot: null };
  const spotId = isRecord(raw) && isId(raw.spotId) ? raw.spotId : null;
  const prefillSpot = spotId === null ? null : await tx.getSpot(spotId);
  const venue = validateVenue(prefillVenueFee(raw, prefillSpot), now);
  return { venue, spot: await venueSpot(tx, venue) };
}

/** The consent fields of an event that must ask (again): `pending` for 72 h from `now`. */
export const venueConsentRequest = (now: Date) => ({
  venueConsent: 'pending' as const,
  venueConsentExpiresAt: new Date(now.getTime() + VENUE_CONSENT_HOURS * HOUR_MS),
});

/** The consent fields of an event with no (or a new) venue: nothing asked, no fee. */
export const NO_VENUE_CONSENT = Object.freeze({
  venueConsent: 'not_required' as const,
  venueConsentExpiresAt: null,
  venueFeePerGuest: 0,
  venueManagerId: null,
});

/** What the emitter needs to tell the manager (after the transaction commits). */
export interface VenueRequest {
  readonly managerId: string;
  readonly event: EventRecord;
  readonly spot: string;
}

/** Best effort: the request is stored; a missed notice only means the 72 h run without a nudge. */
export async function tellVenueRequested(notify: NotifyDeps | undefined, r: VenueRequest | null): Promise<void> {
  if (notify === undefined || r === null || (r.event.venueConsentExpiresAt ?? null) === null) return;
  await notifyEventVenueRequested(notify, {
    managerId: r.managerId, eventId: r.event.id, title: r.event.title, spot: r.spot,
    expiresAt: (r.event.venueConsentExpiresAt as Date).toISOString(),
    host: { id: r.event.host.id, name: r.event.host.name, avatarUrl: r.event.host.avatarUrl },
  }).catch(() => undefined);
}

/**
 * The `venue_fee` line of a registration of `quantity` guests (spec §7.2), paid to the manager who
 * accepted; null when the event carries no fee.
 */
export function venueFeeLine(
  event: EventRecord,
  quantity: number,
  ref: { readonly paymentId: string; readonly registrationId: string },
): GroupLine | null {
  const fee = venueFeeOf(event);
  const payee = event.venueManagerId ?? null;
  if (fee <= 0 || payee === null || quantity < 1) return null;
  return {
    paymentId: ref.paymentId, kind: 'venue_fee', subjectType: 'event_registration', subjectId: ref.registrationId,
    payeeId: payee, amount: fee * quantity,
  };
}

/**
 * A ticket of an event with a venue fee (Decisions 6, 16): one group payment of `price × quantity` that
 * the customer pays, its `event_ticket` line (`(price − fee) × quantity` to `ticketPayeeId`) and its
 * `venue_fee` line (`fee × quantity` to the manager, `payeeKind: organizer`). Both lines carry the event,
 * so its completion stamps their release (`stampTicketRelease`). The group's idempotency key is the
 * ticket's (`idempotencyKey`), so a second tap with the same method finds it. Pure; the caller writes.
 */
export function venueTicketGroup(p: {
  readonly groupId: string;
  readonly ticketLineId: string;
  readonly venueLineId: string;
  readonly event: EventRecord;
  readonly registrationId: string;
  readonly quantity: number;
  readonly ticketPayeeId: string;
  readonly payerId: string;
  readonly method: PaymentMethod;
  readonly provider: PaymentProvider;
  readonly idempotencyKey: string;
  readonly now: Date;
  readonly expiresAt: Date;
}): { readonly group: Payment; readonly ticketLine: Payment; readonly lines: readonly Payment[]; readonly view: PaymentGroupView } {
  const { event: ev, quantity: q } = p;
  const venue = venueFeeLine(ev, q, { paymentId: p.venueLineId, registrationId: p.registrationId });
  if (venue === null) throw new DomainError('invalid_argument');
  const total = (ev.price ?? 0) * q;
  const group = newGroupPayment({
    id: p.groupId, payerId: p.payerId, total, method: p.method, provider: p.provider,
    idempotencyKey: p.idempotencyKey, now: p.now, expiresAt: p.expiresAt,
  });
  const common = { groupId: group.id, payerId: p.payerId, method: p.method, provider: p.provider, eventId: ev.id, now: p.now, expiresAt: p.expiresAt };
  const ticketLine = newChildPayment({
    ...common, id: p.ticketLineId,
    line: {
      kind: 'event_ticket', subjectType: 'event_registration', subjectId: p.registrationId,
      payeeId: p.ticketPayeeId, amount: total - venue.amount,
    },
    ...(ev.host.type === 'organizer' ? { payeeKind: 'organizer' as const } : {}),
  });
  const venueLine = newChildPayment({
    ...common, id: p.venueLineId,
    line: { kind: 'venue_fee', subjectType: venue.subjectType, subjectId: venue.subjectId, payeeId: venue.payeeId, amount: venue.amount },
    payeeKind: 'organizer',
  });
  const lines = [ticketLine, venueLine];
  assertLinesSum(group, lines);
  return { group, ticketLine, lines, view: groupViewOf(group, lines.map(lineOf), 'created', p.now) };
}

/** Writes only: the 72 h passed without an answer, so the draft is cancelled and its hashtag is free again. */
export function expireVenueConsent(tx: EventTx, ev: EventRecord, now: Date): void {
  if (ev.hashtagKey !== '') tx.deleteHashtag(ev.hashtagKey);
  tx.putEvent({
    ...ev, venueConsent: 'expired', status: 'cancelled', cancelledAt: now,
    version: ev.version + 1, updatedAt: now,
  });
}

function parseFee(v: unknown): number {
  if (v === undefined || v === null) return 0;
  if (typeof v !== 'number' || !Number.isSafeInteger(v) || v < 0) throw new DomainError('invalid_argument', 'venueFeePerGuest');
  return v;
}

/**
 * S11.02-venue-consent: the manager of the event's spot accepts (with a fee per guest, 0 by default) or
 * declines (the draft is cancelled). The fee is part of the ticket price, so it must stay below a priced
 * event's price and be 0 for a free event (`invalid_argument` venueFeePerGuest); a fee above 0 needs the
 * manager's business (`business_required`). `not_spot_manager` for anyone else, `conflict` once answered,
 * `deadline_passed` after the 72 h (the draft is then expired). The host is told (best effort).
 */
export async function respondVenueConsent(
  deps: EventDeps & { readonly notify?: NotifyDeps },
  caller: EventCaller,
  raw: unknown,
): Promise<void> {
  if (!isRecord(raw)) throw new DomainError('invalid_argument');
  if (!isId(raw.eventId)) throw new DomainError('invalid_argument', 'eventId');
  const eventId = raw.eventId;
  if (typeof raw.accept !== 'boolean') throw new DomainError('invalid_argument', 'accept');
  const accept = raw.accept;
  const fee = accept ? parseFee(raw.venueFeePerGuest) : 0;

  const out = await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    const v = ev.venue ?? null;
    const spot = v === null || v.kind !== 'managed_spot' || v.spotId === null ? null : await tx.getSpot(v.spotId);
    if (spot === null || spot.managedBy !== caller.uid) throw new DomainError('not_spot_manager');
    const org = fee > 0 ? await tx.getOrganizer(caller.uid) : null;
    if (ev.status !== 'draft' || venueConsentOf(ev) !== 'pending') throw new DomainError('conflict');
    const requestExpiresAt = ev.venueConsentExpiresAt ?? null;
    if (requestExpiresAt !== null && now.getTime() >= requestExpiresAt.getTime()) {
      expireVenueConsent(tx, ev, now);
      return null;
    }
    if (accept) {
      const price = ev.price ?? 0;
      if (fee > 0 && fee >= price) throw new DomainError('invalid_argument', 'venueFeePerGuest');
      if (fee > 0 && (org === null || !canSell(org))) throw new DomainError('business_required');
      tx.putEvent({
        ...ev, venueConsent: 'accepted', venueFeePerGuest: fee, venueManagerId: caller.uid,
        version: ev.version + 1, updatedAt: now,
      });
    } else {
      if (ev.hashtagKey !== '') tx.deleteHashtag(ev.hashtagKey);
      tx.putEvent({
        ...ev, venueConsent: 'declined', status: 'cancelled', cancelledAt: now,
        version: ev.version + 1, updatedAt: now,
      });
    }
    return { ev, spot: spot.name, requestExpiresAt: (requestExpiresAt ?? now).toISOString() };
  });
  if (out === null) throw new DomainError('deadline_passed');
  const hostId = out.ev.host.id ?? out.ev.createdBy;
  if (deps.notify !== undefined) {
    await notifyEventVenueAnswered(deps.notify, {
      hostId, eventId: out.ev.id, title: out.ev.title, spot: out.spot, accepted: accept, requestExpiresAt: out.requestExpiresAt,
    }).catch(() => undefined);
  }
}
