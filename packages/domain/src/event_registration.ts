import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import {
  CHECKIN_GRACE_HOURS,
  FREE_CANCEL_HOURS,
  TICKETS_PER_REGISTRATION,
  isEventManager,
  statusAfterSeats,
  type EventCaller,
  type EventRecord,
  type RegistrationContact,
  type RegistrationDoc,
  type RegistrationStatus,
} from './event.js';
import { parseVnDateTime } from './booking_policy.js';
import type { EventDeps } from './event_ports.js';
import { RetryableConflict } from './event_ports.js';
import { isId } from './ids.js';
import type { UserContactRecord } from './ports.js';
import { requireCustomerPhone } from './require_phone.js';
import { isTicketCode, ticketCodeCandidates } from './ticket_code.js';

const HOUR_MS = 3_600_000;
const NAME_MAX = 60;

export interface RegisterResult {
  readonly registrationId: string;
  readonly status: RegistrationStatus;
  readonly paymentId: string | null;
  readonly payUrl: string | null;
  readonly holdExpiresAt: Date | null;
}

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

const resultOf = (r: RegistrationDoc): RegisterResult => ({
  registrationId: r.id,
  status: r.status,
  paymentId: r.paymentId,
  payUrl: null,
  holdExpiresAt: r.holdExpiresAt,
});

/**
 * Refund share when an attendee cancels a PAID ticket (spec §3g, O4): 100% at least 48 h before the
 * start, nothing after (cancelling is still allowed then; the money stays held for the host).
 */
export function cancellationRefundPercent(startAt: Date, now: Date): 0 | 100 {
  return startAt.getTime() - now.getTime() >= FREE_CANCEL_HOURS * HOUR_MS ? 100 : 0;
}

/**
 * The private contact snapshot of a ticket that unlocks contact (a paid ticket after payment, O3).
 * Task 9 writes it when the payment lands; free registrations never get one.
 */
export function registrationContactOf(name: string, phone: string, record: UserContactRecord | null): RegistrationContact {
  const r = (record ?? {}) as { allowZalo?: unknown; allowWhatsApp?: unknown };
  return { name, phone, allowZalo: r.allowZalo === true, allowWhatsApp: r.allowWhatsApp === true };
}

export async function registerEvent(deps: EventDeps, caller: EventCaller, raw: unknown): Promise<RegisterResult> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const q = r.quantity;
  if (typeof q !== 'number' || !Number.isInteger(q) || q < 1) throw new DomainError('invalid_argument');
  if (q > TICKETS_PER_REGISTRATION) throw new DomainError('limit_exceeded');
  if (typeof r.name !== 'string') throw new DomainError('invalid_argument');
  const name = r.name.normalize('NFC').trim();
  const n = graphemeCount(name);
  if (n < 1 || n > NAME_MAX) throw new DomainError('invalid_argument');
  const profile = await deps.people.user(caller.uid);

  const out = await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (!ev || ev.status === 'draft') throw new DomainError('not_found');
    if (isEventManager(ev, caller)) throw new DomainError('permission_denied');
    // §3b.1: every registration needs a phone, free ones too. Enforced here, not only in the UI.
    await requireCustomerPhone(deps.contacts, caller.uid);
    if (ev.status === 'cancelled' || ev.status === 'completed' || ev.status === 'closed'
      || ev.registrationDeadline === null || now.getTime() >= ev.registrationDeadline.getTime()) {
      throw new DomainError('deadline_passed');
    }
    const active = await tx.activeRegistrationOf(ev.id, caller.uid);
    if (active) return { result: resultOf(active), soldOut: false };
    if ((ev.price ?? 0) > 0) throw new DomainError('not_eligible'); // Decision 27; Task 9 replaces this
    const stale = await tx.expiredHolds(ev.id, now);
    const codes = ticketCodeCandidates(ev.startAt as Date, deps.random, 5);
    const taken = await Promise.all(codes.map((c) => tx.ticketCodeTaken(c)));
    const code = codes.find((_, i) => !taken[i]);
    if (code === undefined) throw new RetryableConflict();

    // ---- writes from here ----
    let held = ev.heldCount;
    for (const s of stale) {
      tx.putRegistration({ ...s, status: 'cancelled', cancelledAt: now, updatedAt: now, version: s.version + 1 });
      held -= s.quantity;
    }
    if ((ev.capacity as number) - ev.registeredCount - held < q) {
      if (stale.length > 0) {
        const released = { ...ev, heldCount: held };
        tx.putEvent({ ...released, status: statusAfterSeats(released, now), version: ev.version + 1, updatedAt: now });
      }
      return { result: null, soldOut: true }; // a throw would abort the release above
    }
    const regId = deps.ids.newId();
    const start = ev.startAt as Date;
    const loc = ev.location as NonNullable<EventRecord['location']>;
    const reg: RegistrationDoc = {
      id: regId, eventId: ev.id, userId: caller.uid, userName: name,
      userAvatarUrl: profile?.avatarUrl ?? null,
      quantity: q, amount: 0, status: 'paid', holdExpiresAt: null,
      ticketCode: code, paymentId: null,
      contactEligible: false, // O3: a free ticket opens the group chat only, never phone/Zalo/WhatsApp
      checkedInAt: null, cancelledAt: null, refundPercent: null,
      event: {
        title: ev.title, type: ev.type, startAt: start, endAt: ev.endAt as Date,
        locationName: loc.name, lat: loc.lat, lng: loc.lng, coverUrl: ev.coverUrl,
      },
      version: 1, createdAt: now, updatedAt: now,
    };
    tx.putTicketCode(code, ev.id, regId);
    tx.putRegistration(reg);
    const next = { ...ev, heldCount: held, registeredCount: ev.registeredCount + q, hashtagLocked: true };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return { result: resultOf(reg), soldOut: false };
  });
  if (out.soldOut || out.result === null) throw new DomainError('sold_out');
  return out.result;
}

