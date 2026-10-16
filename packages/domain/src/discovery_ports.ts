import type { Clock } from './ports.js';
import type {
  PhotographerStatsSnapshot,
  DiscoveryStatsPatch,
  EngagementKind,
  ExploreCategoryStat,
} from './discovery_stats.js';

export interface DiscoveryStatsStore {
  /** photographers/{uid} stats fields; null when the document is missing. */
  snapshot(uid: string): Promise<PhotographerStatsSnapshot | null>;
  /** Day keys with a stored availability document in [from, toExclusive). */
  blockedDays(uid: string, from: string, toExclusive: string): Promise<Set<string>>;
  activeServicePrices(uid: string): Promise<number[]>;
  /** count() of bookings with this photographerId and status in completed | reviewed. */
  completedBookings(uid: string): Promise<number>;
  /** Applies the patch in one update; a missing document is a no-op (never recreated). */
  apply(uid: string, patch: DiscoveryStatsPatch): Promise<void>;
  /** Up to `limit` uids with stats.nextFreeDate < beforeDay, by uid, after `afterUid`. */
  staleNextFree(beforeDay: string, limit: number, afterUid: string | null): Promise<string[]>;
}

export interface EngagementStore {
  /** Recount and write in one transaction; 'missing' when the post is gone. */
  recount(kind: EngagementKind, postId: string): Promise<'written' | 'unchanged' | 'missing'>;
}

export interface ExploreCatalogStore {
  activeServiceCount(specialty: string): Promise<number>;
  latestActiveCover(specialty: string): Promise<string | null>;
  current(specialty: string): Promise<ExploreCategoryStat | null>;
  put(specialty: string, stat: ExploreCategoryStat): Promise<void>;
}

export interface DiscoveryDeps {
  readonly stats: DiscoveryStatsStore;
  readonly engagement: EngagementStore;
  readonly catalog: ExploreCatalogStore;
  readonly clock: Clock;
}
