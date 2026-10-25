import * as logger from 'firebase-functions/logger';
import {
  bookingDepsOf,
  runPaymentSweeps,
  type BookingDeps,
  type PaymentSweepExtras,
  type PaymentSweepResults,
  type RefundAccountDeps,
  type RefundSubjects,
  type SettlementDeps,
} from '@photobooking/domain';
import { liveSettlementDeps } from '../infra/live_payments.js';
import { liveRefundAccountDeps } from '../infra/live_refund_account.js';
import { liveRefundSubjects } from '../infra/live_refunds.js';

export interface PaymentClockExtras {
  readonly refundSubjects?: RefundSubjects;
  /**
   * #141: the deps of the `confirmDueRefundAccounts` step (S22.04's 24-hour default). Absent: built
   * around the booking settler's deps (the refunds' store), with the live ticket and dispute deps.
   */
  readonly refundAccounts?: RefundAccountDeps;
}

/**
 * `paymentClock` (every 5 minutes, payments spec §3.3): reconciles open payments with the provider,
 * expires the QRs past `expiresAt` (refunding what they received), re-sends pending refunds and,
 * last (#141), sends refunds still waiting for an account past their 24 hours to the paying account.
 * Logs the counts only, never a payment, a body or a payer; a failure is logged by its error kind and rethrown.
 */
export async function handlePaymentClock(
  deps: SettlementDeps | BookingDeps = liveSettlementDeps(),
  extras: PaymentClockExtras = { refundSubjects: liveRefundSubjects() },
): Promise<PaymentSweepResults> {
  const bookingDeps = bookingDepsOf(deps);
  if (bookingDeps === null) {
    // Refunds are read through the booking settler's store; without it the re-send step does nothing.
    logger.warn('paymentClock refund re-send skipped', { reason: 'no_booking_settler' });
  }
  const refundAccounts =
    extras.refundAccounts ?? (bookingDeps !== null ? liveRefundAccountDeps({ bookings: bookingDeps }) : undefined);
  let results: PaymentSweepResults;
  try {
    const sweepExtras: PaymentSweepExtras = {
      ...(extras.refundSubjects !== undefined ? { refundSubjects: extras.refundSubjects } : {}),
      ...(refundAccounts !== undefined ? { refundAccounts } : {}),
    };
    results = await runPaymentSweeps(deps, sweepExtras);
  } catch (e) {
    logger.error('paymentClock failed', e instanceof Error ? { name: e.name } : {});
    throw e;
  }
  const {
    reconciled,
    expired,
    refunded,
    refundsResent,
    reconcileFailed,
    expireFailed,
    resendFailed,
    skippedRefunds,
    refundAccountsConfirmed,
    confirmFailed,
  } = results;
  logger.info('paymentClock completed', {
    reconciled,
    expired,
    refunded,
    refundsResent,
    reconcileFailed,
    expireFailed,
    resendFailed,
    skippedRefunds,
    refundAccountsConfirmed,
    confirmFailed,
  });
  return results;
}

