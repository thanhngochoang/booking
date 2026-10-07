/**
 * Old deposit flow (payment id based). Kept until the Functions callables move to createPayment /
 * handleTransferNotification (#129 Task 4), then deleted. Its normal and late paths live in
 * booking_payment_paths.ts, shared with handle_transfer.ts.
 */

import type { Booking } from './booking.js';
import type { BookingDeps } from './booking_ports.js';
import { markPaid, moveDraftToRequested, paymentReceivedEntry, refundLatePayment } from './booking_payment_paths.js';
import { DomainError } from './errors.js';
import type { Payment, Refund } from './escrow.js';
import { dispatchRefund } from './refunds.js';

export interface HandlePaymentResult {
  readonly payment: Payment;
  readonly booking: Booking | null;
  readonly refunded: boolean;
  readonly refund?: Refund;
}

export async function handlePaymentNotification(
  deps: BookingDeps,
  params: {
    readonly paymentId: string;
    readonly providerRef?: string;
    readonly paidAt?: Date;
  },
): Promise<HandlePaymentResult> {
  const now = params.paidAt ?? deps.clock.now();
  let pendingRefund: { refund: Refund; provider: Payment['provider'] } | undefined;

  const result = await deps.store.runTransaction(async (tx) => {
    pendingRefund = undefined;
    const payment = await tx.getPayment(params.paymentId);
    if (!payment) {
      throw new DomainError('not_found');
    }

    // Duplicate confirmation idempotent check (Review Focus 3)
    if (payment.status === 'paid') {
      const booking = await tx.getBooking(payment.subjectId);
      return { payment, booking, refunded: false };
    }

    if (payment.status === 'refunded' || payment.status === 'partially_refunded') {
      const booking = await tx.getBooking(payment.subjectId);
      return { payment, booking, refunded: true };
    }

    const booking = await tx.getBooking(payment.subjectId);
    const paid = markPaid(payment, now, params.providerRef);
    await tx.addLedgerEntry(paymentReceivedEntry(deps, payment, payment.amount, now));

    // Case: Late payment after draft clean up or cancellation -> 100% refund immediately
    if (!booking || booking.status !== 'draft') {
      const late = await refundLatePayment(tx, deps, paid, now);
      pendingRefund = { refund: late.refund, provider: payment.provider };
      return { payment: late.payment, booking: null, refunded: true, refund: late.refund };
    }

    // Normal case: Move booking from draft to requested
    await tx.setPayment(paid);
    const updatedBooking = await moveDraftToRequested(tx, deps, booking, paid, now);
    return { payment: paid, booking: updatedBooking, refunded: false };
  });

  // If a late-payment refund was created in the transaction, dispatch to gateway outside tx
  if (pendingRefund) {
    await dispatchRefund(deps, pendingRefund.refund, pendingRefund.provider);
  }

  return result;
}

/**
 * Confirms payment in fake gateway mode (dev/test only).
 */
export async function confirmFakePayment(
  deps: BookingDeps,
  params: { readonly paymentId: string; readonly customerId: string },
): Promise<HandlePaymentResult> {
  const payment = await deps.store.getPayment(params.paymentId);
  if (!payment) {
    throw new DomainError('not_found');
  }
  if (payment.payerId !== params.customerId) {
    throw new DomainError('permission_denied');
  }

  return handlePaymentNotification(deps, {
    paymentId: params.paymentId,
    providerRef: `fake_confirmed_${params.paymentId}`,
  });
}

/**
 * Checks deposit status with gateway if client returns from redirect (S08).
 */
export async function checkDeposit(
  deps: BookingDeps,
  params: { readonly bookingId: string; readonly customerId: string },
): Promise<{ readonly paid: boolean; readonly booking: Booking | null }> {
  const booking = await deps.store.getBooking(params.bookingId);
  if (!booking) {
    throw new DomainError('not_found');
  }
  if (booking.customerId !== params.customerId) {
    throw new DomainError('permission_denied');
  }

  if (booking.status !== 'draft') {
    return { paid: true, booking };
  }

  const payments = await deps.store.getPaymentsForBooking(booking.id);
  const latestPayment = payments[payments.length - 1];
  if (!latestPayment) {
    return { paid: false, booking };
  }

  const status = await deps.gateway.checkPaymentStatus({
    paymentId: latestPayment.id,
    provider: latestPayment.provider,
    providerRef: latestPayment.providerRef,
  });

  if (status.paid) {
    const res = await handlePaymentNotification(deps, {
      paymentId: latestPayment.id,
      providerRef: status.providerRef,
    });
    return { paid: true, booking: res.booking };
  }

  return { paid: false, booking };
}
