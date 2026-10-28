/**
 * Spot domain models and pure helpers (spec S29).
 */

import type { SpotAccess } from './organizer.js';

export const SPOT_STATUSES = ['active', 'archived'] as const;
export type SpotStatus = (typeof SPOT_STATUSES)[number];

export const SPOT_AREAS = [
  { code: 'hcm', name: 'TP.HCM' },
  { code: 'hn', name: 'Hà Nội' },
  { code: 'dn', name: 'Đà Nẵng' },
  { code: 'hue', name: 'Huế' },
  { code: 'da-lat', name: 'Đà Lạt' },
  { code: 'nha-trang', name: 'Nha Trang' },
  { code: 'hoi-an', name: 'Hội An' },
  { code: 'yen-bai', name: 'Yên Bái' },
] as const;

export const SPOT_NAME_MIN = 3;
export const SPOT_NAME_MAX = 60;
export const SPOT_RADIUS_MIN = 100;
export const SPOT_RADIUS_MAX = 3000;
export const SPOT_DESCRIPTION_MAX = 600;
export const SPOT_TIPS_MAX = 5;
export const SPOT_TIP_MAX = 120;
export const SPOT_EVENT_SLACK_M = 500;

export interface LatLng {
  readonly lat: number;
  readonly lng: number;
}

export interface SpotStats {
  readonly posts14d: number;
  readonly events: number;
  readonly bookings14d: number;
  readonly openSchedules: number;
  readonly providersWeek: number;
  readonly providersWeekend: number;
}

export interface SpotCover {
  readonly url: string;
  readonly cardUrl: string;
  readonly path: string;
}

export interface Spot {
  readonly id: string;
  readonly name: string;
  readonly city: string;
  readonly areaCode: string;
  readonly point: LatLng;
  readonly geohash: string;
  readonly radiusM: number;
  readonly cover: SpotCover | null;
  readonly description: string;
  readonly tips: readonly string[];
  readonly seasonMonths: readonly number[];
  readonly pinned: boolean;
  readonly hidden: boolean;
  readonly status: SpotStatus;
  readonly hotScore: number;
  readonly stats: SpotStats;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly rankedAt: string | null;
  readonly updatedBy: string;
  /** S30 (#223): the organizer managing the spot (approved claim), at most one; null = no manager. */
  readonly managedBy: string | null;
  /** S30: reference entry fees (staff or the manager); null = unknown. */
  readonly access: SpotAccess | null;
  /** S30: opening hours (Vietnam `HH:mm`), display only; null = not given. */
  readonly openHours: SpotOpenHours | null;
}

export interface SpotOpenHours {
  readonly start: string;
  readonly end: string;
}

export const EMPTY_SPOT_STATS: SpotStats = Object.freeze({
  posts14d: 0,
  events: 0,
  bookings14d: 0,
  openSchedules: 0,
  providersWeek: 0,
  providersWeekend: 0,
});

/**
 * Maps an areaId (e.g. 'hcm-q1', 'hn-ba-dinh', 'dn-hai-chau', 'da-lat') to region.
 * Decision 2: null → 'all'. Prefix before first '-' when hcm, hn or dn, else id itself.
 */
export function regionOfArea(areaId: string | null): string {
  if (!areaId) return 'all';
  const dashIdx = areaId.indexOf('-');
  if (dashIdx > 0) {
    const prefix = areaId.slice(0, dashIdx);
    if (prefix === 'hcm' || prefix === 'hn' || prefix === 'dn') {
      return prefix;
    }
  }
  return areaId;
}

/** Non-empty and contains month (1..12). */
export function inSeason(seasonMonths: readonly number[], month: number): boolean {
  return seasonMonths.length > 0 && seasonMonths.includes(month);
}

/** Empty or inSeason. */
export function seasonOk(s: Pick<Spot, 'seasonMonths'>, month: number): boolean {
  return s.seasonMonths.length === 0 || inSeason(s.seasonMonths, month);
}

/**
 * Last month of the continuous season run containing `month`.
 * Returns null if `month` is not in `seasonMonths`.
 * Wraps 12 → 1.
 */
export function seasonRunEnd(seasonMonths: readonly number[], month: number): number | null {
  if (!seasonMonths.includes(month)) return null;

  const set = new Set(seasonMonths);
  if (set.size === 12) {
    return ((month + 10) % 12) + 1;
  }

  let curr = month;
  while (true) {
    const next = (curr % 12) + 1;
    if (set.has(next)) {
      curr = next;
    } else {
      break;
    }
  }
  return curr;
}

const EARTH_RADIUS_METERS = 6_371_000;

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

/** Haversine distance in meters, R = 6,371,000 m. */
export function distanceMeters(a: LatLng, b: LatLng): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);

  const sinDLat2 = Math.sin(dLat / 2);
  const sinDLng2 = Math.sin(dLng / 2);
  const h = sinDLat2 * sinDLat2 + Math.cos(lat1) * Math.cos(lat2) * sinDLng2 * sinDLng2;
  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(h));
}

/** Returns true if p is within s.radiusM (+ slackM) of s.point. */
export function spotCovers(
  s: Pick<Spot, 'point' | 'radiusM'>,
  p: LatLng,
  slackM = 0,
): boolean {
  return distanceMeters(s.point, p) <= s.radiusM + slackM;
}
