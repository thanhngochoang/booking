import {
  AWARDS_PER_PHOTOGRAPHER,
  FINAL_STATUSES,
  PROOF_PURGE_DAYS,
  nextStatus,
  validateAwardInput,
  validateReviewNote,
  type Award,
  type AwardInput,
  type AwardProof,
  type AwardStatus,
  type ReviewAction,
} from './award.js';
import { tierFor } from './artist_tier.js';
import type { AwardDeps } from './award_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const ACTIONS: readonly ReviewAction[] = ['approve', 'needs_info', 'reject', 'revoke'];

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

const sameList = (a: readonly string[], b: readonly string[]): boolean =>
  a.length === b.length && a.every((x, i) => x === b[i]);

function contentSame(a: Award, p: AwardProof, i: AwardInput): boolean {
  return (
    a.competition === i.competition &&
    a.year === i.year &&
    a.category === i.category &&
    a.result === i.result &&
    a.workPostId === i.workPostId &&
    sameList(p.files, i.proofFiles) &&
    sameList(p.links, i.proofLinks)
  );
}

export async function createAward(
  deps: AwardDeps,
  callerId: string,
  raw: unknown,
): Promise<{ awardId: string }> {
  const input = validateAwardInput(raw, callerId, deps.clock.now());
  await deps.awards.runTransaction(async (tx) => {
    const existing = await tx.getAward(input.awardId);
    if (existing !== null) throw new DomainError('conflict');
    if ((await tx.countAwards(callerId)) >= AWARDS_PER_PHOTOGRAPHER) {
      throw new DomainError('limit_exceeded');
    }
    if (input.workPostId !== null && !(await tx.isOwnWorkPost(input.workPostId, callerId))) {
      throw new DomainError('invalid_argument');
    }
    const now = deps.clock.now();
    tx.putAward({
      id: input.awardId,
      photographerId: callerId,
      competition: input.competition,
      year: input.year,
      category: input.category,
      result: input.result,
      workPostId: input.workPostId,
      status: 'pending',
      reviewNote: null,
      reviewedBy: null,
      reviewedAt: null,
      createdAt: now,
      updatedAt: now,
    });
    tx.putProof({
      awardId: input.awardId,
      photographerId: callerId,
      files: input.proofFiles,
      links: input.proofLinks,
      purgeAfter: null,
    });
  });
  return { awardId: input.awardId };
}

export async function updateAward(deps: AwardDeps, callerId: string, raw: unknown): Promise<void> {
  const input = validateAwardInput(raw, callerId, deps.clock.now());
  const outcome = await deps.awards.runTransaction(async (tx) => {
    const award = await tx.getAward(input.awardId);
    if (award === null) throw new DomainError('not_found');
    if (award.photographerId !== callerId) throw new DomainError('permission_denied');
    if (award.status === 'revoked') throw new DomainError('conflict');
    const proof = await tx.getProof(input.awardId);
    const old: AwardProof = proof ?? {
      awardId: award.id,
      photographerId: callerId,
      files: [],
      links: [],
      purgeAfter: null,
    };
    const changed = !contentSame(award, old, input);
    if (
      changed &&
      input.workPostId !== null &&
      input.workPostId !== award.workPostId &&
      !(await tx.isOwnWorkPost(input.workPostId, callerId))
    ) {
      throw new DomainError('invalid_argument');
    }
    // needs_info and rejected go back to the queue whenever the owner saves.
    const requeue = award.status === 'needs_info' || award.status === 'rejected' || (award.status === 'approved' && changed);
    if (!changed && !requeue) return { wasApproved: false, dropped: [] as string[] };
    const status: AwardStatus = requeue ? 'pending' : award.status;
    tx.putAward({
      ...award,
      competition: input.competition,
      year: input.year,
      category: input.category,
      result: input.result,
      workPostId: input.workPostId,
      status,
      reviewNote: requeue ? null : award.reviewNote,
      reviewedBy: requeue ? null : award.reviewedBy,
      reviewedAt: requeue ? null : award.reviewedAt,
      updatedAt: deps.clock.now(),
    });
    tx.putProof({
      awardId: award.id,
      photographerId: callerId,
      files: input.proofFiles,
      links: input.proofLinks,
      purgeAfter: requeue ? null : old.purgeAfter,
    });
    const kept = new Set(input.proofFiles);
    return {
      wasApproved: award.status === 'approved' && requeue,
      dropped: old.files.filter((f) => !kept.has(f)),
    };
  });
  if (outcome.dropped.length > 0) await deps.files.delete(outcome.dropped);
  if (outcome.wasApproved) await recomputeTier(deps, callerId);
}

