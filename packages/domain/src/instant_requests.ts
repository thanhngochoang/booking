/**
 * Chụp ngay, customer side and sweeps (plan #140 Task 3, money #202 Task 11): create a request,
 * rounds of 5, invites (the first one opens the payment; the offers go out once it is paid,
 * Decision 5), cancel (Decision 9 money), confirm (release, Decision 7), tick and the clock step.
 * Every use case settles the request first inside its transaction (Decision 3) and keeps what the
 * clock settled even when it refuses. Refunds are sent after the commit; the clock step never sends one.
 */
import { PAYMENT_EXPIRY_MINUTES, formatVnDate } from './booking_policy.js';
import { checkSubjectPayments, freshPaymentId, instructionsOf, issuePaymentInstructions, newSubjectPayment } from './create_payment.js';
import { DomainError } from './errors.js';
import { isPaymentMethod, type Payment, type PaymentMethod } from './escrow.js';
import { isId } from './ids.js';
import {
  INSTANT,
  cityAt,
  areaLabelAt,
  estimateEtaMinutes,
  instantSearchCells,
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
} from './instant.js';
import { quoteInstantCancel, type InstantCancelQuote } from './instant_cancel.js';
import { dayBlocksInstant, rankCandidates, type InstantDayState } from './instant_match.js';
import { offerPushMessage } from './instant_notices.js';
import { mirrorRefund, refundInstantShare, sendInstantRefunds } from './instant_payments.js';
import type { InstantCaller, InstantDeps } from './instant_ports.js';
import { InstantWork, peekInstantRequest, runInstant, type InstantRefundSend } from './instant_work.js';
import { distanceKm } from './geo.js';
import { orderBlocker, type OrderBlock } from './order_gate.js';
import type { PaymentInstructions } from './payment_ports.js';
import { expireUnpaid, type SettlementDeps } from './payment_settlement.js';
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

