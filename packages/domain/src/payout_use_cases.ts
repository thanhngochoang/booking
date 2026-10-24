/**
 * Staff payout use cases: batch released money, approve a first payout, pay it through a gateway,
 * hold and resume. The daily run (`daily_payouts.ts`) drives the same use cases as the system actor.
 */

import { DomainError } from './errors.js';
import type { LedgerEntry, LedgerEntryType, Payment } from './escrow.js';
import { graphemeCount } from './booking_requests.js';
import {
  HOLD_REASON_REPEATED_FAILURE,
  MAX_CONSECUTIVE_FAILURES,
  type Payout,
  type PayoutItem,
  type PayoutStatus,
} from './payout.js';
import { type MilestoneKind, type PaymentMilestone, withMilestones } from './milestones.js';
import { isAccountActiveAt, type PayoutAccount } from './payout_account.js';
import { payoutLineOf, taxRateBpOf } from './payout_policy.js';
import type { PayoutDeps, PayoutTx } from './payout_ports.js';

export interface StaffActor {
  readonly uid: string;
  readonly isAdmin: boolean;
}

/** The actor of the daily `createPayouts` job. */
export const SYSTEM_PAYOUT_ACTOR: StaffActor = { uid: 'system:createPayouts', isAdmin: true };

export const MIN_HOLD_REASON_LENGTH = 5;
export const MAX_HOLD_REASON_LENGTH = 200;

function requireAdmin(actor: StaffActor): void {
  if (!actor.isAdmin) throw new DomainError('permission_denied');
}

/**
 * Staff approve the first payout to each account (M5): until some payout to it is paid or
 * approved, and for every payout while staff must still compare the holder name.
 */
function needsApproval(account: PayoutAccount, cleared: boolean): boolean {
  return !cleared || account.nameStatus === 'pending_review';
}

/** The last MAX_CONSECUTIVE_FAILURES finished payouts to the account all failed. */
async function failedTooOften(tx: PayoutTx, accountId: string): Promise<boolean> {
  const last = await tx.lastFinishedPayouts(accountId, MAX_CONSECUTIVE_FAILURES);
  return last.length === MAX_CONSECUTIVE_FAILURES && last.every((p) => p.status === 'failed');
}

/** What the gateway sends: the net amount (gross on a payout written before tax existed). */
function transferAmountOf(p: Payout): number {
  return typeof p.amountNet === 'number' ? p.amountNet : p.amount;
}

/** An item's split; an item written before tax existed is all net. */
function itemSplit(i: PayoutItem): { fee: number; tax: number; net: number } {
  return typeof i.net === 'number' ? { fee: i.fee, tax: i.tax, net: i.net } : { fee: 0, tax: 0, net: i.amount };
}

export async function createPayout(deps: PayoutDeps, actor: StaffActor, payeeId: string): Promise<Payout> {
  requireAdmin(actor);
  return deps.store.runTransaction(async (tx) => {
    const clockNow = deps.clock.now();
    const now = clockNow.toISOString();
    const account = await tx.getActiveAccount(payeeId);
    // No money moves before the account's activeFrom (the 72 hours after a change).
    if (account === null || !isAccountActiveAt(account, clockNow)) throw new DomainError('not_eligible');
    const payeeType = await tx.getPayeeType(payeeId);
    const payableItems: { payment: Payment; gross: number; milestone?: MilestoneKind }[] = [];
    for (const p of await tx.listPayablePayments(payeeId)) {
      if (p.milestones) {
        for (const m of p.milestones) {
          if (m.status === 'released' && !m.payoutId) {
            payableItems.push({ payment: p, gross: m.amount, milestone: m.kind });
          }
        }
      } else {
        const gross = p.amount - (await tx.refundedTotal(p.id));
        if (gross > 0) payableItems.push({ payment: p, gross });
      }
    }
    const cleared = await tx.hasApprovedOrPaidPayout(account.id);
    const held = await failedTooOften(tx, account.id);
    if (payableItems.length === 0) throw new DomainError('not_eligible');

    const items: PayoutItem[] = payableItems.map(({ payment, gross, milestone }) => {
      const line = payoutLineOf(gross, payeeType, deps.policy, payment.feeBp);
      return {
        paymentId: payment.id,
        amount: line.gross,
        fee: line.fee,
        tax: line.tax,
        net: line.net,
        ...(milestone ? { milestone } : {}),
      };
    });
    const sum = (f: (i: PayoutItem) => number): number => items.reduce((s, i) => s + f(i), 0);
    const status: PayoutStatus = held ? 'on_hold' : needsApproval(account, cleared) ? 'needs_approval' : 'pending';
    const payout: Payout = {
      id: deps.ids.newId(),
      payeeId,
      accountId: account.id,
      amount: sum((i) => i.amount),
      status,
      items,
      platformFee: sum((i) => i.fee),
      taxWithheld: sum((i) => i.tax),
      amountNet: sum((i) => i.net),
      feeRateBp: deps.policy.feeBp[payeeType],
      taxRateBp: taxRateBpOf(payeeType, deps.policy),
      firstPayout: !cleared,
      ...(held ? { holdReason: HOLD_REASON_REPEATED_FAILURE } : {}),
      createdBy: actor.uid,
      createdAt: now,
      updatedAt: now,
    };
    tx.putPayout(payout);

    // Group payable items by payment to update milestones or payment payoutId
    const distinctPaymentIds = [...new Set(payableItems.map((pi) => pi.payment.id))];
    for (const pid of distinctPaymentIds) {
      const pay = payableItems.find((pi) => pi.payment.id === pid)?.payment;
      if (!pay) continue;
      if (pay.milestones) {
        const kindsToBatch = new Set(
          payableItems
            .filter((pi) => pi.payment.id === pid && pi.milestone !== undefined && pi.milestone !== null)
            .map((pi) => pi.milestone as MilestoneKind),
        );
        const updatedMs: PaymentMilestone[] = pay.milestones.map((m) =>
          kindsToBatch.has(m.kind) ? { ...m, payoutId: payout.id } : m,
        );
        const updatedPayment = withMilestones(pay, updatedMs, now);
        tx.setPayment(updatedPayment);
      } else {
        tx.setPayment({ ...pay, payoutId: payout.id, updatedAt: now });
      }
    }
    return payout;
  });
}

