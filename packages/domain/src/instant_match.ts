/**
 * The 5-person round of Chụp ngay (spec §3.2, plan Decisions 12, 14, 23): who may be suggested,
 * the priority and expanded tiers, the score and the reasons shown as chips on S13.02.
 */
import type { AvailabilityDayRecord } from './booking_ports.js';
import { distanceKm } from './geo.js';
import {
  INSTANT,
  estimateEtaMinutes,
  livePendingOffers,
  presenceFresh,
  type InstantCandidate,
  type InstantGenre,
  type InstantPresence,
  type InstantReason,
} from './instant.js';
import { TOMATO_PCT_MIN_REVIEWS } from './review.js';

/** The state of the provider's `availability/{uid}/days/{today}`; missing = no record. */
export type InstantDayState = AvailabilityDayRecord['state'];

/** Below this tomato percentage (with ≥ 5 reviews) a photographer is expanded tier (the old "< 4,5 sao"). */
const PRIORITY_TOMATO_PCT = 90;
/** With at least this many offers, cancels and acceptance count. */
const RELIABILITY_MIN_OFFERS = 10;
const PRIORITY_MAX_CANCEL_RATE = 0.1;
const HELP_READY_BONUS = 0.05;
const MAX_RADIUS_KM = Math.max(...INSTANT.RADII_KM);
const W = { eta: 0.45, genre: 0.25, rating: 0.15, reliability: 0.15 } as const;

const GENRE_WORDS: Readonly<Record<InstantGenre, string>> = {
  portrait: 'chân dung',
  couple: 'cặp đôi',
  family: 'gia đình',
  event: 'sự kiện nhỏ',
  product: 'sản phẩm',
};

/**
 * Today holds the provider elsewhere: an open spot schedule (`spot`, #194 Decision 17), a studio
 * whose free members are all taken (`full`, #136 Decision 26) or a booking (`booked`; holds are
 * day-granular and instant has no time-of-day data, #140 Task 2 ruling). Such a provider is not
 * suggested, offered or allowed to accept. `off` and `pending` stay eligible: switching Live
 * Shutter on is the newer, explicit signal.
 */
export function dayBlocksInstant(state: InstantDayState | null | undefined): boolean {
  return state === 'spot' || state === 'full' || state === 'booked';
}

/**
 * Priority tier (spec §3.2): "Sẵn sàng hỗ trợ", or verified and up to standard where there is
 * enough data (tomato ≥ 90% with ≥ 5 reviews; cancelled / accepted ≤ 10% with ≥ 10 offers, the
 * same cancel rate as the reliability score; #140 Task 2 ruling).
 */
export function isPriorityTier(p: InstantPresence): boolean {
  if (p.helpReady) return true;
  if (!p.profile.verified) return false;
  if (p.profile.reviewCount >= TOMATO_PCT_MIN_REVIEWS && p.profile.tomatoPct < PRIORITY_TOMATO_PCT) return false;
  const r = p.reliability;
  return !(r.offers >= RELIABILITY_MIN_OFFERS && r.cancelled / Math.max(r.accepted, 1) > PRIORITY_MAX_CANCEL_RATE);
}

/** "1,2 km", or "800 m" below 1 km (rounded to 100 m, at least 100 m). */
export function instantDistanceText(km: number): string {
  const tenths = Math.round(km * 10);
  if (tenths < 10) return `${Math.max(1, tenths) * 100} m`;
  return `${String(tenths / 10).replace('.', ',')} km`;
}

/** At most two chips: the genre first when the photographer lists it, then the distance. */
export function candidateReasons(p: InstantPresence, genre: InstantGenre, km: number): { code: 'genre' | 'distance'; text: string }[] {
  const out: { code: 'genre' | 'distance'; text: string }[] = [];
  if (p.profile.specialties.includes(genre)) out.push({ code: 'genre', text: `Chuyên ${GENRE_WORDS[genre]}` });
  out.push({ code: 'distance', text: `Cách ${instantDistanceText(km)}` });
  return out.slice(0, 2);
}

const clamp01 = (x: number): number => Math.min(1, Math.max(0, x));