export async function cancelRegistration(
  deps: EventDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ status: RegistrationStatus; refundPercent: number | null }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const regId = idOf(r.registrationId);
  return deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const reg = await tx.getRegistration(eventId, regId);
    if (reg === null) throw new DomainError('not_found');
    if (reg.userId !== caller.uid) throw new DomainError('permission_denied');
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (reg.status === 'cancelled' || reg.status === 'refunded') {
      return { status: reg.status, refundPercent: reg.refundPercent };
    }
    if (reg.checkedInAt !== null) throw new DomainError('conflict');
    if (ev.startAt === null || now.getTime() >= ev.startAt.getTime()) throw new DomainError('not_eligible');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    // A paid ticket's refund or no-refund cancel (O4, `cancellationRefundPercent`) lands with Task 9.
    if (reg.amount > 0) throw new DomainError('not_eligible');

    tx.putRegistration({ ...reg, status: 'cancelled', cancelledAt: now, updatedAt: now, version: reg.version + 1 });
    const next = reg.status === 'held'
      ? { ...ev, heldCount: ev.heldCount - reg.quantity }
      : { ...ev, registeredCount: ev.registeredCount - reg.quantity };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return { status: 'cancelled' as const, refundPercent: null };
  });
}

export async function checkInRegistration(
  deps: EventDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ name: string; quantity: number }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  if (typeof r.ticketCode !== 'string') throw new DomainError('invalid_argument');
  const code = r.ticketCode.trim().toUpperCase();
  return deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null || ev.status === 'draft') throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if (ev.status === 'cancelled') throw new DomainError('not_eligible');
    if (ev.dayKey === null || ev.endAt === null) throw new DomainError('not_found');
    const opens = parseVnDateTime(ev.dayKey, '00:00').getTime();
    const closes = ev.endAt.getTime() + CHECKIN_GRACE_HOURS * HOUR_MS;
    if (now.getTime() < opens || now.getTime() > closes) throw new DomainError('not_eligible');
    if (!isTicketCode(code)) throw new DomainError('not_found');
    const found = await tx.findTicket(code);
    if (found === null || found.eventId !== ev.id) throw new DomainError('not_found');
    const reg = await tx.getRegistration(ev.id, found.registrationId);
    if (reg === null || reg.status !== 'paid') throw new DomainError('not_found');
    if (reg.checkedInAt !== null) throw new DomainError('conflict');
    tx.putRegistration({ ...reg, checkedInAt: now, updatedAt: now, version: reg.version + 1 });
    return { name: reg.userName, quantity: reg.quantity };
  });
}
