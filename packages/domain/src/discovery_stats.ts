export const NEXT_FREE_HORIZON_DAYS = 60;

/**
 * Calendar arithmetic on `yyyy-MM-dd` (no time zone involved).
 */
export function addDays(dayKey: string, days: number): string {
  const parts = dayKey.split('-');
  if (parts.length !== 3 || !parts[0] || !parts[1] || !parts[2]) {
    throw new Error(`Invalid dayKey: ${dayKey}`);
  }
  const y = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  const d = parseInt(parts[2], 10);

  const ms = Date.UTC(y, m - 1, d + days);
  const dt = new Date(ms);
  const resY = dt.getUTCFullYear();
  const resM = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const resD = String(dt.getUTCDate()).padStart(2, '0');
  return `${resY}-${resM}-${resD}`;
}

/**
 * First day in [today, today + horizonDays) that is not a key of `blocked`; null when none.
 * Any stored state blocks.
 */
export function computeNextFreeDate(
  today: string,
  blocked: ReadonlySet<string>,
  horizonDays: number = NEXT_FREE_HORIZON_DAYS,
): string | null {
  for (let i = 0; i < horizonDays; i++) {
    const candidate = addDays(today, i);
    if (!blocked.has(candidate)) {
      return candidate;
    }
  }
  return null;
}

/**
 * Smallest positive integer price; null when there is none.
 * Non-integers and <= 0 are ignored.
 */
export function computeStartingPrice(prices: readonly unknown[]): number | null {
  let min: number | null = null;
  for (const p of prices) {
    if (typeof p === 'number' && Number.isInteger(p) && p > 0) {
      if (min === null || p < min) {
        min = p;
      }
    }
  }
  return min;
}

export interface PhotographerStatsSnapshot {
  readonly nextFreeDate?: unknown;
  readonly score?: unknown;
  readonly completedCount?: unknown;
  readonly startingPrice?: unknown;
}

/**
 * Named DiscoveryStatsPatch because review_stats.ts already exports PhotographerStatsPatch.
 */
export interface DiscoveryStatsPatch {
  readonly nextFreeDate?: string | null;
  readonly ensureScore?: true;
  readonly completedCount?: number;
  readonly startingPrice?: number | null;
}

/**
 * The fields that differ from `current` (plus ensureScore when score is not a number);
 * null when nothing changes.
 */
export function statsPatch(
  current: PhotographerStatsSnapshot,
  next: Partial<{
    nextFreeDate: string | null;
    completedCount: number;
    startingPrice: number | null;
  }>,
): DiscoveryStatsPatch | null {
  let changed = false;
  const patch: Record<string, unknown> = {};

  if (next.nextFreeDate !== undefined && next.nextFreeDate !== (current.nextFreeDate ?? null)) {
    patch.nextFreeDate = next.nextFreeDate;
    changed = true;
  }

  if (
    next.completedCount !== undefined &&
    next.completedCount !== (current.completedCount ?? 0)
  ) {
    patch.completedCount = next.completedCount;
    changed = true;
  }

  if (
    next.startingPrice !== undefined &&
    next.startingPrice !== (current.startingPrice ?? null)
  ) {
    patch.startingPrice = next.startingPrice;
    changed = true;
  }

  const needsScore = typeof current.score !== 'number';
  if (needsScore && (patch.nextFreeDate !== undefined || next.nextFreeDate !== undefined)) {
    // Decision 6: The writer of nextFreeDate also writes stats.score: 0 when the field is missing
    patch.ensureScore = true;
    changed = true;
  }

  if (!changed) {
    return null;
  }

  return patch as DiscoveryStatsPatch;
}

export type EngagementKind = 'like' | 'save';

export const ENGAGEMENT_FIELD = {
  like: 'likeCount',
  save: 'saveCount',
} as const;

export interface ExploreCategoryStat {
  readonly serviceCount: number;
  readonly coverUrl: string | null;
}

const CATALOG_SPECIALTY_RE = /^[a-z][a-z0-9_]{1,39}$/;

/**
 * True for a specialty code shape ^[a-z][a-z0-9_]{1,39}$
 */
export function isCatalogSpecialty(code: unknown): code is string {
  if (typeof code !== 'string') return false;
  return CATALOG_SPECIALTY_RE.test(code);
}
