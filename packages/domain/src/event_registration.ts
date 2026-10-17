import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import type { PaymentGateway } from './booking_ports.js';
import { isPaymentMethod, type Payment, type PaymentMethod } from './escrow.js';
import {
  CHECKIN_GRACE_HOURS,
  HOLD_MINUTES,
  TICKETS_PER_REGISTRATION,
  isEventManager,
  statusAfterSeats,
  type EventCaller,
  type EventRecord,
  type RegistrationDoc,
  type RegistrationStatus,
} from './event.js';
import { parseVnDateTime } from './booking_policy.js';
import type { EventDeps } from './event_ports.js';
import { RetryableConflict } from './event_ports.js';
import { isId } from './ids.js';
import {
  newTicketPayment,
  refundTicket,
  ticketIdempotencyKey,
  ticketRefundPercent,
} from './event_payments.js';
import { requireCustomerPhone } from './require_phone.js';
import { isTicketCode, ticketCodeCandidates } from './ticket_code.js';
import type { PaymentInstructions } from './payment_ports.js';
import type { PaymentLookup } from './payment_settlement.js';
import { freshPaymentId, instructionsOf, issuePaymentInstructions } from './create_payment.js';
import { MemoryPaymentLookup, type PaymentSource } from './memory_payment_lookup.js';

import type { AccountCipher } from './payout_ports.js';

const HOUR_MS = 3_600_000;
const NAME_MAX = 60;

export interface RegisterResult {
  readonly registrationId: string;
  readonly status: RegistrationStatus;
  readonly paymentId: string | null;
  readonly instructions: PaymentInstructions | null;
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

function parseMethod(v: unknown): PaymentMethod | null {
  if (v === undefined || v === null) return null;
  if (!isPaymentMethod(v)) throw new DomainError('invalid_argument');
  return v;
}

const resultOf = (r: RegistrationDoc): RegisterResult => ({
  registrationId: r.id,
  status: r.status,
  paymentId: r.paymentId,
  instructions: null,
  holdExpiresAt: r.holdExpiresAt,
});

/**
 * Refund share when an attendee cancels a PAID ticket (spec §3g, O4): 100% at least 48 h before the
 * start, nothing after (cancelling is still allowed then; the money stays held for the host).
 */
export function cancellationRefundPercent(startAt: Date, now: Date): 0 | 100 {
  return ticketRefundPercent(startAt, now);
}

/** Register needs the payment gateway only for paid events (Decision 27 → Task 9). */
export type RegisterDeps = EventDeps & {
  readonly gateway?: PaymentGateway;
  readonly payments?: PaymentLookup;
  readonly cipher?: AccountCipher;
};

type RegisterOut = { result: RegisterResult | null; soldOut: boolean; intent: Payment | null };

export async function registerEvent(deps: RegisterDeps, caller: EventCaller, raw: unknown): Promise<RegisterResult> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const q = r.quantity;
  if (typeof q !== 'number' || !Number.isInteger(q) || q < 1) throw new DomainError('invalid_argument');
  if (q > TICKETS_PER_REGISTRATION) throw new DomainError('limit_exceeded');
  if (typeof r.name !== 'string') throw new DomainError('invalid_argument');
  const name = r.name.normalize('NFC').trim();
  const n = graphemeCount(name);
  if (n < 1 || n > NAME_MAX) throw new DomainError('invalid_argument');
  if ('provider' in r) throw new DomainError('invalid_argument');
  const method = parseMethod(r.method);
  const profile = await deps.people.user(caller.uid);

  // When method is present and payments lookup exists, draw a fresh payment id before transaction (Decision 5).
  const preDrawnPaymentId = method !== null && deps.payments !== undefined
    ? await freshPaymentId(deps.payments, deps.ids)
    : deps.ids.newId();

