import {
  EVENT_DESC_MAX,
  EVENT_TITLE_MAX,
  HOST_CONSENT_HOURS,
  encodeGeohash,
  isEventManager,
  sameInstant,
  statusAfterSeats,
  validateEventFields,
  type EventCaller,
  type EventFields,
  type EventHost,
  type EventRecord,
  type RegistrationDoc,
} from './event.js';
import { DomainError } from './errors.js';
import { GROUP_READONLY_DAYS } from './event_chat.js';
import { hashtagBase, hashtagKeyOf, hashtagWithSuffix } from './event_hashtag.js';
import type { EventDeps, EventGroupChatSeed, EventTx } from './event_ports.js';
import { isId } from './ids.js';
import { SPOT_EVENT_SLACK_M, spotCovers, type Spot } from './spot.js';
import { formatVnDate } from './booking_policy.js';
import { graphemeCount } from './booking_requests.js';
import {
  entryFieldsOf,
  entryRangeInstants,
  isOpenDay,
  validateEntryEvent,
  weekdayOf,
  type EntryFields,
} from './entry_tickets.js';
import { readEntryDays, releaseDeltas, writeEntryDays } from './entry_days.js';
import { canSell } from './organizer.js';
import type { NotifyDeps } from './notification_ports.js';
import {
  NO_VENUE_CONSENT,
  readVenue,
  tellVenueRequested,
  venueConsentNeeded,
  venueConsentOf,
  venueConsentRequest,
  venueRequired,
  venueSpot,
  type Venue,
  type VenueRequest,
} from './event_venue.js';

const HOUR_MS = 3_600_000;
const CLIENT_EVENT_ID = /^[A-Za-z0-9_-]{20,64}$/;

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

/**
 * Event state is only ever written by the server, so the host fields are looked up, never trusted.
 * A signed-in user hosts as a photographer (an onboarded profile) or, without one or with
 * `hostAs: 'organizer'`, as an active organizer (S30 Decision 3: `host.type 'organizer'`, the
 * organizer document's name and avatar, `verified` = its verified business).
 */
async function resolveHost(
  deps: EventDeps,
  tx: EventTx,
  caller: EventCaller,
  hostPhotographerId: unknown,
  hostAs: unknown,
): Promise<{ host: EventHost; createdByRole: EventRecord['createdByRole']; consent: boolean }> {
  const requested = hostPhotographerId === undefined || hostPhotographerId === null ? null : idOf(hostPhotographerId);
  if (hostAs !== undefined && hostAs !== null && hostAs !== 'photographer' && hostAs !== 'organizer') {
    throw new DomainError('invalid_argument', 'hostAs');
  }
  if (caller.staffRole !== null) {
    if (hostAs === 'organizer') throw new DomainError('invalid_argument', 'hostAs');
    if (requested === null) {
      return {
        host: { type: 'platform', id: null, name: null, avatarUrl: null, verified: true },
        createdByRole: caller.staffRole,
        consent: false,
      };
    }
    // O1: staff may create for a photographer, but only as a draft the photographer must accept.
    const p = await deps.people.photographer(requested);
    if (p === null || !p.onboardingComplete) throw new DomainError('not_eligible');
    return {
      host: { type: 'photographer', id: requested, name: p.name, avatarUrl: p.avatarUrl, verified: p.verified },
      createdByRole: caller.staffRole,
      consent: true,
    };
  }
  if (requested !== null && requested !== caller.uid) throw new DomainError('permission_denied');
  const p = hostAs === 'organizer' ? null : await deps.people.photographer(caller.uid);
  if (p !== null && p.onboardingComplete) {
    return {
      host: { type: 'photographer', id: caller.uid, name: p.name, avatarUrl: p.avatarUrl, verified: p.verified },
      createdByRole: 'photographer',
      consent: false,
    };
  }
  if (hostAs === 'photographer' || requested !== null) throw new DomainError('permission_denied');
  const org = await tx.getOrganizer(caller.uid);
  if (org === null || org.status !== 'active') throw new DomainError('permission_denied');
  return {
    host: { type: 'organizer', id: org.id, name: org.name, avatarUrl: org.avatarUrl, verified: org.businessVerified },
    createdByRole: 'photographer',
    consent: false,
  };
}

/**
 * Decision 3: an organizer host must be active; a priced event needs it to be able to sell
 * (`business_required`), a free one only `active`. Reads only.
 */
