/**
 * Use case: createPayment (S04.03 "Thanh toán", S04.04 "Tạo QR mới").
 * Opens a payment of the full price for a draft booking and mirrors how to pay it on the booking.
 */

import type { Booking, BookingCheckout, BookingEntry, PaymentProvider } from './booking.js';
import { assertEntryBookable } from './booking_entry.js';
import { entryFieldsOf, entryReleaseAt } from './entry_tickets.js';
import type { EventRecord, RegistrationDoc } from './event.js';
import {
  EntryFold,
  assertLinesSum,
  expireGroupLines,
  groupViewOf,
  lineOf,
  newChildPayment,
  newGroupPayment,
  readGroup,
  type GroupLine,
  type GroupRead,
} from './group_settlement.js';
import { PLATFORM_PAYEE } from './payout.js';
import {
  DRAFT_EXPIRY_MINUTES,
  DRAFT_PAYMENT_GRACE_MINUTES,
  MAX_PAYMENT_ATTEMPTS,
  PAYMENT_EXPIRY_MINUTES,
  parseVnDateTime,
} from './booking_policy.js';
import type { BookingDeps, BookingTx, GatewayInstructions, PaymentGateway } from './booking_ports.js';
import { expireOpenPayment } from './booking_payment_paths.js';
import { DomainError } from './errors.js';
import {
  isPaymentMethod,
  type Payment,
  type PaymentMethod,
  type PaymentSubject,
  type Refund,
} from './escrow.js';
import { isId } from './ids.js';
import { assertOrderAllowed } from './order_gate.js';
import { transferCodeFor } from './payment_code.js';
import type { PaymentInstructions } from './payment_ports.js';
import { type PaymentLookup, type SettlementDeps, settleTransfer } from './payment_settlement.js';
import type { IdGenerator } from './ports.js';
import { dispatchRefunds } from './refunds.js';
import { requireCustomerPhone } from './require_phone.js';

/** Tries at drawing a payment id whose transfer code no open payment uses (#129 Decision 5). */
const CODE_TRIES = 3;
const MINUTE = 60_000;

export interface CreatePaymentResult {
  readonly paymentId: string;
  readonly checkout: BookingCheckout;
  /** S30: a booking with tickets is paid as a group: `paymentId` is the group payment, `lines` its children. */
  readonly groupId?: string;
  readonly lines?: readonly GroupLine[];
}

/**
 * Creates a brand new Payment object for any subject.
 */
export function newSubjectPayment(p: {
  readonly id: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly payerId: string;
  readonly payeeId: string;
  readonly amount: number;
  readonly method: PaymentMethod;
  readonly provider: PaymentProvider;
  readonly idempotencyKey: string;
  readonly now: Date;
  readonly expiresAt: Date;
}): Payment {
  const at = p.now.toISOString();
  return {
    id: p.id,
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    payerId: p.payerId,
    payeeId: p.payeeId,
    provider: p.provider,
    amount: p.amount,
    status: 'created',
    escrowStatus: 'held',
    idempotencyKey: p.idempotencyKey,
    method: p.method,
    transferCode: transferCodeFor(p.id),
    expiresAt: p.expiresAt.toISOString(),
    receivedAmount: 0,
    createdAt: at,
    updatedAt: at,
  };
}

/**
 * A payment id whose transfer code no payment of any subject or status uses (#129 Decision 5, now cross-subject).
 */
export async function freshPaymentId(
  payments: Pick<PaymentLookup, 'findPaymentsByTransferCode'>,
  ids: IdGenerator,
): Promise<string> {
  for (let i = 0; i < CODE_TRIES; i++) {
    const id = ids.newId();
    const code = transferCodeFor(id);
    const taken = (await payments.findPaymentsByTransferCode(code)).length > 0;
    if (!taken) return id;
  }
  throw new DomainError('conflict');
}

/**
 * Outside any transaction: gateway.createPayment, then save(providerRef, instructions)
 * (the caller's short tx, only while still created).
 */
