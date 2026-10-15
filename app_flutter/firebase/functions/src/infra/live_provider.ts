import * as logger from 'firebase-functions/logger';
import { recomputeTier, type ProviderDeps } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { liveAwardDeps } from './live_award.js';
import { FirestoreProviderStore } from './provider_firestore.js';

export function liveProviderDeps(): ProviderDeps {
  return {
    providers: new FirestoreProviderStore(adminDb()),
    clock: { now: () => new Date() },
    // Runs after setProviderType's commit: a failure is logged and never undoes the switch.
    recomputeArtistTier: async (uid) => {
      try {
        await recomputeTier(liveAwardDeps(), uid);
      } catch (e) {
        logger.error('recomputeArtistTier failed', { uid, error: String(e) });
      }
    },
  };
}
