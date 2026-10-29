/**
 * In-memory implementations of SpotRankStore, SpotCounter, and SpotAdminStore.
 */

import type { Spot } from './spot.js';
import type {
  SpotRankStore,
  SpotCounter,
  SpotRankings,
  DirectoryEntry,
} from './spot_ranking.js';
import type { SpotAdminStore, SpotField } from './spot_admin.js';

export interface SpotCounterCounts {
  posts?: number;
  events?: number;
  paidBookings?: number;
  schedulesNext30?: number;
  schedulesNext7?: number;
  schedulesWeekend?: number;
}

export class MemorySpotCounter implements SpotCounter {
  private readonly counts = new Map<string, SpotCounterCounts>();

  setCounts(spotId: string, counts: SpotCounterCounts): void {
    this.counts.set(spotId, counts);
  }

  async posts(spotId: string, sinceIso: string): Promise<number> {
    void sinceIso;
    return this.counts.get(spotId)?.posts ?? 0;
  }

  async events(spotId: string, fromIso: string, toIso: string): Promise<number> {
    void fromIso;
    void toIso;
    return this.counts.get(spotId)?.events ?? 0;
  }

  async paidBookings(spotId: string, sinceIso: string): Promise<number> {
    void sinceIso;
    return this.counts.get(spotId)?.paidBookings ?? 0;
  }

  async schedulesWithDay(spotId: string, days: readonly string[]): Promise<number> {
    const c = this.counts.get(spotId);
    if (!c) return 0;
    // Map based on day count
    if (days.length === 30) return c.schedulesNext30 ?? 0;
    if (days.length === 7) return c.schedulesNext7 ?? 0;
    return c.schedulesWeekend ?? 0;
  }
}

export class MemorySpotRankStore implements SpotRankStore, SpotAdminStore {
  private readonly spots = new Map<string, Spot>();
  private readonly rankings = new Map<string, SpotRankings>();
  private directory: DirectoryEntry[] = [];
  private rankingKeys = new Set<string>();

  seedSpot(spot: Spot): void {
    this.spots.set(spot.id, spot);
  }

  seedRankingKey(key: string): void {
    this.rankingKeys.add(key);
  }

  async listSpots(): Promise<Spot[]> {
    return [...this.spots.values()];
  }

  async getSpot(id: string): Promise<Spot | null> {
    return this.spots.get(id) ?? null;
  }

  async saveSpot(s: Spot): Promise<void> {
    this.spots.set(s.id, s);
  }

  async putSpot(s: Spot, fields?: readonly SpotField[]): Promise<void> {
    const current = this.spots.get(s.id);
    if (fields === undefined || current === undefined) {
      this.spots.set(s.id, s);
      return;
    }
    const next: Record<string, unknown> = { ...current };
    for (const f of fields) next[f] = s[f];
    this.spots.set(s.id, next as unknown as Spot);
  }

  async listRankingKeys(): Promise<string[]> {
    return [...this.rankingKeys];
  }

  async saveRankings(r: readonly SpotRankings[], staleKeys: readonly string[]): Promise<void> {
    for (const ranking of r) {
      this.rankings.set(ranking.key, ranking);
      this.rankingKeys.add(ranking.key);
    }
    for (const key of staleKeys) {
      this.rankings.delete(key);
      this.rankingKeys.delete(key);
    }
  }

  async saveDirectory(e: readonly DirectoryEntry[], now: string): Promise<void> {
    void now;
    this.directory = [...e];
  }

  getRankings(): SpotRankings[] {
    return [...this.rankings.values()];
  }

  getDirectory(): DirectoryEntry[] {
    return [...this.directory];
  }
}
