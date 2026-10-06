/** Staff payout use cases: batch released money, pay it through a gateway, hold and resume. */

import { DomainError } from './errors.js';
import type { LedgerEntry, Payment } from './escrow.js';
import { graphemeCount } from './booking_requests.js';
import type { Payout, PayoutItem } from './payout.js';
import type { PayoutDeps } from './payout_ports.js';

export interface StaffActor {
  readonly uid: string;
  readonly isAdmin: boolean;
}

export const MIN_HOLD_REASON_LENGTH = 5;
export const MAX_HOLD_REASON_LENGTH = 200;

function requireAdmin(actor: StaffActor): void {
  if (!actor.isAdmin) throw new DomainError('permission_denied');
}

export async function createPayout(deps: PayoutDeps, actor: StaffActor, payeeId: string): Promise<Payout> {
  requireAdmin(actor);
  return deps.store.runTransaction(async (tx) => {
    const now = deps.clock.now().toISOString();
    const account = await tx.getActiveAccount(payeeId);
    if (account === null) throw new DomainError('not_eligible');
    const items: PayoutItem[] = [];
    const batched: Payment[] = [];
    for (const p of await tx.listPayablePayments(payeeId)) {
      const net = p.amount - (await tx.refundedTotal(p.id));
      if (net <= 0) continue;
      items.push({ paymentId: p.id, amount: net });
      batched.push(p);
    }
    if (items.length === 0) throw new DomainError('not_eligible');
    const payout: Payout = {
      id: deps.ids.newId(),
      payeeId,
      accountId: account.id,
      amount: items.reduce((s, i) => s + i.amount, 0),
      status: 'pending',
      items,
      createdBy: actor.uid,
      createdAt: now,
      updatedAt: now,
    };
    tx.putPayout(payout);
    for (const p of batched) tx.setPayment({ ...p, payoutId: payout.id, updatedAt: now });
    return payout;
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
    return account;
  });
  const accountNumber = await deps.cipher.decrypt(preview.accountNumberEnc);

  const started = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'pending' && p.status !== 'processing') throw new DomainError('conflict');
    const account = await tx.getAccount(p.payeeId, p.accountId);
    if (account === null || account.accountNumberEnc !== preview.accountNumberEnc) throw new DomainError('conflict');
    const at = deps.clock.now().toISOString();
    const processing: Payout =
      p.status === 'processing' ? p : { ...p, status: 'processing', processingAt: at, updatedAt: at };
    if (p.status !== 'processing') tx.putPayout(processing);
    return { payout: processing, account };
  });

  const outcome = await deps.gateway.transfer({
    payoutId,
    amount: started.payout.amount,
    bankCode: started.account.bankCode,
    accountNumber,
    holderName: started.account.holderName,
  });

  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'processing') throw new DomainError('conflict');
    const at = deps.clock.now().toISOString();
    const payments = await tx.getPayments(p.items.map((i) => i.paymentId));
    // Every batched payment must still be released into this batch; otherwise nothing is written
    // (no partial ledger) and the payout stays `processing` for staff to look at.
    if (payments.some((pay) => pay === null || pay.escrowStatus !== 'released' || pay.payoutId !== p.id)) {
      throw new DomainError('conflict');
    }

    if (outcome.status === 'paid') {
      const done: Payout = { ...p, status: 'paid', paidAt: at, reference: outcome.reference, updatedAt: at };
      tx.putPayout(done);
      p.items.forEach((item, idx) => {
        const pay = payments[idx];
        if (pay === null || pay === undefined) return;
        tx.setPayment({ ...pay, escrowStatus: 'paid_out', updatedAt: at });
        const entry: LedgerEntry = {
          id: deps.ids.newId(),
          type: 'payout_paid',
          paymentId: pay.id,
          payoutId: p.id,
          subjectType: pay.subjectType,
          subjectId: pay.subjectId,
          accountOwnerId: p.payeeId,
          amount: -item.amount,
          note: `Payout ${p.id}`,
          at,
        };
        tx.addLedgerEntry(entry);
      });
      return done;
    }

    const failed: Payout = {
      ...p,
      status: 'failed',
      failureReason: outcome.failureReason ?? 'failed',
      updatedAt: at,
    };
    tx.putPayout(failed);
    for (const pay of payments) {
      if (pay !== null) tx.setPayment({ ...pay, payoutId: null, updatedAt: at });
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

export async function resumePayout(deps: PayoutDeps, actor: StaffActor, payoutId: string): Promise<Payout> {
  requireAdmin(actor);
  return deps.store.runTransaction(async (tx) => {
    const p = await tx.getPayout(payoutId);
    if (p === null) throw new DomainError('not_found');
    if (p.status !== 'on_hold') throw new DomainError('conflict');
    const { holdReason, ...rest } = p;
    void holdReason;
    const resumed: Payout = { ...rest, status: 'pending', updatedAt: deps.clock.now().toISOString() };
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
