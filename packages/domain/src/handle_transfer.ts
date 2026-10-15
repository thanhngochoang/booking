/**
 * Incoming bank transfers for booking payments (payments spec §3.3, #129 Decisions 5–9):
 * match the memo to a payment, apply the mis-transfer table, keep the ledger balanced, and make a
 * repeated notification (webhook retry, reconciliation) a no-op.
 */

import type { Booking } from './booking.js';
import { PAYMENT_EXPIRY_MINUTES } from './booking_policy.js';
import type {
  BookingDeps,
  BookingTx,
  TransferNotification,
  TransferOutcome,
  TransferRecord,
} from './booking_ports.js';
import { markPaid, moveDraftToRequested, paymentReceivedEntry, refundLatePayment } from './booking_payment_paths.js';
import { DomainError } from './errors.js';
import type { Payment, Refund, StoredBankAccount } from './escrow.js';
import { payerAccountOf } from './payer_account.js';
import { transferCodesIn } from './payment_code.js';
import { dispatchRefunds, transferRefund } from './refunds.js';
import { decideTransfer } from './transfer_rules.js';

export interface TransferResult {
  readonly outcome: TransferOutcome;
  readonly paymentId?: string;
}

/** The id of a transfer's record: the provider's transaction id, namespaced by provider. */
export const transferRecordId = (n: Pick<TransferNotification, 'provider' | 'txnId'>): string =>
  `${n.provider}_${n.txnId}`;

function validNotification(n: TransferNotification): boolean {
  return (
    typeof n.txnId === 'string' &&
    n.txnId.length > 0 &&
    Number.isInteger(n.amount) &&
    n.amount > 0 &&
    typeof n.content === 'string' &&
    typeof n.receivedAt === 'string' &&
    !Number.isNaN(Date.parse(n.receivedAt))
  );
}

/**
 * The payment a memo names: the first transfer code in it that belongs to a booking payment
 * created no later than the transfer was received (a transfer never pays a payment that did not
 * exist yet). Codes are unique across payments (createPayment); for older data sharing a code,
 * the open one wins, else the most recently created.
 */
async function matchPayment(deps: BookingDeps, content: string, receivedAt: string): Promise<Payment | null> {
  const receivedMs = Date.parse(receivedAt);
  for (const code of transferCodesIn(content)) {
    const candidates = (await deps.store.findPaymentsByTransferCode(code)).filter(
      (p) => p.subjectType === 'booking' && Date.parse(p.createdAt) <= receivedMs,
    );
    if (candidates.length === 0) continue;
    const open = candidates.find((p) => p.status === 'created');
    if (open) return open;
    return [...candidates].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))[0] ?? null;
  }
  return null;
}

