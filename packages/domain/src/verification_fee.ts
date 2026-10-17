/**
 * The S21 verification fee (#203, Decision 4): the payment subject `verification_fee` on V1's
 * shared payments. 99.000₫ / 299.000₫ by kind, payee `platform` (platform revenue: released at
 * once, never earnings, never payouts). Money arrives only through V1's settlement
 * (`VerificationFeeSettler`); refunds go out with V2's `sendRefundOnce` and are re-sent by the
 * payment clock through `verificationFeeRefundHandler`.
 */

import { PAYMENT_EXPIRY_MINUTES } from './booking_policy.js';
import type { TransferNotification, TransferOutcome } from './booking_ports.js';
import {
  checkSubjectPayments,
  freshPaymentId,
  instructionsOf,
  issuePaymentInstructions,
  newSubjectPayment,
} from './create_payment.js';
import { DomainError } from './errors.js';
import {
  applyRefundToPayment,
  isPaymentMethod,
  type LedgerEntry,
  PAYMENT_METHODS,
  type Payment,
  type PaymentMethod,
  type Refund,
} from './escrow.js';
import { payerAccountOf } from './payer_account.js';
import type { PaymentInstructions, SubjectSettler } from './payment_ports.js';
import {
  applyTransfer,
  expireUnpaid,
  type SettlementDeps,
  transferRecordId,
  transferRecordOf,
} from './payment_settlement.js';
import { PLATFORM_PAYEE } from './payout.js';
import { refundWithoutPayment, type RefundSubjectHandler } from './refund_subjects.js';
import { mergeRefundOutcome, sendRefundOnce, transferRefund } from './refunds.js';
import {
  emptyVerification,
  feeFor,
  feeWaived,
  RESUBMITTABLE_REASONS,
  type VerificationRecord,
  verificationKindOf,
} from './verification.js';
import type { VerificationDeps, VerificationTx } from './verification_ports.js';

/** Policy refund of a second fee paid for an attempt whose fee is already recorded. */
export const DUPLICATE_FEE_REFUND_REASON = 'duplicate_verification_fee';
/** Policy refund of a code that no longer fits the fee: another kind's amount, an earlier attempt, or a record that cannot use a fee. */
export const STALE_FEE_REFUND_REASON = 'stale_verification_fee';
/** Why a paid verification fee went back in full (`applyRefundToPayment`, from what the payment holds). */
export const VERIFICATION_FEE_REFUND_REASONS = [DUPLICATE_FEE_REFUND_REASON, STALE_FEE_REFUND_REASON] as const;

/** The ledger account the fee is charged to (Decision 4). */
export const PLATFORM_REVENUE_ACCOUNT = 'platform_revenue';

/**
 * Whether the fee can be opened and recorded for this record: not paid and not waived (`feeWaived`),
 * and the record still walking the steps (`not_started`, `in_progress`) or rejected for a reason
 * that allows a resubmit (a pre-#203 rejection pays before its paid resubmit). A final rejection
 * (`underage`, `duplicate_account`) can never use a fee.
 */
export function feePayable(rec: VerificationRecord): boolean {
  if (rec.steps.fee !== null || feeWaived(rec)) return false;
  if (rec.status === 'not_started' || rec.status === 'in_progress') return true;
  return rec.status === 'rejected' && rec.rejectReason !== null
    && (RESUBMITTABLE_REASONS as readonly string[]).includes(rec.rejectReason.code);
}

const MINUTE = 60_000;

/**
 * Idempotency key of a fee payment: `vfee_{uid}_{feeAttempt}_{method}` for the first code of an
 * attempt and method, `…_{n}` for the n-th (a renewed code needs a new key at the gateway).
 */
export function verificationFeeKey(uid: string, attempt: number, method: PaymentMethod, n = 1): string {
  const base = `vfee_${uid}_${attempt}_${method}`;
  return n <= 1 ? base : `${base}_${n}`;
}

