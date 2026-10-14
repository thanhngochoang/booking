import { rollNextFreeDates, type DiscoveryDeps } from '@photobooking/domain';

export async function handleRollNextFree(
  deps: DiscoveryDeps,
): Promise<{ refreshed: number; pages: number }> {
  return rollNextFreeDates(deps);
}