async function checkOrganizerHost(tx: EventTx, host: EventHost, price: number | null): Promise<void> {
  if (host.type !== 'organizer') return;
  const org = host.id === null ? null : await tx.getOrganizer(host.id);
  if (org === null || org.status !== 'active') throw new DomainError('permission_denied');
  if ((price ?? 0) > 0 && !canSell(org)) throw new DomainError('business_required');
}

/** The venue's fields after a save: a new venue starts over (nothing asked, no fee). */
function venueFieldsOf(existing: EventRecord | null, next: Venue | null | undefined): Partial<EventRecord> {
  if (next === undefined) return existing === null ? { venue: null, ...NO_VENUE_CONSENT } : {};
  if (existing !== null && JSON.stringify(existing.venue ?? null) === JSON.stringify(next)) return {};
  return { venue: next, ...NO_VENUE_CONSENT };
}

/** §7.2: what the spot's manager agreed to: the day and hours, the seats and the price. */
function venueMaterialChange(e: EventRecord, f: EventFields): string | null {
  if (!sameInstant(f.startAt, e.startAt)) return 'startAt';
  if (!sameInstant(f.endAt, e.endAt)) return 'endAt';
  if (f.capacity !== e.capacity) return 'capacity';
  if (f.price !== e.price) return 'price';
  return null;
}

function checkCoverAndFaq(deps: EventDeps, caller: EventCaller, f: EventFields, host: EventHost, createdBy: string, eventId: string): void {
  if (f.touched.has('coverUrl') || f.touched.has('coverPath')) {
    // Uploaded by the creator (staff or photographer) or by the host photographer.
    const uploaders = [createdBy, ...(host.type === 'photographer' && host.id !== null ? [host.id] : [])];
    const url = f.coverUrl;
    const path = f.coverPath;
    if (url !== null && path !== null && !uploaders.some((u) => deps.media.isOwnUpload(url, path, u, eventId))) {
      throw new DomainError('invalid_argument');
    }
  }
  // O2: the Q&A is staff-entered and only for platform-hosted events.
  if (f.touched.has('faq') && f.faq.length > 0) {
    if (caller.staffRole === null) throw new DomainError('permission_denied');
    if (host.type !== 'platform') throw new DomainError('invalid_argument');
  }
}

/**
 * Reads only (Decision 14). A tagged spot must exist, be active, and (once the event has a place)
 * cover it within the radius plus SPOT_EVENT_SLACK_M.
 */
async function checkSpot(tx: EventTx, f: EventFields): Promise<void> {
  if (f.spotId === null) return;
  const spot = await tx.getSpot(f.spotId);
  if (spot === null) throw new DomainError('not_found', 'spotId');
  if (spot.status !== 'active') throw new DomainError('spot_archived', 'spotId');
  if (f.location !== null && !spotCovers(spot, { lat: f.location.lat, lng: f.location.lng }, SPOT_EVENT_SLACK_M)) {
    throw new DomainError('invalid_argument', 'spotId');
  }
}

/** Whether a save must re-check the spot: the tag or the place moved (an old tag of a later archived spot stays). */
const spotNeedsCheck = (existing: EventRecord | null, f: EventFields): boolean =>
  f.spotId !== (existing?.spotId ?? null) || JSON.stringify(f.location) !== JSON.stringify(existing?.location ?? null);

function materialChange(e: EventRecord, f: EventFields): boolean {
  return f.title !== e.title || f.description !== e.description || f.type !== e.type
    || f.coverUrl !== e.coverUrl || !sameInstant(f.startAt, e.startAt) || !sameInstant(f.endAt, e.endAt)
    || JSON.stringify(f.location) !== JSON.stringify(e.location)
    || f.price !== e.price || f.capacity !== e.capacity;
}

const hashtagLocked = (e: EventRecord): boolean =>
  e.hashtagLocked || e.registeredCount + e.heldCount > 0 || e.postCount > 0;

interface HashtagPlan {
  readonly tag: string;
  readonly key: string;
  readonly oldKey: string | null; // set when the guard moves
}

