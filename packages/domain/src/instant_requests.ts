/**
 * Chụp ngay, customer side and sweeps (plan #140 Task 3): create a request, rounds of 5, invites
 * (#140: offers go out at once, no payment), cancel, confirm, tick and the clock step. Every use case
 * settles the request first inside its transaction (Decision 3) and keeps what the clock settled even
 * when it refuses. No payment, refund or ledger write here: money is #202's (Task 11).
 */
import { formatVnDate } from './booking_policy.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import {
  INSTANT,
  cityAt,
  areaLabelAt,
  estimateEtaMinutes,
  instantSearchCells,
  isInstantActive,
  isInstantGenre,
  livePendingOffers,
  nextInstantStatus,
  photographerEarning,
  presenceFresh,
  quoteInstantPrice,
  type InstantCandidate,
  type InstantConfig,
  type InstantGenre,
  type InstantMeetPoint,
  type InstantOffer,
  type InstantOfferRow,
  type InstantPresence,
  type InstantRequest,
  type InstantStatus,
  type OfferOutcome,
} from './instant.js';
import { quoteInstantCancel, type InstantCancelQuote } from './instant_cancel.js';
import { dayBlocksInstant, rankCandidates, type InstantDayState } from './instant_match.js';
import { offerPushMessage } from './instant_notices.js';
import type { InstantCaller, InstantDeps, InstantTrackDoc, InstantTx } from './instant_ports.js';
import { nextDeadlineOf, settleInstant } from './instant_settle.js';
import { distanceKm } from './geo.js';
import type { BookingContactSnapshot } from './booking.js';
import { orderBlocker, type OrderBlock } from './order_gate.js';
import { isVnE164 } from './phone.js';

const SEC = 1000;
const MIN = 60 * SEC;
/** Cells queried per ring (Decision 12). */
const NEARBY_LIMIT = 50;
/** Ids a customer may skip in one call (a round shows 5). */
const MAX_SKIPPED = 50;

// ---------------------------------------------------------------- input

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const invalid = (): never => {
  throw new DomainError('invalid_argument');
};

/** The callable payload as a record, else `invalid_argument`. */
export function instantInput(raw: unknown): Record<string, unknown> {
  return isRecord(raw) ? raw : invalid();
}

export function instantRequestId(d: Record<string, unknown>): string {
  return isId(d.requestId) ? d.requestId : invalid();
}

/** Distinct ids, `min`..`max` of them; missing = []. */
export function instantIdList(v: unknown, min: number, max: number): string[] {
  const list = v === undefined ? [] : v;
  if (!Array.isArray(list) || !list.every(isId)) return invalid();
  const ids = [...new Set(list as string[])];
  return ids.length < min || ids.length > max || ids.length !== list.length ? invalid() : ids;
}

export interface InstantLocation { readonly lat: number; readonly lng: number; readonly accuracyM: number }

/** `{lat, lng, accuracyM}` or undefined when absent; anything malformed is `invalid_argument`. */
export function instantLocation(v: unknown): InstantLocation | undefined {
  if (v === undefined || v === null) return undefined;
  if (!isRecord(v)) return invalid();
  const { lat, lng, accuracyM } = v;
  const num = (x: unknown, lo: number, hi: number): x is number => typeof x === 'number' && Number.isFinite(x) && x >= lo && x <= hi;
  if (!num(lat, -90, 90) || !num(lng, -180, 180) || !num(accuracyM, 0, 100_000)) return invalid();
  return { lat, lng, accuracyM };
}

const optionalBool = (v: unknown): boolean | undefined => (v === undefined ? undefined : typeof v === 'boolean' ? v : invalid());

// ---------------------------------------------------------------- the unit of work

interface Slot<T> { readonly base: T | null; cur: T | null }

const union = (a: readonly string[], b: readonly string[]): string[] => [...new Set([...a, ...b])];

/**
 * Everything one instant transaction reads and decides on: documents are read once through the
 * transaction (all reads happen before `flush`, which is the only place that writes), changed in
 * memory, and written together. Rule for the use cases: settle and read first, decide (and refuse)
 * next, change last; a refusal then keeps exactly what the settles changed.
 */
export class InstantWork {
  private readonly requests = new Map<string, Slot<InstantRequest>>();
  private readonly offers = new Map<string, Slot<InstantOffer>>();
  private readonly presences = new Map<string, Slot<InstantPresence>>();
  private side: Array<(tx: InstantTx) => void> = [];
  private mark: { requests: Map<string, InstantRequest | null>; offers: Map<string, InstantOffer | null>; presences: Map<string, InstantPresence | null>; side: number } | null = null;
  private discarded = false;

