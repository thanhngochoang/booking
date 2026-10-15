import {
  BADGE_CATALOG,
  eligibleBadges,
  planBadges,
  snapshotText,
  type BadgeMetric,
} from './badge.js';
import type { BadgeDeps } from './badge_ports.js';
import { formatVnDate } from './booking_policy.js';
import { notify } from './notification_use_cases.js';

const NEW_MEMBER_DAYS = 30;
const HOLDER_PAGE = 200;
const HOLDER_MAX_PAGES = 50;

/**
 * Idempotent: reads metrics outside the transaction, applies the plan inside one, then tells the user
 * about new badges (best effort, a failed notice never undoes an award).
 */
export async function evaluateUserBadges(
  deps: BadgeDeps,
  uid: string,
): Promise<{ awarded: string[]; revoked: string[] }> {
  const eligible = eligibleBadges(await deps.metrics.isPhotographer(uid));
  const needed = new Set<BadgeMetric>();
  for (const b of eligible) {
    needed.add(b.rule.metric);
    if (b.rule.minSample) needed.add(b.rule.minSample.metric);
  }
  const m = await deps.metrics.read(uid, needed);
  const now = deps.clock.now();

  const plan = await deps.badges.runTransaction(async (tx) => {
    const earned = new Set((await tx.listEarned(uid)).map((e) => e.badgeId));
    const p = planBadges(eligible, m, earned);
    for (const b of p.award) tx.putEarned(uid, { badgeId: b.id, awardedAt: now, snapshotText: snapshotText(b, m) });
    for (const id of p.revoke) tx.deleteEarned(uid, id);
    tx.setProgress(uid, p.progress, now);
    return p;
  });

  const day = formatVnDate(now).replace(/-/g, '');
  for (const b of plan.award) {
    try {
      await notify(deps.notify, {
        userId: uid,
        content: { type: 'badge_new', name: b.name, description: b.description },
        target: `/u/${uid}/badges`,
        dedupeKey: `badge_new_${b.id}_${day}`,
      });
    } catch (e) {
      deps.notify.onPushError?.(uid, e);
    }
  }
  return { awarded: plan.award.map((b) => b.id), revoked: [...plan.revoke] };
}

/** Nightly: sync the catalogue docs, then re-evaluate `new_member` holders past their 30 days. */
export async function reconcileBadges(deps: BadgeDeps): Promise<{ catalogWrites: number; reevaluated: number }> {
  const catalogWrites = await deps.badges.syncCatalog(BADGE_CATALOG);
  const cutoff = new Date(deps.clock.now().getTime() - NEW_MEMBER_DAYS * 24 * 60 * 60 * 1000);
  let cursor: string | null = null;
  let reevaluated = 0;
  let firstError: unknown = null;
  for (let page = 0; page < HOLDER_MAX_PAGES; page++) {
    const holders = await deps.badges.holdersOlderThan('new_member', cutoff, HOLDER_PAGE, cursor);
    if (holders.length === 0) break;
    for (const uid of holders) {
      try {
        await evaluateUserBadges(deps, uid);
        reevaluated += 1;
      } catch (e) {
        firstError ??= e; // one bad user must not stop the nightly run
      }
    }
    cursor = holders[holders.length - 1] ?? null;
    if (holders.length < HOLDER_PAGE) break;
  }
  if (firstError !== null) throw new Error(`reconcileBadges: some users failed: ${String(firstError)}`);
  return { catalogWrites, reevaluated };
}
