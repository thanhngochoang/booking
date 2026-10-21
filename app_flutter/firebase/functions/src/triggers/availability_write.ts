import {
  formatVnDate,
  addDays,
  NEXT_FREE_HORIZON_DAYS,
  refreshNextFreeDate,
  type DiscoveryDeps,
  type ProviderType,
  type RefreshOutcome,
} from '@photobooking/domain';

export async function handleAvailabilityWrite(
  uid: string,
  dayKey: string,
  deps: DiscoveryDeps,
): Promise<RefreshOutcome | 'skipped'> {
  const today = formatVnDate(deps.clock.now());
  const maxDayExclusive = addDays(today, NEXT_FREE_HORIZON_DAYS);

  if (dayKey < today || dayKey >= maxDayExclusive) {
    return 'skipped';
  }

  return refreshNextFreeDate(deps, uid);
}

/** What the studio step of the availability trigger reads and runs (#136 Decision 26). */
export interface StudioDayDeps {
  readonly now: () => Date;
  /** `photographers/{uid}`: the studio a member belongs to and the provider type; null without a document. */
  profile(uid: string): Promise<{ readonly studioId: string | null; readonly providerType: ProviderType } | null>;
  recompute(studioId: string, day: string): Promise<unknown>;
}

/**
 * A day record of a member (a personal booking, an `off` day, an assignment) changes what their studio can take
 * that day; a studio's own `off` day closes it. The server's own `full` mark is not a cause, so it cannot loop.
 * Returns the studio recomputed, or null.
 */
export async function handleStudioDayWrite(
  uid: string,
  dayKey: string,
  before: Readonly<Record<string, unknown>> | undefined,
  after: Readonly<Record<string, unknown>> | undefined,
  deps: StudioDayDeps,
): Promise<string | null> {
  if (dayKey < formatVnDate(deps.now())) return null;
  const states = [before?.state, after?.state].filter((s) => s !== undefined);
  if (states.length > 0 && states.every((s) => s === 'full')) return null;
  const p = await deps.profile(uid);
  const studioId = p?.studioId ?? (p?.providerType === 'studio' ? uid : null);
  if (studioId === null) return null;
  await deps.recompute(studioId, dayKey);
  return studioId;
}