  constructor(readonly tx: InstantTx, readonly now: Date) {}

  async request(id: string): Promise<InstantRequest | null> {
    let s = this.requests.get(id);
    if (s === undefined) {
      const r = await this.tx.getRequest(id);
      s = { base: r, cur: r };
      this.requests.set(id, s);
    }
    return s.cur;
  }

  async offer(photographerId: string, offerId: string): Promise<InstantOffer | null> {
    const key = `${photographerId}/${offerId}`;
    let s = this.offers.get(key);
    if (s === undefined) {
      const o = await this.tx.getOffer(photographerId, offerId);
      s = { base: o, cur: o };
      this.offers.set(key, s);
    }
    return s.cur;
  }

  async presence(uid: string): Promise<InstantPresence | null> {
    let s = this.presences.get(uid);
    if (s === undefined) {
      const p = await this.tx.getPresence(uid);
      s = { base: p, cur: p };
      this.presences.set(uid, s);
    }
    return s.cur;
  }

  setRequest(r: InstantRequest): void {
    const s = this.requests.get(r.id);
    if (s === undefined) this.requests.set(r.id, { base: null, cur: r });
    else s.cur = r;
  }

  setOffer(o: InstantOffer): void {
    const key = `${o.photographerId}/${o.id}`;
    const s = this.offers.get(key);
    if (s === undefined) this.offers.set(key, { base: null, cur: o });
    else s.cur = o;
  }

  setPresence(p: InstantPresence): void {
    const s = this.presences.get(p.uid);
    if (s === undefined) this.presences.set(p.uid, { base: null, cur: p });
    else s.cur = p;
  }

  putTrack(requestId: string, t: InstantTrackDoc): void {
    this.side.push((tx) => tx.putTrack(requestId, t));
  }

  deleteTrack(requestId: string): void {
    this.side.push((tx) => tx.deleteTrack(requestId));
  }

  putContact(requestId: string, c: BookingContactSnapshot): void {
    this.side.push((tx) => tx.putContact(requestId, c));
  }

  deleteContact(requestId: string): void {
    this.side.push((tx) => tx.deleteContact(requestId));
  }

  /** Nothing of this transaction is written (a dry run). */
  discard(): void {
    this.discarded = true;
  }

  /**
   * Applies every timer due now to the request and the side writes of what settled: expired and
   * withdrawn offer docs, the photographers' pending entries (`reliability.expired` on expiry), and
   * on an end the assigned photographer's presence and the track. Marks the point a refusal rolls back to.
   */
  async settle(id: string): Promise<InstantRequest | null> {
    const r = await this.request(id);
    if (r === null) return null;
    const out = settleInstant(r, this.now);
    if (out.changed) {
      for (const row of out.expired) await this.closeOffer(row, 'expired');
      for (const row of out.withdrawn) await this.closeOffer(row, 'withdrawn');
      if (out.ended && out.request.photographerId !== null) {
        await this.freePresence(out.request.photographerId, id);
        this.deleteTrack(id);
      }
      this.setRequest(out.request);
    } else if ((r.nextDeadlineAt?.getTime() ?? null) !== (nextDeadlineOf(r)?.getTime() ?? null)) {
      this.setRequest({ ...r }); // a stale stored deadline would make the clock step pick it forever
    }
    this.checkpoint();
    return this.requests.get(id)?.cur ?? null;
  }

  /**
   * The offer doc of a row gets its final outcome (only while still pending) and the photographer's
   * pending entry goes; an expiry counts in `reliability.expired`, a decline in `declined`.
   */
  async closeOffer(row: Pick<InstantOfferRow, 'offerId' | 'photographerId'>, outcome: Exclude<OfferOutcome, 'pending' | 'accepted'>): Promise<void> {
    if (row.offerId === null) return;
    const offer = await this.offer(row.photographerId, row.offerId);
    const presence = await this.presence(row.photographerId);
    if (offer !== null && offer.outcome === 'pending') this.setOffer({ ...offer, outcome, decidedAt: this.now });
    if (presence !== null) {
      const rel = presence.reliability;
      this.setPresence({
        ...presence,
        pendingOffers: presence.pendingOffers.filter((p) => p.offerId !== row.offerId),
        reliability: outcome === 'expired' ? { ...rel, expired: rel.expired + 1 }
          : outcome === 'declined' ? { ...rel, declined: rel.declined + 1 } : rel,
      });
    }
  }

