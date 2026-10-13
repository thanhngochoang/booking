import * as logger from 'firebase-functions/logger';
import { runPaymentSweeps, type BookingDeps, type PaymentSweepResults, type SettlementDeps } from '@photobooking/domain';
import { liveSettlementDeps } from '../infra/live_payments.js';

/**
 * `paymentClock` (every 5 minutes, payments spec §3.3): reconciles open payments with the provider
 * and expires the QRs past `expiresAt` (refunding what they received). Logs the counts only, never
 * a payment, a body or a payer; a failure is logged by its error kind and rethrown.
 */
export async function handlePaymentClock(deps: SettlementDeps | BookingDeps = liveSettlementDeps()): Promise<PaymentSweepResults> {
  let results: PaymentSweepResults;
  try {
    results = await runPaymentSweeps(deps);
  } catch (e) {
    logger.error('paymentClock failed', e instanceof Error ? { name: e.name } : {});
    throw e;
  }
  const { reconciled, expired, refunded, reconcileFailed, expireFailed } = results;
  logger.info('paymentClock completed', { reconciled, expired, refunded, reconcileFailed, expireFailed });
  return results;
}
