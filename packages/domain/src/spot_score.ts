/**
 * Pure spot scoring rules (spec S29).
 */

import type { SpotStats } from './spot.js';
import { inSeason } from './spot.js';

export const HOT_WEIGHTS = {
  posts14d: 1,
  events: 3,
  bookings14d: 2,
  openSchedules: 2,
} as const;

export const SEASON_MULTIPLIER = 1.5;
export const RANK_HOT_LIMIT = 10;
export const RANKING_MAX_ENTRIES = 20;

/**
 * Computes hot score from stats, season months, and the target month (1..12).
 * Raw sum: 1 * posts14d + 3 * events + 2 * bookings14d + 2 * openSchedules.
 * In season: multiplied by 1.5 and rounded (Math.round).
 * Season-less spots get no multiplier.
 */
export function spotHotScore(
  stats: SpotStats,
  seasonMonths: readonly number[],
  month: number,
): number {
  const raw =
    stats.posts14d * HOT_WEIGHTS.posts14d +
    stats.events * HOT_WEIGHTS.events +
    stats.bookings14d * HOT_WEIGHTS.bookings14d +
    stats.openSchedules * HOT_WEIGHTS.openSchedules;

  if (seasonMonths.length > 0 && inSeason(seasonMonths, month)) {
    return Math.round(raw * SEASON_MULTIPLIER);
  }
  return raw;
}
