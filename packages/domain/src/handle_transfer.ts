/**
 * Incoming bank transfers for booking payments (payments spec §3.3, #129 Decisions 5–9):
 * match the memo to a payment, apply the mis-transfer table, keep the ledger balanced, and make a
 * repeated notification (webhook retry, reconciliation) a no-op.
 */

import type { Booking } from './booking.js';
import type {
  BookingDeps,
  BookingTx,
  TransferNotification,
  TransferOutcome,
} from './booking_ports.js';
import { moveDraftToRequested, refundLatePayment } from './booking_payment_paths.js';
import { DomainError } from './errors.js';
import type { Payment, Refund, StoredBankAccount } from './escrow.js';
import { payerAccountOf } from './payer_account.js';
import { dispatchRefunds, transferRefund } from './refunds.js';

import {
  applyTransfer as applyTransferPure,
  type TransferResult,
  transferRecordId,
} from './payment_settlement.js';

export { type TransferResult, transferRecordId };

/**
 * Applies one matched transfer inside the transaction: records it as `payment_received`, then
 * pays, keeps the running total, or refunds, per `decideTransfer`. The caller has read the payment
 * and booking; the one read left is the payee's `acceptsOrders` on the paid path, made through
 * `deps.providers` (not a transaction read, so not part of the transaction's snapshot), possibly
 * after an overpayment refund is staged.
 * Returns the outcome and the refunds to dispatch after the transaction.
 */
async function applyTransfer(
  tx: BookingTx,
  deps: BookingDeps,
  payment: Payment,
  booking: Booking | null,
  n: TransferNotification,
  captured: StoredBankAccount | null,
  now: Date,
): Promise<{ readonly outcome: Exclude<TransferOutcome, 'duplicate' | 'needs_review'>; readonly refunds: Refund[] }> {
  const { payment: stepPayment, ledgerEntry, decision, excess } = applyTransferPure({
    payment,
    transfer: n,
    ledgerEntryId: deps.ids.newId(),
    now,
  });

  await tx.addLedgerEntry(ledgerEntry);

  let current: Payment = payment;
  const refunds: Refund[] = [];

  const addTransferRefund = async (amount: number, reason: Parameters<typeof transferRefund>[0]['reason']) => {
    const { refund, ledgerEntry: refundLedger, payment: nextPayment } = transferRefund({
      payment: current,
      refundId: deps.ids.newId(),
      ledgerEntryId: deps.ids.newId(),
      amount,
      reason,
      destination: captured ?? current.payer,
      providerRef: n.txnId,
      now,
    });
    current = nextPayment;
    await tx.addRefund(refund);
    await tx.addLedgerEntry(refundLedger);
    refunds.push(refund);
  };

  switch (decision.kind) {
    case 'partial':
      // The first sender that counts toward the payment is kept as its payer (V2 Decision 2).
      current = { ...stepPayment, payer: payment.payer ?? captured };
      await tx.setPayment(current);
      return { outcome: 'partial', refunds: [] };

    case 'refund':
      // The whole transfer goes back; the payment's refundedAmount is updated, payer unchanged.
      await addTransferRefund(n.amount, decision.reason);
      current = { ...current, updatedAt: now.toISOString() };
      await tx.setPayment(current);
      return { outcome: 'refunded', refunds };

    case 'paid': {
      current = { ...stepPayment, payer: payment.payer ?? captured };
      if (excess > 0) await addTransferRefund(excess, 'overpaid_excess');
      if (!booking || booking.status !== 'draft') {
        const late = await refundLatePayment(tx, deps, current, now);
        refunds.push(late.refund);
        return { outcome: 'refunded', refunds };
      }
      const accepts = await deps.providers.acceptsOrders(payment.payeeId);
      if (!accepts) {
        const late = await refundLatePayment(tx, deps, current, now, 'provider_not_accepting');
        refunds.push(late.refund);
        return { outcome: 'refunded', refunds };
      }
      await tx.setPayment(current);
      await moveDraftToRequested(tx, deps, booking, current, now);
      return { outcome: excess > 0 ? 'paid_with_refund' : 'paid', refunds };
    }
  }
}

import type { BookingStore } from './booking_ports.js';
import { expireOpenPayment } from './booking_payment_paths.js';
import type { SubjectSettler } from './payment_ports.js';
import {
  type PaymentLookup,
  type SettlementDeps,
  settleTransfer,
  transferRecordOf,
} from './payment_settlement.js';

export class BookingPaymentSettler implements SubjectSettler {
  constructor(private readonly deps: BookingDeps) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    const recordId = transferRecordId(transfer);
    // Encrypted before the transaction; a cipher failure fails the notification (provider retries).
    const captured = await payerAccountOf(this.deps.cipher, transfer.payer);
    const now = this.deps.clock.now();
    let pending: Refund[] = [];
    let provider: Payment['provider'] = this.deps.gateway.provider;

