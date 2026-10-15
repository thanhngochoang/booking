import {
  formatVnDate,
  addDays,
  NEXT_FREE_HORIZON_DAYS,
  refreshNextFreeDate,
  type DiscoveryDeps,
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
