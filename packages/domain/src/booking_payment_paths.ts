/**
 * Transaction steps shared by the booking payment use cases (transfer handling, createPayment, the
 * payment sweep). Internal: not exported from index.ts.
 * Callers do every transaction read before calling these (they only write).
 */

import type { Booking } from './booking.js';
import { computeAcceptDeadline, parseVnDateTime } from './booking_policy.js';
import type { BookingDeps, BookingTx } from './booking_ports.js';
import { applyRefundToPayment, type LedgerEntry, type Payment, type Refund } from './escrow.js';
import { transferRefund } from './refunds.js';

/** The payment reached its amount: `paid`, escrow `held`. */
export function markPaid(payment: Payment, now: Date, providerRef?: string): Payment {
  const at = now.toISOString();
  return {
    ...payment,
    status: 'paid',
    escrowStatus: 'held',
    providerRef: providerRef ?? payment.providerRef,
    paidAt: at,
    updatedAt: at,
  };
}

/** The `payment_received` ledger entry for `amount` VND that reached the platform escrow. */
export function paymentReceivedEntry(deps: BookingDeps, payment: Payment, amount: number, now: Date): LedgerEntry {
  return {
    id: deps.ids.newId(),
    type: 'payment_received',
    paymentId: payment.id,
    subjectType: 'booking',
    subjectId: payment.subjectId,
    accountOwnerId: 'platform_escrow',
    amount,
    note: `Payment for booking ${payment.subjectId}`,
    at: now.toISOString(),
  };
}

/** Normal path: the paid draft becomes `requested` with its accept deadline, escrow `held`, one booking event. */
export async function moveDraftToRequested(
  tx: BookingTx,
  deps: BookingDeps,
  booking: Booking,
  payment: Payment,
  now: Date,
): Promise<Booking> {
  const acceptDeadline = computeAcceptDeadline(now, parseVnDateTime(booking.day, booking.start));
  const updated: Booking = {
    ...booking,
    status: 'requested',
    depositProvider: payment.provider,
    depositPaidAt: now.toISOString(),
    acceptDeadline: acceptDeadline.toISOString(),
    escrowStatus: 'held',
    version: booking.version + 1,
    updatedAt: now.toISOString(),
  };
  await tx.setBooking(updated);
  await tx.addBookingEvent({
    id: deps.ids.newId(),
    bookingId: booking.id,
    status: 'requested',
    at: now.toISOString(),
  });
  return updated;
}

/**
 * Late path: a paid payment whose draft is gone or no longer a draft is refunded in full
 * (`late_payment_draft_expired`). Writes the refunded payment, the refund and its ledger entry;
 * the caller dispatches the refund after the transaction.
 */
export async function refundLatePayment(
  tx: BookingTx,
  deps: BookingDeps,
  paid: Payment,
  now: Date,
): Promise<{ readonly payment: Payment; readonly refund: Refund }> {
  const r = applyRefundToPayment({
    payment: paid,
    refundId: deps.ids.newId(),
    percent: 100,
    ledgerEntryId: deps.ids.newId(),
    reason: 'late_payment_draft_expired',
    now,
  });
  await tx.setPayment(r.payment);
  await tx.addRefund(r.refund);
  await tx.addLedgerEntry(r.ledgerEntry);
  return { payment: r.payment, refund: r.refund };
}

/**
 * An open payment that nobody finished paying (its QR expired or was replaced): `expired`, escrow
 * `refunded` (nothing is held), and what it had received goes back (`underpaid_expired`).
 * Returns that refund, if any, for the caller to dispatch after the transaction.
 */
export async function expireOpenPayment(
  tx: BookingTx,
  deps: BookingDeps,
  payment: Payment,
  now: Date,
): Promise<Refund | undefined> {
  await tx.setPayment({ ...payment, status: 'expired', escrowStatus: 'refunded', updatedAt: now.toISOString() });
  const received = payment.receivedAmount ?? 0;
  if (received <= 0) return undefined;
  const { refund, ledgerEntry } = transferRefund({
    payment,
    refundId: deps.ids.newId(),
    ledgerEntryId: deps.ids.newId(),
    amount: received,
    reason: 'underpaid_expired',
    now,
  });
  await tx.addRefund(refund);
  await tx.addLedgerEntry(ledgerEntry);
  return refund;
}