/** Reads only. First save generates a unique tag; later saves may edit it until it locks. */
async function planHashtag(
  tx: EventTx,
  existing: EventRecord | null,
  f: EventFields,
  eventId: string,
  now: Date,
): Promise<HashtagPlan> {
  if (existing === null) {
    if (f.hashtag !== undefined) {
      const key = hashtagKeyOf(f.hashtag);
      if ((await tx.hashtagOwner(key)) !== null) throw new DomainError('conflict');
      return { tag: f.hashtag, key, oldKey: null };
    }
    const base = hashtagBase(f.title, f.startAt ?? now);
    for (let n = 1; n <= 100; n++) {
      const tag = hashtagWithSuffix(base, n);
      if ((await tx.hashtagOwner(hashtagKeyOf(tag))) === null) return { tag, key: hashtagKeyOf(tag), oldKey: null };
    }
    throw new DomainError('conflict');
  }
  if (f.hashtag === undefined || f.hashtag === existing.hashtag) {
    return { tag: existing.hashtag, key: existing.hashtagKey, oldKey: null };
  }
  if (hashtagLocked(existing)) throw new DomainError('conflict');
  const key = hashtagKeyOf(f.hashtag);
  if (key === existing.hashtagKey) return { tag: f.hashtag, key, oldKey: null };
  const owner = await tx.hashtagOwner(key);
  if (owner !== null && owner !== eventId) throw new DomainError('conflict');
  return { tag: f.hashtag, key, oldKey: existing.hashtagKey };
}

function writeHashtag(tx: EventTx, plan: HashtagPlan, eventId: string, isNew: boolean): void {
  if (plan.oldKey !== null) tx.deleteHashtag(plan.oldKey);
  if (isNew || plan.oldKey !== null) tx.putHashtag(plan.key, eventId);
}

// ---- entry events (S30, Decision 11) -------------------------------------------------------

const ENTRY_KEYS = ['spotId', 'startAt', 'endAt', 'closedWeekdays', 'closedDays', 'openHours', 'ticketTypes',
  'dailyCapacity', 'refundCutoffHours'] as const;

/** The stored entry fields with the request's entry keys on top (an entry save always validates the whole set). */
function mergedEntryRaw(existing: EventRecord | null, r: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = existing === null ? {} : { ...entryFieldsOf(existing) };
  for (const k of ENTRY_KEYS) if (r[k] !== undefined) out[k] = r[k];
  return out;
}

function textField(v: unknown, field: string, min: number, max: number): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument', field);
  const t = v.normalize('NFC').trim();
  const n = graphemeCount(t);
  if (n < min || n > max) throw new DomainError('invalid_argument', field);
  return t;
}

/** Reads only: the spot must exist, be active and be managed by the host organizer. */
async function entrySpot(tx: EventTx, spotId: string, organizerId: string | null): Promise<Spot> {
  const spot = await tx.getSpot(spotId);
  if (spot === null) throw new DomainError('not_found', 'spotId');
  if (spot.status !== 'active') throw new DomainError('spot_archived', 'spotId');
  if (organizerId === null || spot.managedBy !== organizerId) throw new DomainError('not_spot_manager');
  return spot;
}

/** Decision 11: an entry event's record fields; place and cover are the spot's, the one-day fields are empty. */
function entryRecordFields(f: EntryFields, spot: Spot, r: Record<string, unknown>, existing: EventRecord | null) {
  const { startAt, endAt } = entryRangeInstants(f);
  return {
    title: r.title === undefined ? (existing?.title ?? spot.name) : textField(r.title, 'title', 1, EVENT_TITLE_MAX),
    description: r.description === undefined ? (existing?.description ?? '') : textField(r.description, 'description', 0, EVENT_DESC_MAX),
    type: 'entry' as const,
    coverUrl: spot.cover?.url ?? null,
    coverPath: spot.cover?.path ?? null,
    startAt, endAt, dayKey: null,
    location: {
      name: spot.name, meetingPoint: null, lat: spot.point.lat, lng: spot.point.lng,
      geohash: encodeGeohash(spot.point.lat, spot.point.lng), areaId: isId(spot.areaCode) ? spot.areaCode : null,
    },
    capacity: null, price: null, registrationDeadline: null, faq: [],
    spotId: f.spotId, spotDecided: true,
    closedWeekdays: f.closedWeekdays, closedDays: f.closedDays, openHours: f.openHours, ticketTypes: f.ticketTypes,
    dailyCapacity: f.dailyCapacity, refundCutoffHours: f.refundCutoffHours,
  };
}

/** The request or the stored event is an entry event: only an entry save may touch it. */
function entryTypeGuard(existing: EventRecord | null, r: Record<string, unknown>): boolean {
  const entry = r.type === 'entry' || existing?.type === 'entry';
  if (!entry) return false;
  if (existing !== null && existing.type !== 'entry') throw new DomainError('invalid_argument', 'type');
  if (r.type !== undefined && r.type !== 'entry') throw new DomainError('invalid_argument', 'type');
  if (r.hostPhotographerId !== undefined && r.hostPhotographerId !== null) throw new DomainError('invalid_argument', 'type');
  return true;
}

