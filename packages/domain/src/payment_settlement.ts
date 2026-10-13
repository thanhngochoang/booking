/**
 * Cross-subject payment settlement domain logic and pure helpers.
 */

import { PAYMENT_EXPIRY_MINUTES } from './booking_policy.js';
import type {
  PaymentGateway,
  TransferNotification,
  TransferOutcome,
  TransferRecord,
} from './booking_ports.js';
import { DomainError } from './errors.js';
import type {
  LedgerEntry,
  Payment,
  PaymentSubject,
  Refund,
} from './escrow.js';
import type { Clock } from './ports.js';
import type { SubjectSettler } from './payment_ports.js';
import { transferRefund } from './refunds.js';
import { decideTransfer, type TransferDecision } from './transfer_rules.js';

export interface PaymentLookup {
  getPayment(id: string): Promise<Payment | null>;
  /** Every payment with this transferCode, any subject and status. */
  findPaymentsByTransferCode(code: string): Promise<readonly Payment[]>;
  getTransferRecord(id: string): Promise<TransferRecord | null>;
  /** Stores a `needs_review` record (no payment matched); a second call with the same id is a no-op. */
  saveUnmatchedTransfer(record: TransferRecord): Promise<void>;
  /** `created` payments with a method (checkout payments) of any subject, createdAt <= createdBefore. */
  findPaymentsToReconcile(createdBefore: Date, limit?: number): Promise<readonly Payment[]>;
  /** The same set with expiresAt <= now. */
  findOverduePayments(now: Date, limit?: number): Promise<readonly Payment[]>;
}

export interface SettlementDeps {
  readonly payments: PaymentLookup;
  readonly gateway: PaymentGateway;
  readonly clock: Clock;
  /** Required. booking and event_registration are registered like any other subject (Decision 1). */
  readonly subjects: Readonly<Partial<Record<PaymentSubject, SubjectSettler>>>;
}

export interface TransferResult {
  readonly outcome: TransferOutcome;
  readonly paymentId?: string;
}

/** The id of a transfer's record: the provider's transaction id, namespaced by provider. */
export const transferRecordId = (n: Pick<TransferNotification, 'provider' | 'txnId'>): string =>
  `${n.provider}_${n.txnId}`;

/**
 * Builds a TransferRecord for an handled transfer.
 */
export function transferRecordOf(
  n: TransferNotification,
  outcome: Exclude<TransferOutcome, 'duplicate'>,
  paymentId?: string,
): TransferRecord {
  return {
    id: transferRecordId(n),
    provider: n.provider,
    txnId: n.txnId,
    ...(n.raw !== undefined ? { raw: n.raw } : {}),
    receivedAt: n.receivedAt,
    outcome,
    ...(paymentId !== undefined ? { paymentId } : {}),
  };
}

/**
 * Pure: what one transfer does to a payment (#129's decideTransfer) and its received-ledger entry.
 * - `expiresAt` = `payment.expiresAt ?? createdAt + PAYMENT_EXPIRY_MINUTES` (as today);
 *   `decision = decideTransfer({status, amount, receivedBefore: receivedAmount ?? 0, expiresAt, transferAmount, receivedAt})`.
 * - `ledgerEntry`: type `ticket_received` when `subjectType === 'event_registration'`, else `payment_received`;
 *   `accountOwnerId 'platform_escrow'`, `amount = transfer.amount`, `note = \`Payment for ${subjectType} ${subjectId}\``, `at = now`.
 * - `partial` → `{...payment, receivedAmount: decision.received, updatedAt}`;
 *   `paid` → `status 'paid'`, `escrowStatus 'held'`, `receivedAmount = amount`, `paidAt = updatedAt = now`;
 *   `refund` → payment unchanged.
 * - `excess` = `decision.kind === 'paid' ? decision.excess : 0`.
 */
export function applyTransfer(p: {
  payment: Payment;
  transfer: TransferNotification;
  ledgerEntryId: string;
  now: Date;
}): {
  payment: Payment;
  ledgerEntry: LedgerEntry;
  decision: TransferDecision;
  excess: number;
} {
  const expiresAt =
    p.payment.expiresAt ??
    new Date(Date.parse(p.payment.createdAt) + PAYMENT_EXPIRY_MINUTES * 60_000).toISOString();
  const decision = decideTransfer({
    status: p.payment.status,
    amount: p.payment.amount,
    receivedBefore: p.payment.receivedAmount ?? 0,
    expiresAt,
    transferAmount: p.transfer.amount,
    receivedAt: p.transfer.receivedAt,
  });

  const ledgerType = p.payment.subjectType === 'event_registration' ? 'ticket_received' : 'payment_received';
  const ledgerEntry: LedgerEntry = {
    id: p.ledgerEntryId,
    type: ledgerType,
    paymentId: p.payment.id,
    subjectType: p.payment.subjectType,
    subjectId: p.payment.subjectId,
    accountOwnerId: 'platform_escrow',
    amount: p.transfer.amount,
    note: `Payment for ${p.payment.subjectType} ${p.payment.subjectId}`,
    at: p.now.toISOString(),
  };

  const excess = decision.kind === 'paid' ? decision.excess : 0;
  const nowIso = p.now.toISOString();

  let updatedPayment = p.payment;
  if (decision.kind === 'partial') {
    updatedPayment = {
      ...p.payment,
      receivedAmount: decision.received,
      updatedAt: nowIso,
    };
  } else if (decision.kind === 'paid') {
    updatedPayment = {
      ...p.payment,
      status: 'paid',
      escrowStatus: 'held',
      receivedAmount: p.payment.amount,
      paidAt: nowIso,
      updatedAt: nowIso,
    };
  }

  return {
    payment: updatedPayment,
    ledgerEntry,
    decision,
    excess,
  };
}

/**
 * Pure: an open payment nobody finished paying → expired, escrow refunded,
 * refund of receivedAmount (underpaid_expired) if > 0.
 * Throws DomainError('conflict') unless status === 'created'.
 */
export function expireUnpaid(p: {
  payment: Payment;
  refundId: string;
  ledgerEntryId: string;
  now: Date;
}): {
  payment: Payment;
  refund: Refund | null;
  ledgerEntry: LedgerEntry | null;
} {
  if (p.payment.status !== 'created') {
    throw new DomainError('conflict');
  }

  const nowIso = p.now.toISOString();
  const expiredPayment: Payment = {
    ...p.payment,
    status: 'expired',
    escrowStatus: 'refunded',
    updatedAt: nowIso,
  };

  const received = p.payment.receivedAmount ?? 0;
  if (received <= 0) {
    return {
      payment: expiredPayment,
      refund: null,
      ledgerEntry: null,
    };
  }

  const { refund, ledgerEntry } = transferRefund({
    payment: p.payment,
    refundId: p.refundId,
    ledgerEntryId: p.ledgerEntryId,
    amount: received,
    reason: 'underpaid_expired',
    now: p.now,
  });

  return {
    payment: expiredPayment,
    refund,
    ledgerEntry,
  };
}