/**
 * Staff approve a payout waiting for them (`needs_approval` → `pending`). A holder name staff had
 * to compare (`pending_review`) is confirmed with it, on the account and its owner view.
 */
export async function approvePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout> {
  requireAdmin(actor);
  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'needs_approval') throw new DomainError('conflict');
    const account = await tx.getAccount(p.payeeId, p.accountId);
    const at = deps.clock.now().toISOString();
    const approved: Payout = { ...p, status: 'pending', approvedBy: actor.uid, approvedAt: at, updatedAt: at };
    tx.putPayout(approved);
    if (account !== null && account.nameStatus === 'pending_review') {
      const confirmed: PayoutAccount = { ...account, nameStatus: 'staff_confirmed' };
      tx.putAccount(confirmed);
      if (confirmed.active) {
        tx.putAccountView(confirmed.userId, {
          accountId: confirmed.id,
          bankCode: confirmed.bankCode,
          accountLast4: confirmed.accountLast4,
          holderName: confirmed.holderName,
          updatedAt: at,
          nameStatus: confirmed.nameStatus,
          activeFrom: confirmed.activeFrom,
        });
      }
    }
    return approved;
  });
}

export async function executePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout> {
  requireAdmin(actor);

  // Decrypt before anything is written: a key problem then fails fast and leaves the payout as it
  // was, not `processing`. (Remaining case for S23 staff tooling: the gateway keeps throwing after
  // the payout is `processing`; it stays `processing` for staff to look at and re-run.)
  const preview = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'pending' && p.status !== 'processing') throw new DomainError('conflict');
    const account = await tx.getAccount(p.payeeId, p.accountId);
    if (account === null) throw new DomainError('not_eligible');
    // No money moves to a deactivated account (defence in depth: a change re-points open payouts)
    // nor before the account's activeFrom (the 72 hours after a change).
    if (!isAccountActiveAt(account, deps.clock.now())) throw new DomainError('not_eligible');
    return account;
  });
  const accountNumber = await deps.cipher.decrypt(preview.accountNumberEnc);

  const started = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'pending' && p.status !== 'processing') throw new DomainError('conflict');
    const account = await tx.getAccount(p.payeeId, p.accountId);
    if (account === null || account.accountNumberEnc !== preview.accountNumberEnc) throw new DomainError('conflict');
    if (!isAccountActiveAt(account, deps.clock.now())) throw new DomainError('not_eligible');
    const at = deps.clock.now().toISOString();
    const processing: Payout =
      p.status === 'processing' ? p : { ...p, status: 'processing', processingAt: at, updatedAt: at };
    if (p.status !== 'processing') tx.putPayout(processing);
    return { payout: processing, account };
  });

  const outcome = await deps.gateway.transfer({
    payoutId,
    amount: transferAmountOf(started.payout),
    bankCode: started.account.bankCode,
    accountNumber,
    holderName: started.account.holderName,
  });

  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'processing') throw new DomainError('conflict');
    const at = deps.clock.now().toISOString();
    const paymentIds = [...new Set(p.items.map((i) => i.paymentId))];
    const paymentsList = await tx.getPayments(paymentIds);
    const paymentsMap = new Map<string, Payment>();
    paymentsList.forEach((pay) => {
      if (pay) paymentsMap.set(pay.id, pay);
    });

    // Validate that every batched item is still valid:
    for (const item of p.items) {
      const pay = paymentsMap.get(item.paymentId);
      if (!pay) throw new DomainError('conflict');
      if (pay.milestones) {
        if (!item.milestone) throw new DomainError('conflict');
        const ms = pay.milestones.find((m) => m.kind === item.milestone);
        if (!ms || ms.status !== 'released' || ms.payoutId !== p.id) {
          throw new DomainError('conflict');
        }
      } else {
        if (pay.escrowStatus !== 'released' || pay.payoutId !== p.id) {
          throw new DomainError('conflict');
        }
      }
    }

    if (outcome.status === 'paid') {
      const done: Payout = { ...p, status: 'paid', paidAt: at, reference: outcome.reference, updatedAt: at };
      tx.putPayout(done);

      for (const item of p.items) {
        const pay = paymentsMap.get(item.paymentId);
        if (!pay) continue;
        const split = itemSplit(item);
        const lines: [LedgerEntryType, number][] = [
          ['payout_paid', split.net],
          ['tax_withheld', split.tax],
          ['platform_fee', split.fee],
        ];
        for (const [type, amount] of lines) {
          if (amount <= 0) continue;
          const entry: LedgerEntry = {
            id: deps.ids.newId(),
            type,
            paymentId: pay.id,
            payoutId: p.id,
            subjectType: pay.subjectType,
            subjectId: pay.subjectId,
            accountOwnerId: p.payeeId,
            amount: -amount,
            note: `Payout ${p.id}`,
            at,
          };
          tx.addLedgerEntry(entry);
        }
      }

      // Update payments
      for (const pay of paymentsMap.values()) {
        if (pay.milestones) {
          const batchedKinds = new Set(
            p.items
              .filter((it) => it.paymentId === pay.id && it.milestone !== undefined && it.milestone !== null)
              .map((it) => it.milestone as MilestoneKind),
          );
          const updatedMs: PaymentMilestone[] = pay.milestones.map((m) =>
            batchedKinds.has(m.kind) ? { ...m, status: 'paid_out' as const, payoutId: p.id } : m,
          );
          const updatedPay = withMilestones(pay, updatedMs, at);
          tx.setPayment(updatedPay);
        } else {
          tx.setPayment({ ...pay, escrowStatus: 'paid_out', updatedAt: at });
        }
      }
      return done;
    }

    const failed: Payout = {
      ...p,
      status: 'failed',
      failureReason: outcome.failureReason ?? 'failed',
      updatedAt: at,
    };
    tx.putPayout(failed);
    for (const pay of paymentsMap.values()) {
      if (pay.milestones) {
        const batchedKinds = new Set(
          p.items
            .filter((it) => it.paymentId === pay.id && it.milestone !== undefined && it.milestone !== null)
            .map((it) => it.milestone as MilestoneKind),
        );
        const updatedMs: PaymentMilestone[] = pay.milestones.map((m) =>
          batchedKinds.has(m.kind) ? { ...m, payoutId: null } : m,
        );
        const updatedPay = withMilestones(pay, updatedMs, at);
        tx.setPayment(updatedPay);
      } else {
        tx.setPayment({ ...pay, payoutId: null, updatedAt: at });
      }
    }
    return failed;
  });
}