/** An organizer's entry draft (Decision 11): host = the caller's organizer document, on a spot it manages. */
async function saveEntryDraft(
  deps: EventDeps,
  caller: EventCaller,
  tx: EventTx,
  r: Record<string, unknown>,
  eventId: string,
  existing: EventRecord | null,
  now: Date,
): Promise<{ eventId: string; hashtag: string }> {
  let host: EventHost;
  if (existing !== null) {
    if (!isEventManager(existing, caller)) throw new DomainError('permission_denied');
    if (existing.status !== 'draft') throw new DomainError('conflict');
    host = existing.host;
  } else {
    // Only an organizer hosts entry events (a photographer or staff cannot).
    const org = caller.staffRole === null ? await tx.getOrganizer(caller.uid) : null;
    if (org === null) throw new DomainError('invalid_argument', 'type');
    if (org.status !== 'active') throw new DomainError('permission_denied');
    host = { type: 'organizer', id: org.id, name: org.name, avatarUrl: org.avatarUrl, verified: org.businessVerified };
  }
  const f = validateEntryEvent(mergedEntryRaw(existing, r), formatVnDate(now), { newId: () => deps.ids.newId() });
  const spot = await entrySpot(tx, f.spotId, host.id);
  const fields = entryRecordFields(f, spot, r, existing);
  if (existing !== null) {
    tx.putEvent({ ...existing, ...fields, version: existing.version + 1, updatedAt: now });
  } else {
    tx.putEvent({
      id: eventId, host, createdBy: caller.uid, createdByRole: 'photographer',
      hostConsent: 'not_required', hostConsentExpiresAt: null,
      ...fields,
      hashtag: '', hashtagKey: '', hashtagLocked: true,
      status: 'draft', registeredCount: 0, heldCount: 0, chatId: null, postCount: 0, version: 1,
      publishedAt: null, completedAt: null, cancelledAt: null, createdAt: now, updatedAt: now,
    });
  }
  return { eventId, hashtag: '' };
}

/** Decision 3: publishing sells tickets, so the organizer must be able to sell (`business_required`). */
async function publishEntry(tx: EventTx, ev: EventRecord, now: Date): Promise<void> {
  const org = ev.host.id === null ? null : await tx.getOrganizer(ev.host.id);
  if (org === null || org.status !== 'active') throw new DomainError('permission_denied');
  if (!canSell(org)) throw new DomainError('business_required');
  const f = validateEntryEvent(mergedEntryRaw(ev, {}), formatVnDate(now));
  const spot = await entrySpot(tx, f.spotId, org.id);
  tx.putEvent({
    ...ev, ...entryRecordFields(f, spot, {}, ev),
    status: 'open', publishedAt: now, version: ev.version + 1, updatedAt: now,
  });
}

/** Where a day with tickets stops being an open day, the field that closed it. */
function closingField(f: EntryFields, day: string): string {
  if (day < f.startAt) return 'startAt';
  if (day > f.endAt) return 'endAt';
  return f.closedWeekdays.includes(weekdayOf(day)) ? 'closedWeekdays' : 'closedDays';
}

/**
 * Edits of a published entry event (S30.04): a sold ticket type can only be hidden, a day's capacity
 * never goes under its tickets, and a day with tickets stays open (closing one is `closeEntryDay`,
 * which refunds). The spot never changes. Prices paid stay on the registrations.
 */
async function updateEntry(deps: EventDeps, tx: EventTx, ev: EventRecord, r: Record<string, unknown>, now: Date): Promise<void> {
  const today = formatVnDate(now);
  const f = validateEntryEvent(mergedEntryRaw(ev, r), today, {
    newId: () => deps.ids.newId(),
    existingStartAt: entryFieldsOf(ev).startAt,
  });
  if (f.spotId !== ev.spotId) throw new DomainError('invalid_argument', 'spotId');
  const regs = await tx.activeRegistrations(ev.id);
  const spot = await entrySpot(tx, f.spotId, ev.host.id);

  const kept = new Set(f.ticketTypes.map((t) => t.id));
  if (regs.some((x) => (x.items ?? []).some((i) => !kept.has(i.ticketTypeId)))) {
    throw new DomainError('invalid_argument', 'ticketTypes');
  }
  const perDay = new Map<string, number>();
  for (const x of regs) {
    const d = x.visitDay ?? null;
    if (d !== null && d >= today) perDay.set(d, (perDay.get(d) ?? 0) + x.quantity);
  }
  const days = [...perDay].sort(([a], [b]) => (a < b ? -1 : 1));
  const cap = f.dailyCapacity;
  const over = cap === null ? [] : days.filter(([, n]) => n > cap);
  if (over.length > 0) {
    throw new DomainError('invalid_argument', 'dailyCapacity', { days: over.map(([day, sold]) => ({ day, sold })) });
  }
  const shut = days.filter(([d]) => !isOpenDay(f, d));
  const firstShut = shut[0];
  if (firstShut !== undefined) {
    throw new DomainError('invalid_argument', closingField(f, firstShut[0]), { days: shut.map(([day, sold]) => ({ day, sold })) });
  }
  tx.putEvent({ ...ev, ...entryRecordFields(f, spot, r, ev), version: ev.version + 1, updatedAt: now });
}

