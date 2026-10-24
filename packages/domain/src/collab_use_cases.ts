/**
 * S27 studio ↔ collaborator relationships (spec §4; plan #151 Decisions 4, 5, 12, 16). Each use case reads
 * everything first, then writes, in one `RecruitTx`; notifications go through #138's hooks after the commit
 * and never fail the use case. Counted actions: the studio's invite, cancel and end (≤ 10 per VN day, shared
 * with answering applications), the collaborator's end (≤ 5); answering an invite is free.
 */

import { isId } from './ids.js';
import { notifyCollabInvite, notifyCollabInviteResult } from './notification_hooks.js';
import { collabChatId } from './open_collab_chat.js';
import type { IdGenerator } from './ports.js';
import {
  isRecruitBlocked,
  isValidRecruitFee,
  recruitDaysAfter,
  STUDIO_COLLAB_DAILY_ACTIONS,
  takeRecruitDaily,
  type RecruitCounters,
} from './recruit.js';
import type { ProviderFacts, RecruitDeps, RecruitTx } from './recruit_ports.js';
import { decrement, fail, objectOf, safely } from './recruit_shared.js';
import {
  COLLAB_INVITE_TTL_DAYS,
  COLLABORATOR_DAILY_ACTIONS,
  collabPairOf,
  collabPartyOf,
  collaborationId,
  collaboratorLimit,
  inCollabCooldown,
  isCollabStudio,
  isCollaboratorAccount,
  isOpenCollab,
  isStaleInvite,
  MAX_COLLABS_PER_COLLABORATOR,
  MAX_PENDING_COLLAB_INVITES,
  type Collaboration,
} from './studio_collaboration.js';

/** `defaultFee`: absent or null = none; otherwise 1.000–100.000.000 in steps of 1.000. */
function defaultFeeOf(r: Record<string, unknown>): number | null {
  const v = r.defaultFee;
  if (v === undefined || v === null) return null;
  return isValidRecruitFee(v) ? v : fail('invalid_argument', 'defaultFee');
}

const invitedAtOf = (c: Collaboration): string => c.createdAt.toISOString();

function notifyInviteResult(deps: RecruitDeps, c: Collaboration, outcome: 'accepted' | 'declined' | 'expired'): Promise<void> {
  return safely(deps, c.studioId, () => notifyCollabInviteResult(deps.notify,
    { studioId: c.studioId, collaboratorId: c.collaboratorId, invitedAt: invitedAtOf(c), outcome }));
}

/** A terminal status written by an answer, a cancel, an expiry or an end. */
function closed(c: Collaboration, status: 'declined' | 'cancelled' | 'expired' | 'ended',
  by: 'studio' | 'collaborator' | 'system', now: Date): Collaboration {
  return { ...c, status, endedAt: now, endedBy: by, updatedAt: now };
}

/** Both sides verified (`ProviderOrderGate`) and neither blocked the other (#198). */
async function assertCanCollaborate(deps: RecruitDeps, studioId: string, collaboratorId: string): Promise<void> {
  if (!(await deps.orders.acceptsOrders(studioId)) || !(await deps.orders.acceptsOrders(collaboratorId))) {
    fail('not_accepting_orders');
  }
  if (await deps.blocks.isBlockedEitherWay(studioId, collaboratorId)) fail('blocked');
}

/**
 * The single place a pair becomes `active` (accepting an invite or a collaborator application). Reads the
 * main collaboration document, the studio's and the collaborator's counters and the collaborator's S26
 * membership, then refuses `conflict` (already active), `membership_conflict` (active member of this studio),
 * `collab_full` (the studio's 5/50 or the collaborator's 5). A pending invite of the pair is answered in
 * place (its slot freed); any other earlier record is archived to history. Writes the collaboration and both
 * counters; `adjust` lets the caller fold its own counter changes into the same writes.
 */
