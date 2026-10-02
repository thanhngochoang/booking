/**
 * Payment confirmation and notification handlers.
 * Handles duplicate payments, late payments on cleaned-up drafts, and deposit checking.
 */

import type { Booking } from './booking.js';
import { computeAcceptDeadline, parseVnDateTime } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { DomainError } from './errors.js';
import { createDepositPayment, applyRefundToPayment, type Payment, type Refund } from './escrow.js';
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

    // Case: Late payment after draft clean up or cancellation -> 100% refund immediately
    if (!booking || booking.status !== 'draft') {
      const depositPayment = createDepositPayment({
        paymentId: payment.id,
        bookingId: payment.subjectId,
        customerId: payment.payerId,
        photographerId: payment.payeeId,
        provider: payment.provider,
        amount: payment.amount,
        idempotencyKey: payment.idempotencyKey,
        providerRef: params.providerRef ?? payment.providerRef,
        ledgerEntryId: deps.ids.newId(),
        now,
      });

      await tx.setPayment(depositPayment.payment);
      await tx.addLedgerEntry(depositPayment.ledgerEntry);

      // Issue 100% refund
      const refundResult = applyRefundToPayment({
        payment: depositPayment.payment,
        refundId: deps.ids.newId(),
        percent: 100,
        ledgerEntryId: deps.ids.newId(),
        reason: 'late_payment_draft_expired',
        now,
      });

      await tx.setPayment(refundResult.payment);
      await tx.addRefund(refundResult.refund);
      await tx.addLedgerEntry(refundResult.ledgerEntry);

      pendingRefund = { refund: refundResult.refund, provider: payment.provider };

      return {
        payment: refundResult.payment,
        booking: null,
        refunded: true,
        refund: refundResult.refund,
      };
    }

    // Normal case: Move booking from draft to requested
    const startsAt = parseVnDateTime(booking.day, booking.start);
    const acceptDeadline = computeAcceptDeadline(now, startsAt);

    const updatedPayment: Payment = {
      ...payment,
      status: 'paid',
      escrowStatus: 'held',
      providerRef: params.providerRef ?? payment.providerRef,
      paidAt: now.toISOString(),
      updatedAt: now.toISOString(),
    };

    await tx.setPayment(updatedPayment);
    await tx.addLedgerEntry({
      id: deps.ids.newId(),
      type: 'deposit_received',
      paymentId: payment.id,
      subjectType: 'booking',
      subjectId: booking.id,
      accountOwnerId: 'platform_escrow',
      amount: payment.amount,
      note: `Deposit for booking ${booking.id}`,
      at: now.toISOString(),
    });

    const updatedBooking: Booking = {
      ...booking,
      status: 'requested',
      depositProvider: payment.provider,
      depositPaidAt: now.toISOString(),
      acceptDeadline: acceptDeadline.toISOString(),
      escrowStatus: 'held',
      version: booking.version + 1,
      updatedAt: now.toISOString(),
    };

    await tx.setBooking(updatedBooking);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: booking.id,
      status: 'requested',
      at: now.toISOString(),
    });

    return {
      payment: updatedPayment,
      booking: updatedBooking,
      refunded: false,
    };
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
