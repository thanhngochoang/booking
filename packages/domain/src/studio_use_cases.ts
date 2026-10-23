import { formatVnDate } from './booking_policy.js';
import { DomainError } from './errors.js';
import {
  canJoinAsMember,
  cooldownUntil,
  inCooldown,
  inviteExpiresAt,
  isStudio,
  MAX_PENDING_INVITES,
  maxMembers,
  quotaLeft,
  relationId,
  spendQuota,
  type DailyQuota,
  type StudioProfile,
  type StudioRelation,
} from './studio_membership.js';
import { notifyStudioInviteExpiring } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { fields, idField } from './studio_input.js';
import type { StudioDeps, StudioTx } from './studio_ports.js';

// S26 membership use cases (spec §3.2–3.3, plan #136 Decisions 1–7). Each runs in one transaction with
// every read before the first write; the daily quota is read and spent in the same transaction.

/** Every use case returns the relation before and after, for `membershipNotices`. */
export interface RelationChange {
  readonly before: StudioRelation | null;
  readonly after: StudioRelation;
}

export type MembershipNotice = 'invite' | 'join_request' | 'invite_accepted' | 'join_approved' | 'removed';

/** An invite is announced as expiring once, within this time of `expiresAt`. */
const EXPIRING_NOTICE_MS = 24 * 60 * 60 * 1000;

/** Relations sent to the sweep per run. */
export const MEMBERSHIP_SWEEP_LIMIT = 200;

// Relation ids are `{studioId}_{memberId}_{ms}`: longer than `isId` allows with 28-character uids. Ending in
// digits also keeps Firestore-reserved `__x__` ids out (invalid_argument, not a transport error).
const RELATION_ID = /^[A-Za-z0-9_-]{1,160}_\d{1,16}$/;

function relationIdField(raw: unknown): string {
  const v = fields(raw).relationId;
  if (typeof v !== 'string' || !RELATION_ID.test(v)) throw new DomainError('invalid_argument', 'relationId');
  return v;
}

function acceptField(raw: unknown): boolean {
  const v = fields(raw).accept;
  if (typeof v !== 'boolean') throw new DomainError('invalid_argument', 'accept');
  return v;
}

function requireStudio(p: StudioProfile | null): StudioProfile {
  if (p === null) throw new DomainError('not_found');
  if (!isStudio(p)) throw new DomainError('invalid_argument');
  return p;
}

function requireJoinable(p: StudioProfile | null): StudioProfile {
  if (p === null) throw new DomainError('not_found');
  if (!canJoinAsMember(p)) throw new DomainError('invalid_argument');
  return p;
}

/** One studio and one member per photographer; 7 days off after leaving. */
function assertFreeToJoin(member: StudioProfile, now: Date): void {
  if (member.studioId !== null) throw new DomainError('membership_conflict');
  if (inCooldown(member, now)) throw new DomainError('cooldown');
}

function assertQuota(q: DailyQuota | null, side: 'studio' | 'member', now: Date): void {
  if (quotaLeft(q, side, now) <= 0) throw new DomainError('rate_limited');
}

const isExpired = (r: StudioRelation, now: Date): boolean => Date.parse(r.expiresAt) <= now.getTime();

function expired(r: StudioRelation, nowIso: string): StudioRelation {
  return { ...r, status: 'expired', endedAt: nowIso, endedBy: 'system', version: r.version + 1 };
}

function openRelation(
  studio: StudioProfile,
  member: StudioProfile,
  initiatedBy: 'studio' | 'member',
  now: Date,
): StudioRelation {
  return {
    id: relationId(studio.uid, member.uid, now),
    studioId: studio.uid,
    memberId: member.uid,
    status: initiatedBy === 'studio' ? 'invited' : 'requested',
    initiatedBy,
    createdAt: now.toISOString(),
    expiresAt: inviteExpiresAt(now),
    respondedAt: null,
    joinedAt: null,
    endedAt: null,
    endedBy: null,
    expiringNotifiedAt: null,
    studioName: studio.name,
    studioAvatarUrl: studio.avatarUrl,
    memberName: member.name,
    memberAvatarUrl: member.avatarUrl,
    version: 1,
  };
}

/** Writes an active relation, the member's lock and the studio's count. */
function join(tx: StudioTx, rel: StudioRelation, nowIso: string): RelationChange {
  const after: StudioRelation = {
    ...rel,
    status: 'active',
    respondedAt: nowIso,
    joinedAt: nowIso,
    version: rel.version + 1,
  };
  tx.putRelation(after);
  tx.setMemberStudio(rel.memberId, { studioId: rel.studioId, studioJoinedAt: nowIso });
  tx.addMemberCount(rel.studioId, 1);
  return { before: rel, after };
}

