import type {
  DiscoveryStatsStore,
  EngagementStore,
  ExploreCatalogStore,
} from './discovery_ports.js';
import {
  type PhotographerStatsSnapshot,
  type DiscoveryStatsPatch,
  type EngagementKind,
  type ExploreCategoryStat,
  ENGAGEMENT_FIELD,
} from './discovery_stats.js';

interface StoredPhotographer {
  nextFreeDate: string | null;
  score: number | null;
  completedCount: number;
  startingPrice: number | null;
}

interface StoredService {
  price?: number;
  active: boolean;
  specialty?: string;
  coverUrl?: string | null;
  updatedAt?: number;
}

interface StoredPost {
  likeCount: number;
  saveCount: number;
}

export class MemoryDiscoveryStore
  implements DiscoveryStatsStore, EngagementStore, ExploreCatalogStore
{
  private photographers = new Map<string, StoredPhotographer>();
  private blockedAvailability = new Map<string, Set<string>>(); // uid -> set of blocked day keys
  private services = new Map<string, StoredService[]>(); // uid -> services
  private catalogServices: StoredService[] = [];
  private bookings = new Map<string, string[]>(); // uid -> statuses
  private posts = new Map<string, StoredPost>();
  private engagements = new Map<string, Set<string>>(); // `${kind}_${postId}` -> set of userIds
  private catalog = new Map<string, ExploreCategoryStat>();

  // --- Test helpers ---
  addPhotographer(
    uid: string,
    stats: Partial<StoredPhotographer> = {},
  ): void {
    this.photographers.set(uid, {
      nextFreeDate: stats.nextFreeDate ?? null,
      score: stats.score !== undefined ? stats.score : null,
      completedCount: stats.completedCount ?? 0,
      startingPrice: stats.startingPrice ?? null,
    });
  }

  setBlockedDay(uid: string, dayKey: string): void {
    let set = this.blockedAvailability.get(uid);
    if (!set) {
      set = new Set();
      this.blockedAvailability.set(uid, set);
    }
    set.add(dayKey);
  }

  addService(uid: string, service: StoredService): void {
    let list = this.services.get(uid);
    if (!list) {
      list = [];
      this.services.set(uid, list);
    }
    list.push(service);
  }

  addServiceWithCatalog(service: StoredService): void {
    this.catalogServices.push(service);
  }

  addBooking(uid: string, status: string): void {
    let list = this.bookings.get(uid);
    if (!list) {
      list = [];
      this.bookings.set(uid, list);
    }
    list.push(status);
  }

  addPost(postId: string, post: StoredPost): void {
    this.posts.set(postId, { ...post });
  }

  addEngagement(kind: EngagementKind, postId: string, userId: string): void {
    const key = `${kind}_${postId}`;
    let set = this.engagements.get(key);
    if (!set) {
      set = new Set();
      this.engagements.set(key, set);
    }
    set.add(userId);
  }

  // --- DiscoveryStatsStore ---
  async snapshot(uid: string): Promise<PhotographerStatsSnapshot | null> {
    const p = this.photographers.get(uid);
    if (!p) return null;
    return {
      nextFreeDate: p.nextFreeDate,
      score: p.score ?? undefined,
      completedCount: p.completedCount,
      startingPrice: p.startingPrice,
    };
  }

  async blockedDays(
    uid: string,
    from: string,
    toExclusive: string,
  ): Promise<Set<string>> {
    const set = this.blockedAvailability.get(uid);
    const result = new Set<string>();
    if (!set) return result;
    for (const day of set) {
      if (day >= from && day < toExclusive) {
        result.add(day);
      }
    }
    return result;
  }

  async activeServicePrices(uid: string): Promise<number[]> {
    const list = this.services.get(uid) ?? [];
    return list
      .filter((s) => s.active && typeof s.price === 'number')
      .map((s) => s.price as number);
  }

  async completedBookings(uid: string): Promise<number> {
    const list = this.bookings.get(uid) ?? [];
    return list.filter((st) => st === 'completed' || st === 'reviewed').length;
  }

  async apply(uid: string, patch: DiscoveryStatsPatch): Promise<void> {
    const p = this.photographers.get(uid);
    if (!p) return;
    if (patch.nextFreeDate !== undefined) {
      p.nextFreeDate = patch.nextFreeDate;
    }
    if (patch.ensureScore && p.score === null) {
      p.score = 0;
    }
    if (patch.completedCount !== undefined) {
      p.completedCount = patch.completedCount;
    }
    if (patch.startingPrice !== undefined) {
      p.startingPrice = patch.startingPrice;
    }
  }

  async staleNextFree(
    beforeDay: string,
    limit: number,
    afterUid: string | null,
  ): Promise<string[]> {
    const uids: string[] = [];
    const sorted = Array.from(this.photographers.entries()).sort(([a], [b]) =>
      a.localeCompare(b),
    );

    for (const [uid, p] of sorted) {
      if (afterUid && uid <= afterUid) continue;
      if (p.nextFreeDate !== null && p.nextFreeDate < beforeDay) {
        uids.push(uid);
        if (uids.length >= limit) break;
      }
    }
    return uids;
  }

  // --- EngagementStore ---
  async recount(
    kind: EngagementKind,
    postId: string,
  ): Promise<'written' | 'unchanged' | 'missing'> {
    const post = this.posts.get(postId);
    if (!post) return 'missing';

    const count = this.engagements.get(`${kind}_${postId}`)?.size ?? 0;
    const field = ENGAGEMENT_FIELD[kind];

    if (post[field] === count) {
      return 'unchanged';
    }

    post[field] = count;
    return 'written';
  }

  // --- ExploreCatalogStore ---
  async activeServiceCount(specialty: string): Promise<number> {
    return this.catalogServices.filter(
      (s) => s.specialty === specialty && s.active,
    ).length;
  }

  async latestActiveCover(specialty: string): Promise<string | null> {
    const candidates = this.catalogServices
      .filter((s) => s.specialty === specialty && s.active && s.coverUrl)
      .sort((a, b) => (b.updatedAt ?? 0) - (a.updatedAt ?? 0));

    return candidates[0]?.coverUrl ?? null;
  }

  async current(specialty: string): Promise<ExploreCategoryStat | null> {
    return this.catalog.get(specialty) ?? null;
  }

  async put(specialty: string, stat: ExploreCategoryStat): Promise<void> {
    this.catalog.set(specialty, { ...stat });
  }
}
