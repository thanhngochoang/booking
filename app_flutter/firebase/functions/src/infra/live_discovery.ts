import { db } from './admin.js';
import type { DiscoveryDeps } from '@photobooking/domain';
import {
  FirestoreDiscoveryStatsStore,
  FirestoreEngagementStore,
  FirestoreExploreCatalogStore,
} from './discovery_firestore.js';

export function liveDiscoveryDeps(): DiscoveryDeps {
  const firestore = db();
  return {
    stats: new FirestoreDiscoveryStatsStore(firestore),
    engagement: new FirestoreEngagementStore(firestore),
    catalog: new FirestoreExploreCatalogStore(firestore),
    clock: { now: () => new Date() },
  };
}