/** Ends an active relation (left or removed) and starts the member's 7-day cooldown. */
function end(tx: StudioTx, rel: StudioRelation, by: 'member' | 'studio', now: Date): RelationChange {
  const nowIso = now.toISOString();
  const after: StudioRelation = {
    ...rel,
    status: by === 'member' ? 'left' : 'removed',
    endedAt: nowIso,
    endedBy: by,
    version: rel.version + 1,
  };
  tx.putRelation(after);
  tx.setMemberStudio(rel.memberId, { studioId: null, studioJoinedAt: null, studioCooldownUntil: cooldownUntil(now) });
  tx.addMemberCount(rel.studioId, -1);
  return { before: rel, after };
}

/** A new relation for a pair; refuses a second open one and an id already taken in the same millisecond. */
async function readNewPair(
  tx: StudioTx,
  studioId: string,
  memberId: string,
  now: Date,
): Promise<{ studio: StudioProfile; member: StudioProfile }> {
  const studio = requireStudio(await tx.getProfile(studioId));
  const member = requireJoinable(await tx.getProfile(memberId));
  const open = await tx.openRelationOf(studioId, memberId);
  const sameId = await tx.getRelation(relationId(studioId, memberId, now));
  if (open !== null || sameId !== null) throw new DomainError('conflict');
  return { studio, member };
}

/** Studio invites a photographer (`{memberId}`); counts a studio action. */
export async function inviteMember(deps: StudioDeps, studioId: string, raw: unknown): Promise<RelationChange> {
  const memberId = idField(raw, 'memberId');
  if (memberId === studioId) throw new DomainError('invalid_argument', 'memberId');
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const { studio, member } = await readNewPair(tx, studioId, memberId, now);
    const openInvites = await tx.countOpenInvites(studioId, now);
    const quota = await tx.getQuota(studioId);
    // ---- all reads above ----
    assertFreeToJoin(member, now);
    if (openInvites >= MAX_PENDING_INVITES || studio.memberCount + openInvites >= maxMembers(studio)) {
      throw new DomainError('studio_full');
    }
    assertQuota(quota, 'studio', now);
    const after = openRelation(studio, member, 'studio', now);
    tx.putRelation(after);
    tx.putQuota(studioId, spendQuota(quota, 'studio', now));
    return { before: null, after };
  });
}

/** Studio withdraws its own open invite (`{relationId}`); counts a studio action. */
export async function cancelInvite(deps: StudioDeps, studioId: string, raw: unknown): Promise<RelationChange> {
  const id = relationIdField(raw);
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const rel = await tx.getRelation(id);
    const quota = await tx.getQuota(studioId);
    // ---- all reads above ----
    if (rel === null) throw new DomainError('not_found');
    if (rel.studioId !== studioId) throw new DomainError('permission_denied');
    if (rel.status !== 'invited') throw new DomainError('conflict');
    assertQuota(quota, 'studio', now);
    const nowIso = now.toISOString();
    const after: StudioRelation = { ...rel, status: 'cancelled', endedAt: nowIso, endedBy: 'studio', version: rel.version + 1 };
    tx.putRelation(after);
    tx.putQuota(studioId, spendQuota(quota, 'studio', now));
    return { before: rel, after };
  });
}

/** Photographer asks to join a studio (`{studioId}`); counts a member action; no seat is held until approval. */
export async function requestToJoin(deps: StudioDeps, memberId: string, raw: unknown): Promise<RelationChange> {
  const studioId = idField(raw, 'studioId');
  if (studioId === memberId) throw new DomainError('invalid_argument', 'studioId');
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const { studio, member } = await readNewPair(tx, studioId, memberId, now);
    const quota = await tx.getQuota(memberId);
    // ---- all reads above ----
    assertFreeToJoin(member, now);
    assertQuota(quota, 'member', now);
    const after = openRelation(studio, member, 'member', now);
    tx.putRelation(after);
    tx.putQuota(memberId, spendQuota(quota, 'member', now));
    return { before: null, after };
  });
}

/** Photographer withdraws their own open request (`{relationId}`); counts a member action. */
export async function cancelJoinRequest(deps: StudioDeps, memberId: string, raw: unknown): Promise<RelationChange> {
  const id = relationIdField(raw);
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const rel = await tx.getRelation(id);
    const quota = await tx.getQuota(memberId);
    // ---- all reads above ----
    if (rel === null) throw new DomainError('not_found');
    if (rel.memberId !== memberId) throw new DomainError('permission_denied');
    if (rel.status !== 'requested') throw new DomainError('conflict');
    assertQuota(quota, 'member', now);
    const nowIso = now.toISOString();
    const after: StudioRelation = { ...rel, status: 'cancelled', endedAt: nowIso, endedBy: 'member', version: rel.version + 1 };
    tx.putRelation(after);
    tx.putQuota(memberId, spendQuota(quota, 'member', now));
    return { before: rel, after };
  });
}

