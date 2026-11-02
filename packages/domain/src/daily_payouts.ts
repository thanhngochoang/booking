/**
 * The daily payout run (payments spec M5 "chi tự động mỗi ngày, không ngưỡng tối thiểu"):
 * (a) one payout per due payee (and payee kind) with an account whose activeFrom has come, (b) send every `pending`
 * payout, approved ones included. One payee's or payout's failure never stops the others, and a
 * second run the same day creates nothing new (batched payments carry `payoutId`).
 */

import { DomainError } from './errors.js';
import type { PayoutDeps } from './payout_ports.js';
import { SYSTEM_PAYOUT_ACTOR, createPayouts, executePayout } from './payout_use_cases.js';

export interface DailyPayoutReport {
  created: number;
  needsApproval: number;
  onHold: number;
  executed: number;
  paid: number;
  failed: number;
  noAccount: number;
  notActive: number;
  errors: number;
}

/** Payouts sent per run at most; the rest wait for the next run. */
export const DAILY_EXECUTE_LIMIT = 200;

export async function runDailyPayouts(
  deps: PayoutDeps,
  onError: (id: string, step: 'create' | 'execute', e: unknown) => void = () => undefined,
): Promise<DailyPayoutReport> {
  const r: DailyPayoutReport = {
    created: 0, needsApproval: 0, onHold: 0, executed: 0, paid: 0, failed: 0, noAccount: 0, notActive: 0, errors: 0,
  };
  for (const due of await deps.store.listDuePayees()) {
    if (!due.hasAccount) {
      r.noAccount += 1;
      await deps.notices.accountNeeded(due.payeeId, due.amount).catch((e: unknown) => onError(due.payeeId, 'create', e));
      continue;
    }
    try {
      // One payout per payee kind (S30 Decision 12): a photographer who is also an organizer gets two.
      for (const p of await createPayouts(deps, SYSTEM_PAYOUT_ACTOR, due.payeeId)) {
        r.created += 1;
        if (p.status === 'needs_approval') r.needsApproval += 1;
        if (p.status === 'on_hold') r.onHold += 1;
      }
    } catch (e) {
      // No money left after all, or the account is not active yet (the 72 hours after a change).
      if (e instanceof DomainError && e.code === 'not_eligible') {
        r.notActive += 1;
        continue;
      }
      r.errors += 1;
      onError(due.payeeId, 'create', e);
    }
  }
  for (const id of await deps.store.listPayoutIdsByStatus(['pending'], DAILY_EXECUTE_LIMIT)) {
    try {
      const done = await executePayout(deps, SYSTEM_PAYOUT_ACTOR, id);
      r.executed += 1;
      if (done.status === 'paid') r.paid += 1;
      else r.failed += 1;
    } catch (e) {
      if (e instanceof DomainError && e.code === 'not_eligible') {
        r.notActive += 1;
        continue;
      }
      r.errors += 1;
      onError(id, 'execute', e);
    }
  }
  return r;
}