    const outcome = await this.deps.store.runTransaction(async (tx): Promise<Exclude<TransferOutcome, 'needs_review'>> => {
      pending = [];
      const seen = await tx.getTransferRecord(recordId);
      if (seen) return 'duplicate';

      const payment = await tx.getPayment(paymentId);
      if (!payment || payment.subjectType !== 'booking') throw new DomainError('not_found');
      provider = payment.provider;
      const booking = await tx.getBooking(payment.subjectId);

      const applied = await applyTransfer(tx, this.deps, payment, booking, transfer, captured, now);
      await tx.saveTransferRecord(transferRecordOf(transfer, applied.outcome, payment.id));
      pending = applied.refunds;
      return applied.outcome;
    });

    if (outcome !== 'duplicate' && pending.length > 0) {
      await Promise.all(pending.map((r) => this.dispatchRefund(r, { provider } as Payment)));
    }

    return outcome;
  }

  async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
    let refund: Refund | undefined;
    let provider: Payment['provider'] = this.deps.gateway.provider;
    const expired = await this.deps.store.runTransaction(async (tx) => {
      refund = undefined;
      const current = await tx.getPayment(paymentId);
      if (!current || current.subjectType !== 'booking' || current.status !== 'created' || !current.expiresAt) {
        return false;
      }
      if (Date.parse(current.expiresAt) > now.getTime()) return false;
      provider = current.provider;
      refund = await expireOpenPayment(tx, this.deps, current, now);
      return true;
    });

    if (!expired) return 'unchanged';
    if (refund) {
      await this.dispatchRefund(refund, { provider } as Payment);
    }
    return 'expired';
  }

  async dispatchRefund(refund: Refund, payment: Payment): Promise<Refund> {
    const res = await dispatchRefunds(this.deps, [{ refund, provider: payment.provider }]);
    return res[0] ?? refund;
  }

  async statusOf(payment: Payment): Promise<string> {
    const booking = await this.deps.store.getBooking(payment.subjectId);
    return booking?.status ?? 'gone';
  }
}

export function bookingPaymentLookup(store: BookingStore): PaymentLookup {
  return {
    getPayment: (id) => store.getPayment(id),
    findPaymentsByTransferCode: (code) => store.findPaymentsByTransferCode(code),
    getTransferRecord: (id) => store.getTransferRecord(id),
    saveUnmatchedTransfer: async (record) => {
      await store.runTransaction(async (tx) => {
        const seen = await tx.getTransferRecord(record.id);
        if (!seen) await tx.saveTransferRecord(record);
      });
    },
    findPaymentsToReconcile: (createdBefore, limit) => store.findPaymentsToReconcile(createdBefore, limit),
    findOverduePayments: (now, limit) => store.findOverduePayments(now, limit),
  };
}

export function bookingSettlement(deps: BookingDeps): SettlementDeps {
  return {
    payments: bookingPaymentLookup(deps.store),
    gateway: deps.gateway,
    clock: deps.clock,
    subjects: {
      booking: new BookingPaymentSettler(deps),
    },
  };
}

export function asSettlement(deps: SettlementDeps | BookingDeps): SettlementDeps {
  return 'subjects' in deps ? (deps as SettlementDeps) : bookingSettlement(deps as BookingDeps);
}

/**
 * Handles one transfer the provider reports (already authenticated by the adapter).
 * Wrapper around settleTransfer using bookingSettlement.
 */
export async function handleTransferNotification(deps: BookingDeps, n: TransferNotification): Promise<TransferResult> {
  return settleTransfer(bookingSettlement(deps), n);
}

/** The payment if `customerId` is its payer: `not_found` / `permission_denied` otherwise. */
export async function assertPaymentPayer(deps: BookingDeps, paymentId: string, customerId: string): Promise<Payment> {
  const payment = await deps.store.getPayment(paymentId);
  if (!payment) throw new DomainError('not_found');
  if (payment.payerId !== customerId) throw new DomainError('permission_denied');
  return payment;
}

/**
 * "Kiểm tra lại" on S04.04: asks the provider for transfers to the booking's current payment and
 * handles each one (repeats are no-ops). `paid` is true once the booking has left `draft`.
 */
export async function checkPayment(
  deps: BookingDeps,
  input: { readonly bookingId: string; readonly customerId: string },
): Promise<{ readonly paid: boolean; readonly booking: Booking | null }> {
  const booking = await deps.store.getBooking(input.bookingId);
  if (!booking) throw new DomainError('not_found');
  if (booking.customerId !== input.customerId) throw new DomainError('permission_denied');
  if (booking.status !== 'draft') return { paid: true, booking };

  const paymentId = booking.checkout?.paymentId;
  const payment = paymentId ? await deps.store.getPayment(paymentId) : null;
  if (!payment || payment.status !== 'created' || !payment.transferCode) return { paid: false, booking };

  const transfers = await deps.gateway.queryTransfers({
    paymentId: payment.id,
    transferCode: payment.transferCode,
    providerRef: payment.providerRef,
  });
  for (const n of transfers) await handleTransferNotification(deps, n);

  const after = await deps.store.getBooking(booking.id);
  return { paid: after !== null && after.status !== 'draft', booking: after };
}