export async function holdPayout(
  deps: PayoutDeps,
  actor: StaffActor,
  payoutId: string,
  reason: string,
): Promise<Payout> {
  requireAdmin(actor);
  const text = typeof reason === 'string' ? reason.trim() : '';
  const count = graphemeCount(text);
  if (count < MIN_HOLD_REASON_LENGTH || count > MAX_HOLD_REASON_LENGTH) {
    throw new DomainError('invalid_argument');
  }
  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'pending') throw new DomainError('conflict');
    const held: Payout = { ...p, status: 'on_hold', holdReason: text, updatedAt: deps.clock.now().toISOString() };
    tx.putPayout(held);
    return held;
  });
}

/**
 * Back to `pending` when staff approved it before the hold or the account is cleared; otherwise to
 * `needs_approval`.
 */
export async function resumePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout> {
  requireAdmin(actor);
  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'on_hold') throw new DomainError('conflict');
    const account = await tx.getAccount(p.payeeId, p.accountId);
    const cleared = await tx.hasApprovedOrPaidPayout(p.accountId);
    const status: PayoutStatus =
      p.approvedBy !== undefined ? 'pending' : account === null || needsApproval(account, cleared) ? 'needs_approval' : 'pending';
    const { holdReason, ...rest } = p;
    void holdReason;
    const resumed: Payout = { ...rest, status, updatedAt: deps.clock.now().toISOString() };
    tx.putPayout(resumed);
    return resumed;
  });
}

export async function listDuePayees(
  deps: PayoutDeps,
  actor: StaffActor,
): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]> {
  requireAdmin(actor);
  return deps.store.listDuePayees();
}
