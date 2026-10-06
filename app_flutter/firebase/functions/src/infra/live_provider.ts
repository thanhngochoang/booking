import type { ProviderDeps } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { FirestoreProviderStore } from './provider_firestore.js';

export function liveProviderDeps(): ProviderDeps {
  return {
    providers: new FirestoreProviderStore(adminDb()),
    clock: { now: () => new Date() },
    // Plan B1 (2026-10-05-b1-awards-artist-tier.md) fills this with the NAG tier recompute.
    recomputeArtistTier: async () => {},
  };
}