/**
 * Applies one matched transfer inside the transaction (all reads already done): records it as
 * `payment_received`, then pays, keeps the running total, or refunds, per `decideTransfer`.
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
  const expiresAt =
    payment.expiresAt ?? new Date(Date.parse(payment.createdAt) + PAYMENT_EXPIRY_MINUTES * 60_000).toISOString();
  const decision = decideTransfer({
    status: payment.status,
    amount: payment.amount,
    receivedBefore: payment.receivedAmount ?? 0,
    expiresAt,
    transferAmount: n.amount,
    receivedAt: n.receivedAt,
  });

  await tx.addLedgerEntry(paymentReceivedEntry(deps, payment, n.amount, now));

  let current: Payment = payment;
  const refunds: Refund[] = [];

  const addTransferRefund = async (amount: number, reason: Parameters<typeof transferRefund>[0]['reason']) => {
    const { refund, ledgerEntry, payment: nextPayment } = transferRefund({
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
    await tx.addLedgerEntry(ledgerEntry);
    refunds.push(refund);
  };

  switch (decision.kind) {
    case 'partial':
      current = {
        ...current,
        receivedAmount: decision.received,
        payer: current.payer ?? captured,
        updatedAt: now.toISOString(),
      };
      await tx.setPayment(current);
      return { outcome: 'partial', refunds: [] };

    case 'refund':
      // The whole transfer goes back; the payment's refundedAmount is updated, payer unchanged.
      await addTransferRefund(n.amount, decision.reason);
      current = {
        ...current,
        updatedAt: now.toISOString(),
      };
      await tx.setPayment(current);
      return { outcome: 'refunded', refunds };

    case 'paid': {
      current = markPaid(
        {
          ...current,
          receivedAmount: payment.amount,
          payer: current.payer ?? captured,
        },
        now,
      );
      if (decision.excess > 0) {
        await addTransferRefund(decision.excess, 'overpaid_excess');
      }
      if (!booking || booking.status !== 'draft') {
        const late = await refundLatePayment(tx, deps, current, now);
        refunds.push(late.refund);
        return { outcome: 'refunded', refunds };
      }
      await tx.setPayment(current);
      await moveDraftToRequested(tx, deps, booking, current, now);
      return { outcome: decision.excess > 0 ? 'paid_with_refund' : 'paid', refunds };
    }
  }
}

/**
 * Handles one transfer the provider reports (already authenticated by the adapter):
 * - seen before (same `${provider}_${txnId}`): `duplicate`, nothing changes;
 * - no transfer code in the memo names a payment: stored as `needs_review`, nothing else changes;
 * - otherwise the mis-transfer table (`decideTransfer`): `paid` / `paid_with_refund` / `partial` /
 *   `refunded`. The transfer record is written in the same transaction as the payment and ledger,
 *   and refunds are sent to the gateway afterwards (`refundId` is the idempotency key).
 */
export async function handleTransferNotification(deps: BookingDeps, n: TransferNotification): Promise<TransferResult> {
  if (!validNotification(n)) throw new DomainError('invalid_argument');
  const recordId = transferRecordId(n);

  const known = await deps.store.getTransferRecord(recordId);
  if (known) return { outcome: 'duplicate', ...(known.paymentId ? { paymentId: known.paymentId } : {}) };

  const captured = await payerAccountOf(deps.cipher, n.payer);
  const matched = await matchPayment(deps, n.content, n.receivedAt);
  const now = deps.clock.now();
  let pending: Refund[] = [];

  const result = await deps.store.runTransaction(async (tx): Promise<TransferResult & { provider?: Payment['provider'] }> => {
    pending = [];
    const seen = await tx.getTransferRecord(recordId);
    if (seen) return { outcome: 'duplicate', ...(seen.paymentId ? { paymentId: seen.paymentId } : {}) };

    const payment = matched ? await tx.getPayment(matched.id) : null;
    const booking = payment ? await tx.getBooking(payment.subjectId) : null;

    const base: Omit<TransferRecord, 'outcome'> = {
      id: recordId,
      provider: n.provider,
      txnId: n.txnId,
      receivedAt: n.receivedAt,
      ...(n.raw !== undefined ? { raw: n.raw } : {}),
    };

    if (!payment) {
      await tx.saveTransferRecord({ ...base, outcome: 'needs_review' });
      return { outcome: 'needs_review' };
    }

    const applied = await applyTransfer(tx, deps, payment, booking, n, captured, now);
    await tx.saveTransferRecord({ ...base, outcome: applied.outcome, paymentId: payment.id });
    pending = applied.refunds;
    return { outcome: applied.outcome, paymentId: payment.id, provider: payment.provider };
  });

  // The transfer is recorded: a refund the gateway refuses or throws on is left `failed` for staff,
  // since a provider retry of this notification is a duplicate and would never re-send it.
  const provider = result.provider ?? n.provider;
  await dispatchRefunds(
    deps,
    pending.map((refund) => ({ refund, provider })),
  );

  return { outcome: result.outcome, ...(result.paymentId ? { paymentId: result.paymentId } : {}) };
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
