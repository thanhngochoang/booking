/**
 * Use case: createDeposit
 * Customer initiates payment for the 30% deposit of a draft booking.
 */

import type { PaymentProvider } from './booking.js';
import type { BookingDeps } from './booking_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { requireCustomerPhone } from './require_phone.js';

export interface CreateDepositInput {
  readonly bookingId: string;
  readonly customerId: string;
  readonly provider: PaymentProvider;
  readonly returnUrl?: string;
}

export interface CreateDepositResult {
  readonly paymentId: string;
  readonly payUrl: string;
  readonly provider: PaymentProvider;
}

export async function createDeposit(
  deps: BookingDeps,
  input: CreateDepositInput,
): Promise<CreateDepositResult> {
  if (!isId(input.bookingId) || !isId(input.customerId)) {
    throw new DomainError('invalid_argument');
  }

  // 1. Phone check
  await requireCustomerPhone(deps.contacts, input.customerId);

  const now = deps.clock.now();

  return deps.store.runTransaction(async (tx) => {
    const booking = await tx.getBooking(input.bookingId);
    if (!booking) {
      throw new DomainError('not_found');
    }
    if (booking.customerId !== input.customerId) {
      throw new DomainError('permission_denied');
    }
    if (booking.status !== 'draft') {
      throw new DomainError('conflict');
    }

    // Availability must still be pending for this booking
    const day = await tx.getAvailabilityDay(booking.photographerId, booking.day);
    if (!day || day.state !== 'pending' || day.bookingId !== booking.id) {
      throw new DomainError('day_taken');
    }

    const idempotencyKey = `dep_${booking.id}_${input.provider}`;
    let payment = await tx.getPaymentByIdempotencyKey(idempotencyKey);

    if (!payment) {
      const paymentId = deps.ids.newId();
      const createdAt = now.toISOString();
      payment = {
        id: paymentId,
        subjectType: 'booking',
        subjectId: booking.id,
        payerId: booking.customerId,
        payeeId: booking.photographerId,
        provider: input.provider,
        amount: booking.deposit,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey,
        createdAt,
        updatedAt: createdAt,
      };
      await tx.setPayment(payment);
    }

    const intent = await deps.gateway.createDepositIntent({
      paymentId: payment.id,
      bookingId: booking.id,
      amount: payment.amount,
      provider: input.provider,
      returnUrl: input.returnUrl,
    });

    if (intent.providerRef && intent.providerRef !== payment.providerRef) {
      payment = {
        ...payment,
        providerRef: intent.providerRef,
        updatedAt: now.toISOString(),
      };
      await tx.setPayment(payment);
    }

    return {
      paymentId: payment.id,
      payUrl: intent.payUrl,
      provider: input.provider,
    };
  });
}