/** True when `p` is a fee payment of this uid's `attempt` (and `method`, when given). */
function isFeeOf(p: Payment, uid: string, attempt: number, method?: PaymentMethod): boolean {
  const methods = method === undefined ? PAYMENT_METHODS : [method];
  return methods.some((m) => {
    const base = verificationFeeKey(uid, attempt, m);
    return p.idempotencyKey === base || p.idempotencyKey.startsWith(`${base}_`);
  });
}

function parseFeeInput(raw: unknown): { method: PaymentMethod; renew: boolean } {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  const { method, renew } = raw as { method?: unknown; renew?: unknown };
  if (!isPaymentMethod(method)) throw new DomainError('invalid_argument');
  if (renew !== undefined && typeof renew !== 'boolean') throw new DomainError('invalid_argument');
  return { method, renew: renew === true };
}

/**
 * "Thanh toán {amount}" on S21.02-fee and "Tạo QR mới" on S04.04 (`renew`).
 * One transaction: the provider and their record, the fee not yet paid, the live payment of this
 * attempt and method reused (no gateway call), else every open one expired (`expireUnpaid`) and a
 * new `created` platform payment written. The gateway is asked outside it, and its answer saved
 * while the payment is still `created` (V1's `issuePaymentInstructions`).
 * Refusals: bad input → `invalid_argument`; not a provider → `permission_denied`; the fee off,
 * already paid, or the record past the steps (submitted, approved, revoked) → `not_eligible`.
 */
export async function startVerificationFee(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<PaymentInstructions> {
  const { method, renew } = parseFeeInput(raw);
  if (!deps.feeRequired) throw new DomainError('not_eligible');

  // Drawn outside the transaction: its transfer code must not clash with any payment of any subject.
  const paymentId = await freshPaymentId(deps.payments, deps.ids);
  let expired: { refund: Refund; payment: Payment }[] = [];

  const intent = await deps.store.runTransaction(async (tx): Promise<Payment> => {
    expired = [];
    const now = deps.clock.now();
    const nowIso = now.toISOString();
    const provider = await tx.getProvider(uid);
    if (!provider) throw new DomainError('permission_denied');
    const stored = await tx.getVerification(uid);
    const base = stored ?? emptyVerification(uid, verificationKindOf(provider.providerType), now);
    if (!feePayable(base)) throw new DomainError('not_eligible');
    // Decision 5: the kind follows the provider type until the fee is paid.
    const rec: VerificationRecord = { ...base, kind: verificationKindOf(provider.providerType) };
    const amount = feeFor(rec.kind);

    const ofAttempt = (await tx.feePaymentsOf(uid)).filter((p) => isFeeOf(p, uid, rec.feeAttempt));
    const mine = ofAttempt.filter((p) => isFeeOf(p, uid, rec.feeAttempt, method));
    const open = mine.filter((p) => p.status === 'created');
    const live = open.find(
      (p) => p.amount === amount && p.expiresAt !== undefined && Date.parse(p.expiresAt) > now.getTime(),
    );
    const reuse = live !== undefined && !renew;
    // Codes of this attempt (any method) for another kind's fee can no longer be the fee; the
    // settler would refund them as stale, so they are closed here too.
    const stale = ofAttempt.filter((p) => p.status === 'created' && p.amount !== amount);
    const toExpire = new Map<string, Payment>(stale.map((p) => [p.id, p]));
    if (!reuse) for (const p of open) toExpire.set(p.id, p);

    // ---- writes ----
    for (const p of toExpire.values()) {
      const out = expireUnpaid({ payment: p, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), now });
      tx.putPayment(out.payment);
      if (out.refund !== null && out.ledgerEntry !== null) {
        tx.putRefund(out.refund);
        tx.addLedgerEntry(out.ledgerEntry);
        expired.push({ refund: out.refund, payment: out.payment });
      }
    }

    // Always written, even when nothing on it changes: two starts racing on the same attempt then
    // conflict on this document (the payments query alone does not serialize them, and both could
    // write a payment under the same idempotency key).
    tx.putVerification({
      ...rec,
      status: rec.status === 'not_started' ? 'in_progress' : rec.status,
      updatedAt: nowIso,
      version: rec.version + 1,
    });
    if (reuse) return live;

    const payment = newSubjectPayment({
      id: paymentId,
      subjectType: 'verification_fee',
      subjectId: uid,
      payerId: uid,
      payeeId: PLATFORM_PAYEE,
      amount,
      method,
      provider: deps.gateway.provider,
      idempotencyKey: verificationFeeKey(uid, rec.feeAttempt, method, mine.length + 1),
      now,
      expiresAt: new Date(now.getTime() + PAYMENT_EXPIRY_MINUTES * MINUTE),
    });
    tx.putPayment(payment);
    return payment;
  });

  // The expiries are committed: send their refunds before the gateway is asked for the new code, so a
  // gateway failure there never strands them (a refused or thrown refund stays for V2's re-send or staff).
  for (const { refund, payment } of expired) {
    await dispatchVerificationFeeRefund(deps, refund, payment);
  }

  const reused = instructionsOf(intent);
  const instructions = reused ?? await issuePaymentInstructions(deps.gateway, intent, async (providerRef, inst) => {
    await deps.store.runTransaction(async (tx) => {
      const cur = await tx.getPayment(intent.id);
      if (cur === null || cur.status !== 'created') return;
      tx.putPayment({
        ...cur,
        ...(providerRef ? { providerRef } : {}),
        instructions: inst,
        updatedAt: deps.clock.now().toISOString(),
      });
    });
  });

  return instructions;
}