export async function saveEventDraft(
  deps: EventDeps & { readonly notify?: NotifyDeps },
  caller: EventCaller,
  raw: unknown,
): Promise<{ eventId: string; hashtag: string }> {
  const r = obj(raw);
  const eventId = r.eventId === undefined ? deps.ids.newId() : idOf(r.eventId);
  let request: VenueRequest | null = null;
  const out = await deps.events.runTransaction(async (tx) => {
    request = null;
    const now = deps.clock.now();
    const existing = await tx.getEvent(eventId);
    // A client-chosen id must be unguessable (ULID-like), so nobody can squat a predictable one.
    if (existing === null && r.eventId !== undefined && !CLIENT_EVENT_ID.test(eventId)) {
      throw new DomainError('invalid_argument');
    }
    if (entryTypeGuard(existing, r)) return saveEntryDraft(deps, caller, tx, r, eventId, existing, now);
    if (existing !== null) {
      if (!isEventManager(existing, caller)) throw new DomainError('permission_denied');
      if (existing.status !== 'draft') throw new DomainError('conflict');
      if (r.hostPhotographerId !== undefined && r.hostPhotographerId !== existing.host.id) {
        throw new DomainError('invalid_argument');
      }
    }
    const created = existing === null ? await resolveHost(deps, tx, caller, r.hostPhotographerId, r.hostAs) : null;
    const f = validateEventFields(raw, 'draft', now, existing);
    const host = existing?.host ?? (created as NonNullable<typeof created>).host;
    checkCoverAndFaq(deps, caller, f, host, existing?.createdBy ?? caller.uid, eventId);
    const plan = await planHashtag(tx, existing, f, eventId, now);
    if (spotNeedsCheck(existing, f)) await checkSpot(tx, f);
    // S30 Decision 16: the venue is saved as sent (checked whole); a new venue starts over, and a
    // material edit of a draft its spot's manager accepted asks the manager again (72 h).
    const venueIn = await readVenue(tx, r.venue, now);
    const venue = venueFieldsOf(existing, venueIn?.venue);
    const askAgain = existing !== null && venue.venue === undefined && venueConsentOf(existing) === 'accepted'
      && venueMaterialChange(existing, f) !== null;
    const askSpot = askAgain && existing?.venue?.spotId != null ? await tx.getSpot(existing.venue.spotId) : null;

    const base = {
      title: f.title, description: f.description, type: f.type,
      coverUrl: f.coverUrl, coverPath: f.coverPath,
      startAt: f.startAt, endAt: f.endAt, dayKey: f.dayKey,
      location: f.location, capacity: f.capacity, price: f.price,
      registrationDeadline: f.registrationDeadline, faq: f.faq, spotId: f.spotId,
      spotDecided: f.touched.has('spotId') || (existing?.spotDecided ?? false),
      hashtag: plan.tag, hashtagKey: plan.key, updatedAt: now,
    };
    writeHashtag(tx, plan, eventId, existing === null);
    if (existing !== null) {
      // O1: material edits by staff to a draft the photographer already accepted need a new answer.
      const reset = caller.staffRole !== null && existing.hostConsent === 'accepted' && materialChange(existing, f);
      const next: EventRecord = {
        ...existing, ...base, ...venue,
        ...(reset
          ? { hostConsent: 'pending' as const, hostConsentExpiresAt: new Date(now.getTime() + HOST_CONSENT_HOURS * HOUR_MS) }
          : {}),
        ...(askSpot?.managedBy != null ? venueConsentRequest(now) : {}),
        version: existing.version + 1,
      };
      tx.putEvent(next);
      if (askSpot?.managedBy != null) request = { managerId: askSpot.managedBy, event: next, spot: askSpot.name };
    } else {
      const c = created as NonNullable<typeof created>;
      tx.putEvent({
        id: eventId,
        host: c.host,
        createdBy: caller.uid,
        createdByRole: c.createdByRole,
        hostConsent: c.consent ? 'pending' : 'not_required',
        hostConsentExpiresAt: c.consent ? new Date(now.getTime() + HOST_CONSENT_HOURS * HOUR_MS) : null,
        ...base,
        ...venue,
        hashtagLocked: false,
        status: 'draft',
        registeredCount: 0,
        heldCount: 0,
        chatId: null,
        postCount: 0,
        version: 1,
        publishedAt: null,
        completedAt: null,
        cancelledAt: null,
        createdAt: now,
      });
    }
    return { eventId, hashtag: plan.tag };
  });
  await tellVenueRequested(deps.notify, request);
  return out;
}

