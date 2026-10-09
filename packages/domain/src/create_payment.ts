/**
 * Use case: createPayment (S04.03 "Thanh toán", S04.04 "Tạo QR mới").
 * Opens a payment of the full price for a draft booking and mirrors how to pay it on the booking.
 */

import type { BookingCheckout } from './booking.js';
import {
  DRAFT_EXPIRY_MINUTES,
  DRAFT_PAYMENT_GRACE_MINUTES,
  MAX_PAYMENT_ATTEMPTS,
  PAYMENT_EXPIRY_MINUTES,
} from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { expireOpenPayment } from './booking_payment_paths.js';
import { DomainError } from './errors.js';
import { isPaymentMethod, type Payment, type Refund } from './escrow.js';
import { isId } from './ids.js';
import { assertOrderAllowed } from './order_gate.js';
import { transferCodeFor } from './payment_code.js';
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
 * A new payment id whose transfer code no payment of any status uses, so a transfer to an old QR
 * can never reach another customer's payment.
 */
async function freshPaymentId(deps: BookingDeps): Promise<{ readonly id: string; readonly code: string }> {
  for (let i = 0; i < CODE_TRIES; i++) {
    const id = deps.ids.newId();
    const code = transferCodeFor(id);
    const taken = (await deps.store.findPaymentsByTransferCode(code)).length > 0;
    if (!taken) return { id, code };
  }
  throw new DomainError('conflict');
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
  const { id: paymentId, code: transferCode } = await freshPaymentId(deps);
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
      ...(instructions.providerRef ? { providerRef: instructions.providerRef } : {}),
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