async function feePaymentsOfAttempt(tx: VerificationTx, uid: string): Promise<readonly Payment[]> {
  const rec = await tx.getVerification(uid);
  if (rec === null) return [];
  return (await tx.feePaymentsOf(uid))
    .filter((p) => p.status === 'created' && isFeeOf(p, uid, rec.feeAttempt))
    .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt));
}

/** The created payments of the current fee attempt (for V1's `checkSubjectPayments`), oldest first. */
export async function verificationFeePayments(deps: VerificationDeps, uid: string): Promise<readonly Payment[]> {
  return deps.store.runTransaction((tx) => feePaymentsOfAttempt(tx, uid));
}

/**
 * "Kiểm tra" on resume: asks the gateway about every created payment of the current attempt and
 * applies what it reports (V1's `checkSubjectPayments`). `instructions` is the newest live code
 * while the fee is unpaid, else null.
 */
export async function checkVerificationFee(
  deps: VerificationDeps,
  uid: string,
  settlement: SettlementDeps = {
    payments: deps.payments,
    gateway: deps.gateway,
    clock: deps.clock,
    subjects: { verification_fee: new VerificationFeeSettler(deps) },
  },
): Promise<{ paid: boolean; instructions: PaymentInstructions | null }> {
  const first = await deps.store.runTransaction(async (tx) => {
    if ((await tx.getProvider(uid)) === null) throw new DomainError('permission_denied');
    const rec = await tx.getVerification(uid);
    if (rec === null) throw new DomainError('not_found');
    return { paid: rec.steps.fee !== null, open: await feePaymentsOfAttempt(tx, uid) };
  });
  if (first.paid) return { paid: true, instructions: null };

  await checkSubjectPayments(settlement, first.open);

  const after = await deps.store.runTransaction(async (tx) => ({
    paid: (await tx.getVerification(uid))?.steps.fee != null,
    open: await feePaymentsOfAttempt(tx, uid),
  }));
  if (after.paid) return { paid: true, instructions: null };
  const nowMs = deps.clock.now().getTime();
  const live = [...after.open].reverse().find((p) => p.expiresAt !== undefined && Date.parse(p.expiresAt) > nowMs);
  return { paid: false, instructions: live === undefined ? null : instructionsOf(live) };
}

/**
 * Fee refunds (V2's `RefundSubjects` entry for `verification_fee`): the payment clock re-sends
 * pending ones and refund events are stored here. No mirror on the verification record.
 */
