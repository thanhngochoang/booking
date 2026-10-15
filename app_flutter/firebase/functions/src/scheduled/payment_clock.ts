import * as logger from 'firebase-functions/logger';
import {
  runPaymentSweeps,
  type BookingDeps,
  type PaymentSweepExtras,
  type PaymentSweepResults,
  type RefundSubjects,
} from '@photobooking/domain';
import { liveBookingDeps } from '../infra/live_booking.js';
import { liveRefundSubjects } from '../infra/live_refunds.js';

export interface PaymentClockExtras {
  readonly refundSubjects?: RefundSubjects;
}

/**
 * `paymentClock` (every 5 minutes, payments spec §3.3): reconciles open payments with the provider,
 * expires the QRs past `expiresAt` (refunding what they received) and re-sends pending refunds.
 * Logs the counts only, never a payment, a body or a payer; a failure is logged by its error kind and rethrown.
 */
export async function handlePaymentClock(
  deps: BookingDeps = liveBookingDeps(),
  extras: PaymentClockExtras = { refundSubjects: liveRefundSubjects() },
): Promise<PaymentSweepResults> {
  let results: PaymentSweepResults;
  try {
    const sweepExtras: PaymentSweepExtras = {
      ...(extras.refundSubjects !== undefined ? { refundSubjects: extras.refundSubjects } : {}),
    };
    results = await runPaymentSweeps(deps, sweepExtras);
  } catch (e) {
    logger.error('paymentClock failed', e instanceof Error ? { name: e.name } : {});
    throw e;
  }
  const { reconciled, expired, refunded, refundsResent, reconcileFailed, expireFailed, resendFailed, skippedRefunds } = results;
  logger.info('paymentClock completed', {
    reconciled,
    expired,
    refunded,
    refundsResent,
    reconcileFailed,
    expireFailed,
    resendFailed,
    skippedRefunds,
  });
  return results;
}

