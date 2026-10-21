/**
 * Staff CLI use cases for spots (spec S29).
 */

import type { Clock, IdGenerator } from './ports.js';
import { DomainError } from './errors.js';
import { encodeGeohash } from './event.js';
import {
  type Spot,
  type SpotCover,
  EMPTY_SPOT_STATS,
  SPOT_AREAS,
  SPOT_NAME_MIN,
  SPOT_NAME_MAX,
  SPOT_RADIUS_MIN,
  SPOT_RADIUS_MAX,
  SPOT_DESCRIPTION_MAX,
  SPOT_TIPS_MAX,
  SPOT_TIP_MAX,
} from './spot.js';

export interface SpotInput {
  readonly name: string;
  readonly city: string;
  readonly areaCode: string;
  readonly lat: number;
  readonly lng: number;
  readonly radiusM: number;
  readonly description: string;
  readonly tips: readonly string[];
  readonly seasonMonths: readonly number[];
  readonly cover?: SpotCover | null;
}

export interface SpotAdminStore {
  getSpot(id: string): Promise<Spot | null>;
  putSpot(s: Spot): Promise<void>;
}

export interface SpotAdminDeps {
  readonly spots: SpotAdminStore;
  readonly staff: { isAdmin(uid: string): Promise<boolean> };
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

function graphemeCount(s: string): number {
  if (typeof Intl !== 'undefined' && 'Segmenter' in Intl) {
    const segmenter = new Intl.Segmenter('vi', { granularity: 'grapheme' });
    return Array.from(segmenter.segment(s)).length;
  }
  return Array.from(s).length;
}

/**
 * Validates spot input fields.
 */
export function validateSpotInput(raw: unknown): SpotInput {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  // name
  if (typeof r.name !== 'string') throw new DomainError('invalid_argument', 'name');
  const name = r.name.trim();
  const nameLen = graphemeCount(name);
  if (nameLen < SPOT_NAME_MIN || nameLen > SPOT_NAME_MAX) {
    throw new DomainError('invalid_argument', 'name');
  }

  // city
  if (typeof r.city !== 'string') throw new DomainError('invalid_argument', 'city');
  const city = r.city.trim();
  if (city.length === 0) throw new DomainError('invalid_argument', 'city');

  // areaCode
  if (typeof r.areaCode !== 'string') throw new DomainError('invalid_argument', 'areaCode');
  const areaCode = r.areaCode.trim();
  if (!SPOT_AREAS.some((a) => a.code === areaCode)) {
    throw new DomainError('invalid_argument', 'areaCode');
  }

  // lat
  if (typeof r.lat !== 'number' || !Number.isFinite(r.lat) || r.lat < -90 || r.lat > 90) {
    throw new DomainError('invalid_argument', 'lat');
  }
  const lat = r.lat;

  // lng
  if (typeof r.lng !== 'number' || !Number.isFinite(r.lng) || r.lng < -180 || r.lng > 180) {
    throw new DomainError('invalid_argument', 'lng');
  }
  const lng = r.lng;

  // radiusM
  if (
    typeof r.radiusM !== 'number' ||
    !Number.isInteger(r.radiusM) ||
    r.radiusM < SPOT_RADIUS_MIN ||
    r.radiusM > SPOT_RADIUS_MAX
  ) {
    throw new DomainError('invalid_argument', 'radiusM');
  }
  const radiusM = r.radiusM;

  // description
  const description = typeof r.description === 'string' ? r.description.trim() : '';
  if (graphemeCount(description) > SPOT_DESCRIPTION_MAX) {
    throw new DomainError('invalid_argument', 'description');
  }

  // tips
  if (!Array.isArray(r.tips)) throw new DomainError('invalid_argument', 'tips');
  if (r.tips.length > SPOT_TIPS_MAX) throw new DomainError('invalid_argument', 'tips');
  const tips: string[] = [];
  for (const t of r.tips) {
    if (typeof t !== 'string') throw new DomainError('invalid_argument', 'tips');
    const trimmed = t.trim();
    if (graphemeCount(trimmed) > SPOT_TIP_MAX) {
      throw new DomainError('invalid_argument', 'tips');
    }
    tips.push(trimmed);
  }

  // seasonMonths
  if (!Array.isArray(r.seasonMonths)) throw new DomainError('invalid_argument', 'seasonMonths');
  const seasonMonthsSet = new Set<number>();
  for (const m of r.seasonMonths) {
    if (typeof m !== 'number' || !Number.isInteger(m) || m < 1 || m > 12) {
      throw new DomainError('invalid_argument', 'seasonMonths');
    }
    seasonMonthsSet.add(m);
  }
  const seasonMonths = [...seasonMonthsSet].sort((a, b) => a - b);

  // cover
  let cover: SpotCover | null | undefined = undefined;
  if (r.cover !== undefined) {
    if (r.cover === null) {
      cover = null;
    } else if (typeof r.cover === 'object') {
      const c = r.cover as Record<string, unknown>;
      if (typeof c.url === 'string' && typeof c.cardUrl === 'string') {
        cover = {
          url: c.url,
          cardUrl: c.cardUrl,
          path: typeof c.path === 'string' ? c.path : '',
        };
      } else {
        throw new DomainError('invalid_argument', 'cover');
      }
    } else {
      throw new DomainError('invalid_argument', 'cover');
    }
  }

  return {
    name,
    city,
    areaCode,
    lat,
    lng,
    radiusM,
    description,
    tips,
    seasonMonths,
    cover,
  };
}

/**
 * Adds a new active spot. Requires admin.
 */
export async function addSpot(deps: SpotAdminDeps, actor: string, raw: unknown): Promise<Spot> {
  if (!(await deps.staff.isAdmin(actor))) {
    throw new DomainError('permission_denied');
  }
  const input = validateSpotInput(raw);
  const now = deps.clock.now().toISOString();
  const id = deps.ids.newId();
  const geohash = encodeGeohash(input.lat, input.lng);

  const spot: Spot = {
    id,
    name: input.name,
    city: input.city,
    areaCode: input.areaCode,
    point: { lat: input.lat, lng: input.lng },
    geohash,
    radiusM: input.radiusM,
    cover: input.cover ?? null,
    description: input.description,
    tips: input.tips,
    seasonMonths: input.seasonMonths,
    pinned: false,
    hidden: false,
    status: 'active',
    hotScore: 0,
    stats: EMPTY_SPOT_STATS,
    createdAt: now,
    updatedAt: now,
    rankedAt: null,
    updatedBy: actor,
  };

  await deps.spots.putSpot(spot);
  return spot;
}

/**
 * Edits an existing spot. Keeps stats and hotScore. Requires admin.
 */
export async function editSpot(deps: SpotAdminDeps, actor: string, id: string, raw: unknown): Promise<Spot> {
  if (!(await deps.staff.isAdmin(actor))) {
    throw new DomainError('permission_denied');
  }
  const existing = await deps.spots.getSpot(id);
  if (!existing) {
    throw new DomainError('not_found');
  }

  const input = validateSpotInput(raw);
  const now = deps.clock.now().toISOString();
  const geohash = encodeGeohash(input.lat, input.lng);

  const updated: Spot = {
    ...existing,
    name: input.name,
    city: input.city,
    areaCode: input.areaCode,
    point: { lat: input.lat, lng: input.lng },
    geohash,
    radiusM: input.radiusM,
    cover: input.cover !== undefined ? input.cover : existing.cover,
    description: input.description,
    tips: input.tips,
    seasonMonths: input.seasonMonths,
    updatedAt: now,
    updatedBy: actor,
  };

  await deps.spots.putSpot(updated);
  return updated;
}

/**
 * Sets a flag on a spot (pin, unpin, hide, unhide, archive). Requires admin.
 */
export async function setSpotFlag(
  deps: SpotAdminDeps,
  actor: string,
  id: string,
  flag: 'pin' | 'unpin' | 'hide' | 'unhide' | 'archive',
): Promise<Spot> {
  if (!(await deps.staff.isAdmin(actor))) {
    throw new DomainError('permission_denied');
  }
  if (!['pin', 'unpin', 'hide', 'unhide', 'archive'].includes(flag)) {
    throw new DomainError('invalid_argument');
  }

  const existing = await deps.spots.getSpot(id);
  if (!existing) {
    throw new DomainError('not_found');
  }

  let pinned = existing.pinned;
  let hidden = existing.hidden;
  let status = existing.status;

  if (flag === 'pin') pinned = true;
  if (flag === 'unpin') pinned = false;
  if (flag === 'hide') hidden = true;
  if (flag === 'unhide') hidden = false;
  if (flag === 'archive') status = 'archived';

  const now = deps.clock.now().toISOString();
  const updated: Spot = {
    ...existing,
    pinned,
    hidden,
    status,
    updatedAt: now,
    updatedBy: actor,
  };

  await deps.spots.putSpot(updated);
  return updated;
}
