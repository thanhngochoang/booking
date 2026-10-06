import * as logger from 'firebase-functions/logger';
import { purgeDueProofs, type AwardDeps, type AwardProof } from '@photobooking/domain';
import { liveAwardDeps, liveAwardStore } from '../infra/live_award.js';

/** Daily: deletes the files and the doc of proofs whose 30-day window has passed. */
export async function handleAwardPurge(
  deps: AwardDeps & { proofsDue: (now: Date) => Promise<AwardProof[]> } = {
    ...liveAwardDeps(),
    proofsDue: (now) => liveAwardStore().proofsDue(now),
  },
): Promise<number> {
  try {
    const purged = await purgeDueProofs(deps);
    logger.info('purgeAwardProofs completed', { purged });
    return purged;
  } catch (e) {
    logger.error('purgeAwardProofs failed', { error: String(e) });
    throw e;
  }
}