  /** The photographer is free again when this request was their job. */
  async freePresence(uid: string, requestId: string): Promise<InstantPresence | null> {
    const p = await this.presence(uid);
    if (p === null || p.activeRequestId !== requestId) return p;
    const next = { ...p, activeRequestId: null };
    this.setPresence(next);
    return next;
  }

  private checkpoint(): void {
    const snap = <T>(m: Map<string, Slot<T>>): Map<string, T | null> => new Map([...m].map(([k, s]) => [k, s.cur]));
    this.mark = { requests: snap(this.requests), offers: snap(this.offers), presences: snap(this.presences), side: this.side.length };
  }

  /** Back to the last settle; false when nothing was settled (then nothing is worth writing). */
  rollback(): boolean {
    if (this.mark === null || this.discarded) return false;
    const restore = <T>(m: Map<string, Slot<T>>, saved: Map<string, T | null>): void => {
      for (const [k, s] of m) {
        if (saved.has(k)) s.cur = saved.get(k) ?? null;
        else if (s.base === null) m.delete(k);
        else s.cur = s.base;
      }
    };
    restore(this.requests, this.mark.requests);
    restore(this.offers, this.mark.offers);
    restore(this.presences, this.mark.presences);
    this.side = this.side.slice(0, this.mark.side);
    return true;
  }

  /**
   * Writes every changed document. Requests get `active`, `nextDeadlineAt = nextDeadlineOf(r)`,
   * `updatedAt` and one version bump; presences drop pending entries that expired (Decision 14).
   */
  flush(): void {
    if (this.discarded) return;
    for (const s of this.requests.values()) {
      if (s.cur === null || s.cur === s.base) continue;
      const r = { ...s.cur, active: isInstantActive(s.cur.status) };
      this.tx.putRequest({
        ...r,
        nextDeadlineAt: nextDeadlineOf(r),
        updatedAt: s.base === null ? r.updatedAt : this.now,
        version: s.base === null ? r.version : s.base.version + 1,
      });
    }
    for (const s of this.offers.values()) {
      if (s.cur !== null && s.cur !== s.base) this.tx.putOffer(s.cur);
    }
    for (const s of this.presences.values()) {
      if (s.cur === null || s.cur === s.base) continue;
      this.tx.putPresence({ ...s.cur, pendingOffers: livePendingOffers(s.cur, this.now), updatedAt: this.now });
    }
    for (const write of this.side) write(this.tx);
  }
}

/**
 * One instant transaction. A DomainError refuses the call but still writes what the settles of this
 * transaction changed (an accept at 60,5 s answers `offer_expired` and the row reads "Hết hạn").
 */
export async function runInstant<T>(deps: Pick<InstantDeps, 'store' | 'clock'>, fn: (w: InstantWork) => Promise<T>): Promise<T> {
  const box: { error: DomainError | null } = { error: null };
  const result = await deps.store.runTransaction(async (tx) => {
    box.error = null;
    const w = new InstantWork(tx, deps.clock.now());
    try {
      const out = await fn(w);
      w.flush();
      return out;
    } catch (e) {
      if (!(e instanceof DomainError)) throw e;
      if (w.rollback()) w.flush();
      box.error = e;
      return undefined;
    }
  });
  if (box.error !== null) throw box.error;
  return result as T;
}

/** A read outside any decision (pre-reads for the gate, the day state and the candidates). */
export async function peekInstantRequest(deps: Pick<InstantDeps, 'store'>, id: string): Promise<InstantRequest | null> {
  return deps.store.runTransaction((tx) => tx.getRequest(id));
}

// ---------------------------------------------------------------- shared rules

/** `searching` with no pending row left → `choosing` with `roundEnded` and no candidates (Decision 16). */
export function endRoundIfDone(r: InstantRequest): InstantRequest {
  if (r.status !== 'searching' || r.offers.some((o) => o.outcome === 'pending')) return r;
  return { ...r, status: nextInstantStatus(r.status, 'round_ended'), roundEnded: true, candidates: [] };
}

/** Today's (Vietnam date) availability state of each uid. */
export async function instantDayStates(deps: Pick<InstantDeps, 'days'>, uids: readonly string[], now: Date): Promise<Map<string, InstantDayState>> {
  const day = formatVnDate(now);
  const states = await Promise.all(uids.map(async (uid) => [uid, await deps.days.stateOf(uid, day)] as const));
  return new Map(states.filter((e): e is readonly [string, InstantDayState] => e[1] !== null));
}

