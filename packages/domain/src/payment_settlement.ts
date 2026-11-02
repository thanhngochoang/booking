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
  PaymentStatus,
  PaymentSubject,
  Refund,
  StoredBankAccount,
} from './escrow.js';
import {
  FAKE_TRANSFER_KINDS,
  type FakeTransferKind,
  fakeTransferFor,
} from './fake_payment_gateway.js';
import { isId } from './ids.js';
import { transferCodesIn } from './payment_code.js';
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
  /** Where a bank-transfer refund goes; omitted → `payment.payer` (the first sender), null → none (awaiting_account). */
  destination?: StoredBankAccount | null;
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

  const { refund, ledgerEntry, payment: refunded } = transferRefund({
    payment: p.payment,
    refundId: p.refundId,
    ledgerEntryId: p.ledgerEntryId,
    amount: received,
    reason: 'underpaid_expired',
    destination: 'destination' in p ? p.destination : p.payment.payer,
    now: p.now,
  });

  return {
    payment: { ...expiredPayment, refundedAmount: refunded.refundedAmount },
    refund,
    ledgerEntry,
  };
}

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
 * Matches a transfer's content to a payment across subjects.
 * For each code in transferCodesIn(content), candidates = findPaymentsByTransferCode(code)
 * with createdAt <= receivedAt AND a settler for their subject, never an `awaiting_group` line.
 * Open payment wins, else the newest.
 */
async function matchPayment(
  deps: SettlementDeps,
  content: string,
  receivedAt: string,
): Promise<Payment | null> {
  const receivedMs = Date.parse(receivedAt);
  const codes = transferCodesIn(content);
  for (const code of codes) {
    const all = await deps.payments.findPaymentsByTransferCode(code);
    const candidates = all.filter(
      (p) =>
        // A group's line is never paid on its own (S30 Decision 6): its group payment is.
        p.status !== 'awaiting_group' &&
        Date.parse(p.createdAt) <= receivedMs &&
        deps.subjects[p.subjectType] !== undefined,
    );
    if (candidates.length === 0) continue;
    const open = candidates.find((p) => p.status === 'created');
    if (open) return open;
    return [...candidates].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))[0] ?? null;
  }
  return null;
}

/**
 * Dispatches one transfer notification across any subject settler.
 */
export async function settleTransfer(deps: SettlementDeps, n: TransferNotification): Promise<TransferResult> {
  if (!validNotification(n)) {
    throw new DomainError('invalid_argument');
  }

  const recordId = transferRecordId(n);
  const existingRecord = await deps.payments.getTransferRecord(recordId);
  if (existingRecord) {
    return {
      outcome: 'duplicate',
      ...(existingRecord.paymentId ? { paymentId: existingRecord.paymentId } : {}),
    };
  }

  const payment = await matchPayment(deps, n.content, n.receivedAt);
  if (!payment) {
    await deps.payments.saveUnmatchedTransfer(transferRecordOf(n, 'needs_review'));
    return { outcome: 'needs_review' };
  }

  const settler = deps.subjects[payment.subjectType];
  if (!settler) {
    await deps.payments.saveUnmatchedTransfer(transferRecordOf(n, 'needs_review'));
    return { outcome: 'needs_review' };
  }

  const outcome = await settler.settle(payment.id, n);
  return { outcome, paymentId: payment.id };
}

/**
 * Dev/emulator tool and CLIs: simulates a transfer of `kind` to the caller's own payment (Decision 9).
 * A group's line (`groupId`) confirms its group payment: a transfer of the group's total (S30).
 */
export async function confirmFakePayment(
  deps: SettlementDeps,
  caller: { readonly uid: string },
  raw: unknown,
): Promise<{ outcome: TransferOutcome; subjectType: PaymentSubject; paymentStatus: PaymentStatus; subjectStatus: string }> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const { paymentId, kind = 'exact' } = raw as { paymentId?: unknown; kind?: unknown };
  if (typeof paymentId !== 'string' || !isId(paymentId)) throw new DomainError('invalid_argument');
  if (typeof kind !== 'string' || !(FAKE_TRANSFER_KINDS as readonly string[]).includes(kind)) {
    throw new DomainError('invalid_argument');
  }

  const found = await deps.payments.getPayment(paymentId);
  if (!found) throw new DomainError('not_found');
  if (found.payerId !== caller.uid) throw new DomainError('permission_denied');
  // A line of a group (a booking or registration paid with others, S30) is paid through its group.
  const p = found.groupId !== undefined ? await deps.payments.getPayment(found.groupId) : found;
  if (!p) throw new DomainError('not_found');
  if (p.payerId !== caller.uid) throw new DomainError('permission_denied');
  if (!p.transferCode) throw new DomainError('conflict');

  const settler = deps.subjects[p.subjectType];
  if (!settler) throw new DomainError('not_eligible');

  const now = deps.clock.now();
  const transfer = fakeTransferFor(p as Payment & { readonly transferCode: string }, kind as FakeTransferKind, now);
  const result = await settleTransfer(deps, transfer);

  const reRead = await deps.payments.getPayment(p.id);
  const paymentStatus = reRead?.status ?? p.status;
  const subjectStatus = await settler.statusOf(reRead ?? p);

  return {
    outcome: result.outcome,
    subjectType: p.subjectType,
    paymentStatus,
    subjectStatus,
  };
}