export async function activateCollaboration(
  tx: RecruitTx,
  input: {
    readonly studio: ProviderFacts;
    readonly collaborator: ProviderFacts;
    readonly initiatedBy: 'studio' | 'application';
    readonly applicationId: string | null;
    readonly termsAcceptedAt: Date;
    readonly now: Date;
    readonly ids: IdGenerator;
    readonly adjust?: {
      readonly studio?: (c: RecruitCounters) => RecruitCounters;
      readonly collaborator?: (c: RecruitCounters) => RecruitCounters;
    };
  },
): Promise<Collaboration> {
  const { studio, collaborator, now } = input;
  const prev = await tx.getCollaboration(studio.uid, collaborator.uid);
  const sc = await tx.getCounters(studio.uid);
  const cc = await tx.getCounters(collaborator.uid);
  const memberOf = await tx.activeMembershipStudioOf(collaborator.uid);
  // ---- all reads above ----
  if (prev?.status === 'active') fail('conflict');
  if (memberOf === studio.uid) fail('membership_conflict');
  if (sc.activeCollabCount >= collaboratorLimit(studio.businessVerified)) fail('collab_full');
  if (cc.activeCollabCount >= MAX_COLLABS_PER_COLLABORATOR) fail('collab_full');
  const pending = prev !== null && (prev.status === 'invited' || prev.status === 'requested') ? prev : null;
  if (prev !== null && pending === null) tx.archiveCollaboration(prev, input.ids.newId());
  const next: Collaboration = {
    id: collaborationId(studio.uid, collaborator.uid),
    studioId: studio.uid,
    collaboratorId: collaborator.uid,
    studio: collabPartyOf(studio),
    collaborator: collabPartyOf(collaborator),
    status: 'active',
    initiatedBy: input.initiatedBy,
    applicationId: input.applicationId ?? pending?.applicationId ?? null,
    defaultFee: pending?.defaultFee ?? null,
    termsAcceptedAt: input.termsAcceptedAt,
    createdAt: pending?.createdAt ?? now,
    expiresAt: pending?.expiresAt ?? recruitDaysAfter(now, COLLAB_INVITE_TTL_DAYS),
    activeAt: now,
    endedAt: null,
    endedBy: null,
    updatedAt: now,
  };
  tx.putCollaboration(next);
  const studioNext: RecruitCounters = {
    ...sc,
    activeCollabCount: sc.activeCollabCount + 1,
    pendingInviteCount: pending?.status === 'invited' ? decrement(sc.pendingInviteCount) : sc.pendingInviteCount,
  };
  const collaboratorNext: RecruitCounters = { ...cc, activeCollabCount: cc.activeCollabCount + 1 };
  tx.putCounters(studio.uid, input.adjust?.studio?.(studioNext) ?? studioNext);
  tx.putCounters(collaborator.uid, input.adjust?.collaborator?.(collaboratorNext) ?? collaboratorNext);
  return next;
}

/**
 * S27.06 "Mời cộng tác" (`{collaboratorId, defaultFee?}`): a verified studio invites a verified individual or
 * artist, not its own active member, not within 3 days after their collaboration ended; ≤ 5 pending invites;
 * a studio action; refused while the studio is recruit-blocked.
 */
export async function inviteCollaborator(deps: RecruitDeps, studioId: string, raw: unknown): Promise<void> {
  const r = objectOf(raw);
  const collaboratorId = r.collaboratorId;
  if (!isId(collaboratorId) || collaboratorId === studioId) fail('invalid_argument', 'collaboratorId');
  const defaultFee = defaultFeeOf(r);
  const studio = await deps.people.provider(studioId);
  if (!isCollabStudio(studio)) fail('invalid_argument');
  const collaborator = await deps.people.provider(collaboratorId);
  if (!isCollaboratorAccount(collaborator)) fail('invalid_argument', 'collaboratorId');
  await assertCanCollaborate(deps, studioId, collaboratorId);
  const now = deps.clock.now();
  const invited = await deps.store.runTransaction(async (tx) => {
    const prev = await tx.getCollaboration(studioId, collaboratorId);
    const c = await tx.getCounters(studioId);
    const memberOf = await tx.activeMembershipStudioOf(collaboratorId);
    // ---- all reads above ----
    if (isRecruitBlocked(c, now)) fail('recruit_blocked');
    const stale = prev !== null && isStaleInvite(prev, now);
    if (prev !== null && !stale && isOpenCollab(prev)) fail('conflict');
    if (prev !== null && inCollabCooldown(prev, now)) fail('cooldown');
    if (memberOf === studioId) fail('membership_conflict');
    const pendingInviteCount = stale ? decrement(c.pendingInviteCount) : c.pendingInviteCount;
    if (pendingInviteCount >= MAX_PENDING_COLLAB_INVITES) fail('collab_full');
    if (c.activeCollabCount >= collaboratorLimit(studio.businessVerified)) fail('collab_full');
    const collabActions = takeRecruitDaily(c.collabActions, now, STUDIO_COLLAB_DAILY_ACTIONS);
    // ---- writes ----
    if (prev !== null) tx.archiveCollaboration(stale ? closed(prev, 'expired', 'system', now) : prev, deps.ids.newId());
    const next: Collaboration = {
      id: collaborationId(studioId, collaboratorId),
      studioId,
      collaboratorId,
      studio: collabPartyOf(studio),
      collaborator: collabPartyOf(collaborator),
      status: 'invited',
      initiatedBy: 'studio',
      applicationId: null,
      defaultFee,
      termsAcceptedAt: null,
      createdAt: now,
      expiresAt: recruitDaysAfter(now, COLLAB_INVITE_TTL_DAYS),
      activeAt: null,
      endedAt: null,
      endedBy: null,
      updatedAt: now,
    };
    tx.putCollaboration(next);
    tx.putCounters(studioId, { ...c, pendingInviteCount: pendingInviteCount + 1, collabActions });
    return next;
  });
  await safely(deps, collaboratorId, () => notifyCollabInvite(deps.notify,
    { collaboratorId, studioId, invitedAt: invitedAtOf(invited) }));
}