export function verificationFeeRefundHandler(deps: VerificationDeps): RefundSubjectHandler {
  return {
    async resend(refund: Refund): Promise<Refund> {
      // Re-read: only a refund still pending is sent (an event or staff may have settled it since the query).
      const { stored, payment } = await deps.store.runTransaction(async (tx) => {
        const s = await tx.getRefund(refund.id);
        return { stored: s, payment: s === null ? null : await tx.getPayment(s.paymentId) };
      });
      if (stored === null || stored.status !== 'pending') return stored ?? refund;
      if (payment === null) {
        const gone = refundWithoutPayment(stored, deps.clock.now());
        return (await this.record(gone)) ?? gone;
      }
      const next = await sendRefundOnce(deps, stored, payment);
      return (await this.record(next)) ?? next;
    },

    async record(next: Refund): Promise<Refund | null> {
      return deps.store.runTransaction(async (tx) => {
        const stored = await tx.getRefund(next.id);
        const merged = stored ? mergeRefundOutcome(stored, next) : next;
        if (!merged) return null;
        tx.putRefund(merged);
        return merged;
      });
    },
  };
}

/** One gateway call under the refund's id (V2), then the outcome stored with `mergeRefundOutcome`. */
export async function dispatchVerificationFeeRefund(
  deps: VerificationDeps,
  refund: Refund,
  payment: Pick<Payment, 'id' | 'provider'>,
): Promise<Refund> {
  const next = await sendRefundOnce(deps, refund, payment);
  return (await verificationFeeRefundHandler(deps).record(next)) ?? next;
}

/**
 * V1's `SubjectSettler` for `verification_fee`, over the VerificationStore.
 * A transfer that pays the fee records the fee step of the current attempt, releases the payment
 * (platform revenue) and adds `fee_charged`; a fee paid when the attempt's fee is already recorded
 * is refunded 100% (`duplicate_verification_fee`); over, under and late transfers follow #129's
 * table (`decideTransfer`).
 */
export class VerificationFeeSettler implements SubjectSettler {
  constructor(private readonly deps: VerificationDeps) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    const deps = this.deps;
    const recordId = transferRecordId(transfer);
    // The sender's account, encrypted before the transaction (V2 Decision 2).
    const captured = await payerAccountOf(deps.cipher, transfer.payer);
    let toSend: Refund[] = [];
    let paymentForRefund: Payment | null = null;

