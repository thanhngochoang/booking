/**
 * S27 area matching (plan #151 Decision 6). Photographers store `serviceArea {city, radiusKm, center?}`,
 * not area ids; a provider's areas are every area whose centre lies within `radiusKm` of `center`, else
 * every area of the city named in `serviceArea.city`. Studios and customers get no areas.
 */

import { foldVietnamese } from './event_hashtag.js';
import { distanceKm } from './geo.js';
import { providerTypeOf } from './provider_type.js';

export interface RecruitArea {
  readonly id: string;
  readonly cityKey: string;
  readonly lat: number;
  readonly lng: number;
}

/**
 * Same ids, order and centres as `builtInAreas` (app_flutter/lib/data/location/area.dart); a Dart test
 * keeps the id lists equal. Change both together.
 */
export const RECRUIT_AREAS: readonly RecruitArea[] = [
  { id: 'hcm-q1', cityKey: 'hcm', lat: 10.7769, lng: 106.7009 },
  { id: 'hcm-q3', cityKey: 'hcm', lat: 10.784, lng: 106.6842 },
  { id: 'hcm-q7', cityKey: 'hcm', lat: 10.734, lng: 106.7219 },
  { id: 'hcm-binh-thanh', cityKey: 'hcm', lat: 10.8106, lng: 106.7091 },
  { id: 'hcm-thu-duc', cityKey: 'hcm', lat: 10.8494, lng: 106.7537 },
  { id: 'hn-hoan-kiem', cityKey: 'hn', lat: 21.0285, lng: 105.8542 },
  { id: 'hn-ba-dinh', cityKey: 'hn', lat: 21.034, lng: 105.819 },
  { id: 'hn-cau-giay', cityKey: 'hn', lat: 21.0333, lng: 105.794 },
  { id: 'dn-hai-chau', cityKey: 'dn', lat: 16.0471, lng: 108.2208 },
  { id: 'hue', cityKey: 'hue', lat: 16.4637, lng: 107.5909 },
  { id: 'da-lat', cityKey: 'da-lat', lat: 11.9404, lng: 108.4583 },
  { id: 'nha-trang', cityKey: 'nha-trang', lat: 12.2388, lng: 109.1967 },
];

/** Folded city text (no accents, lower case, single spaces, no "tp."/"thanh pho" prefix) → city key. */
const CITY_ALIASES: Readonly<Record<string, string>> = {
  'hcm': 'hcm',
  'tphcm': 'hcm',
  'ho chi minh': 'hcm',
  'sai gon': 'hcm',
  'saigon': 'hcm',
  'ha noi': 'hn',
  'hanoi': 'hn',
  'da nang': 'dn',
  'danang': 'dn',
  'hue': 'hue',
  'thua thien hue': 'hue',
  'da lat': 'da-lat',
  'dalat': 'da-lat',
  'nha trang': 'nha-trang',
};

/** "TP.HCM", "Hồ Chí Minh", "Sài Gòn" → 'hcm'; "Hà Nội" → 'hn'; … ; unknown → null. */
export function recruitCityOf(city: string): string | null {
  const folded = foldVietnamese(city)
    .toLowerCase()
    .replace(/[.,]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^(?:tp|thanh pho) /, '');
  return CITY_ALIASES[folded] ?? null;
}

const isFiniteNumber = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v);

function centreOf(raw: unknown): { lat: number; lng: number } | null {
  if (raw === null || typeof raw !== 'object') return null;
  const { lat, lng } = raw as { lat?: unknown; lng?: unknown };
  return isFiniteNumber(lat) && isFiniteNumber(lng) ? { lat, lng } : null;
}

/** The area ids a service area covers, in `RECRUIT_AREAS` order. */
export function recruitAreasOf(
  area: { city?: unknown; radiusKm?: unknown; center?: { lat: number; lng: number } | null } | null,
): string[] {
  if (area === null || typeof area !== 'object') return [];
  const centre = centreOf(area.center);
  if (centre !== null && isFiniteNumber(area.radiusKm) && area.radiusKm > 0) {
    const radius = area.radiusKm;
    return RECRUIT_AREAS.filter((a) => distanceKm(centre, a) <= radius).map((a) => a.id);
  }
  const cityKey = typeof area.city === 'string' ? recruitCityOf(area.city) : null;
  return cityKey === null ? [] : RECRUIT_AREAS.filter((a) => a.cityKey === cityKey).map((a) => a.id);
}

/** `a=<area>|s=<specialty>` for every area × specialty (duplicates dropped, input order kept). */
export function recruitMatchKeys(areas: readonly string[], specialties: readonly string[]): string[] {
  const keys: string[] = [];
  for (const a of new Set(areas)) for (const s of new Set(specialties)) keys.push(`a=${a}|s=${s}`);
  return keys;
}

/**
 * `photographers/{uid}.recruitMatchKeys` (Decision 7): empty unless the account is in photographer mode
 * and not a studio (studios never receive `recruit_post_new`).
 */
export function recruitMatchKeysOf(p: {
  role: unknown;
  providerType: unknown;
  serviceArea: unknown;
  specialties: readonly string[];
}): string[] {
  if (p.role !== 'photographer' || providerTypeOf(p.providerType) === 'studio') return [];
  const area = p.serviceArea !== null && typeof p.serviceArea === 'object'
    ? (p.serviceArea as { city?: unknown; radiusKm?: unknown; center?: { lat: number; lng: number } | null })
    : null;
  return recruitMatchKeys(recruitAreasOf(area), p.specialties);
}