  const out = await deps.events.runTransaction(async (tx): Promise<RegisterOut> => {
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
    const paidEvent = (ev.price ?? 0) > 0;
    if (paidEvent && deps.gateway === undefined) throw new DomainError('not_eligible');
    const active = await tx.activeRegistrationOf(ev.id, caller.uid);
    const stale = await tx.expiredHolds(ev.id, now);
    // A lapsed hold is not "the active registration": a new tap starts a new hold (Task 1 carry).
    const live = active !== null && !stale.some((s) => s.id === active.id) ? active : null;
    if (live !== null && !(paidEvent && live.status === 'held')) {
      return { result: resultOf(live), soldOut: false, intent: null };
    }
    if (live !== null) {
      // Same hold, another tap: reuse the method's payment, or open a second intent.
      // Without a method ("Thanh toán tiếp") the hold keeps the method of its current payment.
      const current = method === null && live.paymentId !== null ? await tx.getPayment(live.paymentId) : null;
      const chosen = method ?? current?.method ?? null;
      if (chosen === null) throw new DomainError('invalid_argument');
      const existing = current ?? await tx.paymentByIdempotencyKey(ticketIdempotencyKey(live.id, chosen));
      const holdExpiresAt = live.holdExpiresAt ?? new Date(now.getTime() + HOLD_MINUTES * 60_000);
      const payment = existing ?? newTicketPayment({
        id: preDrawnPaymentId, event: ev, registrationId: live.id, payerId: caller.uid, method: chosen,
        provider: deps.gateway?.provider ?? 'fake', amount: live.amount, now, expiresAt: holdExpiresAt,
      });
      if (existing === null) tx.putPayment(payment);
      const reg = live.paymentId === payment.id
        ? live
        : { ...live, paymentId: payment.id, updatedAt: now, version: live.version + 1 };
      if (reg !== live) tx.putRegistration(reg);
      return { result: resultOf(reg), soldOut: false, intent: payment };
    }
    if (paidEvent && method === null) throw new DomainError('invalid_argument');
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
      return { result: null, soldOut: true, intent: null }; // a throw would abort the release above
    }
    const regId = deps.ids.newId();
    const start = ev.startAt as Date;
    const loc = ev.location as NonNullable<EventRecord['location']>;
    const holdExpiresAt = new Date(now.getTime() + HOLD_MINUTES * 60_000);
    const payment = paidEvent && method !== null
      ? newTicketPayment({
        id: preDrawnPaymentId, event: ev, registrationId: regId, payerId: caller.uid, method,
        provider: deps.gateway?.provider ?? 'fake',
        amount: q * (ev.price as number), now, expiresAt: holdExpiresAt,
      })
      : null;
    const reg: RegistrationDoc = {
      id: regId, eventId: ev.id, userId: caller.uid, userName: name,
      userAvatarUrl: profile?.avatarUrl ?? null,
      quantity: q,
      amount: payment?.amount ?? 0,
      // Free: a ticket at once. Paid: seats held 10 minutes while the customer pays (Decision 9).
      status: payment === null ? 'paid' : 'held',
      holdExpiresAt: payment === null ? null : holdExpiresAt,
      ticketCode: code, paymentId: payment?.id ?? null,
      contactEligible: false, // O3: free never unlocks contact; a paid ticket does once the payment lands
      checkedInAt: null, cancelledAt: null, refundPercent: null,
      event: {
        title: ev.title, type: ev.type, startAt: start, endAt: ev.endAt as Date,
        locationName: loc.name, lat: loc.lat, lng: loc.lng, coverUrl: ev.coverUrl,
      },
      version: 1, createdAt: now, updatedAt: now,
    };
    tx.putTicketCode(code, ev.id, regId);
    tx.putRegistration(reg);
    if (payment !== null) tx.putPayment(payment);
    const next = payment === null
      ? { ...ev, heldCount: held, registeredCount: ev.registeredCount + q, hashtagLocked: true }
      : { ...ev, heldCount: held + q, hashtagLocked: true };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return { result: resultOf(reg), soldOut: false, intent: payment };
  });
  if (out.soldOut || out.result === null) throw new DomainError('sold_out');
  if (out.intent === null || deps.gateway === undefined) return out.result;

  const storedInst = instructionsOf(out.intent);
  if (storedInst !== null) {
    return { ...out.result, instructions: storedInst };
  }

  const intent = out.intent;
  const intentId = intent.id;
  const instructions = await issuePaymentInstructions(
    deps.gateway,
    intent,
    async (providerRef, restInstructions) => {
      await deps.events.runTransaction(async (tx) => {
        const cur = await tx.getPayment(intentId);
        if (cur === null || cur.status !== 'created') return;
        tx.putPayment({
          ...cur,
          ...(providerRef ? { providerRef } : {}),
          instructions: restInstructions,
          updatedAt: deps.clock.now().toISOString(),
        });
      });
    },
  );

  return { ...out.result, instructions };
}

export async function cancelRegistration(
  deps: RegisterDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ status: RegistrationStatus; refundPercent: number | null }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const regId = idOf(r.registrationId);
  const decided = await deps.events.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const reg = await tx.getRegistration(eventId, regId);
    if (reg === null) throw new DomainError('not_found');
    if (reg.userId !== caller.uid) throw new DomainError('permission_denied');
    const ev = await tx.getEvent(eventId);
    if (ev === null) throw new DomainError('not_found');
    if (reg.status === 'cancelled' || reg.status === 'refunded') {
      return { status: reg.status, refundPercent: reg.refundPercent, refund: false };
    }
    if (reg.checkedInAt !== null) throw new DomainError('conflict');
    if (ev.startAt === null || now.getTime() >= ev.startAt.getTime()) throw new DomainError('not_eligible');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    if (reg.status === 'paid' && reg.amount > 0) {
      // ≥ 48 h: refunded in its own transaction below (refundTicket). Later: O4, no refund, seat back,
      // the money stays held and goes to the host with the other tickets after the event.
      if (ticketRefundPercent(ev.startAt, now) === 100) return { status: reg.status, refundPercent: null, refund: true };
      tx.putRegistration({
        ...reg, status: 'cancelled', cancelledAt: now, refundPercent: 0, updatedAt: now, version: reg.version + 1,
      });
      tx.deleteRegistrationContact(eventId, regId);
      const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
      return { status: 'cancelled' as const, refundPercent: 0, refund: false };
    }

    tx.putRegistration({ ...reg, status: 'cancelled', cancelledAt: now, updatedAt: now, version: reg.version + 1 });
    const next = reg.status === 'held'
      ? { ...ev, heldCount: Math.max(0, ev.heldCount - reg.quantity) }
      : { ...ev, registeredCount: ev.registeredCount - reg.quantity };
    tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
    return { status: 'cancelled' as const, refundPercent: null, refund: false };
  });
  if (!decided.refund) return { status: decided.status, refundPercent: decided.refundPercent };
  if (deps.gateway === undefined || deps.cipher === undefined) throw new DomainError('not_eligible');
  const payments = deps.payments ?? new MemoryPaymentLookup([deps.events as unknown as PaymentSource]);
  const done = await refundTicket(
    { ...deps, gateway: deps.gateway, cipher: deps.cipher, payments }, eventId, regId, 100, 'customer_cancel');
  if (done === 'skipped') {
    // A host cancel (or a second tap) refunded it first: the ticket is refunded either way.
    const now = await deps.events.runTransaction((tx) => tx.getRegistration(eventId, regId));
    if (now?.status === 'refunded') return { status: 'refunded', refundPercent: now.refundPercent };
    throw new DomainError('conflict');
  }
  return { status: 'refunded', refundPercent: 100 };
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