type Answer = { outcome: 'ok'; change: RelationChange } | { outcome: 'expired' };

/** Records `expired` (the transaction commits) and then refuses `deadline_passed`. */
function answered(a: Answer): RelationChange {
  if (a.outcome === 'expired') throw new DomainError('deadline_passed');
  return a.change;
}

/** The invited photographer accepts or declines (`{relationId, accept}`); free of the daily quota. */
export async function respondInvite(deps: StudioDeps, memberId: string, raw: unknown): Promise<RelationChange> {
  const id = relationIdField(raw);
  const accept = acceptField(raw);
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const a = await deps.studios.runTransaction(async (tx): Promise<Answer> => {
    const rel = await tx.getRelation(id);
    if (rel === null) throw new DomainError('not_found');
    if (rel.memberId !== memberId) throw new DomainError('permission_denied');
    // The sweep may have expired it already: the same answer as finding it past expiresAt below.
    if (rel.status === 'expired') throw new DomainError('deadline_passed');
    if (rel.status !== 'invited') throw new DomainError('conflict');
    const member = await tx.getProfile(memberId);
    const studio = await tx.getProfile(rel.studioId);
    // ---- all reads above ----
    if (member === null || studio === null) throw new DomainError('not_found');
    if (isExpired(rel, now)) {
      tx.putRelation(expired(rel, nowIso));
      return { outcome: 'expired' };
    }
    if (!accept) {
      const after: StudioRelation = {
        ...rel,
        status: 'declined',
        respondedAt: nowIso,
        endedAt: nowIso,
        endedBy: 'member',
        version: rel.version + 1,
      };
      tx.putRelation(after);
      return { outcome: 'ok', change: { before: rel, after } };
    }
    assertFreeToJoin(member, now);
    // The invite already holds its seat, so only the members count.
    if (studio.memberCount >= maxMembers(studio)) throw new DomainError('studio_full');
    return { outcome: 'ok', change: join(tx, rel, nowIso) };
  });
  return answered(a);
}

/** The studio approves (a studio action, cap checked) or declines (free) a request (`{relationId, accept}`). */
export async function respondJoinRequest(deps: StudioDeps, studioId: string, raw: unknown): Promise<RelationChange> {
  const id = relationIdField(raw);
  const accept = acceptField(raw);
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const a = await deps.studios.runTransaction(async (tx): Promise<Answer> => {
    const rel = await tx.getRelation(id);
    if (rel === null) throw new DomainError('not_found');
    if (rel.studioId !== studioId) throw new DomainError('permission_denied');
    if (rel.status === 'expired') throw new DomainError('deadline_passed');
    if (rel.status !== 'requested') throw new DomainError('conflict');
    const member = await tx.getProfile(rel.memberId);
    const studio = await tx.getProfile(studioId);
    const openInvites = await tx.countOpenInvites(studioId, now);
    const quota = await tx.getQuota(studioId);
    // ---- all reads above ----
    if (member === null || studio === null) throw new DomainError('not_found');
    if (isExpired(rel, now)) {
      tx.putRelation(expired(rel, nowIso));
      return { outcome: 'expired' };
    }
    if (!accept) {
      const after: StudioRelation = {
        ...rel,
        status: 'declined',
        respondedAt: nowIso,
        endedAt: nowIso,
        endedBy: 'studio',
        version: rel.version + 1,
      };
      tx.putRelation(after);
      return { outcome: 'ok', change: { before: rel, after } };
    }
    assertFreeToJoin(member, now);
    if (studio.memberCount + openInvites >= maxMembers(studio)) throw new DomainError('studio_full');
    assertQuota(quota, 'studio', now);
    const change = join(tx, rel, nowIso);
    tx.putQuota(studioId, spendQuota(quota, 'studio', now));
    return { outcome: 'ok', change };
  });
  return answered(a);
}

/** Reads the member's active relation, open studio bookings and open spot schedules; refuses `member_busy`. */
async function readActive(
  tx: StudioTx,
  member: StudioProfile | null,
  studioId: string | null,
  now: Date,
): Promise<StudioRelation> {
  if (member === null || studioId === null) throw new DomainError('not_found');
  // The caller is the member (studioId is theirs) or a studio removing someone who is not its member.
  if (member.studioId !== studioId) throw new DomainError('permission_denied');
  const rel = await tx.openRelationOf(studioId, member.uid);
  if (rel === null || rel.status !== 'active') throw new DomainError('not_found');
  if ((await tx.countOpenAssignments(studioId, member.uid)) > 0) throw new DomainError('member_busy');
  // #194 Decision 7: a member named on an open spot schedule with a day still ahead holds that day for the studio.
  if ((await tx.countOpenSpotSchedules(studioId, member.uid, formatVnDate(now))) > 0) {
    throw new DomainError('member_busy');
  }
  return rel;
}