/**
 * Reads only (S30 Decision 16): the venue gate of a publish. No venue: refused (`invalid_argument`
 * venue) for events created on or after VENUE_REQUIRED_FROM. A managed spot whose manager is not the
 * host: published only once that manager `accepted` (and is still the manager); while `pending`,
 * `venue_consent_required`; otherwise the request to ask (the publish then keeps the draft).
 */
async function venueGate(tx: EventTx, ev: EventRecord): Promise<{ managerId: string; spot: string } | null> {
  const v = ev.venue ?? null;
  if (v === null) {
    if (venueRequired(ev)) throw new DomainError('invalid_argument', 'venue');
    return null;
  }
  const spot = await venueSpot(tx, v);
  const managedBy = spot?.managedBy ?? null;
  if (spot === null || managedBy === null || !venueConsentNeeded(v, ev.host.id, managedBy)) return null;
  const consent = venueConsentOf(ev);
  if (consent === 'pending') throw new DomainError('venue_consent_required');
  if (consent === 'accepted' && ev.venueManagerId === managedBy) return null;
  return { managerId: managedBy, spot: spot.name };
}

export async function publishEvent(deps: EventDeps & { readonly notify?: NotifyDeps }, caller: EventCaller, raw: unknown): Promise<void> {
  const eventId = idOf(obj(raw).eventId);
  let request: VenueRequest | null = null;
  await deps.events.runTransaction(async (tx) => {
    request = null;
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status !== 'draft') throw new DomainError('conflict');
    // O1: an event staff created for a photographer needs that photographer's acceptance first.
    if (ev.hostConsent !== 'not_required' && ev.hostConsent !== 'accepted') throw new DomainError('not_eligible');
    // Entry events: no group chat and no host availability (Decision 11).
    if (ev.type === 'entry') return publishEntry(tx, ev, now);
    const f = validateEventFields({}, 'publish', now, ev);
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const dayKey = f.dayKey as string;
    const av = hostId === null ? null : await tx.availability(hostId, dayKey);
    if (av !== null && (av.state === 'booked' || av.state === 'pending' || av.state === 'spot')) throw new DomainError('day_taken');
    await checkSpot(tx, f);
    await checkOrganizerHost(tx, ev.host, ev.price);
    const ask = await venueGate(tx, ev);
    if (ask !== null) {
      // §7.2: the spot's manager is asked; the event stays a draft until they accept.
      const next: EventRecord = { ...ev, ...venueConsentRequest(now), venueFeePerGuest: 0, venueManagerId: null, version: ev.version + 1, updatedAt: now };
      tx.putEvent(next);
      request = { managerId: ask.managerId, event: next, spot: ask.spot };
      return;
    }

    const chatId = `event_${ev.id}`;
    // The host (photographer or organizer) moderates the group chat; only a photographer's day is booked.
    const memberHost = ev.host.type === 'platform' ? null : ev.host.id;
    const moderators = [...new Set([memberHost, ev.createdBy].filter((x): x is string => x !== null))];
    const creator = ev.createdBy === memberHost ? null : await deps.people.user(ev.createdBy);
    const memberProfiles = moderators.map((uid) => uid === memberHost
      ? { uid, name: ev.host.name ?? 'Ban tổ chức', avatarUrl: ev.host.avatarUrl }
      : { uid, name: creator?.name ?? 'Ban tổ chức', avatarUrl: creator?.avatarUrl ?? null });
    const chat: EventGroupChatSeed = {
      id: chatId, kind: 'event_group', eventId: ev.id, title: ev.title,
      members: moderators, moderators, memberProfiles, memberCount: moderators.length, moderatorsOnly: false,
      lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null,
      createdAt: now, updatedAt: now,
    };
    if (hostId !== null) tx.setAvailabilityBooked(hostId, dayKey, ev.id);
    tx.putGroupChat(chat);
    tx.putEvent({
      ...ev,
      registrationDeadline: f.registrationDeadline,
      dayKey,
      status: 'open',
      chatId,
      publishedAt: now,
      version: ev.version + 1,
      updatedAt: now,
    });
  });
  await tellVenueRequested(deps.notify, request);
}

