import type { DocumentData } from 'firebase-admin/firestore';
import {
  evaluateUserBadges,
  refreshStartingPrice,
  refreshExploreCategory,
  type BadgeDeps,
  type DiscoveryDeps,
  type RefreshOutcome,
} from '@photobooking/domain';

type Service = { active?: unknown; price?: unknown; specialty?: unknown; coverUrl?: unknown } | undefined;

/** `complete_profile` depends on having an active package: evaluate when that changes. */
export async function handleServiceWrite(
  uid: string,
  before: Service,
  after: Service,
  deps: BadgeDeps,
): Promise<boolean> {
  const active = (s: Service): boolean => s !== undefined && s.active !== false;
  if (active(before) === active(after)) return false;
  await evaluateUserBadges(deps, uid);
  return true;
}

export async function handleServiceDiscovery(
  uid: string,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
  deps: DiscoveryDeps,
): Promise<{ price: RefreshOutcome | 'skipped'; categories: string[] }> {
  let priceOutcome: RefreshOutcome | 'skipped' = 'skipped';
  const priceChanged = before?.price !== after?.price || before?.active !== after?.active;
  if (priceChanged) {
    priceOutcome = await refreshStartingPrice(deps, uid);
  }

  const activeChanged = before?.active !== after?.active;
  const specialtyChanged = before?.specialty !== after?.specialty;
  const coverChanged = before?.coverUrl !== after?.coverUrl;

  const categories: string[] = [];
  if (activeChanged || specialtyChanged || coverChanged) {
    const catsToRefresh = new Set<string>();
    if (typeof before?.specialty === 'string') catsToRefresh.add(before.specialty);
    if (typeof after?.specialty === 'string') catsToRefresh.add(after.specialty);

    for (const cat of catsToRefresh) {
      await refreshExploreCategory(deps, cat);
      categories.push(cat);
    }
  }

  return { price: priceOutcome, categories };
}
