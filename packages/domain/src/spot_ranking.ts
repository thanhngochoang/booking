/**
 * Pure spot ranking, directory, and runSpotRanking job (spec S29).
 */

import type { Clock } from './ports.js';
import { formatVnDate } from './booking_policy.js';
import type { Spot, SpotStats } from './spot.js';
import { inSeason, seasonOk } from './spot.js';
import { spotHotScore, RANK_HOT_LIMIT, RANKING_MAX_ENTRIES } from './spot_score.js';

export interface RankingEntry {
  readonly spotId: string;
  readonly name: string;
  readonly city: string;
  readonly areaCode: string;
  readonly cardUrl: string | null;
  readonly lat: number;
  readonly lng: number;
  readonly seasonMonths: readonly number[];
  readonly inSeason: boolean;
  readonly providersWeek: number;
  readonly pinned: boolean;
}

export interface SpotRankings {
  readonly key: string;
  readonly entries: readonly RankingEntry[];
  readonly rankedAt: string;
}

export interface DirectoryEntry extends RankingEntry {
  readonly radiusM: number;
  readonly hidden: boolean;
  readonly hotScore: number;
  readonly openSchedules: number;
  readonly providersWeekend: number;
  readonly upcomingEvents: number;
}

export interface SpotCounter {
  posts(spotId: string, sinceIso: string): Promise<number>;
  events(spotId: string, fromIso: string, toIso: string): Promise<number>;
  paidBookings(spotId: string, sinceIso: string): Promise<number>;
  schedulesWithDay(spotId: string, days: readonly string[]): Promise<number>;
}

export interface SpotRankStore {
  listSpots(): Promise<Spot[]>;
  saveSpot(s: Spot): Promise<void>;
  listRankingKeys?(): Promise<string[]>;
  saveRankings(r: readonly SpotRankings[], staleKeys: readonly string[]): Promise<void>;
  saveDirectory(e: readonly DirectoryEntry[], now: string): Promise<void>;
}

export function entryOf(s: Spot, month: number): RankingEntry {
  return {
    spotId: s.id,
    name: s.name,
    city: s.city,
    areaCode: s.areaCode,
    cardUrl: s.cover?.cardUrl ?? null,
    lat: s.point.lat,
    lng: s.point.lng,
    seasonMonths: s.seasonMonths,
    inSeason: inSeason(s.seasonMonths, month),
    providersWeek: s.stats.providersWeek,
    pinned: s.pinned,
  };
}

export function directoryEntryOf(s: Spot, month: number): DirectoryEntry {
  return {
    ...entryOf(s, month),
    radiusM: s.radiusM,
    hidden: s.hidden,
    hotScore: s.hotScore,
    openSchedules: s.stats.openSchedules,
    providersWeekend: s.stats.providersWeekend,
    upcomingEvents: s.stats.events,
  };
}

/**
 * Produces 'all' + one rankings document per areaCode containing an active spot.
 */
export function rankSpots(spots: readonly Spot[], month: number, now: string): SpotRankings[] {
  const live = spots.filter((s) => s.status === 'active' && !s.hidden);
  const pinned = live.filter((s) => s.pinned);
  const hot = live
    .filter((s) => !s.pinned && s.hotScore > 0 && seasonOk(s, month))
    .sort((a, b) => b.hotScore - a.hotScore || a.name.localeCompare(b.name, 'vi'));
  const national = hot.slice(0, RANK_HOT_LIMIT);
  const entry = (s: Spot) => entryOf(s, month);

  const out: SpotRankings[] = [
    {
      key: 'all',
      rankedAt: now,
      entries: [...pinned, ...national].slice(0, RANKING_MAX_ENTRIES).map(entry),
    },
  ];

  const activeAreas = [...new Set(spots.filter((s) => s.status === 'active').map((s) => s.areaCode))].sort();
  for (const area of activeAreas) {
    const own = hot.filter((s) => s.areaCode === area).slice(0, RANK_HOT_LIMIT);
    const fill = national.filter((s) => s.areaCode !== area).slice(0, RANK_HOT_LIMIT - own.length);
    out.push({
      key: area,
      rankedAt: now,
      entries: [...pinned.filter((s) => s.areaCode === area), ...own, ...fill]
        .slice(0, RANKING_MAX_ENTRIES)
        .map(entry),
    });
  }

  return out;
}

/**
 * Returns all active spots in directory format (including hidden spots).
 */
export function spotDirectory(spots: readonly Spot[], month: number): DirectoryEntry[] {
  return spots
    .filter((s) => s.status === 'active')
    .map((s) => directoryEntryOf(s, month));
}

/**
 * Returns n consecutive VN calendar days formatted yyyy-MM-dd, starting with `today`.
 */
export function nextDays(today: string, n: number): string[] {
  const parts = today.split('-').map(Number);
  const y = parts[0] ?? 2026;
  const m = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  const out: string[] = [];
  for (let i = 0; i < n; i++) {
    const dt = new Date(Date.UTC(y, m - 1, d + i));
    const year = dt.getUTCFullYear();
    const month = String(dt.getUTCMonth() + 1).padStart(2, '0');
    const day = String(dt.getUTCDate()).padStart(2, '0');
    out.push(`${year}-${month}-${day}`);
  }
  return out;
}

