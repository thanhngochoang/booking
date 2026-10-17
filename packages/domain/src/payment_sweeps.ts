/**
 * Payment clock (every 5 minutes, payments spec §3.3):
 * 1. reconcile: ask the provider about `created` payments older than 3 minutes and handle every
 *    transfer it reports (a missed webhook); repeats are no-ops;
 * 2. expire: `created` payments past `expiresAt` become `expired` and what they received goes back;
 * 3. resend: refunds left `pending` (a gateway call threw) are sent again under the same refund id.
 */

import { PAYMENT_RECONCILE_AFTER_MINUTES } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { asSettlement, bookingDepsOf } from './handle_transfer.js';
import { type SettlementDeps, settleTransfer } from './payment_settlement.js';
import { resendPendingRefunds, type RefundSubjects } from './refund_subjects.js';

export interface PaymentSweepExtras {
  /** Handlers for refunds whose subject is not a booking (tickets, later subjects); see `liveRefundSubjects()`. */
  readonly refundSubjects?: RefundSubjects;
}

export interface PaymentSweepResults {
  /** Transfers found by reconciliation that were new (not duplicates). */
  readonly reconciled: number;
  /** Payments marked `expired`. */
  readonly expired: number;
  /** Expired payments whose received money was refunded (a refund the gateway refused stays `failed` for staff). */
  readonly refunded: number;
  /** Refunds left pending that were re-sent successfully. */
  readonly refundsResent: number;
  /** Provider queries or transfers that threw; the next run retries them. */
  readonly reconcileFailed: number;
  /** Expiries whose transaction threw (the next run retries them), or whose refund result could not be recorded. */
  readonly expireFailed: number;
  /** Pending refunds whose re-send threw. */
  readonly resendFailed: number;
  /** Pending refunds skipped because no subject handler was registered. */
  readonly skippedRefunds: number;
}

export async function runPaymentSweeps(
  raw: SettlementDeps | BookingDeps,
  extras?: PaymentSweepExtras,
): Promise<PaymentSweepResults> {
  const deps = asSettlement(raw);
  const now = deps.clock.now();

  // 1. Reconcile: one failing payment or transfer is counted and skipped, never stops the batch.
  let reconciled = 0;
  let reconcileFailed = 0;
  const cutoff = new Date(now.getTime() - PAYMENT_RECONCILE_AFTER_MINUTES * 60_000);
  for (const p of await deps.payments.findPaymentsToReconcile(cutoff)) {
    if (!p.transferCode) continue;
    if (!deps.subjects[p.subjectType]) continue;

    let transfers: Awaited<ReturnType<SettlementDeps['gateway']['queryTransfers']>>;
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
        const res = await settleTransfer(deps, n);
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
  for (const p of await deps.payments.findOverduePayments(now)) {
    const settler = deps.subjects[p.subjectType];
    if (!settler) continue;

    try {
      const outcome = await settler.expire(p.id, now);
      if (outcome === 'expired') {
        expired += 1;
        if ((p.receivedAmount ?? 0) > 0) {
          refunded += 1;
        }
      }
    } catch {
      expireFailed += 1;
    }
  }

  // 3. Re-send pending refunds: wrapped so a query failure counts as resendFailed and never fails the sweep.
  let refundsResent = 0;
  let resendFailed = 0;
  let skippedRefunds = 0;
  // Every subject's refunds live in the booking store's refunds collection; it is reached through
  // the booking settler's deps (the booking deps themselves when the caller passed BookingDeps).
  const bookingDeps = bookingDepsOf(raw);
  if (bookingDeps) {
    try {
      const res = await resendPendingRefunds(bookingDeps, extras?.refundSubjects);
      refundsResent = res.resent;
      resendFailed = res.failed;
      skippedRefunds = res.skipped;
    } catch {
      resendFailed += 1;
    }
  }

  return {
    reconciled,
    expired,
    refunded,
    refundsResent,
    reconcileFailed,
    expireFailed,
    resendFailed,
    skippedRefunds,
  };
}