/** A member leaves their studio; counts a member action; 7 days before joining any studio. */
export async function leaveStudio(deps: StudioDeps, memberId: string): Promise<RelationChange> {
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const member = await tx.getProfile(memberId);
    const rel = await readActive(tx, member, member?.studioId ?? null, now);
    const quota = await tx.getQuota(memberId);
    // ---- all reads above ----
    assertQuota(quota, 'member', now);
    const change = end(tx, rel, 'member', now);
    tx.putQuota(memberId, spendQuota(quota, 'member', now));
    return change;
  });
}

/** The studio removes a member (`{memberId}`); counts a studio action; the member waits 7 days. */
export async function removeMember(deps: StudioDeps, studioId: string, raw: unknown): Promise<RelationChange> {
  const memberId = idField(raw, 'memberId');
  const now = deps.clock.now();
  return deps.studios.runTransaction(async (tx) => {
    const member = await tx.getProfile(memberId);
    const rel = await readActive(tx, member, studioId, now);
    const quota = await tx.getQuota(studioId);
    // ---- all reads above ----
    assertQuota(quota, 'studio', now);
    const change = end(tx, rel, 'studio', now);
    tx.putQuota(studioId, spendQuota(quota, 'studio', now));
    return change;
  });
}

/**
 * bookingClock step (Decision 20c), idempotent: invites and requests past `expiresAt` become `expired`;
 * invites within 24 h of it get the one-time "invite expiring" notice and are then marked `expiringNotifiedAt`.
 * With `notify`, the notice is sent BEFORE the mark is committed: a failed notice leaves the invite unmarked, so
 * the next run sends it again (#138's dedupe key turns a resend after a lost mark into a duplicate). A relation
 * whose transaction fails is counted in `failed` and never stops the batch; the next run finds it again.
 */
export async function runMembershipSweeps(
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<{ expired: RelationChange[]; expiring: StudioRelation[]; notifyFailed: number; failed: number }> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  // The port already narrows to work to do; filtering again keeps a loose adapter from opening no-op transactions.
  const due = (await deps.studios.dueRelations(now, MEMBERSHIP_SWEEP_LIMIT)).filter(
    (r) => sweepActionOf(r, now) !== null,
  );
  const out: { expired: RelationChange[]; expiring: StudioRelation[]; notifyFailed: number; failed: number } = {
    expired: [],
    expiring: [],
    notifyFailed: 0,
    failed: 0,
  };
  for (const d of due) {
    if (notify && sweepActionOf(d, now) === 'expiring') {
      try {
        await notifyStudioInviteExpiring(notify, { photographerId: d.memberId, studioId: d.studioId, inviteId: d.id });
      } catch {
        out.notifyFailed += 1;
        continue;
      }
    }
    let change: RelationChange | null;
    try {
      change = await deps.studios.runTransaction(async (tx): Promise<RelationChange | null> => {
        const rel = await tx.getRelation(d.id);
        const action = rel === null ? null : sweepActionOf(rel, now);
        if (rel === null || action === null) return null;
        const after: StudioRelation =
          action === 'expire' ? expired(rel, nowIso) : { ...rel, expiringNotifiedAt: nowIso, version: rel.version + 1 };
        tx.putRelation(after);
        return { before: rel, after };
      });
    } catch {
      out.failed += 1;
      continue;
    }
    if (change === null) continue;
    if (change.after.status === 'expired') out.expired.push(change);
    else out.expiring.push(change.after);
  }
  return out;
}

/** What the sweep does to a relation now: expire it, mark its expiring notice, or nothing. */
export function sweepActionOf(r: StudioRelation, now: Date): 'expire' | 'expiring' | null {
  if (r.status !== 'invited' && r.status !== 'requested') return null;
  if (isExpired(r, now)) return 'expire';
  const soon = Date.parse(r.expiresAt) <= now.getTime() + EXPIRING_NOTICE_MS;
  return r.status === 'invited' && r.expiringNotifiedAt === null && soon ? 'expiring' : null;
}

/** Which #138 hook the callable adapter calls after commit (the expiring notice comes from the sweep). */
export function membershipNotices(c: RelationChange): MembershipNotice[] {
  const from = c.before?.status ?? null;
  const to = c.after.status;
  if (from === null && to === 'invited') return ['invite'];
  if (from === null && to === 'requested') return ['join_request'];
  if (from === 'invited' && to === 'active') return ['invite_accepted'];
  if (from === 'requested' && to === 'active') return ['join_approved'];
  if (from === 'active' && to === 'removed') return ['removed'];
  return [];
}
