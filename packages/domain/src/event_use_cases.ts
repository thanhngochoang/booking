import {
  HOST_CONSENT_HOURS,
  isEventManager,
  sameInstant,
  statusAfterSeats,
  validateEventFields,
  type EventCaller,
  type EventFields,
  type EventHost,
  type EventRecord,
} from './event.js';
import { DomainError } from './errors.js';
import { hashtagBase, hashtagKeyOf, hashtagWithSuffix } from './event_hashtag.js';
import type { EventDeps, EventGroupChatSeed, EventTx } from './event_ports.js';
import { isId } from './ids.js';

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

/** Event state is only ever written by the server, so the host fields are looked up, never trusted. */
async function resolveHost(
  deps: EventDeps,
  caller: EventCaller,
  hostPhotographerId: unknown,
): Promise<{ host: EventHost; createdByRole: EventRecord['createdByRole']; consent: boolean }> {
  const requested = hostPhotographerId === undefined || hostPhotographerId === null ? null : idOf(hostPhotographerId);
  if (caller.staffRole !== null) {
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
  const p = await deps.people.photographer(caller.uid);
  if (p === null || !p.onboardingComplete) throw new DomainError('permission_denied');
  return {
    host: { type: 'photographer', id: caller.uid, name: p.name, avatarUrl: p.avatarUrl, verified: p.verified },
    createdByRole: 'photographer',
    consent: false,
  };
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

export async function saveEventDraft(
  deps: EventDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ eventId: string; hashtag: string }> {
  const r = obj(raw);
  const eventId = r.eventId === undefined ? deps.ids.newId() : idOf(r.eventId);
  return deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const existing = await tx.getEvent(eventId);
    // A client-chosen id must be unguessable (ULID-like), so nobody can squat a predictable one.
    if (existing === null && r.eventId !== undefined && !CLIENT_EVENT_ID.test(eventId)) {
      throw new DomainError('invalid_argument');
    }
    if (existing !== null) {
      if (!isEventManager(existing, caller)) throw new DomainError('permission_denied');
      if (existing.status !== 'draft') throw new DomainError('conflict');
      if (r.hostPhotographerId !== undefined && r.hostPhotographerId !== existing.host.id) {
        throw new DomainError('invalid_argument');
      }
    }
    const created = existing === null ? await resolveHost(deps, caller, r.hostPhotographerId) : null;
    const f = validateEventFields(raw, 'draft', now, existing);
    const host = existing?.host ?? (created as NonNullable<typeof created>).host;
    checkCoverAndFaq(deps, caller, f, host, existing?.createdBy ?? caller.uid, eventId);
    const plan = await planHashtag(tx, existing, f, eventId, now);

    const base = {
      title: f.title, description: f.description, type: f.type,
      coverUrl: f.coverUrl, coverPath: f.coverPath,
      startAt: f.startAt, endAt: f.endAt, dayKey: f.dayKey,
      location: f.location, capacity: f.capacity, price: f.price,
      registrationDeadline: f.registrationDeadline, faq: f.faq,
      hashtag: plan.tag, hashtagKey: plan.key, updatedAt: now,
    };
    writeHashtag(tx, plan, eventId, existing === null);
    if (existing !== null) {
      // O1: material edits by staff to a draft the photographer already accepted need a new answer.
      const reset = caller.staffRole !== null && existing.hostConsent === 'accepted' && materialChange(existing, f);
      tx.putEvent({
        ...existing, ...base,
        ...(reset
          ? { hostConsent: 'pending' as const, hostConsentExpiresAt: new Date(now.getTime() + HOST_CONSENT_HOURS * HOUR_MS) }
          : {}),
        version: existing.version + 1,
      });
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
}

export async function publishEvent(deps: EventDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const eventId = idOf(obj(raw).eventId);
  await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status !== 'draft') throw new DomainError('conflict');
    // O1: an event staff created for a photographer needs that photographer's acceptance first.
    if (ev.hostConsent !== 'not_required' && ev.hostConsent !== 'accepted') throw new DomainError('not_eligible');
    const f = validateEventFields({}, 'publish', now, ev);
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const dayKey = f.dayKey as string;
    const av = hostId === null ? null : await tx.availability(hostId, dayKey);
    if (av !== null && (av.state === 'booked' || av.state === 'pending')) throw new DomainError('day_taken');

    const chatId = `event_${ev.id}`;
    const moderators = [...new Set([hostId, ev.createdBy].filter((x): x is string => x !== null))];
    const chat: EventGroupChatSeed = {
      id: chatId, kind: 'event_group', eventId: ev.id, title: ev.title,
      members: moderators, moderators, memberCount: moderators.length, moderatorsOnly: false,
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
}

export async function updateEvent(deps: EventDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const eventId = idOf(obj(raw).eventId);
  await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status === 'draft') throw new DomainError('conflict');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    const f = validateEventFields(raw, 'publish', now, ev);
    checkCoverAndFaq(deps, caller, f, ev.host, ev.createdBy, ev.id);

    const sold = ev.registeredCount + ev.heldCount;
    const scheduleChanged = !sameInstant(f.startAt, ev.startAt) || !sameInstant(f.endAt, ev.endAt)
      || !sameInstant(f.registrationDeadline, ev.registrationDeadline);
    if (scheduleChanged && sold > 0) throw new DomainError('conflict');
    if (f.capacity !== null && f.capacity < sold) throw new DomainError('conflict');
    if (f.price !== ev.price && sold > 0) throw new DomainError('conflict');

    const plan = await planHashtag(tx, ev, f, ev.id, now);
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const moveDay = hostId !== null && f.dayKey !== ev.dayKey;
    const newDay = moveDay ? await tx.availability(hostId, f.dayKey as string) : null;
    const oldDay = moveDay && ev.dayKey !== null ? await tx.availability(hostId, ev.dayKey) : null;
    if (newDay !== null && (newDay.state === 'booked' || newDay.state === 'pending')) {
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
      registrationDeadline: f.registrationDeadline, faq: f.faq,
      hashtag: plan.tag, hashtagKey: plan.key,
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
    const hostId = ev.host.type === 'photographer' ? ev.host.id : null;
    const day = hostId !== null && ev.dayKey !== null && ev.status !== 'draft'
      ? await tx.availability(hostId, ev.dayKey)
      : null;

    // Tickets that were paid for are refunded by Task 9 in their own transactions; they stay `paid`
    // (and counted) until that refund lands, so a crash midway never loses track of them.
    const paid = regs.filter((x) => x.status === 'paid' && x.amount > 0);
    const rest = regs.filter((x) => !(x.status === 'paid' && x.amount > 0));
    let registered = ev.registeredCount;
    let held = ev.heldCount;
    for (const x of rest) {
      tx.putRegistration({ ...x, status: 'cancelled', cancelledAt: now, updatedAt: now, version: x.version + 1 });
      if (x.status === 'paid') registered -= x.quantity;
      else held -= x.quantity;
    }
    if (hostId !== null && ev.dayKey !== null && day !== null && day.eventId === ev.id) {
      tx.deleteAvailability(hostId, ev.dayKey);
    }
    if (ev.status === 'draft') tx.deleteHashtag(ev.hashtagKey);
    tx.putEvent({
      ...ev,
      status: 'cancelled',
      registeredCount: registered,
      heldCount: held,
      cancelledAt: now,
      version: ev.version + 1,
      updatedAt: now,
    });
    return { paidRegistrationIds: paid.map((x) => x.id) };
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