    const outcome = await deps.store.runTransaction(async (tx): Promise<Exclude<TransferOutcome, 'needs_review'>> => {
      toSend = [];
      if ((await tx.getTransferRecord(recordId)) !== null) return 'duplicate';
      const p = await tx.getPayment(paymentId);
      if (p === null || p.subjectType !== 'verification_fee') throw new DomainError('not_found');
      paymentForRefund = p;
      const rec = await tx.getVerification(p.subjectId);
      const provider = await tx.getProvider(p.subjectId);
      const now = deps.clock.now();
      const nowIso = now.toISOString();

      // ---- writes ----
      const applied = applyTransfer({ payment: p, transfer, ledgerEntryId: deps.ids.newId(), now });
      tx.addLedgerEntry(applied.ledgerEntry);
      // The first sender that counts toward the payment is kept as its payer.
      const counted: Payment = { ...applied.payment, payer: p.payer ?? captured };

      const giveBack = (payment: Payment, amount: number, reason: Parameters<typeof transferRefund>[0]['reason']) => {
        const out = transferRefund({
          payment,
          refundId: deps.ids.newId(),
          ledgerEntryId: deps.ids.newId(),
          amount,
          reason,
          destination: captured ?? p.payer,
          providerRef: transfer.txnId,
          now,
        });
        tx.putRefund(out.refund);
        tx.addLedgerEntry(out.ledgerEntry);
        toSend.push(out.refund);
        return out.payment;
      };

      if (applied.decision.kind === 'partial') {
        tx.putPayment(counted);
        tx.putTransferRecord(transferRecordOf(transfer, 'partial', p.id));
        return 'partial';
      }

      if (applied.decision.kind === 'refund') {
        // A late or extra transfer goes straight back; the payment keeps its status.
        const kept = giveBack(p, transfer.amount, applied.decision.reason);
        tx.putPayment({ ...kept, updatedAt: nowIso });
        tx.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        return 'refunded';
      }

      // paid
      let paid: Payment = counted;
      if (applied.excess > 0) paid = giveBack(paid, applied.excess, 'overpaid_excess');

      // The kind is frozen only by a recorded fee, so until then it follows the provider type now;
      // a code for another kind's fee or an earlier attempt, or for a record that cannot use a fee
      // (gone, past the steps, finally rejected, fee waived), is not this attempt's fee.
      const duplicate = rec !== null && rec.steps.fee !== null;
      const kind = provider === null ? null : verificationKindOf(provider.providerType);
      const fits = rec !== null && feePayable(rec) && kind !== null && p.amount === feeFor(kind)
        && isFeeOf(p, p.subjectId, rec.feeAttempt);
      if (!fits) {
        const out = applyRefundToPayment({
          payment: paid,
          refundId: deps.ids.newId(),
          percent: 100,
          ledgerEntryId: deps.ids.newId(),
          reason: duplicate ? DUPLICATE_FEE_REFUND_REASON : STALE_FEE_REFUND_REASON,
          now,
        });
        const refund: Refund = { ...out.refund, providerRef: transfer.txnId };
        tx.putPayment(out.payment);
        tx.putRefund(refund);
        tx.addLedgerEntry(out.ledgerEntry);
        toSend.push(refund);
        tx.putTransferRecord(transferRecordOf(transfer, 'refunded', p.id));
        return 'refunded';
      }

      // Platform revenue: never held for a payee, so released at once.
      tx.putPayment({ ...paid, escrowStatus: 'released', releasedAt: nowIso, updatedAt: nowIso });
      const charged: LedgerEntry = {
        id: deps.ids.newId(),
        type: 'fee_charged',
        paymentId: p.id,
        subjectType: p.subjectType,
        subjectId: p.subjectId,
        accountOwnerId: PLATFORM_REVENUE_ACCOUNT,
        amount: p.amount,
        note: `Verification fee ${p.subjectId} attempt ${rec.feeAttempt}`,
        at: nowIso,
      };
      tx.addLedgerEntry(charged);
      tx.putVerification({
        ...rec,
        kind,
        status: rec.status === 'not_started' ? 'in_progress' : rec.status,
        steps: { ...rec.steps, fee: { paymentId: p.id, amount: p.amount, paidAt: nowIso } },
        updatedAt: nowIso,
        version: rec.version + 1,
      });

      const finalOutcome = applied.excess > 0 ? 'paid_with_refund' : 'paid';
      tx.putTransferRecord(transferRecordOf(transfer, finalOutcome, p.id));
      return finalOutcome;
    });

    const payment: Payment | null = paymentForRefund;
    if (outcome !== 'duplicate' && payment !== null) {
      for (const r of toSend) await this.dispatchRefund(r, payment);
    }
    return outcome;
  }

  async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
    let toSend: { refund: Refund; payment: Payment } | null = null;
    const outcome = await this.deps.store.runTransaction(async (tx): Promise<'expired' | 'unchanged'> => {
      toSend = null;
      const p = await tx.getPayment(paymentId);
      if (p === null || p.subjectType !== 'verification_fee' || p.status !== 'created' || !p.expiresAt) {
        return 'unchanged';
      }
      if (Date.parse(p.expiresAt) > now.getTime()) return 'unchanged';
      const out = expireUnpaid({ payment: p, refundId: this.deps.ids.newId(), ledgerEntryId: this.deps.ids.newId(), now });
      tx.putPayment(out.payment);
      if (out.refund !== null && out.ledgerEntry !== null) {
        tx.putRefund(out.refund);
        tx.addLedgerEntry(out.ledgerEntry);
        toSend = { refund: out.refund, payment: out.payment };
      }
      return 'expired';
    });
    const sending = toSend as { refund: Refund; payment: Payment } | null;
    if (sending !== null) await this.dispatchRefund(sending.refund, sending.payment);
    return outcome;
  }

  async dispatchRefund(refund: Refund, payment: Payment): Promise<Refund> {
    return dispatchVerificationFeeRefund(this.deps, refund, payment);
  }

  /** The verification's status (`in_progress` once a fee is recorded on a running record), `gone` without one. */
  async statusOf(payment: Payment): Promise<string> {
    const rec = await this.deps.store.runTransaction((tx) => tx.getVerification(payment.subjectId));
    return rec?.status ?? 'gone';
  }
}