/** Near cells first, then wide cells when fewer than 5 survive (Decision 12), ranked (Task 2). */
export async function findInstantCandidates(
  deps: Pick<InstantDeps, 'presences' | 'days'>,
  q: { meetPoint: { lat: number; lng: number }; genre: InstantGenre; customerId: string; excluded: ReadonlySet<string>; priceListVersion: number; now: Date },
): Promise<InstantCandidate[]> {
  const states = new Map<string, InstantDayState>();
  const known = new Set<string>();
  const rank = async (presences: readonly InstantPresence[]): Promise<InstantCandidate[]> => {
    const fresh = presences.filter((p) => !known.has(p.uid) && presenceFresh(p, q.now) && p.activeRequestId === null).map((p) => p.uid);
    for (const uid of fresh) known.add(uid);
    for (const [uid, s] of await instantDayStates(deps, fresh, q.now)) states.set(uid, s);
    return rankCandidates({ presences, meetPoint: q.meetPoint, genre: q.genre, excluded: q.excluded, customerId: q.customerId,
      priceListVersion: q.priceListVersion, now: q.now, dayStates: states });
  };
  const near = await deps.presences.nearby({ ...instantSearchCells(q.meetPoint.lat, q.meetPoint.lng, 'near'), limit: NEARBY_LIMIT });
  const ranked = await rank(near);
  if (ranked.length >= INSTANT.ROUND_SIZE) return ranked;
  const wide = await deps.presences.nearby({ ...instantSearchCells(q.meetPoint.lat, q.meetPoint.lng, 'wide'), limit: NEARBY_LIMIT });
  return rank([...near, ...wide]);
}

/** Plain reads before an offer goes out or is accepted: #198's gate (with blocks) and today's day state. */
export interface InstantOfferChecks {
  readonly blockers: ReadonlyMap<string, OrderBlock | null>;
  readonly dayStates: ReadonlyMap<string, InstantDayState>;
}

export async function instantOfferChecks(deps: InstantDeps, customerId: string, ids: readonly string[], now: Date): Promise<InstantOfferChecks> {
  const blockers = await Promise.all(ids.map(async (id) => [id, await orderBlocker(deps, { customerId, providerId: id })] as const));
  return { blockers: new Map(blockers), dayStates: await instantDayStates(deps, ids, now) };
}

const roundKm = (km: number): number => Math.round(km * 10) / 10;

/**
 * Sends one offer to each chosen photographer who can still take it (fresh, free, on the current
 * price list, fewer than 3 live offers, not gated or blocked, day not held); the others get an
 * `unavailable` row and stay suggestible. All unavailable → `choosing` with `roundEnded` (spec §10).
 * The search window restarts (spec §3.3); `committedAt` is set on the first send.
 */
