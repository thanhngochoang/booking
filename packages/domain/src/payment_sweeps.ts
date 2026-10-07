/**
 * Payment clock (every 5 minutes, payments spec §3.3):
 * 1. reconcile: ask the provider about `created` payments older than 3 minutes and handle every
 *    transfer it reports (a missed webhook); repeats are no-ops;
 * 2. expire: `created` payments past `expiresAt` become `expired` and what they received goes back.
 */

import { PAYMENT_RECONCILE_AFTER_MINUTES } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { expireOpenPayment } from './booking_payment_paths.js';
import type { Payment, Refund } from './escrow.js';
import { handleTransferNotification } from './handle_transfer.js';
import { dispatchRefunds } from './refunds.js';

export interface PaymentSweepResults {
  /** Transfers found by reconciliation that were new (not duplicates). */
  readonly reconciled: number;
  /** Payments marked `expired`. */
  readonly expired: number;
  /** Expired payments whose received money was refunded (a refund the gateway refused stays `failed` for staff). */
  readonly refunded: number;
  /** Provider queries or transfers that threw; the next run retries them. */
  readonly reconcileFailed: number;
  /** Expiries whose transaction threw (the next run retries them), or whose refund result could not be recorded. */
  readonly expireFailed: number;
}

/** Only checkout payments (with a transfer code) belong to this clock; tickets have their own. */
const isCheckoutPayment = (p: Payment): p is Payment & { readonly transferCode: string } =>
  p.subjectType === 'booking' && typeof p.transferCode === 'string';

export async function runPaymentSweeps(deps: BookingDeps): Promise<PaymentSweepResults> {
  const now = deps.clock.now();

  // 1. Reconcile: one failing payment or transfer is counted and skipped, never stops the batch.
  let reconciled = 0;
  let reconcileFailed = 0;
  const cutoff = new Date(now.getTime() - PAYMENT_RECONCILE_AFTER_MINUTES * 60_000);
  for (const p of await deps.store.findPaymentsToReconcile(cutoff)) {
    if (!isCheckoutPayment(p)) continue;
    let transfers: Awaited<ReturnType<BookingDeps['gateway']['queryTransfers']>>;
    try {
      transfers = await deps.gateway.queryTransfers({
        paymentId: p.id,
        transferCode: p.transferCode,
        providerRef: p.providerRef,
      });
    } catch {
      reconcileFailed += 1;
      continue;
    }
    for (const n of transfers) {
      try {
        const res = await handleTransferNotification(deps, n);
        if (res.outcome !== 'duplicate') reconciled += 1;
      } catch {
        reconcileFailed += 1;
      }
    }
  }

  // 2. Expire: same, per payment.
  let expired = 0;
  let refunded = 0;
  let expireFailed = 0;
  for (const p of await deps.store.findOverduePayments(now)) {
    if (!isCheckoutPayment(p)) continue;
    let refund: Refund | undefined;
    let done: boolean;
    try {
      done = await deps.store.runTransaction(async (tx) => {
        refund = undefined;
        const current = await tx.getPayment(p.id);
        if (!current || current.status !== 'created' || !current.expiresAt) return false;
        if (Date.parse(current.expiresAt) > now.getTime()) return false;
        refund = await expireOpenPayment(tx, deps, current, now);
        return true;
      });
    } catch {
      expireFailed += 1;
      continue;
    }
    if (!done) continue;
    expired += 1;
    if (refund) {
      refunded += 1;
      try {
        // Gateway errors are absorbed (refund left `failed`); only a store write can throw here.
        await dispatchRefunds(deps, [{ refund, provider: p.provider }]);
      } catch {
        expireFailed += 1;
      }
    }
  }

  return { reconciled, expired, refunded, reconcileFailed, expireFailed };
}
