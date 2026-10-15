import * as logger from 'firebase-functions/logger';
import { purgeDueProofs, type AwardDeps, type AwardProof, type Clock } from '@photobooking/domain';
import { liveAwardDeps, liveAwardStore } from '../infra/live_award.js';
import { liveBusinessDocPurgeDeps } from '../infra/live_verification.js';

/** One page of business registration photos per run; the rest waits for the next day. */
export const BUSINESS_PURGE_PAGE = 200;

/** Second step of the daily purge: S21.04 registration photos whose `business.purgeAfter` passed (Decision 20). */
export interface BusinessDocPurgeDeps {
  due(now: Date, limit: number): Promise<readonly { readonly uid: string; readonly docPath: string | null }[]>;
  deleteFiles(paths: readonly string[]): Promise<void>;
  /** Clears `business.docPath` and `business.purgeAfter` once the file is gone. */
  clear(uid: string, docPath: string | null, now: Date): Promise<void>;
  readonly clock: Clock;
}

/** Deletes each due photo, then clears its record; one failure is logged and retried tomorrow. */
export async function purgeBusinessDocs(deps: BusinessDocPurgeDeps): Promise<number> {
  const now = deps.clock.now();
  let purged = 0;
  for (const d of await deps.due(now, BUSINESS_PURGE_PAGE)) {
    try {
      // File first: a failed delete leaves the record in the query for the next run.
      if (d.docPath !== null) await deps.deleteFiles([d.docPath]);
      await deps.clear(d.uid, d.docPath, now);
      if (d.docPath !== null) purged += 1;
    } catch (e) {
      logger.warn('purgeBusinessDocs item failed', { uid: d.uid, error: e instanceof Error ? e.name : 'unknown' });
    }
  }
  return purged;
}

/** Daily: deletes the files and the doc of proofs whose 30-day window has passed, then business photos. */
export async function handleAwardPurge(
  deps: AwardDeps & { proofsDue: (now: Date) => Promise<AwardProof[]> } = {
    ...liveAwardDeps(),
    proofsDue: (now) => liveAwardStore().proofsDue(now),
  },
  business: BusinessDocPurgeDeps = liveBusinessDocPurgeDeps(),
): Promise<number> {
  let purged = 0;
  let awardError: unknown = null;
  try {
    purged = await purgeDueProofs(deps);
    logger.info('purgeAwardProofs completed', { purged });
  } catch (e) {
    logger.error('purgeAwardProofs failed', { error: String(e) });
    awardError = e;
  }
  // Own try: the award purge's result (or error) is what the job reports.
  try {
    const businessDocs = await purgeBusinessDocs(business);
    logger.info('purgeAwardProofs businessDocs completed', { purged: businessDocs });
  } catch (e) {
    logger.error('purgeAwardProofs businessDocs failed', { error: String(e) });
  }
  if (awardError !== null) throw awardError;
  return purged;
}
