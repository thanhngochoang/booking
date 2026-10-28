import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import type { PaymentGateway } from './booking_ports.js';
import { isPaymentMethod, type Payment, type PaymentMethod } from './escrow.js';
import {
  HOLD_MINUTES,
  TICKETS_PER_REGISTRATION,
  isEventManager,
  statusAfterSeats,
  type EventCaller,
  type EventRecord,
  type RegistrationDoc,
  type RegistrationStatus,
} from './event.js';
import { formatVnDate, isDateString, parseVnDateTime } from './booking_policy.js';
import {
  ENTRY_HOLD_MINUTES,
  assertDailyCapacity,
  entryFieldsOf,
  entryRefundPercent,
  entryReleaseAt,
  isOpenDay,
  priceItems,
  visitDayStart,
  type EntryItem,
} from './entry_tickets.js';
import { readEntryDays, readEntryDaysOf, releaseDeltas, visitDayOf, writeEntryDays } from './entry_days.js';
import type { ErrorCode } from './errors.js';
import { canSell } from './organizer.js';
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
import { ticketCodeCandidates } from './ticket_code.js';
import { checkInByManager } from './pass_scan.js';
import type { PaymentInstructions } from './payment_ports.js';
import type { PaymentLookup } from './payment_settlement.js';
import { freshPaymentId, instructionsOf, issuePaymentInstructions } from './create_payment.js';
import { MemoryPaymentLookup, type PaymentSource } from './memory_payment_lookup.js';

import type { AccountCipher } from './payout_ports.js';

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
    // Entry tickets are bought per visit day (registerEntry).
    if (ev.type === 'entry') throw new DomainError('invalid_argument', 'type');
    if (isEventManager(ev, caller)) throw new DomainError('permission_denied');
    if ((ev.host.type === 'photographer' || ev.host.type === 'organizer') && ev.host.id && deps.blocks) {
      if (await deps.blocks.isBlockedEitherWay(caller.uid, ev.host.id)) {
        throw new DomainError('blocked');
      }
    }
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
  return withInstructions(deps, out.result, out.intent);
}

/** After the hold's transaction: the gateway's instructions for its payment (stored ones are reused). */
async function withInstructions(deps: RegisterDeps, result: RegisterResult, intent: Payment | null): Promise<RegisterResult> {
  if (intent === null || deps.gateway === undefined) return result;

  const storedInst = instructionsOf(intent);
  if (storedInst !== null) {
    return { ...result, instructions: storedInst };
  }

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

  return { ...result, instructions };
}

type EntryOut = { result: RegisterResult | null; refusal: ErrorCode | null; intent: Payment | null };

const parseName = (v: unknown): string => {
  if (typeof v !== 'string') throw new DomainError('invalid_argument', 'name');
  const name = v.normalize('NFC').trim();
  const n = graphemeCount(name);
  if (n < 1 || n > NAME_MAX) throw new DomainError('invalid_argument', 'name');
  return name;
};

/**
 * S30.05 (Decision 11): an order of up to 10 entry tickets for one visit day, held 15 minutes while
 * the customer pays. One transaction reads the event, its organizer, the visit day's `entry_days` row
 * and the customer's ticket of that day, then writes the row (`held + qty`; `sold + held + qty ≤
 * dailyCapacity`, else `sold_out_day`), the registration and its payment (paid to the organizer,
 * released `entryReleaseAt(visitDay)`). No public ticket code (Decision 8): the pass is created when
 * the ticket is paid (`TicketPaymentSettler`). A customer has one lone ticket per visit
 * day (`conflict` for a second order); tickets bought with a booking do not count. Hidden types are
 * refused (`invalid_argument` items) but stay on the event for history.
 */