export async function updateEvent(deps: EventDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status === 'draft') throw new DomainError('conflict');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    if (entryTypeGuard(ev, r)) return updateEntry(deps, tx, ev, r, now);
    const f = validateEventFields(raw, 'publish', now, ev);
    checkCoverAndFaq(deps, caller, f, ev.host, ev.createdBy, ev.id);

    const sold = ev.registeredCount + ev.heldCount;
    const scheduleChanged = !sameInstant(f.startAt, ev.startAt) || !sameInstant(f.endAt, ev.endAt)
      || !sameInstant(f.registrationDeadline, ev.registrationDeadline);
    if (scheduleChanged && sold > 0) throw new DomainError('conflict');
    if (f.capacity !== null && f.capacity < sold) throw new DomainError('conflict');
    if (f.price !== ev.price && sold > 0) throw new DomainError('conflict');

    if (f.price !== ev.price) await checkOrganizerHost(tx, ev.host, f.price);
    // S30 Decision 16: what a spot's manager agreed to stays (a published event cannot ask again).
    const venueIn = await readVenue(tx, r.venue, now);
    const venue = venueFieldsOf(ev, venueIn?.venue);
    if (venue.venue === null && venueRequired(ev)) throw new DomainError('invalid_argument', 'venue');
    const asked = venueConsentOf(ev) === 'accepted';
    const moved = asked ? venueMaterialChange(ev, f) : null;
    if (moved !== null) throw new DomainError('venue_consent_required', moved);
    if (venue.venue !== undefined && venue.venue !== null) {
      const managedBy = venueIn?.spot?.managedBy ?? null;
      if (venueConsentNeeded(venue.venue, ev.host.id, managedBy)) throw new DomainError('venue_consent_required', 'venue');
    }
    const plan = await planHashtag(tx, ev, f, ev.id, now);
    if (spotNeedsCheck(ev, f)) await checkSpot(tx, f);
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const moveDay = hostId !== null && f.dayKey !== ev.dayKey;
    const newDay = moveDay ? await tx.availability(hostId, f.dayKey as string) : null;
    const oldDay = moveDay && ev.dayKey !== null ? await tx.availability(hostId, ev.dayKey) : null;
    if (newDay !== null && (newDay.state === 'booked' || newDay.state === 'pending' || newDay.state === 'spot')) {
      throw new DomainError('day_taken');
    }

    writeHashtag(tx, plan, ev.id, false);
    if (moveDay) {
      if (oldDay !== null && oldDay.eventId === ev.id && ev.dayKey !== null) tx.deleteAvailability(hostId, ev.dayKey);
      tx.setAvailabilityBooked(hostId, f.dayKey as string, ev.id);
    }
    const next: EventRecord = {
      ...ev,
      title: f.title, description: f.description, type: f.type,
      coverUrl: f.coverUrl, coverPath: f.coverPath,
      startAt: f.startAt, endAt: f.endAt, dayKey: f.dayKey,
      location: f.location, capacity: f.capacity, price: f.price,
      registrationDeadline: f.registrationDeadline, faq: f.faq, spotId: f.spotId,
      spotDecided: f.touched.has('spotId') || (ev.spotDecided ?? false),
      hashtag: plan.tag, hashtagKey: plan.key,
      ...venue,
      version: ev.version + 1, updatedAt: now,
    };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now) });
  });
}

