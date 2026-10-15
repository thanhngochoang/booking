/**
 * Scheduled job handler for rankSpots (spec S29).
 */

import { runSpotRanking } from '@photobooking/domain';
import { FirestoreSpotCounter, FirestoreSpotRankStore } from '../infra/spot_rank_firestore.js';
import { logger } from 'firebase-functions';

export interface RankSpotsDeps {
  store: FirestoreSpotRankStore;
  counter: FirestoreSpotCounter;
  clock: { now(): Date };
}

export function liveRankSpotsDeps(): RankSpotsDeps {
  return {
    store: new FirestoreSpotRankStore(),
    counter: new FirestoreSpotCounter(),
    clock: { now: () => new Date() },
  };
}

export async function handleRankSpots(deps: RankSpotsDeps): Promise<{ spots: number; changed: number; keys: string[] }> {
  const result = await runSpotRanking(deps);
  logger.info('rankSpots completed', result);
  return result;
}
