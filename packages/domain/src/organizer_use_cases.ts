/**
 * Organizer use cases (S30, plan #223 Decisions 2–5): become an organizer, claim a spot (staff review),
 * edit a managed spot, residents with waivers, gate staff, and the staff tools (access, suspension, the
 * residents sweep). Notifications are sent after the transaction commits and never fail the call.
 */

import { formatVnDate, isDateString, isTimeString } from './booking_policy.js';
import { graphemeCount } from './booking_requests.js';
import { DomainError, type ErrorCode } from './errors.js';
import type { EventCaller } from './event.js';
import { cancelEventWithRefunds } from './event_payments.js';
import { isId } from './ids.js';
import {
  notifyGateStaffInvited,
  notifySpotClaimApproved,
  notifySpotClaimRejected,
  notifySpotResidentAdded,
} from './notification_hooks.js';
import {
  CLAIM_NOTE_MAX,
  CLAIM_PROOFS_MAX,
  CLAIM_PROOFS_MIN,
  CLAIM_REASON_SPOT_MANAGED,
  MAX_GATE_STAFF,
  MAX_RESIDENTS,
  ORGANIZER_BIO_MAX,
  ORGANIZER_NAME_MAX,
  ORGANIZER_NAME_MIN,
  holdsGateSeat,
  inviteOpen,
  validateAccess,
  type GateStaff,
  type Organizer,
  type Resident,
  type SpotClaim,
  type SpotProposal,
} from './organizer.js';
import { ANY_ORGANIZER, type OrganizerDeps, type SuspendOrganizerDeps } from './organizer_ports.js';
import {
  SPOT_DESCRIPTION_MAX,
  SPOT_NAME_MAX,
  SPOT_NAME_MIN,
  SPOT_TIP_MAX,
  SPOT_TIPS_MAX,
  type Spot,
  type SpotCover,
  type SpotOpenHours,
} from './spot.js';

const PROPOSAL_ADDRESS_MAX = 200;
const PROOF_PATH_MAX = 300;
/** Rows deleted per `expireResidents` transaction. */
const EXPIRE_BATCH = 200;

function fail(code: ErrorCode, field?: string): never {
  throw new DomainError(code, field);
}

const objectOf = (raw: unknown): Record<string, unknown> =>
  raw !== null && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : fail('invalid_argument');

const idAt = (r: Record<string, unknown>, field: string): string => (isId(r[field]) ? r[field] : fail('invalid_argument', field));

const boolAt = (r: Record<string, unknown>, field: string): boolean =>
  typeof r[field] === 'boolean' ? r[field] : fail('invalid_argument', field);

/** Optional trimmed text of at most `max` graphemes ('' when absent). */
function textAt(r: Record<string, unknown>, field: string, max: number): string {
  const v = r[field] ?? '';
  if (typeof v !== 'string') fail('invalid_argument', field);
  const t = v.trim();
  return graphemeCount(t) > max ? fail('invalid_argument', field) : t;
}

/** Runs a post-commit notification; a failure is reported, never thrown (the write already happened). */
async function safely(deps: OrganizerDeps, uid: string, send: () => Promise<unknown>): Promise<void> {
  try {
    await send();
  } catch (e) {
    deps.notify.onPushError?.(uid, e);
  }
}

async function assertStaff(deps: OrganizerDeps, actorId: string): Promise<void> {
  if (!(await deps.people.isStaff(actorId))) fail('permission_denied');
}

async function activeOrganizer(deps: OrganizerDeps, uid: string): Promise<Organizer> {
  const o = await deps.organizers.getOrganizer(uid);
  return o !== null && o.status === 'active' ? o : fail('permission_denied');
}

const nowIso = (deps: OrganizerDeps): string => deps.clock.now().toISOString();

// ── Organizer profile (S30.01) ───────────────────────────────────────────────────────────────

/**
 * Creates `organizers/{uid}` (active) or updates its name, bio and avatar. Needs a verified phone
 * (`phone_required`); a suspended organizer cannot come back by itself (`conflict`).
 */
