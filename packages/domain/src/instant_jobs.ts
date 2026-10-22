/**
 * Chụp ngay, photographer side (plan #140 Task 3): Live Shutter and the price list (S14.01),
 * answering offers with first-accept-wins (S14.02, Decision 4) and the job steps (S14.03). Each use
 * case settles the requests it touches first, inside its transaction.
 */
import type { BookingContactSnapshot } from './booking.js';
import { chatIdFor } from './chat.js';
import { encodeGeohash } from './event.js';
import { DomainError } from './errors.js';
import { distanceKm } from './geo.js';
import { isId } from './ids.js';
import {
  INSTANT,
  cityAt,
  livePendingOffers,
  nextInstantStatus,
  type InstantParty,
  type InstantPresence,
  type InstantProfile,
  type InstantRequest,
  type InstantStatus,
} from './instant.js';
import { quoteInstantNoShow } from './instant_cancel.js';
import { dayBlocksInstant } from './instant_match.js';
import type { InstantCaller, InstantDeps } from './instant_ports.js';
import {
  endRoundIfDone,
  instantDayStates,
  instantInput,
  instantLocation,
  instantRequestId,
  type InstantLocation,
} from './instant_requests.js';
import { peekInstantRequest, runInstant } from './instant_work.js';
import { orderBlocker } from './order_gate.js';
import { isVnE164 } from './phone.js';

const MIN = 60_000;

const invalid = (): never => {
  throw new DomainError('invalid_argument');
};

// ---------------------------------------------------------------- Live Shutter, settings

export const LIVE_SHUTTER_REASONS = ['not_accepting_orders', 'phone_required', 'price_list_not_accepted', 'outside_service_area'] as const;
export type LiveShutterReason = (typeof LIVE_SHUTTER_REASONS)[number];

const EMPTY_RELIABILITY = { offers: 0, accepted: 0, declined: 0, expired: 0, cancelled: 0, late: 0, noShow: 0 } as const;

function offlinePresence(uid: string, profile: InstantProfile, now: Date): InstantPresence {
  return {
    uid, online: false, helpReady: false, priceListVersion: null, cityId: null, lat: null, lng: null, accuracyM: null,
    geohash5: null, geohash4: null, heartbeatAt: null, activeRequestId: null, pendingOffers: [], profile,
    reliability: EMPTY_RELIABILITY, updatedAt: now,
  };
}

/**
 * S14.01 switch. Reasons, in this order: the order gate, a phone on file, the current price list
 * accepted, the position inside an open city (only when switching on with a location). A dry run or
 * any reason writes nothing. On: position, geohashes, heartbeat and a fresh profile snapshot. Off:
 * `online: false` only (pending offers expire on their own, an active job is untouched).
 */
