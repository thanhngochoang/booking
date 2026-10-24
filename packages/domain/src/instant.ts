/**
 * Chụp ngay (S13–S14, spec 2026-10-01-instant-booking-design.md): the request model, the server
 * config, pricing, the state machine and presence freshness. Pure: timers live in
 * instant_settle.ts, candidate ranking in instant_match.ts, cancellation money in instant_cancel.ts.
 */
import type { PaymentProvider } from './booking.js';
import { DomainError } from './errors.js';
import type { PaymentMethod, RefundStatus } from './escrow.js';
import { encodeGeohash } from './event.js';
import { distanceKm } from './geo.js';
import type { InstantCancelRule } from './instant_cancel.js';
import type { ProviderType } from './provider_type.js';

/** Spec §3.1 plus `finished` (plan Decision 8; `payment_failed` and `disputed` are not built). */
export const INSTANT_STATUSES = ['choosing', 'pending_payment', 'searching', 'assigned', 'en_route', 'arrived',
  'in_progress', 'finished', 'completed', 'no_match', 'abandoned', 'cancelled_by_customer', 'no_show_customer'] as const;
export type InstantStatus = (typeof INSTANT_STATUSES)[number];

export const INSTANT_TERMINAL: readonly InstantStatus[] = ['completed', 'abandoned', 'cancelled_by_customer', 'no_show_customer'];

/** `no_match` is active: the money stays held until the customer chooses again or cancels (spec §3.1). */
export const isInstantActive = (s: InstantStatus): boolean => !INSTANT_TERMINAL.includes(s);

/** The five kinds of shoot of spec §2.1 (existing specialty codes; `event` reads "Sự kiện nhỏ"). */
export const INSTANT_GENRES = ['portrait', 'couple', 'family', 'event', 'product'] as const;
export type InstantGenre = (typeof INSTANT_GENRES)[number];
export const isInstantGenre = (v: unknown): v is InstantGenre => (INSTANT_GENRES as readonly unknown[]).includes(v);

export const OFFER_OUTCOMES = ['pending', 'accepted', 'declined', 'expired', 'withdrawn'] as const;
export type OfferOutcome = (typeof OFFER_OUTCOMES)[number];
/** `unavailable`: chosen by the customer but busy, offline, gated or full when the offers went out (no offer doc). */
export type OfferRowOutcome = OfferOutcome | 'unavailable';

export const INSTANT = {
  OFFER_TTL_S: 60, MAX_PENDING_OFFERS: 3, ROUND_SIZE: 5, PAYMENT_WINDOW_MIN: 15, SEARCH_WINDOW_MIN: 10,
  ABANDON_AFTER_MIN: 30, FREE_CANCEL_MIN: 2, LATE_GRACE_MIN: 15, NO_SHOW_WAIT_MIN: 15, AUTO_COMPLETE_H: 2,
  ARRIVE_RADIUS_M: 200, POOR_ACCURACY_M: 100, PRESENCE_FRESH_MIN: 30, RADII_KM: [3, 6, 10],
  NOTE_MAX: 140, MEET_NAME_MAX: 80, AREA_MAX_KM: 8, CONTACT_DAYS: 7, // refund re-send timing is V2's REFUND_RESEND_AFTER_MINUTES
} as const;

// ---------------------------------------------------------------- config (`instant_config/current`)

