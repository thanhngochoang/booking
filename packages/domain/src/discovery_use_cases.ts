import { formatVnDate } from './booking_policy.js';
import type {
  DiscoveryDeps,
} from './discovery_ports.js';
import {
  addDays,
  computeNextFreeDate,
  computeStartingPrice,
  statsPatch,
  isCatalogSpecialty,
  NEXT_FREE_HORIZON_DAYS,
  type EngagementKind,
} from './discovery_stats.js';

export type RefreshOutcome = 'written' | 'unchanged' | 'missing';

export async function refreshNextFreeDate(
  deps: DiscoveryDeps,
  uid: string,
): Promise<RefreshOutcome> {
  const snap = await deps.stats.snapshot(uid);
  if (snap === null) return 'missing';
  const today = formatVnDate(deps.clock.now());
  const blocked = await deps.stats.blockedDays(
    uid,
    today,
    addDays(today, NEXT_FREE_HORIZON_DAYS),
  );
  const nextDate = computeNextFreeDate(today, blocked);
  const patch = statsPatch(snap, { nextFreeDate: nextDate });
  if (patch === null) return 'unchanged';
  await deps.stats.apply(uid, patch);
  return 'written';
}

export async function refreshStartingPrice(
  deps: DiscoveryDeps,
  uid: string,
): Promise<RefreshOutcome> {
  const snap = await deps.stats.snapshot(uid);
  if (snap === null) return 'missing';
  const prices = await deps.stats.activeServicePrices(uid);
  const startingPrice = computeStartingPrice(prices);
  const patch = statsPatch(snap, { startingPrice });
  if (patch === null) return 'unchanged';
  await deps.stats.apply(uid, patch);
  return 'written';
}

export async function refreshCompletedCount(
  deps: DiscoveryDeps,
  uid: string,
): Promise<RefreshOutcome> {
  const snap = await deps.stats.snapshot(uid);
  if (snap === null) return 'missing';
  const completedCount = await deps.stats.completedBookings(uid);
  const patch = statsPatch(snap, { completedCount });
  if (patch === null) return 'unchanged';
  await deps.stats.apply(uid, patch);
  return 'written';
}

export async function rollNextFreeDates(
  deps: DiscoveryDeps,
  opts?: { pageSize?: number; maxPages?: number },
): Promise<{ refreshed: number; pages: number }> {
  const pageSize = opts?.pageSize ?? 200;
  const maxPages = opts?.maxPages ?? 25;
  const today = formatVnDate(deps.clock.now());

  let refreshed = 0;
  let pages = 0;
  let lastUid: string | null = null;

  while (pages < maxPages) {
    const batch = await deps.stats.staleNextFree(today, pageSize, lastUid);
    if (batch.length === 0) break;
    pages++;
    for (const uid of batch) {
      const outcome = await refreshNextFreeDate(deps, uid);
      if (outcome === 'written') {
        refreshed++;
      }
    }
    if (batch.length < pageSize) break;
    const last = batch[batch.length - 1];
    if (last === undefined) break;
    lastUid = last;
  }

  return { refreshed, pages };
}

export async function refreshEngagementCount(
  deps: DiscoveryDeps,
  kind: EngagementKind,
  postId: string,
): Promise<RefreshOutcome> {
  return deps.engagement.recount(kind, postId);
}

export async function refreshExploreCategory(
  deps: DiscoveryDeps,
  specialty: string,
): Promise<RefreshOutcome> {
  if (!isCatalogSpecialty(specialty)) {
    return 'unchanged';
  }
  const count = await deps.catalog.activeServiceCount(specialty);
  const coverUrl = await deps.catalog.latestActiveCover(specialty);
  const current = await deps.catalog.current(specialty);

  if (current && current.serviceCount === count && current.coverUrl === coverUrl) {
    return 'unchanged';
  }

  await deps.catalog.put(specialty, { serviceCount: count, coverUrl });
  return 'written';
}