export async function issuePaymentInstructions(
  gateway: PaymentGateway,
  payment: Payment,
  save: (providerRef: string | undefined, instructions: GatewayInstructions) => Promise<void>,
): Promise<PaymentInstructions> {
  if (payment.status !== 'created' || !payment.method || !payment.transferCode || !payment.expiresAt) {
    throw new DomainError('conflict');
  }

  const instructions = await gateway.createPayment({
    paymentId: payment.id,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    amount: payment.amount,
    method: payment.method,
    transferCode: payment.transferCode,
    expiresAt: payment.expiresAt,
    idempotencyKey: payment.idempotencyKey,
  });

  const { providerRef, ...restInstructions } = instructions;
  await save(providerRef, restInstructions);

  const updated: Payment = {
    ...payment,
    ...(providerRef ? { providerRef } : {}),
    instructions: restInstructions,
  };

  const result = instructionsOf(updated);
  if (!result) throw new DomainError('conflict');
  return result;
}

/**
 * From the stored payment (reuse on a second tap); null without method, transferCode, expiresAt or instructions.
 */
export function instructionsOf(payment: Payment): PaymentInstructions | null {
  if (!payment.method || !payment.transferCode || !payment.expiresAt || !payment.instructions) {
    return null;
  }
  const inst = payment.instructions;
  return {
    paymentId: payment.id,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    method: payment.method,
    amount: payment.amount,
    expiresAt: payment.expiresAt,
    transferCode: payment.transferCode,
    ...(inst.qrPayload !== undefined ? { qrPayload: inst.qrPayload } : {}),
    ...(inst.bankName !== undefined ? { bankName: inst.bankName } : {}),
    ...(inst.accountMasked !== undefined ? { accountMasked: inst.accountMasked } : {}),
    ...(inst.payUrl !== undefined ? { payUrl: inst.payUrl } : {}),
    ...(inst.bankAppsUrl !== undefined ? { bankAppsUrl: inst.bankAppsUrl } : {}),
  };
}

/**
 * "Kiểm tra lại" for any subject: queryTransfers for each created payment, settleTransfer each; true when one is now paid.
 */
export async function checkSubjectPayments(
  deps: SettlementDeps,
  payments: readonly Payment[],
): Promise<boolean> {
  for (const payment of payments) {
    if (payment.status !== 'created' || !payment.transferCode) continue;
    const transfers = await deps.gateway.queryTransfers({
      paymentId: payment.id,
      transferCode: payment.transferCode,
      providerRef: payment.providerRef,
    });
    for (const n of transfers) {
      await settleTransfer(deps, n);
    }
  }

  for (const payment of payments) {
    const reRead = await deps.payments.getPayment(payment.id);
    if (reRead?.status === 'paid') return true;
  }
  return false;
}

/**
 * getPaymentInstructions: payer only; instructions of a `created` payment, else null.
 */
export async function readPaymentInstructions(
  deps: Pick<SettlementDeps, 'payments'>,
  caller: { readonly uid: string },
  raw: unknown,
): Promise<PaymentInstructions | null> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const { paymentId } = raw as { paymentId?: unknown };
  if (typeof paymentId !== 'string' || !isId(paymentId)) throw new DomainError('invalid_argument');

  const payment = await deps.payments.getPayment(paymentId);
  if (!payment) throw new DomainError('not_found');
  if (payment.payerId !== caller.uid) throw new DomainError('permission_denied');

  if (payment.status !== 'created') return null;
  return instructionsOf(payment);
}

/**
 * Writes only (S30 Decisions 6, 15): the group payment of a booking with tickets, its two lines (the
 * booking to the provider; the tickets to the event's host, `payeeKind: organizer`, released
 * `entryReleaseAt(visitDay)`), the registration held for the tickets until the group expires (`held`
 * on its visit day, through `fold`) and the `payment_groups` view. The caller writes the group payment.
 */