export async function sendInstantOffers(
  w: InstantWork,
  deps: Pick<InstantDeps, 'ids'>,
  r: InstantRequest,
  ids: readonly string[],
  cfg: Pick<InstantConfig, 'priceListVersion'>,
  checks: InstantOfferChecks,
): Promise<{ request: InstantRequest; offers: InstantOffer[]; invited: string[]; unavailable: string[] }> {
  const now = w.now;
  const presences = new Map<string, InstantPresence | null>();
  for (const id of ids) presences.set(id, await w.presence(id));
  const canTake = (id: string): boolean => {
    const p = presences.get(id) ?? null;
    return p !== null && p.lat !== null && p.lng !== null && presenceFresh(p, now) && p.activeRequestId === null
      && p.priceListVersion === cfg.priceListVersion
      && livePendingOffers(p, now).length < INSTANT.MAX_PENDING_OFFERS
      && checks.blockers.get(id) === null
      && !dayBlocksInstant(checks.dayStates.get(id));
  };
  const invited = ids.filter(canTake);
  const unavailable = ids.filter((id) => !invited.includes(id));
  const status = invited.length > 0 ? nextInstantStatus(r.status, 'invite') : r.status;
  const expiresAt = new Date(now.getTime() + INSTANT.OFFER_TTL_S * SEC);
  const offers: InstantOffer[] = [];
  const rows = ids.map((id): InstantOfferRow => {
    const c = r.candidates.find((x) => x.photographerId === id);
    const p = presences.get(id) ?? null;
    const base = {
      photographerId: id, name: c?.name ?? p?.profile.name ?? '', avatarUrl: c?.avatarUrl ?? p?.profile.avatarUrl ?? null,
      tomatoPct: c?.tomatoPct ?? p?.profile.tomatoPct ?? 0, reviewCount: c?.reviewCount ?? p?.profile.reviewCount ?? 0,
    };
    if (p === null || p.lat === null || p.lng === null || !invited.includes(id)) {
      return { ...base, offerId: null, etaMinutes: c?.etaMinutes ?? 0, outcome: 'unavailable', expiresAt: null };
    }
    const km = distanceKm(r.meetPoint, { lat: p.lat, lng: p.lng });
    const offer: InstantOffer = {
      id: deps.ids.newId(), requestId: r.id, photographerId: id, round: r.round, offeredAt: now, expiresAt,
      outcome: 'pending', decidedAt: null, packageCode: r.packageCode, durationMin: r.durationMin, photos: r.photos,
      genre: r.genre, areaLabel: r.areaLabel, distanceKm: roundKm(km), etaMinutes: estimateEtaMinutes(km),
      earningVnd: r.earningVnd, note: r.note, invitedCount: invited.length,
    };
    offers.push(offer);
    w.setOffer(offer);
    w.setPresence({
      ...p,
      pendingOffers: [...livePendingOffers(p, now), { offerId: offer.id, requestId: r.id, expiresAt }],
      reliability: { ...p.reliability, offers: p.reliability.offers + 1 },
    });
    return { ...base, offerId: offer.id, etaMinutes: offer.etaMinutes, outcome: 'pending', expiresAt };
  });
  const common = {
    offers: rows, searchDeadlineAt: new Date(now.getTime() + INSTANT.SEARCH_WINDOW_MIN * MIN), lastActivityAt: now,
    committedAt: r.committedAt ?? now,
  };
  const request: InstantRequest = invited.length > 0
    ? { ...r, ...common, status, roundEnded: false,
        invitedTotal: r.invitedTotal + invited.length, roundsWithInvites: r.roundsWithInvites + 1 }
    : { ...r, ...common, roundEnded: true, candidates: [] };
  w.setRequest(request);
  return { request, offers, invited, unavailable };
}

/** Sends the offer pushes after the commit; a failing device never fails the call. */
export async function pushInstantOffers(deps: Pick<InstantDeps, 'push'>, offers: readonly InstantOffer[]): Promise<void> {
  await Promise.allSettled(offers.map((o) => deps.push.send(o.photographerId, offerPushMessage(o))));
}

// ---------------------------------------------------------------- createInstantRequest

const CUSTOMER_FALLBACK_NAME = 'Khách hàng';

function parseCreate(raw: unknown): { packageCode: string; genre: InstantGenre; meetPoint: InstantMeetPoint; note: string } {
  const d = instantInput(raw);
  const { packageCode, genre, meetPoint, note } = d;
  if (typeof packageCode !== 'string' || !isInstantGenre(genre) || !isRecord(meetPoint)) return invalid();
  const { lat, lng, name } = meetPoint;
  if (typeof lat !== 'number' || !Number.isFinite(lat) || lat < -90 || lat > 90) return invalid();
  if (typeof lng !== 'number' || !Number.isFinite(lng) || lng < -180 || lng > 180) return invalid();
  const place = typeof name === 'string' ? name.trim() : '';
  if (place.length < 1 || [...place].length > INSTANT.MEET_NAME_MAX) return invalid();
  const text = note === undefined || note === null ? '' : typeof note === 'string' ? note.trim() : invalid();
  if ([...text].length > INSTANT.NOTE_MAX) return invalid();
  return { packageCode, genre, meetPoint: { lat, lng, name: place }, note: text };
}

/**
 * S13.01 → S13.02: a request in `choosing`, round 1, its price locked from the config and up to 5
 * candidates. Refuses `not_eligible` (switched off), `phone_required`, `outside_service_area`,
 * `conflict` (an active request already).
 */