export async function deleteAward(deps: AwardDeps, callerId: string, raw: unknown): Promise<void> {
  const awardId = idOf(obj(raw).awardId);
  const out = await deps.awards.runTransaction(async (tx) => {
    const award = await tx.getAward(awardId);
    if (award === null) throw new DomainError('not_found');
    if (award.photographerId !== callerId) throw new DomainError('permission_denied');
    const proof = await tx.getProof(awardId);
    tx.deleteAward(awardId);
    tx.deleteProof(awardId);
    return { files: proof?.files ?? [], wasApproved: award.status === 'approved' };
  });
  if (out.files.length > 0) await deps.files.delete(out.files);
  if (out.wasApproved) await recomputeTier(deps, callerId);
}

export async function reviewAward(
  deps: AwardDeps,
  actorId: string,
  isAdmin: boolean,
  raw: unknown,
): Promise<{ status: AwardStatus }> {
  if (!isAdmin) throw new DomainError('permission_denied');
  const r = obj(raw);
  const awardId = idOf(r.awardId);
  const action = r.action;
  if (!ACTIONS.includes(action as ReviewAction)) throw new DomainError('invalid_argument');
  const act = action as ReviewAction;
  const note = act === 'approve' ? null : validateReviewNote(r.note);

  const out = await deps.awards.runTransaction(async (tx) => {
    const award = await tx.getAward(awardId);
    if (award === null) throw new DomainError('not_found');
    const proof = await tx.getProof(awardId);
    const status = nextStatus(award.status, act);
    const now = deps.clock.now();
    tx.putAward({
      ...award,
      status,
      reviewNote: note,
      reviewedBy: actorId,
      reviewedAt: now,
      updatedAt: now,
    });
    if (proof !== null) {
      tx.putProof({
        ...proof,
        purgeAfter: FINAL_STATUSES.includes(status) ? new Date(now.getTime() + PROOF_PURGE_DAYS * DAY_MS) : null,
      });
    }
    tx.addAudit({ awardId, actorId, action: act, note, at: now });
    return { status, ownerId: award.photographerId };
  });
  await deps.notify.awardReviewed(out.ownerId, awardId, out.status);
  await recomputeTier(deps, out.ownerId);
  return { status: out.status };
}

/** Idempotent: writes and notifies only when something changed. */
export async function recomputeTier(
  deps: AwardDeps,
  uid: string,
): Promise<'unchanged' | 'artist' | 'individual' | 'count'> {
  const out = await deps.tiers.runTransaction(async (tx) => {
    const state = await tx.getTierState(uid);
    if (state === null) return { result: 'unchanged' as const, to: null };
    const count = await tx.countApproved(uid);
    const type = tierFor(state.providerType, count);
    let artistSince = state.artistSince;
    if (type === 'artist' && state.providerType !== 'artist') artistSince = deps.clock.now();
    if (type !== 'artist') artistSince = null;
    const typeChanged = type !== state.providerType;
    if (!typeChanged && count === state.approvedAwardCount && artistSince === state.artistSince) {
      return { result: 'unchanged' as const, to: null };
    }
    tx.setTierState(uid, { providerType: type, artistSince, approvedAwardCount: count });
    if (typeChanged && (type === 'artist' || type === 'individual')) {
      return { result: type, to: type };
    }
    return { result: 'count' as const, to: null };
  });
  if (out.to !== null) await deps.notify.tierChanged(uid, out.to);
  return out.result;
}

export async function purgeDueProofs(
  deps: AwardDeps & { proofsDue: (now: Date) => Promise<AwardProof[]> },
): Promise<number> {
  const due = await deps.proofsDue(deps.clock.now());
  for (const p of due) {
    // Files first: a failed delete leaves the proof doc for the next run.
    if (p.files.length > 0) await deps.files.delete(p.files);
    await deps.awards.runTransaction(async (tx) => {
      tx.deleteProof(p.awardId);
    });
  }
  return due.length;
}
