/**
 * Use case: createPayment (S04.03 "Thanh toán", S04.04 "Tạo QR mới").
 * Opens a payment of the full price for a draft booking and mirrors how to pay it on the booking.
 */

import type { BookingCheckout, PaymentProvider } from './booking.js';
import {
  DRAFT_EXPIRY_MINUTES,
  DRAFT_PAYMENT_GRACE_MINUTES,
  MAX_PAYMENT_ATTEMPTS,
  PAYMENT_EXPIRY_MINUTES,
} from './booking_policy.js';
import type { BookingDeps, GatewayInstructions, PaymentGateway } from './booking_ports.js';
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
 * 1. `method` must be one of PAYMENT_METHODS (`invalid_argument`).
 * 2. The caller owns the booking, it is a `draft`, they have a phone, and the day is still held
 *    for it (`permission_denied` / `conflict` / `phone_required` / `day_taken`).
 * 3. At most MAX_PAYMENT_ATTEMPTS payments per booking (`payment_attempts_exceeded`).
 * 4. The open payment, if any, expires; what it received is refunded (`underpaid_expired`).
 * 5. A new `created` payment of `booking.deposit` (the full price), valid 15 minutes, with its
 *    transfer code and idempotency key `pay_${bookingId}_${attempt}`; the gateway opens it.
 * 6. `booking.checkout` mirrors it and `payableUntil` becomes max(payableUntil, expiresAt + 5 min).
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

  const result = await deps.store.runTransaction(async (tx) => {
    pendingRefunds = [];
    // Reads
    const booking = await tx.getBooking(input.bookingId);
    if (!booking) throw new DomainError('not_found');
    if (booking.customerId !== input.customerId) throw new DomainError('permission_denied');
    if (booking.status !== 'draft') throw new DomainError('conflict');

    const day = await tx.getAvailabilityDay(booking.photographerId, booking.day);
    if (!day || day.state !== 'pending' || day.bookingId !== booking.id) throw new DomainError('day_taken');

    const attempt = Math.max(prior.length, booking.checkout?.attempt ?? 0) + 1;
    if (attempt > MAX_PAYMENT_ATTEMPTS) throw new DomainError('payment_attempts_exceeded');

    const openIds = new Set(prior.filter((p) => p.status === 'created').map((p) => p.id));
    if (booking.checkout) openIds.add(booking.checkout.paymentId);
    const open: Payment[] = [];
    for (const id of openIds) {
      const p = await tx.getPayment(id);
      if (p && p.status === 'created') open.push(p);
    }

    const idempotencyKey = `pay_${booking.id}_${attempt}`;
    const instructions = await deps.gateway.createPayment({
      paymentId,
      subjectType: 'booking',
      subjectId: booking.id,
      bookingId: booking.id,
      amount: booking.deposit,
      method,
      transferCode,
      expiresAt,
      idempotencyKey,
    });

    // Writes
    for (const p of open) {
      const refund = await expireOpenPayment(tx, deps, p, now);
      if (refund) pendingRefunds.push({ refund, provider: p.provider });
    }

    const { providerRef, ...clientInstructions } = instructions;
    const payment: Payment = {
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
      ...(providerRef ? { providerRef } : {}),
      instructions: clientInstructions,
      createdAt,
      updatedAt: createdAt,
    };
    await tx.setPayment(payment);

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
    await tx.setBooking({ ...booking, checkout, payableUntil, updatedAt: createdAt });

    return { paymentId, checkout };
  });

  // The new QR is committed: a refund the gateway refuses or throws on is left `failed` for staff.
  await dispatchRefunds(deps, pendingRefunds);

  return result;
}