async function openGroup(
  tx: BookingTx,
  deps: BookingDeps,
  p: {
    readonly booking: Booking;
    readonly entry: BookingEntry;
    readonly ev: EventRecord;
    readonly fold: EntryFold;
    readonly userName: string;
    readonly paymentId: string;
    readonly method: PaymentMethod;
    readonly idempotencyKey: string;
    readonly now: Date;
    readonly expiresAt: Date;
  },
): Promise<{ readonly group: Payment; readonly lines: GroupLine[]; readonly registrationId: string }> {
  const { booking, entry, ev, now, expiresAt } = p;
  const provider = deps.gateway.provider;
  const regId = deps.ids.newId();
  const group = newGroupPayment({
    id: p.paymentId, payerId: booking.customerId, total: booking.deposit + entry.amount, method: p.method,
    provider, idempotencyKey: p.idempotencyKey, now, expiresAt,
  });
  const hostPaid = (ev.host.type === 'photographer' || ev.host.type === 'organizer') && ev.host.id !== null;
  const children = [
    newChildPayment({
      id: deps.ids.newId(), groupId: group.id, payerId: booking.customerId, method: p.method, provider, now, expiresAt,
      line: { kind: 'booking', subjectType: 'booking', subjectId: booking.id, payeeId: booking.photographerId, amount: booking.deposit },
    }),
    newChildPayment({
      id: deps.ids.newId(), groupId: group.id, payerId: booking.customerId, method: p.method, provider, now, expiresAt,
      line: {
        kind: 'entry_ticket', subjectType: 'event_registration', subjectId: regId,
        payeeId: hostPaid ? (ev.host.id as string) : PLATFORM_PAYEE, amount: entry.amount,
      },
      ...(ev.host.type === 'organizer' ? { payeeKind: 'organizer' as const } : {}),
      eventId: ev.id,
      releaseAfter: entryReleaseAt(entry.visitDay),
    }),
  ];
  assertLinesSum(group, children);
  for (const c of children) await tx.setPayment(c);

  const fields = entryFieldsOf(ev);
  const loc = ev.location as NonNullable<EventRecord['location']>;
  const quantity = entry.items.reduce((n, l) => n + l.qty, 0);
  const reg: RegistrationDoc = {
    id: regId, eventId: ev.id, userId: booking.customerId, userName: p.userName, userAvatarUrl: null,
    quantity, amount: entry.amount, status: 'held', holdExpiresAt: expiresAt,
    // A booking's tickets have no ticket code of their own: the booking's pass (Task 4) is shown at the gate.
    ticketCode: '', ticketCodeLast4: '',
    paymentId: (children[1] as Payment).id, contactEligible: false,
    checkedInAt: null, cancelledAt: null, refundPercent: null,
    visitDay: entry.visitDay, items: entry.items, bookingId: booking.id, gateCheckedInAt: null,
    event: {
      title: ev.title, type: ev.type,
      startAt: parseVnDateTime(entry.visitDay, fields.openHours.start),
      endAt: parseVnDateTime(entry.visitDay, fields.openHours.end),
      locationName: loc.name, lat: loc.lat, lng: loc.lng, coverUrl: ev.coverUrl,
    },
    version: 1, createdAt: now, updatedAt: now,
  };
  await tx.putRegistration(reg);
  // Stats only: an entry event's status never follows its seats (statusAfterSeats).
  p.fold.putEvent({ ...ev, heldCount: ev.heldCount + quantity, version: ev.version + 1, updatedAt: now });
  p.fold.addDelta(ev.id, { day: entry.visitDay, held: quantity });
  const lines = children.map(lineOf);
  await tx.putGroupView(groupViewOf(group, lines, 'created', now));
  return { group, lines, registrationId: regId };
}

/**
 * 1. `method` must be one of PAYMENT_METHODS (`invalid_argument`).
 * 2. The caller owns the booking, it is a `draft`, they have a phone, and the day is still held
 *    for it (`permission_denied` / `conflict` / `phone_required` / `day_taken`).
 * 3. At most MAX_PAYMENT_ATTEMPTS payments per booking (`payment_attempts_exceeded`).
 * 4. The open payment, if any, expires; what it received is refunded (`underpaid_expired`).
 * 5. A new `created` payment of `booking.deposit` (the full price), valid 15 minutes, with its
 *    transfer code and idempotency key `pay_${bookingId}_${attempt}`; the gateway opens it.
 * 6. `booking.checkout` mirrors it and `payableUntil` becomes max(payableUntil, expiresAt + 5 min).
 * S30 (Decisions 6, 15): a booking with tickets to pay (`entry.items` not empty) gets a group payment of
 * `deposit + entry.amount` instead (its own transfer code, the gateway opens it), with two
 * `awaiting_group` lines (the booking; the tickets to the event's host) and the tickets held on their
 * visit day until the group expires (`day_closed`, `sold_out_day`, `invalid_argument` entry when the
 * day can no longer be sold); an open group it replaces expires with its lines and releases its hold.
 * The result then carries `groupId` and `lines`.
 */