export async function registerEntry(deps: RegisterDeps, caller: EventCaller, raw: unknown): Promise<RegisterResult> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  if (!isDateString(r.visitDay)) throw new DomainError('invalid_argument', 'visitDay');
  const visitDay = r.visitDay;
  if (!Array.isArray(r.items)) throw new DomainError('invalid_argument', 'items');
  const items = r.items as readonly EntryItem[];
  const name = parseName(r.name);
  if ('provider' in r) throw new DomainError('invalid_argument');
  const method = parseMethod(r.method);
  if (method === null) throw new DomainError('invalid_argument', 'method');
  if (deps.gateway === undefined) throw new DomainError('not_eligible');
  const provider = deps.gateway.provider;
  const profile = await deps.people.user(caller.uid);
  const paymentId = deps.payments !== undefined ? await freshPaymentId(deps.payments, deps.ids) : deps.ids.newId();

  const out = await deps.events.runTransaction(async (tx): Promise<EntryOut> => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null || ev.status === 'draft' || ev.type !== 'entry') throw new DomainError('not_found');
    if (isEventManager(ev, caller)) throw new DomainError('permission_denied');
    const hostId = ev.host.id;
    if (hostId !== null && deps.blocks && await deps.blocks.isBlockedEitherWay(caller.uid, hostId)) {
      throw new DomainError('blocked');
    }
    await requireCustomerPhone(deps.contacts, caller.uid);
    if (ev.status !== 'open' && ev.status !== 'full') throw new DomainError('deadline_passed');
    const org = hostId === null ? null : await tx.getOrganizer(hostId);
    if (org === null || !canSell(org)) throw new DomainError('not_eligible');
    const fields = entryFieldsOf(ev);
    if (visitDay < formatVnDate(now) || !isOpenDay(fields, visitDay)
      || now.getTime() >= parseVnDateTime(visitDay, fields.openHours.end).getTime()) {
      throw new DomainError('day_closed');
    }
    const priced = priceItems(fields.ticketTypes, items);
    const active = await tx.activeRegistrationOf(ev.id, caller.uid, visitDay);
    const stale = await tx.expiredHolds(ev.id, now);
    // A lapsed hold is not "the active registration" (it is released below).
    if (active !== null && !stale.some((s) => s.id === active.id)) throw new DomainError('conflict');
    const staleDays = stale.map((s) => visitDayOf(ev, s)).filter((d): d is string => d !== null);
    const days = await readEntryDaysOf(tx, ev.id, [visitDay, ...staleDays]);

    // ---- writes from here ----
    let held = ev.heldCount;
    for (const s of stale) {
      tx.putRegistration({ ...s, status: 'cancelled', cancelledAt: now, updatedAt: now, version: s.version + 1 });
      held -= s.quantity;
    }
    const released = releaseDeltas(ev, stale);
    const row = days.get(visitDay) ?? null;
    const freed = released.filter((d) => d.day === visitDay).reduce((n, d) => n + (d.held ?? 0), 0);
    let refusal: ErrorCode | null = null;
    try {
      assertDailyCapacity(row === null ? null : { ...row, held: Math.max(0, row.held + freed) }, fields.dailyCapacity, priced.quantity);
    } catch (e) {
      if (!(e instanceof DomainError)) throw e;
      refusal = e.code;
    }
    if (refusal !== null) {
      // A throw would abort the release of the lapsed holds above.
      if (stale.length > 0) {
        writeEntryDays(tx, ev.id, days, released, now);
        tx.putEvent({ ...ev, heldCount: Math.max(0, held), version: ev.version + 1, updatedAt: now });
      }
      return { result: null, refusal, intent: null };
    }

    const regId = deps.ids.newId();
    const loc = ev.location as NonNullable<EventRecord['location']>;
    const holdExpiresAt = new Date(now.getTime() + ENTRY_HOLD_MINUTES * 60_000);
    const payment = newTicketPayment({
      id: paymentId, event: ev, registrationId: regId, payerId: caller.uid, method, provider,
      amount: priced.total, now, expiresAt: holdExpiresAt,
      lineKind: 'entry_ticket', releaseAfter: entryReleaseAt(visitDay),
    });
    const reg: RegistrationDoc = {
      id: regId, eventId: ev.id, userId: caller.uid, userName: name,
      userAvatarUrl: profile?.avatarUrl ?? null,
      quantity: priced.quantity,
      amount: priced.total,
      status: 'held',
      holdExpiresAt,
      // Decision 8: no public code. The pass (`passes/{code8}`, `private/pass`) is created when the ticket
      // is paid, which sets `ticketCodeLast4`.
      ticketCode: '',
      ticketCodeLast4: '',
      paymentId: payment.id,
      contactEligible: false,
      checkedInAt: null, cancelledAt: null, refundPercent: null,
      visitDay, items: priced.lines, bookingId: null, gateCheckedInAt: null,
      event: {
        title: ev.title, type: ev.type,
        startAt: parseVnDateTime(visitDay, fields.openHours.start),
        endAt: parseVnDateTime(visitDay, fields.openHours.end),
        locationName: loc.name, lat: loc.lat, lng: loc.lng, coverUrl: ev.coverUrl,
      },
      version: 1, createdAt: now, updatedAt: now,
    };
    writeEntryDays(tx, ev.id, days, [...released, { day: visitDay, held: priced.quantity }], now);
    tx.putRegistration(reg);
    tx.putPayment(payment);
    // Stats only: an entry event's status never follows its seats (statusAfterSeats).
    tx.putEvent({ ...ev, heldCount: Math.max(0, held) + priced.quantity, version: ev.version + 1, updatedAt: now });
    return { result: resultOf(reg), refusal: null, intent: payment };
  });
  if (out.refusal !== null || out.result === null) throw new DomainError(out.refusal ?? 'sold_out_day');
  return withInstructions(deps, out.result, out.intent);
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
    if (reg.checkedInAt !== null || (reg.gateCheckedInAt ?? null) !== null) throw new DomainError('conflict');
    // An entry ticket (S30) can be cancelled until its visit day starts; the cutoff decides the refund.
    const visitDay = ev.type === 'entry' ? (reg.visitDay ?? null) : null;
    const startsAt = visitDay !== null ? visitDayStart(visitDay) : ev.startAt;
    if (startsAt === null || now.getTime() >= startsAt.getTime()) throw new DomainError('not_eligible');
    if (ev.status === 'cancelled' || ev.status === 'completed') throw new DomainError('not_eligible');
    const days = await readEntryDays(tx, ev, [reg]);
    if (reg.status === 'paid' && reg.amount > 0) {
      // ≥ 48 h: refunded in its own transaction below (refundTicket). Later: O4, no refund, seat back,
      // the money stays held and goes to the host with the other tickets after the event.
      const percent = visitDay !== null
        ? entryRefundPercent(visitDay, now, entryFieldsOf(ev).refundCutoffHours)
        : ticketRefundPercent(startsAt, now);
      if (percent === 100) return { status: reg.status, refundPercent: null, refund: true };
      tx.putRegistration({
        ...reg, status: 'cancelled', cancelledAt: now, refundPercent: 0, updatedAt: now, version: reg.version + 1,
      });
      tx.deleteRegistrationContact(eventId, regId);
      writeEntryDays(tx, ev.id, days, releaseDeltas(ev, [reg]), now);
      const next = { ...ev, registeredCount: Math.max(0, ev.registeredCount - reg.quantity) };
      tx.putEvent({ ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now });
      return { status: 'cancelled' as const, refundPercent: 0, refund: false };
    }

    writeEntryDays(tx, ev.id, days, releaseDeltas(ev, [reg]), now);
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

/**
 * The old manager check-in (S12.03, old clients; Decision 9): delegates to the scan (`checkInByManager`,
 * `pass_scan.ts`) as the event's manager only, with the old answers and error codes.
 */
export async function checkInRegistration(
  deps: EventDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ name: string; quantity: number }> {
  return checkInByManager(deps, caller, raw);
}