export async function cancelEvent(
  deps: EventDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ paidRegistrationIds: string[] }> {
  const eventId = idOf(obj(raw).eventId);
  return deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    if (ev.endAt !== null && now.getTime() >= ev.endAt.getTime()) throw new DomainError('not_eligible');
    const regs = await tx.activeRegistrations(ev.id);
    // S30 (spec §4.1 "mọi vé chưa dùng"): an entry event refunds only unused tickets, those of today or
    // later never checked in; past or used tickets keep their money and their release.
    const today = formatVnDate(now);
    const unused = (x: RegistrationDoc): boolean => ev.type !== 'entry'
      || ((x.visitDay ?? '') >= today && x.checkedInAt === null && (x.gateCheckedInAt ?? null) === null);
    // Task 9: every ticket whose money is still held is refunded after this transaction, including
    // tickets cancelled late without a refund (O4): the host does not keep money for a cancelled event.
    const heldMoney = await tx.heldTicketPayments(ev.id);
    const activeIds = new Set(regs.map((x) => x.id));
    const lateIds = [...new Set(heldMoney.map((p) => p.subjectId))].filter((id) => !activeIds.has(id));
    const late = (await Promise.all(lateIds.map((id) => tx.getRegistration(ev.id, id))))
      .filter((x): x is RegistrationDoc => x !== null && x.status === 'cancelled' && unused(x));
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const day = hostId !== null && ev.dayKey !== null && ev.status !== 'draft'
      ? await tx.availability(hostId, ev.dayKey)
      : null;

    // Paid tickets stay `paid` (and counted) with `refundDue` until their refund lands in its own
    // transaction, so a crash midway never loses track of them (the event clock retries).
    const paid = regs.filter((x) => x.status === 'paid' && x.amount > 0 && unused(x));
    const kept = regs.filter((x) => x.status === 'paid' && x.amount > 0 && !unused(x));
    const rest = regs.filter((x) => !paid.includes(x) && !kept.includes(x));
    const days = await readEntryDays(tx, ev, rest);
    let registered = ev.registeredCount;
    let held = ev.heldCount;
    for (const x of rest) {
      tx.putRegistration({ ...x, status: 'cancelled', cancelledAt: now, updatedAt: now, version: x.version + 1 });
      if (x.status === 'paid') registered -= x.quantity;
      else held -= x.quantity;
    }
    writeEntryDays(tx, ev.id, days, releaseDeltas(ev, rest), now);
    for (const x of [...paid, ...late]) {
      tx.putRegistration({ ...x, refundDue: true, updatedAt: now, version: x.version + 1 });
    }
    if (hostId !== null && ev.dayKey !== null && day !== null && day.eventId === ev.id) {
      tx.deleteAvailability(hostId, ev.dayKey);
    }
    if (ev.status === 'draft' && ev.hashtagKey !== '') tx.deleteHashtag(ev.hashtagKey);
    // M5: the group chat of a cancelled event closes like a completed one, 7 days later.
    if (ev.chatId !== null) tx.setChatReadOnlyAt(ev.chatId, new Date(now.getTime() + GROUP_READONLY_DAYS * 86_400_000));
    tx.putEvent({
      ...ev,
      status: 'cancelled',
      registeredCount: registered,
      heldCount: held,
      cancelledAt: now,
      version: ev.version + 1,
      updatedAt: now,
    });
    return { paidRegistrationIds: [...paid, ...late].map((x) => x.id) };
  });
}

/** O1: staff-created event for a photographer: the photographer accepts or declines within 24 h. */
export async function respondToHostConsent(deps: EventDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  if (typeof r.accept !== 'boolean') throw new DomainError('invalid_argument');
  const accept = r.accept;
  const expired = await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (ev.host.type !== 'photographer' || ev.host.id !== caller.uid) throw new DomainError('permission_denied');
    if (ev.status !== 'draft' || ev.hostConsent !== 'pending') throw new DomainError('conflict');
    if (ev.hostConsentExpiresAt !== null && now.getTime() >= ev.hostConsentExpiresAt.getTime()) {
      expireHostConsent(tx, ev, now);
      return true;
    }
    if (accept) {
      tx.putEvent({ ...ev, hostConsent: 'accepted', version: ev.version + 1, updatedAt: now });
    } else {
      tx.deleteHashtag(ev.hashtagKey);
      tx.putEvent({
        ...ev, hostConsent: 'declined', status: 'cancelled', cancelledAt: now,
        version: ev.version + 1, updatedAt: now,
      });
    }
    return false;
  });
  if (expired) throw new DomainError('deadline_passed');
}

/** Writes only: the 24 h passed, so the draft is cancelled and its hashtag is free again. */
export function expireHostConsent(tx: EventTx, ev: EventRecord, now: Date): void {
  tx.deleteHashtag(ev.hashtagKey);
  tx.putEvent({
    ...ev, hostConsent: 'expired', status: 'cancelled', cancelledAt: now,
    version: ev.version + 1, updatedAt: now,
  });
}