export async function setLiveShutter(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<{ online: boolean; reasons: LiveShutterReason[] }> {
  const d = instantInput(raw);
  if (typeof d.online !== 'boolean') return invalid();
  const online = d.online;
  const dryRun = d.dryRun === undefined ? false : typeof d.dryRun === 'boolean' ? d.dryRun : invalid();
  const location = instantLocation(d.location);
  if (online && location === undefined && !dryRun) return invalid();
  const uid = caller.uid;
  const cfg = await deps.config.get();
  const current = await deps.store.runTransaction((tx) => tx.getPresence(uid));
  const reasons: LiveShutterReason[] = [];
  if (online) {
    if (!(await deps.providers.acceptsOrders(uid))) reasons.push('not_accepting_orders');
    if (!(await deps.phones.hasPhone(uid))) reasons.push('phone_required');
    if (current?.priceListVersion !== cfg.priceListVersion) reasons.push('price_list_not_accepted');
    if (location !== undefined && cityAt(cfg, location.lat, location.lng) === null) reasons.push('outside_service_area');
  }
  if (dryRun || reasons.length > 0) return { online: current?.online ?? false, reasons };
  if (!online) {
    if (current === null) return { online: false, reasons };
    await runInstant(deps, async (w) => {
      const p = await w.presence(uid);
      if (p !== null && p.online) w.setPresence({ ...p, online: false });
    });
    return { online: false, reasons };
  }
  const at = location as InstantLocation;
  const city = cityAt(cfg, at.lat, at.lng);
  const profile = await deps.profiles.snapshot(uid);
  if (profile === null || city === null) return { online: current?.online ?? false, reasons: ['not_accepting_orders'] };
  const geohash5 = encodeGeohash(at.lat, at.lng, 5);
  await runInstant(deps, async (w) => {
    const p = await w.presence(uid);
    if (p === null || p.priceListVersion !== cfg.priceListVersion) throw new DomainError('price_changed');
    w.setPresence({
      ...p, online: true, lat: at.lat, lng: at.lng, accuracyM: at.accuracyM, geohash5, geohash4: geohash5.slice(0, 4),
      heartbeatAt: w.now, cityId: city.id, profile,
    });
  });
  return { online: true, reasons };
}

/**
 * S14.01 terms and "Sẵn sàng hỗ trợ". Accepting a price list other than the current one is
 * `price_changed`. The presence is created offline when missing (a provider profile is needed).
 */
export async function saveInstantSettings(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<{ priceListVersion: number | null; helpReady: boolean }> {
  const d = instantInput(raw);
  const accept = d.acceptPriceListVersion;
  if (accept !== undefined && (typeof accept !== 'number' || !Number.isInteger(accept))) return invalid();
  const helpReady = d.helpReady === undefined ? undefined : typeof d.helpReady === 'boolean' ? d.helpReady : invalid();
  const cfg = await deps.config.get();
  if (accept !== undefined && accept !== cfg.priceListVersion) throw new DomainError('price_changed');
  const existing = await deps.store.runTransaction((tx) => tx.getPresence(caller.uid));
  const profile = existing === null ? await deps.profiles.snapshot(caller.uid) : existing.profile;
  if (profile === null) throw new DomainError('not_eligible');
  return runInstant(deps, async (w) => {
    const p = (await w.presence(caller.uid)) ?? offlinePresence(caller.uid, profile, w.now);
    const next = { ...p, priceListVersion: accept ?? p.priceListVersion, helpReady: helpReady ?? p.helpReady };
    w.setPresence(next);
    return { priceListVersion: next.priceListVersion, helpReady: next.helpReady };
  });
}

// ---------------------------------------------------------------- answerInstantOffer

const partyOf = (uid: string, p: InstantProfile): InstantParty => ({
  id: uid, name: p.name, avatarUrl: p.avatarUrl, verified: p.verified, tomatoPct: p.tomatoPct,
  reviewCount: p.reviewCount, completedCount: p.completedCount,
});

/**
 * S14.02 "Nhận việc" / "Từ chối". Accept is first-accept-wins in one transaction (Decision 4): the
 * request, the offer, the photographer's presence and the requests of their other live offers are
 * read and settled first; the winner gets the job, every other pending offer of the request and every
 * other offer of the winner is withdrawn (rounds end where nothing is pending). Refusals:
 * `offer_expired` (server time is the referee; also an offer withdrawn with nobody on the job, e.g.
 * the customer cancelled), `already_assigned` (someone else won, or the photographer has a job), #198's `not_accepting_orders` /
 * `blocked`, `not_eligible` (today's day is held by a spot or a full studio). Decline excludes the
 * photographer from the request.
 */
export async function answerInstantOffer(
  deps: InstantDeps,
  caller: InstantCaller,
  raw: unknown,
): Promise<{ outcome: 'accepted' | 'declined'; requestId: string }> {
  const d = instantInput(raw);
  const offerId = isId(d.offerId) ? d.offerId : invalid();
  const action = d.action === 'accept' || d.action === 'decline' ? d.action : invalid();
  const uid = caller.uid;
  if (action === 'decline') return declineOffer(deps, uid, offerId);

  // Plain reads before the transaction: #198's gate (provider + blocks), today's day, the customer contact.
  const pre = await deps.store.runTransaction((tx) => tx.getOffer(uid, offerId));
  if (pre === null) throw new DomainError('not_found');
  const preRequest = await peekInstantRequest(deps, pre.requestId);
  if (preRequest === null) throw new DomainError('not_found');
  const blocker = await orderBlocker(deps, { customerId: preRequest.customerId, providerId: uid });
  const day = (await instantDayStates(deps, [uid], deps.clock.now())).get(uid);
  const contact = preRequest.paidAt === null ? null : await deps.contacts.get(preRequest.customerId);

  return runInstant(deps, async (w) => {
    const now = w.now;
    const first = await w.offer(uid, offerId);
    if (first === null) throw new DomainError('not_found');
    const before = await w.presence(uid);
    const others = before === null ? [] : livePendingOffers(before, now).filter((p) => p.requestId !== first.requestId);
    const r = await w.settle(first.requestId);
    if (r === null) throw new DomainError('not_found');
    for (const o of others) {
      await w.settle(o.requestId);
      await w.offer(uid, o.offerId);
    }
    // ---- decisions (nothing changed yet besides what the settles did)
    const offer = await w.offer(uid, offerId);
    if (offer === null) throw new DomainError('not_found');
    if (offer.outcome === 'accepted' && r.photographerId === uid) return { outcome: 'accepted', requestId: r.id };
    if (offer.outcome === 'expired' || (offer.outcome === 'pending' && offer.expiresAt.getTime() <= now.getTime())) {
      throw new DomainError('offer_expired');
    }
    if (offer.outcome !== 'pending' && offer.outcome !== 'withdrawn') throw new DomainError('conflict');
    const presence = await w.presence(uid);
    // Withdrawn with nobody on the job (the customer cancelled, or the search ran out): the offer is simply gone.
    if (offer.outcome === 'withdrawn' && r.photographerId === null && (presence === null || presence.activeRequestId === null)) {
      throw new DomainError('offer_expired');
    }
    if (offer.outcome === 'withdrawn' || r.status !== 'searching' || presence === null || presence.activeRequestId !== null) {
      throw new DomainError('already_assigned');
    }
    if (blocker !== null) throw new DomainError(blocker);
    if (dayBlocksInstant(day)) throw new DomainError('not_eligible');
    const status = nextInstantStatus(r.status, 'accept');
    // ---- writes
    for (const row of r.offers) {
      if (row.outcome === 'pending' && row.offerId !== offerId) await w.closeOffer(row, 'withdrawn');
    }
    w.setOffer({ ...offer, outcome: 'accepted', decidedAt: now });
    for (const o of others) {
      const od = await w.offer(uid, o.offerId);
      if (od !== null && od.outcome === 'pending') w.setOffer({ ...od, outcome: 'withdrawn', decidedAt: now });
      const other = await w.request(o.requestId);
      if (other === null || other.status !== 'searching') continue;
      w.setRequest(endRoundIfDone({
        ...other,
        offers: other.offers.map((row) => (row.offerId === o.offerId && row.outcome === 'pending' ? { ...row, outcome: 'withdrawn' as const } : row)),
      }));
    }
    const current = (await w.presence(uid)) ?? presence;
    w.setPresence({
      ...current, activeRequestId: r.id, pendingOffers: [],
      reliability: { ...current.reliability, accepted: current.reliability.accepted + 1 },
    });
    w.setRequest({
      ...r, status, candidates: [], offers: [], pendingInviteIds: [], roundEnded: false, searchDeadlineAt: null,
      photographerId: uid, photographer: partyOf(uid, current.profile), chatId: chatIdFor(r.customerId, uid),
      etaMinutes: offer.etaMinutes, assignedAt: now,
      freeCancelUntil: new Date(now.getTime() + INSTANT.FREE_CANCEL_MIN * MIN),
      lateDeadlineAt: new Date(now.getTime() + (offer.etaMinutes + INSTANT.LATE_GRACE_MIN) * MIN),
      startedRouteAt: null, arrivedAt: null, forcedArrivalAccuracyM: null,
      cancelledAt: null, cancelledBy: null, cancelRule: null, refundPercent: null, feeVnd: null,
    });
    // Decision 22: the customer's number reaches the photographer only for a paid request (never in #140).
    if (r.paidAt !== null && contact !== null && isVnE164(contact.phone)) {
      const copy: BookingContactSnapshot = {
        name: contact.name ?? r.customerName, phone: contact.phone,
        allowZalo: contact.allowZalo === true, allowWhatsApp: contact.allowWhatsApp === true,
      };
      w.putContact(r.id, copy);
    }
    return { outcome: 'accepted', requestId: r.id };
  });
}

async function declineOffer(deps: InstantDeps, uid: string, offerId: string): Promise<{ outcome: 'declined'; requestId: string }> {
  return runInstant(deps, async (w) => {
    const first = await w.offer(uid, offerId);
    if (first === null) throw new DomainError('not_found');
    const r = await w.settle(first.requestId);
    if (r === null) throw new DomainError('not_found');
    const offer = await w.offer(uid, offerId);
    if (offer === null) throw new DomainError('not_found');
    if (offer.outcome === 'declined') return { outcome: 'declined', requestId: r.id };
    if (offer.outcome === 'expired' || offer.expiresAt.getTime() <= w.now.getTime()) throw new DomainError('offer_expired');
    if (offer.outcome === 'withdrawn') throw new DomainError(r.photographerId === null ? 'offer_expired' : 'already_assigned');
    if (offer.outcome !== 'pending') throw new DomainError('conflict');
    await w.closeOffer({ offerId, photographerId: uid }, 'declined');
    w.setRequest(endRoundIfDone({
      ...r,
      excludedIds: r.excludedIds.includes(uid) ? r.excludedIds : [...r.excludedIds, uid],
      offers: r.offers.map((row) => (row.offerId === offerId ? { ...row, outcome: 'declined' as const } : row)),
    }));
    return { outcome: 'declined', requestId: r.id };
  });
}

// ---------------------------------------------------------------- updateInstantJob

export const INSTANT_JOB_ACTIONS = ['start_route', 'arrive', 'start', 'finish', 'no_show'] as const;
export type InstantJobAction = (typeof INSTANT_JOB_ACTIONS)[number];
const isJobAction = (v: unknown): v is InstantJobAction => (INSTANT_JOB_ACTIONS as readonly unknown[]).includes(v);

/**
 * S14.03 steps of the assigned photographer: start the route (needs a position; the track starts),
 * arrive (within 200 m, or forced when the fix is worse than 100 m; the track goes), start the shoot
 * (`shootEndsAt` from the package), finish, and report the customer absent after 15 minutes
 * (`no_show_customer`; #140: rule recorded, no money; the photographer's reliability is untouched).
 */
export async function updateInstantJob(deps: InstantDeps, caller: InstantCaller, raw: unknown): Promise<{ status: InstantStatus }> {
  const d = instantInput(raw);
  const requestId = instantRequestId(d);
  const action = isJobAction(d.action) ? d.action : invalid();
  const location = instantLocation(d.location);
  const force = d.force === undefined ? false : typeof d.force === 'boolean' ? d.force : invalid();
  return runInstant(deps, async (w) => {
    const first = await w.request(requestId);
    if (first === null) throw new DomainError('not_found');
    if (first.photographerId !== caller.uid) throw new DomainError('permission_denied');
    const r = await w.settle(requestId);
    if (r === null) throw new DomainError('not_found');
    if (r.photographerId !== caller.uid) throw new DomainError('permission_denied');
    const now = w.now;
    let next: InstantRequest;
    switch (action) {
      case 'start_route': {
        const status = nextInstantStatus(r.status, 'start_route');
        if (location === undefined) return invalid();
        w.putTrack(r.id, {
          customerId: r.customerId, photographerId: caller.uid, active: true, lat: location.lat, lng: location.lng,
          accuracyM: location.accuracyM, heading: null, at: now,
        });
        next = { ...r, status, startedRouteAt: now };
        break;
      }
      case 'arrive': {
        const status = nextInstantStatus(r.status, 'arrive');
        if (location === undefined) return invalid();
        const near = distanceKm(location, r.meetPoint) * 1000 <= INSTANT.ARRIVE_RADIUS_M;
        const forced = !near && force && location.accuracyM > INSTANT.POOR_ACCURACY_M;
        if (!near && !forced) throw new DomainError('not_eligible');
        w.deleteTrack(r.id);
        next = { ...r, status, arrivedAt: now, forcedArrivalAccuracyM: forced ? location.accuracyM : null };
        break;
      }
      case 'start':
        next = { ...r, status: nextInstantStatus(r.status, 'start'), startedAt: now, shootEndsAt: new Date(now.getTime() + r.durationMin * MIN) };
        break;
      case 'finish':
        next = { ...r, status: nextInstantStatus(r.status, 'finish'), finishedAt: now };
        break;
      case 'no_show': {
        const q = quoteInstantNoShow(r, now);
        const status = nextInstantStatus(r.status, 'no_show');
        await w.freePresence(caller.uid, r.id);
        w.deleteTrack(r.id);
        next = { ...r, status, cancelRule: q.rule, refundPercent: q.refundPercent, feeVnd: q.feeVnd, cancelledAt: now };
        break;
      }
    }
    w.setRequest(next);
    return { status: next.status };
  });
}