export async function createPayment(
  deps: BookingDeps,
  input: { readonly bookingId: string; readonly customerId: string; readonly method: unknown },
): Promise<CreatePaymentResult> {
  const method = input.method;
  if (!isPaymentMethod(method)) throw new DomainError('invalid_argument');
  if (!isId(input.bookingId) || !isId(input.customerId)) throw new DomainError('invalid_argument');

  await requireCustomerPhone(deps.contacts, input.customerId);

  // The provider may have stopped accepting orders, or a block may have started, since the draft.
  // Only the owner of a draft learns about it; anyone else gets the transaction's own answer.
  const pre = await deps.store.getBooking(input.bookingId);
  if (pre && pre.customerId === input.customerId && pre.status === 'draft') {
    await assertOrderAllowed(deps, { customerId: pre.customerId, providerId: pre.photographerId });
  }

  const prior = await deps.store.getPaymentsForBooking(input.bookingId);
  const paymentId = await freshPaymentId(deps.store, deps.ids);
  const transferCode = transferCodeFor(paymentId);
  const now = deps.clock.now();
  const createdAt = now.toISOString();
  const expiresAt = new Date(now.getTime() + PAYMENT_EXPIRY_MINUTES * MINUTE).toISOString();
  let pendingRefunds: { readonly refund: Refund; readonly provider: Payment['provider'] }[] = [];

  const result = await deps.store.runTransaction(async (tx): Promise<CreatePaymentResult> => {
    pendingRefunds = [];
    // Reads
    const booking = await tx.getBooking(input.bookingId);
    if (!booking) throw new DomainError('not_found');
    if (booking.customerId !== input.customerId) throw new DomainError('permission_denied');
    if (booking.status !== 'draft') throw new DomainError('conflict');

    if (booking.spotScheduleId) {
      // A spot draft holds an interval of its schedule's spot day (#194), studio or not (Decision 7).
      const spotDay = await tx.getSpotDay(booking.spotScheduleId, booking.day);
      const hasInterval = spotDay?.taken.some((t) => t.start === booking.start && t.end === booking.end);
      if (!hasInterval) throw new DomainError('day_taken');
    } else if (booking.isStudio === true) {
      // A studio's draft is held on its day load, not on its own day (#136 Decision 26).
      const load = await tx.getStudioDayLoad(booking.photographerId, booking.day);
      if (!load?.unassignedIds.includes(booking.id)) throw new DomainError('day_taken');
    } else {
      const day = await tx.getAvailabilityDay(booking.photographerId, booking.day);
      if (!day || day.state !== 'pending' || day.bookingId !== booking.id) throw new DomainError('day_taken');
    }

    const attempt = Math.max(prior.length, booking.checkout?.attempt ?? 0) + 1;
    if (attempt > MAX_PAYMENT_ATTEMPTS) throw new DomainError('payment_attempts_exceeded');

    const openIds = new Set(prior.filter((p) => p.status === 'created').map((p) => p.id));
    if (booking.checkout) openIds.add(booking.checkout.paymentId);
    const open: Payment[] = [];
    for (const id of openIds) {
      const p = await tx.getPayment(id);
      if (p && p.status === 'created') open.push(p);
    }

    // S30 (Decision 6, 15): a booking with tickets to pay is paid as a group (booking + tickets); an open
    // group it replaces takes its lines and its held tickets with it.
    const fold = new EntryFold();
    const replaced = new Map<string, GroupRead>();
    for (const p of open) if (p.subjectType === 'payment_group') replaced.set(p.id, await readGroup(tx, p, fold));
    const entry = booking.entry !== undefined && booking.entry.items.length > 0 ? booking.entry : null;
    let entryEvent: EventRecord | null = null;
    let userName = '';
    if (entry !== null) {
      const ev = await fold.readEvent(tx, entry.eventId);
      const row = await fold.readDay(tx, entry.eventId, entry.visitDay);
      let freed = 0;
      for (const g of replaced.values()) {
        for (const l of g.lines) {
          if (l.kind === 'ticket' && l.eventId === entry.eventId && l.reg?.status === 'held'
            && l.reg.paymentId === l.payment.id && l.reg.visitDay === entry.visitDay) freed += l.reg.quantity;
        }
      }
      entryEvent = assertEntryBookable({
        event: ev,
        visitDay: entry.visitDay,
        bookingDay: booking.day,
        spotId: booking.spotId ?? null,
        day: row === null ? null : { ...row, held: Math.max(0, row.held - freed) },
        qty: entry.items.reduce((n, l) => n + l.qty, 0),
        now,
      });
      userName = (await tx.getContactSnapshot(booking.id))?.name ?? '';
    }
    const total = booking.deposit + (entry?.amount ?? 0);

    const idempotencyKey = `pay_${booking.id}_${attempt}`;
    const instructions = await deps.gateway.createPayment({
      paymentId,
      subjectType: entry !== null ? 'payment_group' : 'booking',
      subjectId: entry !== null ? paymentId : booking.id,
      bookingId: booking.id,
      amount: total,
      method,
      transferCode,
      expiresAt,
      idempotencyKey,
    });

    // Writes
    for (const p of open) {
      const refund = await expireOpenPayment(tx, deps, p, now);
      if (refund) pendingRefunds.push({ refund, provider: p.provider });
      const g = replaced.get(p.id);
      if (g) await expireGroupLines(tx, g, fold, { ...p, status: 'expired' }, now);
    }

    const { providerRef, ...clientInstructions } = instructions;
    const opened = {
      ...(providerRef ? { providerRef } : {}),
      instructions: clientInstructions,
    };
    let payment: Payment;
    let lines: GroupLine[] | undefined;
    let bookingPatch: Partial<Booking> = {};
    if (entry !== null && entryEvent !== null) {
      const built = await openGroup(tx, deps, {
        booking, entry, ev: fold.event(entryEvent.id) ?? entryEvent, fold, userName,
        paymentId, method, idempotencyKey, now, expiresAt: new Date(expiresAt),
      });
      payment = { ...built.group, ...opened };
      lines = built.lines;
      bookingPatch = { groupId: paymentId, entry: { ...entry, registrationId: built.registrationId } };
    } else {
      payment = {
        id: paymentId,
        subjectType: 'booking',
        subjectId: booking.id,
        payerId: booking.customerId,
        payeeId: booking.photographerId,
        provider: deps.gateway.provider,
        amount: booking.deposit,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey,
        method,
        transferCode,
        expiresAt,
        receivedAmount: 0,
        ...opened,
        createdAt,
        updatedAt: createdAt,
      };
    }
    await tx.setPayment(payment);
    await fold.flush(tx, now);

    const checkout: BookingCheckout = {
      paymentId,
      method,
      amount: payment.amount,
      expiresAt,
      transferCode,
      attempt,
      ...(instructions.qrPayload !== undefined ? { qrPayload: instructions.qrPayload } : {}),
      ...(instructions.bankName !== undefined ? { bankName: instructions.bankName } : {}),
      ...(instructions.accountMasked !== undefined ? { accountMasked: instructions.accountMasked } : {}),
      ...(instructions.payUrl !== undefined ? { payUrl: instructions.payUrl } : {}),
      ...(instructions.bankAppsUrl !== undefined ? { bankAppsUrl: instructions.bankAppsUrl } : {}),
    };
    const draftUntil = booking.payableUntil
      ? Date.parse(booking.payableUntil)
      : Date.parse(booking.createdAt) + DRAFT_EXPIRY_MINUTES * MINUTE;
    const payableUntil = new Date(
      Math.max(draftUntil, Date.parse(expiresAt) + DRAFT_PAYMENT_GRACE_MINUTES * MINUTE),
    ).toISOString();
    await tx.setBooking({ ...booking, ...bookingPatch, checkout, payableUntil, updatedAt: createdAt });

    return { paymentId, checkout, ...(lines !== undefined ? { groupId: paymentId, lines } : {}) };
  });

  // The new QR is committed: a refund the gateway refuses or throws on is left `failed` for staff.
  await dispatchRefunds(deps, pendingRefunds);

  return result;
}
