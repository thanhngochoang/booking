/**
 * Scheduled job handler for rankSpots (spec S29). S30 (#223 Decision 13): the same daily job also removes
 * residents whose `validUntil` is past (`expireResidents`); no new Scheduler job.
 */

import { expireResidents, formatVnDate, runSpotRanking, type OrganizerDeps } from '@photobooking/domain';
import { FirestoreSpotCounter, FirestoreSpotRankStore } from '../infra/spot_rank_firestore.js';
import { logger } from 'firebase-functions';

export interface RankSpotsDeps {
  store: FirestoreSpotRankStore;
  counter: FirestoreSpotCounter;
  clock: { now(): Date };
  /** S30: the organizer store `expireResidents` sweeps; absent → the step is skipped. */
  residents?: OrganizerDeps;
}

export async function liveRankSpotsDeps(): Promise<RankSpotsDeps> {
  const { liveOrganizerDeps } = await import('../infra/live_organizer.js');
  return {
    store: new FirestoreSpotRankStore(),
    counter: new FirestoreSpotCounter(),
    clock: { now: () => new Date() },
    residents: liveOrganizerDeps(),
  };
}

export async function handleRankSpots(
  deps: RankSpotsDeps,
): Promise<{ spots: number; changed: number; keys: string[]; residentsExpired: number }> {
  // S29.02 and S04.03 already ignore an expired waiver (`waiverFor` checks the date); this keeps the list short.
  let residentsExpired = 0;
  if (deps.residents !== undefined) {
    try {
      residentsExpired = await expireResidents(deps.residents, formatVnDate(deps.clock.now()));
      if (residentsExpired > 0) logger.info('rankSpots expireResidents completed', { residentsExpired });
    } catch (e) {
      // Its own try: a failing sweep (e.g. a missing index) never stops the ranking; retried tomorrow.
      logger.error('rankSpots expireResidents failed', { error: e instanceof Error ? e.name : 'unknown' });
    }
  }
  const result = await runSpotRanking(deps);
  logger.info('rankSpots completed', result);
  return { ...result, residentsExpired };
}