/** The studio withdraws its pending invite (`{collaboratorId}`): `cancelled`, the slot freed; a studio action. */
export async function cancelCollabInvite(deps: RecruitDeps, studioId: string, raw: unknown): Promise<void> {
  const collaboratorId = objectOf(raw).collaboratorId;
  if (!isId(collaboratorId)) fail('invalid_argument', 'collaboratorId');
  const now = deps.clock.now();
  await deps.store.runTransaction(async (tx) => {
    const prev = await tx.getCollaboration(studioId, collaboratorId);
    const c = await tx.getCounters(studioId);
    // ---- all reads above ----
    if (prev === null || prev.status !== 'invited') fail('not_found');
    const collabActions = takeRecruitDaily(c.collabActions, now, STUDIO_COLLAB_DAILY_ACTIONS);
    tx.putCollaboration(closed(prev, 'cancelled', 'studio', now));
    tx.putCounters(studioId, { ...c, pendingInviteCount: decrement(c.pendingInviteCount), collabActions });
  });
}

type InviteAnswer = { readonly outcome: 'active' | 'declined' | 'expired'; readonly collab: Collaboration };

/**
 * The invited photographer answers (`{studioId, accept, acceptTerms}`); not a counted action. Accepting needs
 * `acceptTerms: true`, both sides still verified and not blocked, and goes through `activateCollaboration`.
 * An invite past `expiresAt` is recorded `expired` (slot freed) and refused `deadline_passed`.
 */
export async function respondCollabInvite(
  deps: RecruitDeps,
  uid: string,
  raw: unknown,
): Promise<{ status: 'active' | 'declined' }> {
  const r = objectOf(raw);
  const studioId = r.studioId;
  if (!isId(studioId)) fail('invalid_argument', 'studioId');
  if (typeof r.accept !== 'boolean') fail('invalid_argument', 'accept');
  const accept = r.accept;
  if (accept && r.acceptTerms !== true) fail('invalid_argument', 'acceptTerms');
  const now = deps.clock.now();
  let studio: ProviderFacts | null = null;
  let me: ProviderFacts | null = null;
  if (accept) {
    studio = await deps.people.provider(studioId);
    me = await deps.people.provider(uid);
    if (studio === null || me === null) fail('not_found');
    await assertCanCollaborate(deps, studioId, uid);
  }
  const answer = await deps.store.runTransaction(async (tx): Promise<InviteAnswer> => {
    const prev = await tx.getCollaboration(studioId, uid);
    if (prev === null) return fail('not_found');
    if (prev.status === 'expired') fail('deadline_passed');
    if (prev.status !== 'invited') fail('not_found');
    if (isStaleInvite(prev, now) || !accept) {
      const c = await tx.getCounters(studioId);
      const expired = isStaleInvite(prev, now);
      const after = expired ? closed(prev, 'expired', 'system', now) : closed(prev, 'declined', 'collaborator', now);
      tx.putCollaboration(after);
      tx.putCounters(studioId, { ...c, pendingInviteCount: decrement(c.pendingInviteCount) });
      return { outcome: expired ? 'expired' : 'declined', collab: after };
    }
    if (studio === null || me === null) return fail('not_found');
    const after = await activateCollaboration(tx, {
      studio,
      collaborator: me,
      initiatedBy: 'studio',
      applicationId: null,
      termsAcceptedAt: now,
      now,
      ids: deps.ids,
    });
    return { outcome: 'active', collab: after };
  });
  await notifyInviteResult(deps, answer.collab, answer.outcome === 'active' ? 'accepted' : answer.outcome);
  if (answer.outcome === 'expired') fail('deadline_passed');
  return { status: answer.outcome };
}