const union = (a: readonly string[], b: readonly string[]): string[] => [...new Set([...a, ...b])];

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
  deps: Pick<InstantDeps, 'presences' | 'days' | 'blocks'>,
  q: { meetPoint: { lat: number; lng: number }; genre: InstantGenre; customerId: string; excluded: ReadonlySet<string>; priceListVersion: number; now: Date },
): Promise<InstantCandidate[]> {
  const states = new Map<string, InstantDayState>();
  const known = new Set<string>();
  const checked = new Set<string>();
  const excluded = new Set(q.excluded);
  /**
   * Ranks, then checks each ranked candidate once against the BlockGate (either way): a blocked one
   * is excluded and the round re-ranked, so blocked parties are never suggested.
   */
  const rank = async (presences: readonly InstantPresence[]): Promise<InstantCandidate[]> => {
    const fresh = presences.filter((p) => !known.has(p.uid) && presenceFresh(p, q.now) && p.activeRequestId === null).map((p) => p.uid);
    for (const uid of fresh) known.add(uid);
    for (const [uid, s] of await instantDayStates(deps, fresh, q.now)) states.set(uid, s);
    for (;;) {
      const ranked = rankCandidates({ presences, meetPoint: q.meetPoint, genre: q.genre, excluded, customerId: q.customerId,
        priceListVersion: q.priceListVersion, now: q.now, dayStates: states });
      const unchecked = ranked.map((c) => c.photographerId).filter((id) => !checked.has(id));
      if (unchecked.length === 0) return ranked;
      const blocked = await Promise.all(unchecked.map((id) => deps.blocks.isBlockedEitherWay(q.customerId, id)));
      unchecked.forEach((id, i) => {
        checked.add(id);
        if (blocked[i] === true) excluded.add(id);
      });
    }
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
 * The search window restarts (spec §3.3); `committedAt` is set on the first send. From
 * `pending_payment` (#202: the payment of the first round just arrived) the request moves on `paid`.
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
  const fromPayment = r.status === 'pending_payment';
  const status = invited.length > 0 ? nextInstantStatus(r.status, fromPayment ? 'paid' : 'invite')
    : fromPayment ? 'choosing' : r.status;
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
    : { ...r, ...common, status, roundEnded: true, candidates: [] };
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
  | { kind: 'payment'; instructions: PaymentInstructions; amountVnd: number }
  | { kind: 'invited'; invited: string[]; unavailable: string[] }
  | { kind: 'price_changed'; amountVnd: number };

const MINUTE_MS = 60_000;

/**
 * S13.02 "Thanh toán {giá} và gửi lời mời" / "Gửi lời mời": 1–5 people of the current round.
 * Uncommitted (nothing paid yet, #202 Decision 5): `payMethod` is required; in `choosing` the price is
 * re-quoted first (`price_changed` saves the new amount and opens nothing; a stale `expectedAmountVnd`
 * answers the same without a write); then the choice waits in `pendingInviteIds`, the request in
 * `pending_payment`, and the answer is how to pay (V1's `PaymentInstructions`). A second tap
 * (`pending_payment`, "Thanh toán tiếp") reuses the open payment of the same amount and method;
 * another method closes it (`expireUnpaid`) and opens a new one. No offer goes out before the
 * payment is `paid` (`InstantPaymentSettler`). Committed (paid): later rounds send at once on the
 * held money.
 */
export async function inviteInstant(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<InviteResult> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const ids = instantIdList(d.photographerIds, 1, INSTANT.ROUND_SIZE);
  const skipped = instantIdList(d.skipped, 0, MAX_SKIPPED);
  const expected = d.expectedAmountVnd;
  if (typeof expected !== 'number' || !Number.isInteger(expected) || expected < 0) return invalid();
  const payMethod: PaymentMethod | undefined = d.payMethod === undefined || d.payMethod === null ? undefined
    : isPaymentMethod(d.payMethod) ? d.payMethod : invalid();
  const pre = await peekInstantRequest(deps, requestId);
  if (pre === null) throw new DomainError('not_found');
  if (pre.customerId !== caller.uid) throw new DomainError('permission_denied');
  const cfg = await deps.config.get();
  if (!cfg.enabled) throw new DomainError('not_eligible');
  const committed = pre.committedAt !== null;
  if (!committed && payMethod === undefined) return invalid();
  const checks = committed ? await instantOfferChecks(deps, pre.customerId, ids, deps.clock.now()) : null;
  // Drawn outside the transaction: its transfer code must not clash with any payment of any subject.
  const freshId = committed ? null : await freshPaymentId(deps.payments, deps.ids);
  const sent: InstantOffer[] = [];
  let sends: InstantRefundSend[] = [];
  const result = await runInstant(deps, async (w): Promise<InviteResult | { kind: 'issue'; payment: Payment; amountVnd: number }> => {
    sent.length = 0;
    sends = [];
    const r = await customerRequest(w, requestId, caller.uid);
    const excludedIds = union(r.excludedIds, skipped);
    if (r.committedAt !== null) {
      if (r.status !== 'choosing') throw new DomainError('conflict');
      if (!ids.every((id) => r.candidates.some((c) => c.photographerId === id))) throw new DomainError('not_eligible');
      const out = await sendInstantOffers(w, deps, { ...r, excludedIds }, ids, cfg, checks ?? (await instantOfferChecks(deps, r.customerId, ids, w.now)));
      sent.push(...out.offers);
      return { kind: 'invited', invited: out.invited, unavailable: out.unavailable };
    }
    if (r.status !== 'choosing' && r.status !== 'pending_payment') throw new DomainError('conflict');
    if (!ids.every((id) => r.candidates.some((c) => c.photographerId === id))) throw new DomainError('not_eligible');
    if (payMethod === undefined || freshId === null) return invalid();
    if (r.status === 'choosing') {
      // While a payment is open its amount is the price; a closed window re-quotes.
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
    }
    if (expected !== r.amountVnd) return { kind: 'price_changed', amountVnd: r.amountVnd };
    // ---- reads (the request's payments), then the payment decision
    const open = r.paymentId === null ? null : await w.payment(r.paymentId);
    const count = (await w.paymentsOfRequest(r.id)).length;
    const now = w.now;
    const live = open !== null && open.status === 'created' && open.amount === r.amountVnd && open.method === payMethod
      && open.expiresAt !== undefined && Date.parse(open.expiresAt) > now.getTime();
    let payment: Payment;
    if (live) {
      payment = open;
    } else {
      if (open !== null && open.status === 'created') {
        const out = expireUnpaid({ payment: open, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), now });
        w.setPayment(out.payment);
        if (out.refund !== null && out.ledgerEntry !== null) {
          w.putRefund(out.refund);
          w.putLedgerEntry(out.ledgerEntry);
          w.queueRefundSend(out.refund, out.payment);
        }
      }
      payment = {
        ...newSubjectPayment({
          id: freshId, subjectType: 'instant_request', subjectId: r.id, payerId: r.customerId, payeeId: '',
          amount: r.amountVnd, method: payMethod, provider: deps.gateway.provider, idempotencyKey: `inst_${r.id}_${count + 1}`,
          now, expiresAt: new Date(now.getTime() + PAYMENT_EXPIRY_MINUTES * MINUTE_MS),
        }),
        // Decision 6: the payout takes the fee the request snapshotted with its price.
        feeBp: r.platformFeeBp,
      };
      w.setPayment(payment);
    }
    w.setRequest({
      ...r,
      status: r.status === 'choosing' ? nextInstantStatus(r.status, 'invite_unpaid') : r.status,
      pendingInviteIds: ids, excludedIds, payMethod, provider: payment.provider, paymentId: payment.id,
      paymentDeadlineAt: new Date(Date.parse(payment.expiresAt ?? now.toISOString())), lastActivityAt: now,
    });
    sends = w.refundSends();
    return { kind: 'issue', payment, amountVnd: r.amountVnd };
  });
  await sendInstantRefunds(deps, sends);
  await pushInstantOffers(deps, sent);
  if (result.kind !== 'issue') return result;
  const { payment } = result;
  // The gateway is asked outside the transaction; its answer is saved only while the payment is still open.
  const instructions = instructionsOf(payment) ?? await issuePaymentInstructions(deps.gateway, payment, async (providerRef, inst) => {
    await deps.store.runTransaction(async (tx) => {
      const cur = await tx.getPayment(payment.id);
      if (cur === null || cur.status !== 'created') return;
      tx.putPayment({ ...cur, ...(providerRef ? { providerRef } : {}), instructions: inst, updatedAt: deps.clock.now().toISOString() });
    });
  });
  return { kind: 'payment', instructions, amountVnd: result.amountVnd };
}

// ---------------------------------------------------------------- checkInstantPayment

/**
 * S04.04 on resume for an instant request (payer only): asks the gateway about every open payment of
 * the request and applies what it reports through V1's settlement (`checkSubjectPayments`), then
 * answers whether the request is paid and its status.
 */
export async function checkInstantPayment(
  deps: InstantDeps & { readonly settlement: SettlementDeps },
  caller: InstantCaller,
  raw: unknown,
): Promise<{ paid: boolean; status: InstantStatus }> {
  const requestId = instantRequestId(instantInput(raw));
  const open = await deps.store.runTransaction(async (tx) => {
    const r = await tx.getRequest(requestId);
    if (r === null) throw new DomainError('not_found');
    if (r.customerId !== caller.uid) throw new DomainError('permission_denied');
    if (r.paidAt !== null) return [];
    return (await tx.paymentsOfRequest(requestId)).filter((p) => p.status === 'created');
  });
  await checkSubjectPayments(deps.settlement, open);
  const after = await runInstant(deps, (w) => w.settle(requestId));
  if (after === null) throw new DomainError('not_found');
  return { paid: after.paidAt !== null, status: after.status };
}

// ---------------------------------------------------------------- cancelInstantRequest

const PHOTOGRAPHER_RESET = {
  photographerId: null, photographer: null, chatId: null, etaMinutes: null, assignedAt: null, freeCancelUntil: null,
  lateDeadlineAt: null, startedRouteAt: null, arrivedAt: null, forcedArrivalAccuracyM: null,
} as const;

/** The dry run's quote the app sends with the real cancel (`expectedRule`, `expectedRefundVnd`), when it does. */
function expectedQuote(d: Record<string, unknown>): { rule: string; refundVnd: number } | null {
  const { expectedRule: rule, expectedRefundVnd: refundVnd } = d;
  if (rule === undefined && refundVnd === undefined) return null;
  if (typeof rule !== 'string' || typeof refundVnd !== 'number' || !Number.isInteger(refundVnd) || refundVnd < 0) return invalid();
  return { rule, refundVnd };
}

/**
 * S13.08 / the photographer's cancel. `dryRun` answers the quote and writes nothing. A real cancel may
 * carry the dry run's `expectedRule`/`expectedRefundVnd`: when the quote changed in between (a window
 * ended), it is `conflict` and nothing moves, so the customer never confirms one amount and gets another.
 * A customer cancel ends the request (`cancelled_by_customer`) and withdraws the pending offers; an
 * assigned photographer is freed (`reliability.late` when past `lateDeadlineAt` before arrival). Paid
 * (#202): the quote's share goes back to the customer (`applyRefundToPayment`, Decision 9), the rest
 * stays for the photographer and is released 24 h later (Decision 7). A photographer cancel returns
 * the request to `choosing` without them, clears the job and the payment's payee (the money stays held
 * for the next round), restarts the 10-minute window and counts `reliability.cancelled`.
 */
export async function cancelInstantRequest(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<InstantCancelQuote & { status: InstantStatus }> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const dryRun = optionalBool(d.dryRun) ?? false;
  const expected = expectedQuote(d);
  let sends: InstantRefundSend[] = [];
  const result = await runInstant(deps, async (w) => {
    sends = [];
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
    if (expected !== null && (expected.rule !== q.rule || expected.refundVnd !== q.refundVnd)) throw new DomainError('conflict');
    const recorded = { cancelRule: q.rule, refundPercent: q.refundPercent, feeVnd: q.feeVnd, cancelledAt: now };
    const status = nextInstantStatus(r.status, role === 'customer' ? 'customer_cancel' : 'photographer_cancel');
    // #202: the paid money (reads before any decision is written; the work flushes at the end).
    const payment = q.amountVnd > 0 && r.paymentId !== null ? await w.payment(r.paymentId) : null;
    if (role === 'customer') {
      const late = (r.status === 'assigned' || r.status === 'en_route') && r.lateDeadlineAt !== null && now.getTime() > r.lateDeadlineAt.getTime();
      for (const row of r.offers) if (row.outcome === 'pending') await w.closeOffer(row, 'withdrawn');
      if (r.photographerId !== null) {
        const p = await w.freePresence(r.photographerId, r.id);
        if (p !== null && late) w.setPresence({ ...p, reliability: { ...p.reliability, late: p.reliability.late + 1 } });
        w.deleteTrack(r.id);
      }
      let next: InstantRequest = {
        ...r, ...recorded, status, cancelledBy: 'customer', candidates: [],
        offers: r.offers.map((o) => (o.outcome === 'pending' ? { ...o, outcome: 'withdrawn' as const } : o)),
      };
      if (payment !== null) {
        let held = payment;
        if (q.refundVnd > 0) {
          const out = refundInstantShare(w, deps, payment, q.refundPercent, q.rule);
          held = out.payment;
          next = mirrorRefund(next, out.refund);
        }
        // What the photographer keeps is released after the dispute window (Decision 7).
        w.setPayment(held);
        if (q.feeVnd > 0) await w.stampRelease(next, now);
      }
      w.setRequest(next);
      sends = w.refundSends();
      return { ...q, status: next.status };
    }
    const p = await w.freePresence(caller.uid, r.id);
    if (p !== null) w.setPresence({ ...p, reliability: { ...p.reliability, cancelled: p.reliability.cancelled + 1 } });
    // The money stays held for the next round; nobody is its payee until someone else accepts.
    if (payment !== null) w.setPayment({ ...payment, payeeId: '', updatedAt: now.toISOString() });
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
  await sendInstantRefunds(deps, sends);
  return result;
}

// ---------------------------------------------------------------- confirm, tick, sweep

/**
 * The customer confirms the shoot (`in_progress` or `finished` → `completed`); the photographer is free
 * again and the money is released 24 h later (#202, Decision 7: `releaseAfter`, bookingClock's release step).
 */
export async function confirmInstantComplete(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }> {
  const requestId = instantRequestId(instantInput(raw));
  return runInstant(deps, async (w) => {
    const r = await customerRequest(w, requestId, caller.uid);
    if (r.status === 'completed') return { status: r.status };
    const status = nextInstantStatus(r.status, 'complete');
    if (r.photographerId !== null) await w.freePresence(r.photographerId, r.id);
    const next: InstantRequest = { ...r, status, completedAt: w.now, finishedAt: r.finishedAt ?? w.now };
    await w.stampRelease(next, w.now);
    w.setRequest(next);
    return { status };
  });
}

/**
 * Apps call this when a countdown they show reaches zero (Decision 3). Allowed for the customer, the
 * assigned photographer and a photographer who got an offer on the request's current round.
 */
export async function tickInstantRequest(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }> {
  const requestId = instantRequestId(instantInput(raw));
  return runInstant(deps, async (w) => {
    const r = await w.request(requestId);
    if (r === null) throw new DomainError('not_found');
    // An `unavailable` row is no offer: that photographer never saw this request.
    const allowed = r.customerId === caller.uid || r.photographerId === caller.uid
      || r.offers.some((o) => o.photographerId === caller.uid && o.offerId !== null);
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