/**
 * Returns upcoming weekend days for the current week/weekend.
 * On Wednesday: [Sat, Sun].
 * On Saturday: [today (Sat), tomorrow (Sun)].
 * On Sunday: [today (Sun)].
 */
export function weekendDays(today: string): string[] {
  const parts = today.split('-').map(Number);
  const y = parts[0] ?? 2026;
  const m = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  const dt = new Date(Date.UTC(y, m - 1, d));
  const dayOfWeek = dt.getUTCDay(); // 0: Sun, 1: Mon, ..., 6: Sat

  if (dayOfWeek === 0) {
    return [today];
  }
  if (dayOfWeek === 6) {
    const sun = new Date(Date.UTC(y, m - 1, d + 1));
    const sunStr = `${sun.getUTCFullYear()}-${String(sun.getUTCMonth() + 1).padStart(2, '0')}-${String(sun.getUTCDate()).padStart(2, '0')}`;
    return [today, sunStr];
  }

  const satOffset = 6 - dayOfWeek;
  const sunOffset = 7 - dayOfWeek;
  const sat = new Date(Date.UTC(y, m - 1, d + satOffset));
  const sun = new Date(Date.UTC(y, m - 1, d + sunOffset));
  const satStr = `${sat.getUTCFullYear()}-${String(sat.getUTCMonth() + 1).padStart(2, '0')}-${String(sat.getUTCDate()).padStart(2, '0')}`;
  const sunStr = `${sun.getUTCFullYear()}-${String(sun.getUTCMonth() + 1).padStart(2, '0')}-${String(sun.getUTCDate()).padStart(2, '0')}`;
  return [satStr, sunStr];
}

/**
 * Runs the daily spot ranking calculation:
 * - Counts posts (14d), events (30d), paid bookings (14d), schedules (next 30d, 7d, weekend).
 * - Saves spots with changed stats or hotScore.
 * - Writes rankings and directory.
 * - Deletes stale ranking keys.
 */
export async function runSpotRanking(deps: {
  store: SpotRankStore;
  counter: SpotCounter;
  clock: Clock;
}): Promise<{ spots: number; changed: number; keys: string[] }> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const today = formatVnDate(now);
  const month = parseInt(today.split('-')[1] ?? '1', 10);

  const spots = await deps.store.listSpots();
  let changed = 0;

  const since14dIso = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000).toISOString();
  const in30dIso = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const next30 = nextDays(today, 30);
  const next7 = nextDays(today, 7);
  const weekend = weekendDays(today);

  const updatedSpots: Spot[] = [];
  const activeSpots = spots.filter((s) => s.status === 'active');

  for (const s of spots) {
    if (s.status !== 'active') {
      updatedSpots.push(s);
      continue;
    }

    const [posts14d, events, bookings14d, openSchedules, providersWeek, providersWeekend] = await Promise.all([
      deps.counter.posts(s.id, since14dIso),
      deps.counter.events(s.id, nowIso, in30dIso),
      deps.counter.paidBookings(s.id, since14dIso),
      deps.counter.schedulesWithDay(s.id, next30),
      deps.counter.schedulesWithDay(s.id, next7),
      deps.counter.schedulesWithDay(s.id, weekend),
    ]);

    const newStats: SpotStats = {
      posts14d,
      events,
      bookings14d,
      openSchedules,
      providersWeek,
      providersWeekend,
    };

    const newHotScore = spotHotScore(newStats, s.seasonMonths, month);

    const statsChanged =
      s.stats.posts14d !== newStats.posts14d ||
      s.stats.events !== newStats.events ||
      s.stats.bookings14d !== newStats.bookings14d ||
      s.stats.openSchedules !== newStats.openSchedules ||
      s.stats.providersWeek !== newStats.providersWeek ||
      s.stats.providersWeekend !== newStats.providersWeekend ||
      s.hotScore !== newHotScore;

    if (statsChanged) {
      changed += 1;
      const updated: Spot = {
        ...s,
        stats: newStats,
        hotScore: newHotScore,
        rankedAt: nowIso,
        updatedAt: nowIso,
      };
      await deps.store.saveSpot(updated);
      updatedSpots.push(updated);
    } else {
      updatedSpots.push(s);
    }
  }

  const rankings = rankSpots(updatedSpots, month, nowIso);
  const directory = spotDirectory(updatedSpots, month);

  const newKeys = new Set(rankings.map((r) => r.key));
  let staleKeys: string[] = [];
  if (deps.store.listRankingKeys) {
    const existingKeys = await deps.store.listRankingKeys();
    staleKeys = existingKeys.filter((k) => !newKeys.has(k));
  }

  await deps.store.saveRankings(rankings, staleKeys);
  await deps.store.saveDirectory(directory, nowIso);

  return {
    spots: activeSpots.length,
    changed,
    keys: rankings.map((r) => r.key),
  };
}
