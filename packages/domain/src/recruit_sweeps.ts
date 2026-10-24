/**
 * The S27 steps of the 15-minute clock (plan #151 Decisions 9, 13, 15; no new scheduler job): expire posts,
 * applications, invites and collaborator offers, mark pay records due once the shoot milestone is released,
 * and add the studio's unpaid flags. Each due list is read in pages of 200; each item runs in its own
 * transaction that re-reads it and does nothing when it no longer qualifies, so a second run changes nothing.
 * A failing item never stops the batch (the next run finds it again). No money moves (R5).
 */

import { addUnpaidFlag, PAY_OVERDUE_DAYS, type CollabJob } from './collab_jobs.js';
import { expireCollabInvite } from './collab_use_cases.js';
import { notifyCollabPayDue } from './notification_hooks.js';
import type { RecruitDeps } from './recruit_ports.js';
import { safely } from './recruit_shared.js';
import { expireRecruitApplication, expireRecruitPost } from './recruit_use_cases.js';
import { expireCollabOffer, type StudioBookingDeps } from './studio_assignment.js';

/** Items handled per step and run. */
export const RECRUIT_SWEEP_LIMIT = 200;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface RecruitSweepResults {
  readonly postsExpired: number;
  readonly applicationsExpired: number;
  readonly invitesExpired: number;
  readonly offersExpired: number;
  /** Pay records that became `due`. */
  readonly payDue: number;
  /** Unpaid flags added (overdue or disputed). */
  readonly payFlagged: number;
  /** Items whose step threw; they are tried again on the next run. */
  readonly failed: number;
}

export type RecruitSweepDeps = RecruitDeps & { readonly assign: StudioBookingDeps };

/**
 * Accepted job whose booking's shoot milestone went to the studio: `due` from now, the studio reminded
 * ("Trả {tên} {số tiền}"). False when not due yet or no longer qualifying.
 */
async function markPayDue(deps: RecruitDeps, due: CollabJob): Promise<boolean> {
  if (!(await deps.milestones.shotReleased(due.bookingId))) return false;
  const now = deps.clock.now();
  const job = await deps.store.runTransaction(async (tx) => {
    const j = await tx.getCollabJob(due.bookingId, due.collaboratorId);
    if (!j || j.offerStatus !== 'accepted' || j.payStatus !== 'none') return null;
    const next: CollabJob = { ...j, payStatus: 'due', pay: { ...j.pay, dueAt: now }, updatedAt: now };
    tx.putCollabJob(next);
    return next;
  });
  if (job === null) return false;
  await safely(deps, job.studioId, () => notifyCollabPayDue(deps.notify, {
    studioId: job.studioId,
    collaboratorId: job.collaboratorId,
    bookingId: job.bookingId,
    amount: job.pay.amount,
    service: job.shoot.serviceName,
    day: job.shoot.day,
  }));
  return true;
}

/**
 * One unpaid flag on the studio for this job and reason, once (Decision 15): still `due` 7 days after `dueAt`,
 * or `disputed`. The third flag within 90 days blocks recruiting for 30 days.
 */
async function flagUnpaid(deps: RecruitDeps, item: CollabJob, reason: 'overdue' | 'dispute'): Promise<boolean> {
  const now = deps.clock.now();
  return deps.store.runTransaction(async (tx) => {
    const j = await tx.getCollabJob(item.bookingId, item.collaboratorId);
    if (!j) return false;
    const qualifies =
      reason === 'overdue'
        ? j.payStatus === 'due' && j.pay.dueAt !== null && j.pay.overdueFlaggedAt === null
          && j.pay.dueAt.getTime() + PAY_OVERDUE_DAYS * DAY_MS <= now.getTime()
        : j.payStatus === 'disputed' && j.pay.disputeFlaggedAt === null;
    if (!qualifies) return false;
    const c = await tx.getCounters(j.studioId);
    // ---- writes ----
    tx.putCollabJob({
      ...j,
      pay: reason === 'overdue' ? { ...j.pay, overdueFlaggedAt: now } : { ...j.pay, disputeFlaggedAt: now },
      updatedAt: now,
    });
    tx.putCounters(j.studioId, addUnpaidFlag(c, now));
    return true;
  });
}

/** Runs `step` for every item; counts the true answers and the throws. */
async function each<T>(items: readonly T[], step: (item: T) => Promise<boolean>): Promise<{ done: number; failed: number }> {
  let done = 0;
  let failed = 0;
  for (const item of items) {
    try {
      if (await step(item)) done += 1;
    } catch {
      failed += 1;
    }
  }
  return { done, failed };
}

/** Every S27 step, in order. Run before S26's studio-booking step, so an expired offer leaves the booking unassigned for S26's overdue mark. */
export async function runRecruitSweeps(deps: RecruitSweepDeps): Promise<RecruitSweepResults> {
  const now = deps.clock.now();
  const limit = RECRUIT_SWEEP_LIMIT;
  const store = deps.store;
  const posts = await each(await store.duePosts(now, limit), (p) => expireRecruitPost(deps, p.id));
  const apps = await each(await store.dueApplications(now, limit), (a) => expireRecruitApplication(deps, a.postId, a.applicantId));
  const invites = await each(await store.dueInvites(now, limit), (c) => expireCollabInvite(deps, c.studioId, c.collaboratorId));
  const offers = await each(await store.dueOffers(now, limit), (j) => expireCollabOffer(deps.assign, j.bookingId, j.collaboratorId));
  const due = await each(await store.payPending(now, limit), (j) => markPayDue(deps, j));
  const cutoff = new Date(now.getTime() - PAY_OVERDUE_DAYS * DAY_MS);
  const overdue = await each(await store.overduePay(cutoff, limit), (j) => flagUnpaid(deps, j, 'overdue'));
  const disputes = await each(await store.unflaggedDisputes(limit), (j) => flagUnpaid(deps, j, 'dispute'));
  return {
    postsExpired: posts.done,
    applicationsExpired: apps.done,
    invitesExpired: invites.done,
    offersExpired: offers.done,
    payDue: due.done,
    payFlagged: overdue.done + disputes.done,
    failed: posts.failed + apps.failed + invites.failed + offers.failed + due.failed + overdue.failed + disputes.failed,
  };
}