export async function createInstantRequest(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<{ requestId: string; amountVnd: number; round: number; candidateCount: number }> {
  const input = parseCreate(raw);
  const cfg = await deps.config.get();
  const pkg = cfg.packages.find((p) => p.code === input.packageCode) ?? invalid();
  if (!cfg.enabled) throw new DomainError('not_eligible');
  const contact = await deps.contacts.get(caller.uid);
  if (!isVnE164(contact?.phone)) throw new DomainError('phone_required');
  const city = cityAt(cfg, input.meetPoint.lat, input.meetPoint.lng);
  if (city === null) throw new DomainError('outside_service_area');
  const now = deps.clock.now();
  const candidates = await findInstantCandidates(deps, {
    meetPoint: input.meetPoint, genre: input.genre, customerId: caller.uid, excluded: new Set(),
    priceListVersion: cfg.priceListVersion, now,
  });
  const user = await deps.users.get(caller.uid);
  const amountVnd = quoteInstantPrice(pkg, city);
  const request: InstantRequest = {
    id: deps.ids.newId(),
    customerId: caller.uid, customerName: user?.name ?? CUSTOMER_FALLBACK_NAME, customerAvatarUrl: user?.avatarUrl ?? null,
    status: 'choosing', active: true,
    packageCode: pkg.code, durationMin: pkg.durationMin, photos: pkg.photos, genre: input.genre, note: input.note,
    cityId: city.id, meetPoint: input.meetPoint, areaLabel: areaLabelAt(cfg, city, input.meetPoint.lat, input.meetPoint.lng),
    amountVnd, earningVnd: photographerEarning(amountVnd, cfg),
    priceListVersion: cfg.priceListVersion, platformFeeBp: cfg.platformFeeBp,
    arrivedCancelPhotographerPercent: cfg.instantArrivedCancelPhotographerPercent,
    committedAt: null,
    payMethod: null, provider: null, paymentId: null, paidAt: null, paymentDeadlineAt: null, refundId: null, refundStatus: null,
    round: 1, invitedTotal: 0, roundsWithInvites: 0, candidates, offers: [], excludedIds: [], pendingInviteIds: [], roundEnded: false,
    photographerId: null, photographer: null, chatId: null, etaMinutes: null,
    assignedAt: null, freeCancelUntil: null, lateDeadlineAt: null, startedRouteAt: null, arrivedAt: null, forcedArrivalAccuracyM: null,
    startedAt: null, shootEndsAt: null, finishedAt: null, completedAt: null,
    cancelledAt: null, cancelledBy: null, cancelRule: null, refundPercent: null, feeVnd: null,
    searchDeadlineAt: null, lastActivityAt: now, nextDeadlineAt: null, createdAt: now, updatedAt: now, version: 1,
  };
  await runInstant(deps, async (w) => {
    const active = await w.tx.findActiveRequestOfCustomer(caller.uid);
    if (active !== null && (await w.settle(active.id))?.active === true) throw new DomainError('conflict');
    w.setRequest(request);
  });
  return { requestId: request.id, amountVnd, round: 1, candidateCount: candidates.length };
}

// ---------------------------------------------------------------- nextInstantCandidates

/** The customer's request, settled; `not_found` / `permission_denied`. */
async function customerRequest(w: InstantWork, id: string, uid: string): Promise<InstantRequest> {
  const raw = await w.request(id);
  if (raw === null) throw new DomainError('not_found');
  if (raw.customerId !== uid) throw new DomainError('permission_denied');
  const r = await w.settle(id);
  if (r === null) throw new DomainError('not_found');
  return r;
}

/**
 * A new round of up to 5 (S13.02 "Xem thêm"): the skipped people are excluded from now on. From
 * `no_match` the request reopens and its 10-minute window restarts. An empty round of a committed
 * request is `no_match` (spec §2.1.9); an uncommitted one stays `choosing` with no candidates.
 */
export async function nextInstantCandidates(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<{ round: number; candidateCount: number; status: InstantStatus }> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const skipped = instantIdList(d.skipped, 0, MAX_SKIPPED);
  const pre = await peekInstantRequest(deps, requestId);
  if (pre === null) throw new DomainError('not_found');
  if (pre.customerId !== caller.uid) throw new DomainError('permission_denied');
  const cfg = await deps.config.get();
  const now = deps.clock.now();
  const found = await findInstantCandidates(deps, {
    meetPoint: pre.meetPoint, genre: pre.genre, customerId: pre.customerId,
    excluded: new Set([...pre.excludedIds, ...skipped]), priceListVersion: cfg.priceListVersion, now,
  });
  return runInstant(deps, async (w) => {
    const r = await customerRequest(w, requestId, caller.uid);
    if (r.status !== 'choosing' && r.status !== 'no_match') throw new DomainError('conflict');
    const excludedIds = union(r.excludedIds, skipped);
    const candidates = found.filter((c) => !excludedIds.includes(c.photographerId));
    const reopened = r.status === 'no_match';
    let next: InstantRequest = {
      ...r,
      status: reopened ? nextInstantStatus(r.status, 'reopen') : r.status,
      excludedIds, round: r.round + 1, candidates, offers: [], pendingInviteIds: [], roundEnded: false, lastActivityAt: w.now,
      searchDeadlineAt: reopened ? new Date(w.now.getTime() + INSTANT.SEARCH_WINDOW_MIN * MIN) : r.searchDeadlineAt,
    };
    if (candidates.length === 0 && next.committedAt !== null) next = { ...next, status: nextInstantStatus(next.status, 'no_match') };
    w.setRequest(next);
    return { round: next.round, candidateCount: candidates.length, status: next.status };
  });
}

// ---------------------------------------------------------------- inviteInstant

export type InviteResult =
  | { kind: 'invited'; invited: string[]; unavailable: string[] }
  | { kind: 'price_changed'; amountVnd: number };

/**
 * S13.02 "Gửi lời mời": 1–5 people of the current round. Uncommitted: the price is re-quoted first
 * (`price_changed` saves the new amount and sends nothing; a stale `expectedAmountVnd` answers the
 * same without a write). #140 has no payment step: the offers go out at once (Task 11 inserts the
 * payment for #202).
 */
export async function inviteInstant(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<InviteResult> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const ids = instantIdList(d.photographerIds, 1, INSTANT.ROUND_SIZE);
  const skipped = instantIdList(d.skipped, 0, MAX_SKIPPED);
  const expected = d.expectedAmountVnd;
  if (typeof expected !== 'number' || !Number.isInteger(expected) || expected < 0) return invalid();
  const pre = await peekInstantRequest(deps, requestId);
  if (pre === null) throw new DomainError('not_found');
  if (pre.customerId !== caller.uid) throw new DomainError('permission_denied');
  const cfg = await deps.config.get();
  const checks = await instantOfferChecks(deps, pre.customerId, ids, deps.clock.now());
  const sent: InstantOffer[] = [];
  const result = await runInstant(deps, async (w): Promise<InviteResult> => {
    sent.length = 0;
    const r = await customerRequest(w, requestId, caller.uid);
    if (r.status !== 'choosing') throw new DomainError('conflict');
    if (!ids.every((id) => r.candidates.some((c) => c.photographerId === id))) throw new DomainError('not_eligible');
    const excludedIds = union(r.excludedIds, skipped);
    if (r.committedAt === null) {
      const pkg = cfg.packages.find((p) => p.code === r.packageCode);
      const city = cfg.cities.find((c) => c.id === r.cityId);
      if (pkg === undefined || city === undefined) throw new DomainError('not_eligible');
      const amountVnd = quoteInstantPrice(pkg, city);
      if (amountVnd !== r.amountVnd) {
        w.setRequest({
          ...r, amountVnd, earningVnd: photographerEarning(amountVnd, cfg), platformFeeBp: cfg.platformFeeBp,
          priceListVersion: cfg.priceListVersion, excludedIds, lastActivityAt: w.now,
        });
        return { kind: 'price_changed', amountVnd };
      }
      if (expected !== r.amountVnd) return { kind: 'price_changed', amountVnd: r.amountVnd };
    }
    const out = await sendInstantOffers(w, deps, { ...r, excludedIds }, ids, cfg, checks);
    sent.push(...out.offers);
    return { kind: 'invited', invited: out.invited, unavailable: out.unavailable };
  });
  await pushInstantOffers(deps, sent);
  return result;
}

// ---------------------------------------------------------------- cancelInstantRequest

const PHOTOGRAPHER_RESET = {
  photographerId: null, photographer: null, chatId: null, etaMinutes: null, assignedAt: null, freeCancelUntil: null,
  lateDeadlineAt: null, startedRouteAt: null, arrivedAt: null, forcedArrivalAccuracyM: null,
} as const;

/**
 * S13.08 / the photographer's cancel. `dryRun` answers the quote and writes nothing. A customer cancel
 * ends the request (`cancelled_by_customer`; #140: rule `unpaid`, no money) and withdraws the pending
 * offers; an assigned photographer is freed (`reliability.late` when past `lateDeadlineAt` before
 * arrival, whatever the rule). A photographer cancel returns the request to `choosing` without them,
 * clears the job, restarts the 10-minute window and counts `reliability.cancelled`.
 */
export async function cancelInstantRequest(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<InstantCancelQuote & { status: InstantStatus }> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const dryRun = optionalBool(d.dryRun) ?? false;
  return runInstant(deps, async (w) => {
    const first = await w.request(requestId);
    if (first === null) throw new DomainError('not_found');
    const role = first.customerId === caller.uid ? 'customer' : first.photographerId === caller.uid ? 'photographer' : null;
    if (role === null) throw new DomainError('permission_denied');
    const r = await w.settle(requestId);
    if (r === null) throw new DomainError('not_found');
    if (role === 'photographer' && r.photographerId !== caller.uid) throw new DomainError('permission_denied');
    const now = w.now;
    const q = quoteInstantCancel(r, role, now);
    if (dryRun) {
      w.discard();
      return { ...q, status: r.status };
    }
    const recorded = { cancelRule: q.rule, refundPercent: q.refundPercent, feeVnd: q.feeVnd, cancelledAt: now };
    const status = nextInstantStatus(r.status, role === 'customer' ? 'customer_cancel' : 'photographer_cancel');
    if (role === 'customer') {
      const late = (r.status === 'assigned' || r.status === 'en_route') && r.lateDeadlineAt !== null && now.getTime() > r.lateDeadlineAt.getTime();
      for (const row of r.offers) if (row.outcome === 'pending') await w.closeOffer(row, 'withdrawn');
      if (r.photographerId !== null) {
        const p = await w.freePresence(r.photographerId, r.id);
        if (p !== null && late) w.setPresence({ ...p, reliability: { ...p.reliability, late: p.reliability.late + 1 } });
        w.deleteTrack(r.id);
      }
      const next: InstantRequest = {
        ...r, ...recorded, status, cancelledBy: 'customer', candidates: [],
        offers: r.offers.map((o) => (o.outcome === 'pending' ? { ...o, outcome: 'withdrawn' as const } : o)),
      };
      w.setRequest(next);
      return { ...q, status: next.status };
    }
    const p = await w.freePresence(caller.uid, r.id);
    if (p !== null) w.setPresence({ ...p, reliability: { ...p.reliability, cancelled: p.reliability.cancelled + 1 } });
    w.deleteContact(r.id);
    w.deleteTrack(r.id);
    const next: InstantRequest = {
      ...r, ...recorded, ...PHOTOGRAPHER_RESET, status, cancelledBy: 'photographer',
      excludedIds: union(r.excludedIds, [caller.uid]), candidates: [], offers: [], roundEnded: true,
      searchDeadlineAt: new Date(now.getTime() + INSTANT.SEARCH_WINDOW_MIN * MIN),
    };
    w.setRequest(next);
    return { ...q, status: next.status };
  });
}

// ---------------------------------------------------------------- confirm, tick, sweep

/** The customer confirms the shoot (`in_progress` or `finished` → `completed`); the photographer is free again. */
export async function confirmInstantComplete(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }> {
  const requestId = instantRequestId(instantInput(raw));
  return runInstant(deps, async (w) => {
    const r = await customerRequest(w, requestId, caller.uid);
    if (r.status === 'completed') return { status: r.status };
    const status = nextInstantStatus(r.status, 'complete');
    if (r.photographerId !== null) await w.freePresence(r.photographerId, r.id);
    w.setRequest({ ...r, status, completedAt: w.now, finishedAt: r.finishedAt ?? w.now });
    return { status };
  });
}

/**
 * Apps call this when a countdown they show reaches zero (Decision 3). Allowed for the customer, the
 * assigned photographer and a photographer with an offer row on the request.
 */
export async function tickInstantRequest(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }> {
  const requestId = instantRequestId(instantInput(raw));
  return runInstant(deps, async (w) => {
    const r = await w.request(requestId);
    if (r === null) throw new DomainError('not_found');
    const allowed = r.customerId === caller.uid || r.photographerId === caller.uid
      || r.offers.some((o) => o.photographerId === caller.uid);
    if (!allowed) throw new DomainError('permission_denied');
    const settled = await w.settle(requestId);
    return { status: settled?.status ?? r.status };
  });
}

/**
 * The step of the 15-minute clock (Decision 3): settles up to 100 due requests, each in its own
 * transaction; a failing one is reported in `errors` (the caller logs it) and the batch goes on.
 */
export async function runInstantSweep(deps: InstantDeps): Promise<{ settled: number; errors: { requestId: string; error: unknown }[] }> {
  const due = await deps.store.findDue(deps.clock.now(), 100);
  let settled = 0;
  const errors: { requestId: string; error: unknown }[] = [];
  for (const r of due) {
    try {
      await runInstant(deps, async (w) => {
        await w.settle(r.id);
      });
      settled += 1;
    } catch (error) {
      errors.push({ requestId: r.id, error });
    }
  }
  return { settled, errors };
}