/**
 * Sweep step (Task 4 calls it for `dueInvites`): an `invited` collaboration past `expiresAt` becomes
 * `expired`, the studio's pending slot is freed and the studio is told. False when it is not due.
 */
export async function expireCollabInvite(deps: RecruitDeps, studioId: string, collaboratorId: string): Promise<boolean> {
  const now = deps.clock.now();
  const after = await deps.store.runTransaction(async (tx) => {
    const prev = await tx.getCollaboration(studioId, collaboratorId);
    if (prev === null || !isStaleInvite(prev, now)) return null;
    const c = await tx.getCounters(studioId);
    const expired = closed(prev, 'expired', 'system', now);
    tx.putCollaboration(expired);
    tx.putCounters(studioId, { ...c, pendingInviteCount: decrement(c.pendingInviteCount) });
    return expired;
  });
  if (after === null) return false;
  await notifyInviteResult(deps, after, 'expired');
  return true;
}

/**
 * Either side ends an active collaboration (`{studioId}` from the collaborator, `{collaboratorId}` from the
 * studio): `member_busy` while a collab job is pending or accepted; a counted action of the caller (studio
 * ≤ 10, collaborator ≤ 5 per VN day). Returns the collab chat id: the adapter sets its `readOnlyAt` after the
 * commit (Decision 16).
 */
export async function endCollaboration(deps: RecruitDeps, uid: string, raw: unknown): Promise<{ chatId: string }> {
  const { studioId, collaboratorId, side } = collabPairOf(uid, raw);
  if ((await deps.store.openJobCount(studioId, collaboratorId)) > 0) fail('member_busy');
  const now = deps.clock.now();
  await deps.store.runTransaction(async (tx) => {
    const prev = await tx.getCollaboration(studioId, collaboratorId);
    const sc = await tx.getCounters(studioId);
    const cc = await tx.getCounters(collaboratorId);
    // ---- all reads above ----
    if (prev === null || prev.status !== 'active') fail('not_found');
    const mine = side === 'studio' ? sc : cc;
    const collabActions = takeRecruitDaily(mine.collabActions, now,
      side === 'studio' ? STUDIO_COLLAB_DAILY_ACTIONS : COLLABORATOR_DAILY_ACTIONS);
    tx.putCollaboration(closed(prev, 'ended', side, now));
    tx.putCounters(studioId, {
      ...sc,
      activeCollabCount: decrement(sc.activeCollabCount),
      ...(side === 'studio' ? { collabActions } : {}),
    });
    tx.putCounters(collaboratorId, {
      ...cc,
      activeCollabCount: decrement(cc.activeCollabCount),
      ...(side === 'collaborator' ? { collabActions } : {}),
    });
  });
  return { chatId: collabChatId(studioId, collaboratorId) };
}

/** The studio sets (or clears with null) the suggested fee of an invited or active collaborator; not counted. */
export async function setCollabDefaultFee(deps: RecruitDeps, studioId: string, raw: unknown): Promise<void> {
  const r = objectOf(raw);
  const collaboratorId = r.collaboratorId;
  if (!isId(collaboratorId)) fail('invalid_argument', 'collaboratorId');
  if (!('defaultFee' in r)) fail('invalid_argument', 'defaultFee');
  const defaultFee = defaultFeeOf(r);
  const now = deps.clock.now();
  await deps.store.runTransaction(async (tx) => {
    const prev = await tx.getCollaboration(studioId, collaboratorId);
    if (prev === null || (prev.status !== 'invited' && prev.status !== 'active')) fail('not_found');
    tx.putCollaboration({ ...prev, defaultFee, updatedAt: now });
  });
}