export async function becomeOrganizer(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<Organizer> {
  const r = objectOf(raw);
  const name = typeof r.name === 'string' ? r.name.trim() : fail('invalid_argument', 'name');
  const n = graphemeCount(name);
  if (n < ORGANIZER_NAME_MIN || n > ORGANIZER_NAME_MAX) fail('invalid_argument', 'name');
  const bio = textAt(r, 'bio', ORGANIZER_BIO_MAX);
  const avatar = r.avatarUrl;
  if (avatar !== undefined && avatar !== null && typeof avatar !== 'string') fail('invalid_argument', 'avatarUrl');

  if (!(await deps.people.phoneVerified(callerId))) fail('phone_required');
  const [businessVerified, payoutAccountOk] = await Promise.all([
    deps.people.businessVerified(callerId),
    deps.people.payoutAccountOk(callerId),
  ]);

  return deps.organizers.runTransaction(async (tx) => {
    const at = nowIso(deps);
    const existing = await tx.getOrganizer(callerId);
    if (existing?.status === 'suspended') fail('conflict');
    const avatarUrl = avatar === undefined ? (existing?.avatarUrl ?? null) : (avatar as string | null);
    const o: Organizer = existing
      ? { ...existing, name, bio, avatarUrl, phoneVerified: true, businessVerified, payoutAccountOk, updatedAt: at }
      : {
          id: callerId, name, bio, avatarUrl, status: 'active', phoneVerified: true, businessVerified, payoutAccountOk,
          managedSpotIds: [], createdAt: at, updatedAt: at,
        };
    tx.putOrganizer(o);
    return o;
  });
}

// ── Spot claims (S30.02, staff review) ───────────────────────────────────────────────────────

/** 1–3 Storage paths under the claimant's own `spot_claims/{uid}/` folder (Decision 4). */
function proofPathsOf(raw: unknown, uid: string): string[] {
  if (!Array.isArray(raw) || raw.length < CLAIM_PROOFS_MIN || raw.length > CLAIM_PROOFS_MAX) fail('invalid_argument', 'proofPaths');
  const prefix = `spot_claims/${uid}/`;
  const paths = (raw as unknown[]).map((p) =>
    typeof p === 'string' && p.startsWith(prefix) && p.length <= PROOF_PATH_MAX && !p.split('/').includes('..')
      && p.length > prefix.length
      ? p
      : fail('invalid_argument', 'proofPaths'));
  return [...new Set(paths)];
}

function proposalOf(raw: unknown): SpotProposal {
  const p = raw !== null && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : fail('invalid_argument', 'proposal');
  const name = typeof p.name === 'string' ? p.name.trim() : '';
  const address = typeof p.address === 'string' ? p.address.trim() : '';
  const n = graphemeCount(name);
  const a = graphemeCount(address);
  if (n < SPOT_NAME_MIN || n > SPOT_NAME_MAX || a === 0 || a > PROPOSAL_ADDRESS_MAX) fail('invalid_argument', 'proposal');
  return { name, address };
}

/**
 * An active organizer asks to manage a spot (or proposes a new one with `spotId` null and a `proposal`).
 * One pending claim per spot and organizer (`limit_exceeded`); a managed spot is `spot_managed`.
 */
export async function claimSpot(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<{ claimId: string }> {
  const r = objectOf(raw);
  const spotId = r.spotId === undefined || r.spotId === null ? null : idAt(r, 'spotId');
  const proposal = spotId === null ? proposalOf(r.proposal) : null;
  const proofPaths = proofPathsOf(r.proofPaths, callerId);
  const note = textAt(r, 'note', CLAIM_NOTE_MAX);

  return deps.organizers.runTransaction(async (tx) => {
    const org = await tx.getOrganizer(callerId);
    if (org === null || org.status !== 'active') fail('permission_denied');
    if (spotId !== null) {
      const spot = await tx.getSpot(spotId);
      if (spot === null) fail('not_found');
      if (spot.status === 'archived') fail('spot_archived');
      if (spot.managedBy !== null) fail('spot_managed');
    }
    if ((await tx.pendingClaimsOf(spotId, callerId)).length > 0) fail('limit_exceeded');
    const claim: SpotClaim = {
      id: deps.ids.newId(), spotId, proposal, organizerId: callerId, status: 'pending', proofPaths, note,
      reason: null, createdAt: nowIso(deps), reviewedAt: null, reviewedBy: null,
    };
    tx.putClaim(claim);
    return { claimId: claim.id };
  });
}

/**
 * Staff approve or reject a pending claim. Approval sets `spot.managedBy` only while it is still null
 * (`spot_managed` otherwise, nothing written: Review Focus 5), adds the spot to the organizer and rejects
 * the spot's other pending claims with reason `spot_managed`.
 */
export async function reviewSpotClaim(deps: OrganizerDeps, actorId: string, raw: unknown): Promise<SpotClaim> {
  await assertStaff(deps, actorId);
  const r = objectOf(raw);
  const claimId = idAt(r, 'claimId');
  const approve = boolAt(r, 'approve');
  const reasonText = textAt(r, 'reason', CLAIM_NOTE_MAX);
  const reason = reasonText === '' ? null : reasonText;

  const out = await deps.organizers.runTransaction(async (tx) => {
    const at = nowIso(deps);
    const claim = await tx.getClaim(claimId);
    if (!claim || claim.status !== 'pending') fail('not_found');
    const spot = claim.spotId ? await tx.getSpot(claim.spotId) : null;
    const org = await tx.getOrganizer(claim.organizerId);
    if (!org) fail('not_found');
    const others = claim.spotId ? await tx.pendingClaimsOf(claim.spotId, ANY_ORGANIZER) : [];
    const autoRejected: SpotClaim[] = [];
    if (approve) {
      // A proposal is approved only after staff added the spot and set claim.spotId.
      if (!spot) fail('invalid_argument', 'spotId');
      if (spot.status === 'archived') fail('spot_archived');
      if (spot.managedBy !== null) fail('spot_managed');
      if (org.status !== 'active') fail('conflict');
      tx.putSpot({ ...spot, managedBy: org.id, updatedAt: at, updatedBy: actorId });
      tx.putOrganizer({ ...org, managedSpotIds: [...new Set([...org.managedSpotIds, spot.id])], updatedAt: at });
      for (const o of others) {
        if (o.id === claim.id) continue;
        const rejected: SpotClaim = { ...o, status: 'rejected', reason: CLAIM_REASON_SPOT_MANAGED, reviewedAt: at, reviewedBy: actorId };
        tx.putClaim(rejected);
        autoRejected.push(rejected);
      }
    }
    const reviewed: SpotClaim = { ...claim, status: approve ? 'approved' : 'rejected', reason, reviewedAt: at, reviewedBy: actorId };
    tx.putClaim(reviewed);
    return { reviewed, autoRejected, spotName: spot?.name ?? claim.proposal?.name ?? null };
  });

  const { reviewed, autoRejected, spotName } = out;
  if (reviewed.status === 'approved' && reviewed.spotId !== null) {
    const spotId = reviewed.spotId;
    await safely(deps, reviewed.organizerId, () => notifySpotClaimApproved(deps.notify, {
      organizerId: reviewed.organizerId, claimId: reviewed.id, spotId, spotName: spotName ?? '',
    }));
  } else {
    await safely(deps, reviewed.organizerId, () => notifySpotClaimRejected(deps.notify, {
      organizerId: reviewed.organizerId, claimId: reviewed.id, spotName: reviewed.spotId === null ? null : spotName, reason,
    }));
  }
  for (const c of autoRejected) {
    await safely(deps, c.organizerId, () => notifySpotClaimRejected(deps.notify, {
      organizerId: c.organizerId, claimId: c.id, spotName, reason: CLAIM_REASON_SPOT_MANAGED,
    }));
  }
  return reviewed;
}

// ── Managed spot (S30.03) ────────────────────────────────────────────────────────────────────

/** The fields a spot manager may change; name, point, radius and season stay staff-only (spec §3.2). */
const MANAGED_SPOT_FIELDS = new Set(['spotId', 'description', 'tips', 'cover', 'openHours', 'access']);

function openHoursOf(raw: unknown): SpotOpenHours | null {
  if (raw === null) return null;
  const h = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>) : fail('invalid_argument', 'openHours');
  if (!isTimeString(h.start) || !isTimeString(h.end) || h.end <= h.start) fail('invalid_argument', 'openHours');
  return { start: h.start as string, end: h.end as string };
}

function tipsOf(raw: unknown): string[] {
  if (!Array.isArray(raw) || raw.length > SPOT_TIPS_MAX) fail('invalid_argument', 'tips');
  return (raw as unknown[]).map((t) => {
    if (typeof t !== 'string') fail('invalid_argument', 'tips');
    const s = String(t).trim();
    return s === '' || graphemeCount(s) > SPOT_TIP_MAX ? fail('invalid_argument', 'tips') : s;
  });
}

/** A cover the Functions adapter made from the manager's upload (`spots/{spotId}/…`). */
function coverOf(raw: unknown, spotId: string): SpotCover | null {
  if (raw === null) return null;
  const c = raw !== null && typeof raw === 'object' ? (raw as Record<string, unknown>) : fail('invalid_argument', 'cover');
  if (typeof c.url !== 'string' || typeof c.cardUrl !== 'string' || typeof c.path !== 'string'
    || !c.path.startsWith(`spots/${spotId}/`) || c.path.split('/').includes('..')) {
    fail('invalid_argument', 'cover');
  }
  return { url: c.url as string, cardUrl: c.cardUrl as string, path: c.path as string };
}

/**
 * The spot's manager edits description, tips, cover, opening hours and access (`source: organizer`).
 * Any other input field (name, point, radiusM, seasonMonths, …) is `invalid_argument` with that field.
 */
export async function updateManagedSpot(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<Spot> {
  const r = objectOf(raw);
  for (const k of Object.keys(r)) if (!MANAGED_SPOT_FIELDS.has(k)) fail('invalid_argument', k);
  const spotId = idAt(r, 'spotId');
  const now = deps.clock.now();
  const patch: { -readonly [K in keyof Spot]?: Spot[K] } = {};
  if (r.description !== undefined) patch.description = textAt(r, 'description', SPOT_DESCRIPTION_MAX);
  if (r.tips !== undefined) patch.tips = tipsOf(r.tips);
  if (r.cover !== undefined) patch.cover = coverOf(r.cover, spotId);
  if (r.openHours !== undefined) patch.openHours = openHoursOf(r.openHours);
  if (r.access !== undefined) patch.access = r.access === null ? null : validateAccess(r.access, 'organizer', now);

  return deps.organizers.runTransaction(async (tx) => {
    const spot = await tx.getSpot(spotId);
    if (spot === null) fail('not_found');
    const org = await tx.getOrganizer(callerId);
    if (spot.managedBy !== callerId || org === null || org.status !== 'active') fail('not_spot_manager');
    if (spot.status === 'archived') fail('spot_archived');
    const updated: Spot = { ...spot, ...patch, updatedAt: now.toISOString(), updatedBy: callerId };
    tx.putSpot(updated);
    return updated;
  });
}

// ── Residents (S30.03-residents) ─────────────────────────────────────────────────────────────

/** The spot must exist, be active and be managed by `callerId` (an active organizer). */
function assertManages(spot: Spot | null, org: Organizer | null, callerId: string): Spot {
  if (spot === null) fail('not_found');
  if (spot.managedBy !== callerId || org === null || org.status !== 'active') fail('not_spot_manager');
  if (spot.status === 'archived') fail('spot_archived');
  return spot;
}

/**
 * Adds or edits a resident photographer of a managed spot. Only providers that accept orders
 * (`not_accepting_orders`; no provider profile is `not_found`), at most 50 per spot. A new resident
 * gets `spot_resident_added`.
 */
export async function saveResident(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<Resident> {
  const r = objectOf(raw);
  const spotId = idAt(r, 'spotId');
  const providerId = idAt(r, 'providerId');
  const waivesProvider = boolAt(r, 'waivesProvider');
  const waivesGuests = boolAt(r, 'waivesGuests');
  const maxGuests = r.maxGuests === undefined || r.maxGuests === null
    ? null
    : Number.isSafeInteger(r.maxGuests) && (r.maxGuests as number) >= 1 && (r.maxGuests as number) <= 100
      ? (r.maxGuests as number)
      : fail('invalid_argument', 'maxGuests');
  const today = formatVnDate(deps.clock.now());
  const validUntil = r.validUntil === undefined || r.validUntil === null
    ? null
    : isDateString(r.validUntil) && r.validUntil >= today
      ? r.validUntil
      : fail('invalid_argument', 'validUntil');

  const profile = await deps.providers.orderProfile(providerId);
  if (profile === null) fail('not_found');
  if (!profile.acceptsOrders) fail('not_accepting_orders');
  if (deps.blocks && (await deps.blocks.isBlockedEitherWay(callerId, providerId))) fail('blocked');

  const out = await deps.organizers.runTransaction(async (tx) => {
    const org = await tx.getOrganizer(callerId);
    const spot = assertManages(await tx.getSpot(spotId), org, callerId);
    const rows = await tx.residentsOf(spotId);
    const existing = rows.find((x) => x.providerId === providerId) ?? null;
    if (existing === null && rows.length >= MAX_RESIDENTS) fail('limit_exceeded');
    const at = nowIso(deps);
    const resident: Resident = {
      providerId, waivesProvider, waivesGuests, maxGuests, validUntil,
      addedAt: existing?.addedAt ?? at, addedBy: existing?.addedBy ?? callerId,
    };
    tx.putResident(spotId, resident);
    return { resident, added: existing === null, spot, org };
  });

  if (out.added) {
    await safely(deps, providerId, () => notifySpotResidentAdded(deps.notify, {
      providerId, organizerId: callerId, organizerName: out.org?.name ?? '', organizerAvatarUrl: out.org?.avatarUrl ?? null,
      spotId, spotName: out.spot.name, addedAt: out.resident.addedAt,
    }));
  }
  return out.resident;
}

/** The spot's manager removes a resident, or the provider leaves the list themself. Removing nobody is a no-op. */
export async function removeResident(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<void> {
  const r = objectOf(raw);
  const spotId = idAt(r, 'spotId');
  const providerId = idAt(r, 'providerId');
  await deps.organizers.runTransaction(async (tx) => {
    const spot = await tx.getSpot(spotId);
    if (spot === null) fail('not_found');
    if (callerId !== providerId && spot.managedBy !== callerId) fail('not_spot_manager');
    const existing = await tx.getResident(spotId, providerId);
    if (existing !== null) tx.deleteResident(spotId, providerId);
  });
}

/** Daily (`rankSpots`): deletes residents whose `validUntil` is before `today`; returns how many went. */
export async function expireResidents(deps: OrganizerDeps, today: string): Promise<number> {
  let removed = 0;
  for (;;) {
    const due = await deps.organizers.expiredResidents(today, EXPIRE_BATCH);
    if (due.length === 0) return removed;
    const n = await deps.organizers.runTransaction(async (tx) => {
      const rows = await Promise.all(due.map(async (d) => ({ d, r: await tx.getResident(d.spotId, d.providerId) })));
      const stale = rows.filter(({ r }) => r !== null && r.validUntil !== null && r.validUntil < today);
      for (const { d } of stale) tx.deleteResident(d.spotId, d.providerId);
      return stale.length;
    });
    removed += n;
    if (n === 0 || due.length < EXPIRE_BATCH) return removed;
  }
}

// ── Gate staff (S30.06) ──────────────────────────────────────────────────────────────────────

/**
 * Invites an account (phone or `@username`) as gate staff. At most 10 seats (active staff and open
 * invites, `limit_exceeded`); an active staff is a no-op; an expired, declined or removed one is invited again.
 */
export async function inviteGateStaff(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<GateStaff> {
  const r = objectOf(raw);
  const target = typeof r.target === 'string' ? r.target.trim() : '';
  if (target === '' || target.length > 64) fail('invalid_argument', 'target');
  const org = await activeOrganizer(deps, callerId);
  const who = await deps.people.lookup(target);
  if (who === null) fail('not_found');
  if (who.uid === callerId) fail('invalid_argument', 'target');

  const out = await deps.organizers.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const rows = await tx.gateStaffOf(callerId);
    const existing = rows.find((g) => g.staffUid === who.uid) ?? null;
    if (existing !== null && holdsGateSeat(existing, now)) return { g: existing, sent: false };
    if (rows.filter((g) => holdsGateSeat(g, now)).length >= MAX_GATE_STAFF) fail('limit_exceeded');
    const g: GateStaff = { staffUid: who.uid, status: 'invited', invitedAt: now.toISOString(), respondedAt: null };
    tx.putGateStaff(callerId, g);
    return { g, sent: true };
  });

  if (out.sent) {
    await safely(deps, who.uid, () => notifyGateStaffInvited(deps.notify, {
      staffUid: who.uid, organizerId: callerId, organizerName: org.name, organizerAvatarUrl: org.avatarUrl, invitedAt: out.g.invitedAt,
    }));
  }
  return out.g;
}

/** The invitee accepts (→ active) or declines (→ removed) within 72 hours (`deadline_passed` after). */
export async function respondGateStaff(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<GateStaff> {
  const r = objectOf(raw);
  const organizerId = idAt(r, 'organizerId');
  const accept = boolAt(r, 'accept');
  return deps.organizers.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const g = (await tx.gateStaffOf(organizerId)).find((x) => x.staffUid === callerId);
    if (!g || g.status !== 'invited') fail('not_found');
    if (!inviteOpen(g, now)) fail('deadline_passed');
    const out: GateStaff = { ...g, status: accept ? 'active' : 'removed', respondedAt: now.toISOString() };
    tx.putGateStaff(organizerId, out);
    return out;
  });
}

/** The organizer removes a staff member or withdraws an invite; their scans are refused from now on. */
export async function removeGateStaff(deps: OrganizerDeps, callerId: string, raw: unknown): Promise<void> {
  const r = objectOf(raw);
  const staffUid = idAt(r, 'staffUid');
  await deps.organizers.runTransaction(async (tx) => {
    const g = (await tx.gateStaffOf(callerId)).find((x) => x.staffUid === staffUid);
    if (!g || g.status === 'removed') fail('not_found');
    tx.putGateStaff(callerId, { ...g, status: 'removed' });
  });
}

// ── Staff tools (CLI) ────────────────────────────────────────────────────────────────────────

/** Staff set (or clear with null) a spot's reference entry fees (`source: staff`), managed or not. */
export async function setSpotAccess(deps: OrganizerDeps, actorId: string, raw: unknown): Promise<Spot> {
  await assertStaff(deps, actorId);
  const r = objectOf(raw);
  const spotId = idAt(r, 'spotId');
  const now = deps.clock.now();
  const access = r.access === null ? null : validateAccess(r.access, 'staff', now);
  return deps.organizers.runTransaction(async (tx) => {
    const spot = await tx.getSpot(spotId);
    if (spot === null) fail('not_found');
    const updated: Spot = { ...spot, access, updatedAt: now.toISOString(), updatedBy: actorId };
    tx.putSpot(updated);
    return updated;
  });
}

/**
 * Staff suspend an organizer (Decision 2, Needs the owner 3): status `suspended`, then every open event it
 * hosts is cancelled through `cancelEventWithRefunds` (100% refunds), each in its own transactions. Events
 * already ended are left to the event clock. Returns how many events were cancelled.
 */
export async function suspendOrganizer(
  deps: SuspendOrganizerDeps,
  actorId: string,
  raw: unknown,
  onError: (eventId: string, error: unknown) => void = () => undefined,
): Promise<{ cancelledEvents: number }> {
  await assertStaff(deps, actorId);
  const r = objectOf(raw);
  const organizerId = idAt(r, 'organizerId');
  const events = await deps.organizers.runTransaction(async (tx) => {
    const org = await tx.getOrganizer(organizerId);
    if (org === null) fail('not_found');
    const open = await tx.openEventsOf(organizerId);
    if (org.status !== 'suspended') tx.putOrganizer({ ...org, status: 'suspended', updatedAt: nowIso(deps) });
    return open;
  });

  const staff: EventCaller = { uid: actorId, staffRole: 'admin' };
  const now = deps.clock.now().getTime();
  let cancelledEvents = 0;
  for (const ev of events) {
    if (ev.endAt !== null && ev.endAt.getTime() <= now) continue;
    try {
      await cancelEventWithRefunds(deps.eventPayments, staff, { eventId: ev.id });
      cancelledEvents += 1;
    } catch (e) {
      onError(ev.id, e);
    }
  }
  return { cancelledEvents };
}
