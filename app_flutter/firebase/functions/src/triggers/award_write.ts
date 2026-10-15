import * as logger from 'firebase-functions/logger';
import { recomputeTier, type AwardDeps } from '@photobooking/domain';

/**
 * Recomputes the artist tier of the award's owner, and of the previous owner when it differs.
 * Idempotent: recomputeTier writes only when something changed, so there is no loop.
 */
export async function handleAwardWrite(
  before: { photographerId?: unknown } | undefined,
  after: { photographerId?: unknown } | undefined,
  deps: AwardDeps,
): Promise<string[]> {
  const owners = new Set<string>();
  for (const d of [before, after]) {
    if (typeof d?.photographerId === 'string' && d.photographerId !== '') owners.add(d.photographerId);
  }
  for (const uid of owners) {
    const outcome = await recomputeTier(deps, uid);
    if (outcome !== 'unchanged') logger.info('onAwardWrite', { uid, outcome });
  }
  return [...owners];
}