/** Decision 23: `(score + 1) / 2` of the tomato/brick score with ≥ 5 reviews, else 0.5. */
const ratingOf = (p: InstantPresence): number =>
  p.profile.reviewCount >= TOMATO_PCT_MIN_REVIEWS ? clamp01((p.profile.score + 1) / 2) : 0.5;

const reliabilityOf = (p: InstantPresence): number => {
  const r = p.reliability;
  if (r.offers < RELIABILITY_MIN_OFFERS) return 0.5;
  return clamp01(r.accepted / r.offers - r.cancelled / Math.max(r.accepted, 1));
};

export interface RankCandidatesInput {
  /** Everyone the cell queries returned (a photographer found twice counts once). */
  readonly presences: readonly InstantPresence[];
  readonly meetPoint: { readonly lat: number; readonly lng: number };
  readonly genre: InstantGenre;
  /** Declined, expired or skipped earlier on this request. */
  readonly excluded: ReadonlySet<string>;
  readonly customerId: string;
  /** The current price list version of the config. */
  readonly priceListVersion: number;
  readonly now: Date;
  /** Today's availability day state per photographer (missing = no record), see `dayBlocksInstant`. */
  readonly dayStates: ReadonlyMap<string, InstantDayState>;
}

/**
 * Up to 5 candidates: the smallest ring of 3 / 6 / 10 km that holds 5 suggestible photographers
 * (else everyone within 10 km), the priority tier first, each tier by score, distance, uid.
 */
export function rankCandidates(input: RankCandidatesInput): InstantCandidate[] {
  const seen = new Set<string>();
  const pool: { p: InstantPresence; km: number }[] = [];
  for (const p of input.presences) {
    if (seen.has(p.uid)) continue;
    seen.add(p.uid);
    if (p.lat === null || p.lng === null) continue;
    if (!presenceFresh(p, input.now) || p.activeRequestId !== null) continue;
    if (p.uid === input.customerId || input.excluded.has(p.uid)) continue;
    if (p.priceListVersion !== input.priceListVersion) continue;
    if (livePendingOffers(p, input.now).length >= INSTANT.MAX_PENDING_OFFERS) continue;
    if (dayBlocksInstant(input.dayStates.get(p.uid))) continue;
    const km = distanceKm(input.meetPoint, { lat: p.lat, lng: p.lng });
    if (km <= MAX_RADIUS_KM) pool.push({ p, km });
  }
  const radius = INSTANT.RADII_KM.find((r) => pool.filter((x) => x.km <= r).length >= INSTANT.ROUND_SIZE);
  const ring = radius === undefined ? pool : pool.filter((x) => x.km <= radius);

  const scored = ring.map(({ p, km }) => {
    const etaMinutes = estimateEtaMinutes(km);
    const priority = isPriorityTier(p);
    const genreMatch = p.profile.specialties.includes(input.genre) ? 1 : 0;
    const score = W.eta * (1 - Math.min(etaMinutes, 60) / 60) + W.genre * genreMatch
      + W.rating * ratingOf(p) + W.reliability * reliabilityOf(p)
      + (priority && p.helpReady ? HELP_READY_BONUS : 0);
    const reasons: InstantReason[] = candidateReasons(p, input.genre, km);
    const candidate: InstantCandidate = {
      photographerId: p.uid,
      name: p.profile.name,
      avatarUrl: p.profile.avatarUrl,
      verified: p.profile.verified,
      providerType: p.profile.providerType,
      tomatoPct: p.profile.tomatoPct,
      reviewCount: p.profile.reviewCount,
      completedCount: p.profile.completedCount,
      distanceKm: Math.round(km * 10) / 10,
      etaMinutes,
      photos: p.profile.photos.slice(0, 3),
      reasons,
      tier: priority ? 'priority' : 'expanded',
      score,
    };
    return { candidate, km };
  });

  const tierRank = (t: InstantCandidate['tier']): number => (t === 'priority' ? 0 : 1);
  scored.sort((a, b) =>
    tierRank(a.candidate.tier) - tierRank(b.candidate.tier)
    || b.candidate.score - a.candidate.score
    || a.km - b.km
    || (a.candidate.photographerId < b.candidate.photographerId ? -1 : a.candidate.photographerId > b.candidate.photographerId ? 1 : 0));
  return scored.slice(0, INSTANT.ROUND_SIZE).map((s) => s.candidate);
}