export interface InstantPackage { readonly code: string; readonly durationMin: number; readonly photos: number; readonly priceVnd: number }
export interface InstantCity {
  readonly id: string; readonly name: string;
  readonly south: number; readonly west: number; readonly north: number; readonly east: number;
  /** 10000 = ×1.0 (plan Decision 27: one factor per city). */
  readonly surgeBp: number;
}
export interface InstantArea { readonly name: string; readonly lat: number; readonly lng: number }
export interface InstantConfig {
  readonly enabled: boolean;
  readonly priceListVersion: number;
  /** Owner 2026-10-07 (Decision 6): 0–10000, seed 0 = everything to the photographer. */
  readonly platformFeeBp: number;
  /** Owner 2026-10-07 (Decision 9): 0–100, seed 50; the share the photographer keeps on an `arrived` cancel. */
  readonly instantArrivedCancelPhotographerPercent: number;
  readonly packages: readonly InstantPackage[];
  readonly cities: readonly InstantCity[];
  readonly areas: readonly InstantArea[];
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const isInt = (v: unknown, min: number, max = Number.MAX_SAFE_INTEGER): v is number =>
  typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;
const isNum = (v: unknown, min: number, max: number): v is number => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;
const isText = (v: unknown): v is string => typeof v === 'string' && v.trim().length > 0;

function refuse(): never {
  throw new DomainError('not_eligible');
}

function parsePackage(v: unknown): InstantPackage {
  if (!isRecord(v)) return refuse();
  const { code, durationMin, photos, priceVnd } = v;
  if (!isText(code) || !isInt(durationMin, 1) || !isInt(photos, 1) || !isInt(priceVnd, 1)) return refuse();
  return { code, durationMin, photos, priceVnd };
}

function parseCity(v: unknown): InstantCity {
  if (!isRecord(v)) return refuse();
  const { id, name, south, west, north, east, surgeBp } = v;
  if (!isText(id) || !isText(name) || !isInt(surgeBp, 1)) return refuse();
  if (!isNum(south, -90, 90) || !isNum(north, -90, 90) || !isNum(west, -180, 180) || !isNum(east, -180, 180)) return refuse();
  if (south >= north || west >= east) return refuse();
  return { id, name, south, west, north, east, surgeBp };
}

function parseArea(v: unknown): InstantArea {
  if (!isRecord(v)) return refuse();
  const { name, lat, lng } = v;
  if (!isText(name) || !isNum(lat, -90, 90) || !isNum(lng, -180, 180)) return refuse();
  return { name, lat, lng };
}

/**
 * The server config as the adapter read it. Anything missing or out of range is `not_eligible`
 * (Chụp ngay is then unavailable): there is no default in code, the seed holds the defaults.
 */
export function parseInstantConfig(raw: unknown): InstantConfig {
  if (!isRecord(raw)) return refuse();
  const { enabled, priceListVersion, platformFeeBp, instantArrivedCancelPhotographerPercent: split } = raw;
  if (typeof enabled !== 'boolean' || !isInt(priceListVersion, 1)) return refuse();
  if (!isInt(platformFeeBp, 0, 10_000) || !isInt(split, 0, 100)) return refuse();
  if (!Array.isArray(raw.packages) || raw.packages.length === 0) return refuse();
  if (!Array.isArray(raw.cities) || raw.cities.length === 0) return refuse();
  if (!Array.isArray(raw.areas)) return refuse();
  const packages = raw.packages.map(parsePackage);
  const cities = raw.cities.map(parseCity);
  const areas = raw.areas.map(parseArea);
  if (new Set(packages.map((p) => p.code)).size !== packages.length) return refuse();
  if (new Set(cities.map((c) => c.id)).size !== cities.length) return refuse();
  return { enabled, priceListVersion, platformFeeBp, instantArrivedCancelPhotographerPercent: split, packages, cities, areas };
}

/** The first open city whose box holds the point, or null (`outside_service_area`). */
export function cityAt(cfg: InstantConfig, lat: number, lng: number): InstantCity | null {
  return cfg.cities.find((c) => lat >= c.south && lat <= c.north && lng >= c.west && lng <= c.east) ?? null;
}

/** "Quận 1, TP.HCM": the nearest configured area within 8 km, else the city name (Decision 19). */
export function areaLabelAt(cfg: InstantConfig, city: InstantCity, lat: number, lng: number): string {
  let best: { name: string; km: number } | null = null;
  for (const a of cfg.areas) {
    const km = distanceKm({ lat, lng }, a);
    if (km <= INSTANT.AREA_MAX_KM && (best === null || km < best.km)) best = { name: a.name, km };
  }
  return best?.name ?? city.name;
}

/** Package price × the city's surge, rounded to 1.000 ₫ (spec §4). */
export function quoteInstantPrice(pkg: InstantPackage, city: InstantCity): number {
  return Math.round((pkg.priceVnd * city.surgeBp) / 10_000_000) * 1000;
}

/** "30 phút", "1 giờ", "1 giờ 30 phút": a package duration as S06.05 and S14.01 read it. */
export function instantDurationLabel(durationMin: number): string {
  const h = Math.floor(durationMin / 60);
  const m = durationMin % 60;
  if (h === 0) return `${m} phút`;
  return m === 0 ? `${h} giờ` : `${h} giờ ${m} phút`;
}

/** The S06.05 earnings row label of an instant job (#202): "Chụp ngay · 1 giờ". */
export const instantEarningLabel = (durationMin: number): string => `Chụp ngay · ${instantDurationLabel(durationMin)}`;

/** What the photographer is paid for an amount: the amount minus the platform fee (Decision 6). */
export function photographerEarning(amountVnd: number, cfg: Pick<InstantConfig, 'platformFeeBp'>): number {
  return amountVnd - Math.round((amountVnd * cfg.platformFeeBp) / 10_000);
}

// ---------------------------------------------------------------- geometry

/** Straight line × 1,4 at 20 km/h, at least 1 minute (spec §3.2; the UI says "khoảng"). */
export function estimateEtaMinutes(km: number): number {
  // The epsilon keeps a float like 12.000000000000002 from becoming 13.
  return Math.max(1, Math.ceil((km * 1.4 * 60) / 20 - 1e-9));
}

/**
 * The 3×3 geohash cells around a point, centre first: `near` = geohash5 (covers 3 km),
 * `wide` = geohash4 (covers 6 and 10 km) (Decision 12).
 */
export function instantSearchCells(lat: number, lng: number, ring: 'near' | 'wide'): { field: 'geohash5' | 'geohash4'; cells: string[] } {
  const precision = ring === 'near' ? 5 : 4;
  const bits = precision * 5;
  const latSpan = 180 / 2 ** Math.floor(bits / 2);
  const lngSpan = 360 / 2 ** Math.ceil(bits / 2);
  const cLat = -90 + (Math.floor((lat + 90) / latSpan) + 0.5) * latSpan;
  const cLng = -180 + (Math.floor((lng + 180) / lngSpan) + 0.5) * lngSpan;
  const cells = [encodeGeohash(lat, lng, precision)];
  for (const dy of [1, 0, -1]) {
    for (const dx of [-1, 0, 1]) {
      if (dx === 0 && dy === 0) continue;
      const nLat = cLat + dy * latSpan;
      if (nLat <= -90 || nLat >= 90) continue;
      const nLng = ((((cLng + dx * lngSpan + 180) % 360) + 360) % 360) - 180;
      const cell = encodeGeohash(nLat, nLng, precision);
      if (!cells.includes(cell)) cells.push(cell);
    }
  }
  return { field: ring === 'near' ? 'geohash5' : 'geohash4', cells };
}

// ---------------------------------------------------------------- documents

/** Snapshot of a person on a request (`photographer`). */
export interface InstantParty {
  readonly id: string; readonly name: string; readonly avatarUrl: string | null; readonly verified: boolean;
  readonly tomatoPct: number; readonly reviewCount: number; readonly completedCount: number;
}

export interface InstantReason { readonly code: 'genre' | 'distance'; readonly text: string }

/** One card of a round (S13.02). */
export interface InstantCandidate {
  readonly photographerId: string; readonly name: string; readonly avatarUrl: string | null; readonly verified: boolean;
  readonly providerType: ProviderType; readonly tomatoPct: number; readonly reviewCount: number; readonly completedCount: number;
  /** Rounded to 0,1 km. */
  readonly distanceKm: number;
  readonly etaMinutes: number;
  /** At most 3. */
  readonly photos: readonly string[];
  /** At most 2, genre first. */
  readonly reasons: readonly InstantReason[];
  readonly tier: 'priority' | 'expanded';
  readonly score: number;
}

/** One line of S13.03 (who was invited this round and how they answered). */
export interface InstantOfferRow {
  readonly offerId: string | null; readonly photographerId: string; readonly name: string; readonly avatarUrl: string | null;
  readonly tomatoPct: number; readonly reviewCount: number; readonly etaMinutes: number;
  readonly outcome: OfferRowOutcome;
  readonly expiresAt: Date | null;
}

export interface InstantMeetPoint { readonly lat: number; readonly lng: number; readonly name: string }

/** `instant_requests/{id}`. Every instant is a UTC `Date`; money is integer VND. */
export interface InstantRequest {
  readonly id: string;
  readonly customerId: string; readonly customerName: string; readonly customerAvatarUrl: string | null;
  readonly status: InstantStatus;
  /** Always `isInstantActive(status)` (indexed for "my active request" and the clock step). */
  readonly active: boolean;
  readonly packageCode: string; readonly durationMin: number; readonly photos: number;
  readonly genre: InstantGenre; readonly note: string;
  readonly cityId: string; readonly meetPoint: InstantMeetPoint; readonly areaLabel: string;
  readonly amountVnd: number; readonly earningVnd: number;
  /** Snapshots of the config at creation (Decisions 6 and 9). */
  readonly priceListVersion: number; readonly platformFeeBp: number; readonly arrivedCancelPhotographerPercent: number;
  /** Offers sent at least once (#140: on the first send; #202: with `paidAt`). */
  readonly committedAt: Date | null;
  // Money fields: written only by #202; null throughout #140.
  readonly payMethod: PaymentMethod | null; readonly provider: PaymentProvider | null;
  readonly paymentId: string | null; readonly paidAt: Date | null; readonly paymentDeadlineAt: Date | null;
  readonly refundId: string | null; readonly refundStatus: RefundStatus | null;
  // The current round only (Decision 15: emptied at assignment).
  readonly round: number; readonly invitedTotal: number; readonly roundsWithInvites: number;
  readonly candidates: readonly InstantCandidate[]; readonly offers: readonly InstantOfferRow[];
  readonly excludedIds: readonly string[]; readonly pendingInviteIds: readonly string[];
  readonly roundEnded: boolean;
  // The job.
  readonly photographerId: string | null; readonly photographer: InstantParty | null; readonly chatId: string | null;
  readonly etaMinutes: number | null;
  readonly assignedAt: Date | null; readonly freeCancelUntil: Date | null; readonly lateDeadlineAt: Date | null;
  readonly startedRouteAt: Date | null; readonly arrivedAt: Date | null; readonly forcedArrivalAccuracyM: number | null;
  readonly startedAt: Date | null; readonly shootEndsAt: Date | null; readonly finishedAt: Date | null; readonly completedAt: Date | null;
  // The end.
  readonly cancelledAt: Date | null; readonly cancelledBy: 'customer' | 'photographer' | null;
  readonly cancelRule: InstantCancelRule | null; readonly refundPercent: number | null; readonly feeVnd: number | null;
  // Timers.
  readonly searchDeadlineAt: Date | null; readonly lastActivityAt: Date; readonly nextDeadlineAt: Date | null;
  readonly createdAt: Date; readonly updatedAt: Date; readonly version: number;
}

/** `instant_offers/{uid}/offers/{offerId}`: never the meet point, only its area and distance (spec §9). */
export interface InstantOffer {
  readonly id: string; readonly requestId: string; readonly photographerId: string; readonly round: number;
  readonly offeredAt: Date; readonly expiresAt: Date; readonly outcome: OfferOutcome; readonly decidedAt: Date | null;
  readonly packageCode: string; readonly durationMin: number; readonly photos: number; readonly genre: InstantGenre;
  readonly areaLabel: string; readonly distanceKm: number; readonly etaMinutes: number; readonly earningVnd: number;
  readonly note: string;
  /** How many people the customer invited in this round ("Khách đã chọn bạn trong {n} người"). */
  readonly invitedCount: number;
}

export interface InstantPendingOffer { readonly offerId: string; readonly requestId: string; readonly expiresAt: Date }

export interface InstantProfile {
  readonly name: string; readonly avatarUrl: string | null; readonly verified: boolean; readonly providerType: ProviderType;
  /** #130 tomato/brick stats (Decision 23). */
  readonly tomatoPct: number; readonly score: number; readonly reviewCount: number; readonly completedCount: number;
  readonly specialties: readonly string[];
  /** At most 3 latest work photos. */
  readonly photos: readonly string[];
}

export interface InstantReliability {
  readonly offers: number; readonly accepted: number; readonly declined: number; readonly expired: number;
  readonly cancelled: number; readonly late: number; readonly noShow: number;
}

/** `instant_presence/{uid}` (Decision 10). */
export interface InstantPresence {
  readonly uid: string;
  readonly online: boolean; readonly helpReady: boolean;
  /** The price list version the photographer accepted. */
  readonly priceListVersion: number | null;
  readonly cityId: string | null;
  readonly lat: number | null; readonly lng: number | null; readonly accuracyM: number | null;
  readonly geohash5: string | null; readonly geohash4: string | null;
  readonly heartbeatAt: Date | null;
  readonly activeRequestId: string | null;
  /** Only entries with `expiresAt > now` count (Decision 14). */
  readonly pendingOffers: readonly InstantPendingOffer[];
  readonly profile: InstantProfile;
  readonly reliability: InstantReliability;
  readonly updatedAt: Date;
}

// ---------------------------------------------------------------- state machine

/**
 * `invite_unpaid`: the first invite of #202, which waits for the payment; `invite`: offers sent
 * (#140's first invite, #202 later rounds on the held money).
 */
export const INSTANT_EVENTS = ['invite_unpaid', 'invite', 'payment_expired', 'paid', 'round_ended', 'accept', 'photographer_cancel',
  'start_route', 'arrive', 'start', 'finish', 'complete', 'no_match', 'reopen', 'abandon', 'customer_cancel', 'no_show'] as const;
export type InstantEvent = (typeof INSTANT_EVENTS)[number];

const ARROWS: readonly (readonly [InstantStatus, InstantEvent, InstantStatus])[] = [
  ['choosing', 'invite_unpaid', 'pending_payment'],
  ['choosing', 'invite', 'searching'],
  ['pending_payment', 'paid', 'searching'],
  ['pending_payment', 'payment_expired', 'choosing'],
  ['searching', 'round_ended', 'choosing'],
  ['searching', 'accept', 'assigned'],
  ['choosing', 'no_match', 'no_match'],
  ['searching', 'no_match', 'no_match'],
  ['no_match', 'reopen', 'choosing'],
  ['assigned', 'start_route', 'en_route'],
  ['en_route', 'arrive', 'arrived'],
  ['arrived', 'start', 'in_progress'],
  ['in_progress', 'finish', 'finished'],
  ['in_progress', 'complete', 'completed'],
  ['finished', 'complete', 'completed'],
  ['assigned', 'photographer_cancel', 'choosing'],
  ['en_route', 'photographer_cancel', 'choosing'],
  ['arrived', 'photographer_cancel', 'choosing'],
  ['choosing', 'abandon', 'abandoned'],
  ['pending_payment', 'abandon', 'abandoned'],
  ['choosing', 'customer_cancel', 'cancelled_by_customer'],
  ['pending_payment', 'customer_cancel', 'cancelled_by_customer'],
  ['searching', 'customer_cancel', 'cancelled_by_customer'],
  ['no_match', 'customer_cancel', 'cancelled_by_customer'],
  ['assigned', 'customer_cancel', 'cancelled_by_customer'],
  ['en_route', 'customer_cancel', 'cancelled_by_customer'],
  ['arrived', 'customer_cancel', 'cancelled_by_customer'],
  ['arrived', 'no_show', 'no_show_customer'],
];

const NEXT = new Map(ARROWS.map(([from, event, to]) => [`${from}:${event}`, to]));

/** The status an event leads to; `conflict` when the event is not allowed from `from`. */
export function nextInstantStatus(from: InstantStatus, event: InstantEvent): InstantStatus {
  const to = NEXT.get(`${from}:${event}`);
  if (to === undefined) throw new DomainError('conflict');
  return to;
}

// ---------------------------------------------------------------- presence

/** Online with a heartbeat less than 30 minutes old (Decision 10). */
export function presenceFresh(p: InstantPresence, now: Date): boolean {
  return p.online && p.heartbeatAt !== null && now.getTime() - p.heartbeatAt.getTime() < INSTANT.PRESENCE_FRESH_MIN * 60_000;
}

/** The pending offers that still count toward the cap of 3 (`expiresAt > now`). */
export function livePendingOffers(p: InstantPresence, now: Date): InstantPresence['pendingOffers'] {
  return p.pendingOffers.filter((o) => o.expiresAt.getTime() > now.getTime());
}
