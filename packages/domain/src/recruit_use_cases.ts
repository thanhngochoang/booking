/**
 * S27 recruit posts and applications (plan #151 Tasks 2–3). Each use case reads everything first, then
 * writes, in one `RecruitTx`; notifications go through #138's hooks after the commit and never fail the use case.
 */

import { activateCollaboration } from './collab_use_cases.js';
import { DomainError, type ErrorCode } from './errors.js';
import { isId } from './ids.js';
import {
  notifyRecruitApplicationNew,
  notifyRecruitApplicationResult,
  notifyStudioJoinApproved,
} from './notification_hooks.js';
import {
  APPLICATION_MESSAGE_MAX,
  APPLICATION_SAMPLES_MAX,
  APPLICATION_TTL_DAYS,
  APPLY_DAILY,
  assertNoContact,
  isRecruitBlocked,
  MAX_OPEN_APPLICATIONS,
  MAX_OPEN_POSTS,
  RECRUIT_POST_DAYS,
  recruitApplicationId,
  recruitDaysAfter,
  recruitFilterKeys,
  recruitMatchKeys,
  STUDIO_COLLAB_DAILY_ACTIONS,
  STUDIO_POST_DAILY_ACTIONS,
  takeRecruitDaily,
  validateRecruitPostInput,
  type RecruitApplication,
  type RecruitCounters,
  type RecruitKind,
  type RecruitPost,
  type RecruitPostFields,
  type RecruitStudioSnapshot,
} from './recruit.js';
import type { ProviderFacts, RecruitDeps } from './recruit_ports.js';
import { isCollabStudio, isCollaboratorAccount } from './studio_collaboration.js';
import { checkMemberActivation, memberActivation } from './studio_membership.js';

/** Applications settled per page when a post closes or expires (Decision 9). */
const CASCADE_PAGE = 200;
const CASCADE_MAX_PAGES = 50;

function fail(code: ErrorCode, field?: string): never {
  throw new DomainError(code, field);
}

const decrement = (n: number): number => Math.max(0, n - 1);

function objectOf(raw: unknown): Record<string, unknown> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) fail('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(r: Record<string, unknown>, field: string): string {
  const v = r[field];
  return isId(v) ? v : fail('invalid_argument', field);
}

/** Runs a post-commit notification; a failure is reported, never thrown (the write already happened). */
async function safely(deps: RecruitDeps, uid: string, send: () => Promise<unknown>): Promise<void> {
  try {
    await send();
  } catch (e) {
    deps.notify.onPushError?.(uid, e);
  }
}

const snapshotOf = (p: ProviderFacts): RecruitStudioSnapshot =>
  ({ name: p.name, avatarUrl: p.avatarUrl, businessVerified: p.businessVerified });

/** The stored post fields derived from validated input. */
function postFields(kind: RecruitKind, f: RecruitPostFields) {
  return {
    kind,
    title: f.title,
    specialties: f.specialties,
    areas: f.areas,
    frequency: f.frequency,
    feeHint: f.feeHint,
    requirements: f.requirements,
    matchKeys: recruitMatchKeys(f.areas, f.specialties),
    filterKeys: recruitFilterKeys({ kind, areas: f.areas, specialties: f.specialties }),
  };
}

/** The open post of `studioId` (`not_found`, `permission_denied`, `deadline_passed` otherwise). */
function ownOpenPost(post: RecruitPost | null, studioId: string, now: Date): RecruitPost {
  if (!post) return fail('not_found');
  if (post.studioId !== studioId) fail('permission_denied');
  if (post.status !== 'open' || post.expiresAt <= now) fail('deadline_passed');
  return post;
}

// ── posts ─────────────────────────────────────────────────────────────────────────────────────

/** S27.04 "Đăng tin": a verified studio, ≤ 3 open posts, ≤ 5 creates/closes per VN day, not recruit-blocked. */
export async function createRecruitPost(deps: RecruitDeps, uid: string, raw: unknown): Promise<{ postId: string }> {
  const fields = validateRecruitPostInput(raw, 'create');
  const kind = fields.kind ?? fail('invalid_argument', 'kind');
  const me = await deps.people.provider(uid);
  if (!isCollabStudio(me)) fail('invalid_argument');
  if (!(await deps.orders.acceptsOrders(uid))) fail('not_accepting_orders');
  const now = deps.clock.now();
  const postId = deps.ids.newId();
  await deps.store.runTransaction(async (tx) => {
    const c = await tx.getCounters(uid);
    if (isRecruitBlocked(c, now)) fail('recruit_blocked');
    if (c.openPostCount >= MAX_OPEN_POSTS) fail('limit_exceeded');
    const postActions = takeRecruitDaily(c.postActions, now, STUDIO_POST_DAILY_ACTIONS);
    // ---- writes ----
    tx.putPost({
      id: postId,
      studioId: uid,
      studio: snapshotOf(me),
      ...postFields(kind, fields),
      status: 'open',
      renewed: false,
      applicationCount: 0,
      createdAt: now,
      updatedAt: now,
      expiresAt: recruitDaysAfter(now, RECRUIT_POST_DAYS),
      closedAt: null,
    });
    tx.putCounters(uid, { ...c, openPostCount: c.openPostCount + 1, postActions });
  });
  return { postId };
}

/** Edits an open post of the caller; `kind` is fixed after creation (Decision 22). Not a counted action. */
export async function updateRecruitPost(deps: RecruitDeps, uid: string, raw: unknown): Promise<void> {
  const postId = idOf(objectOf(raw), 'postId');
  const fields = validateRecruitPostInput(raw, 'update');
  const me = await deps.people.provider(uid);
  const now = deps.clock.now();
  await deps.store.runTransaction(async (tx) => {
    const post = ownOpenPost(await tx.getPost(postId), uid, now);
    if (fields.kind !== null && fields.kind !== post.kind) fail('invalid_argument', 'kind');
    tx.putPost({
      ...post,
      ...postFields(post.kind, fields),
      studio: me ? snapshotOf(me) : post.studio,
      updatedAt: now,
    });
  });
}

/** One renewal while open: `expiresAt += 30 days` (`conflict` the second time). Not a counted action. */
export async function renewRecruitPost(deps: RecruitDeps, uid: string, raw: unknown): Promise<{ expiresAt: Date }> {
  const postId = idOf(objectOf(raw), 'postId');
  const me = await deps.people.provider(uid);
  const now = deps.clock.now();
  return deps.store.runTransaction(async (tx) => {
    const post = ownOpenPost(await tx.getPost(postId), uid, now);
    if (post.renewed) fail('conflict');
    const expiresAt = recruitDaysAfter(post.expiresAt, RECRUIT_POST_DAYS);
    tx.putPost({ ...post, renewed: true, expiresAt, studio: me ? snapshotOf(me) : post.studio, updatedAt: now });
    return { expiresAt };
  });
}

/**
 * Closes an open post of the caller (a counted action) and declines every application still `applied`
 * (Decision 9), each in its own transaction so each applicant's counter drops exactly once.
 */
export async function closeRecruitPost(deps: RecruitDeps, uid: string, raw: unknown): Promise<void> {
  const postId = idOf(objectOf(raw), 'postId');
  const now = deps.clock.now();
  const post = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPost(postId);
    if (!p) return fail('not_found');
    if (p.studioId !== uid) fail('permission_denied');
    if (p.status !== 'open') fail('deadline_passed');
    const c = await tx.getCounters(uid);
    const postActions = takeRecruitDaily(c.postActions, now, STUDIO_POST_DAILY_ACTIONS);
    // ---- writes ----
    tx.putPost({ ...p, status: 'closed', closedAt: now, updatedAt: now });
    tx.putCounters(uid, { ...c, openPostCount: decrement(c.openPostCount), postActions });
    return p;
  });
  await settleApplied(deps, post.id, 'declined');
}

/**
 * Sweep step (Task 4 calls it): an `open` post past `expiresAt` becomes `expired`, the studio's open-post
 * count drops once, and its `applied` applications expire. False when the post is not due (idempotent).
 */
export async function expireRecruitPost(deps: RecruitDeps, postId: string): Promise<boolean> {
  const now = deps.clock.now();
  const post = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPost(postId);
    if (!p || p.status !== 'open' || p.expiresAt > now) return null;
    const c = await tx.getCounters(p.studioId);
    tx.putPost({ ...p, status: 'expired', updatedAt: now });
    tx.putCounters(p.studioId, { ...c, openPostCount: decrement(c.openPostCount) });
    return p;
  });
  if (!post) return false;
  await settleApplied(deps, post.id, 'expired');
  return true;
}

// ── applications ──────────────────────────────────────────────────────────────────────────────

interface ApplyInput {
  readonly postId: string;
  readonly message: string;
  readonly samplePostIds: readonly string[];
  readonly acceptTerms: boolean;
}

function parseApplyInput(raw: unknown): ApplyInput {
  const r = objectOf(raw);
  const postId = idOf(r, 'postId');
  if (r.message !== undefined && r.message !== null && typeof r.message !== 'string') fail('invalid_argument', 'message');
  const message = typeof r.message === 'string' ? r.message.trim() : '';
  if ([...message.normalize('NFC')].length > APPLICATION_MESSAGE_MAX) fail('invalid_argument', 'message');
  const samples = r.samplePostIds ?? [];
  if (!Array.isArray(samples) || samples.length > APPLICATION_SAMPLES_MAX || !samples.every(isId)
    || new Set(samples).size !== samples.length) {
    fail('invalid_argument', 'samplePostIds');
  }
  if (r.acceptTerms !== undefined && typeof r.acceptTerms !== 'boolean') fail('invalid_argument', 'acceptTerms');
  return { postId, message, samplePostIds: samples as string[], acceptTerms: r.acceptTerms === true };
}

/**
 * S27.03 "Ứng tuyển": a verified individual or artist, not blocked by (and not blocking) the studio, not
 * its active member; once per post, ≤ 10 open applications, ≤ 3 applies per VN day.
 */
export async function applyToRecruitPost(
  deps: RecruitDeps,
  uid: string,
  raw: unknown,
): Promise<{ applicationId: string }> {
  const input = parseApplyInput(raw);
  assertNoContact(input.message, 'message'); // 'zalo' included
  const me = await deps.people.provider(uid);
  if (!isCollaboratorAccount(me)) fail('invalid_argument');
  if (!(await deps.orders.acceptsOrders(uid))) fail('not_accepting_orders');
  if (!(await deps.posts.ownedBy(uid, input.samplePostIds))) fail('invalid_argument', 'samplePostIds');
  const now = deps.clock.now();
  const post = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getPost(input.postId);
    if (!p) return fail('not_found');
    if (p.status !== 'open' || p.expiresAt <= now) fail('deadline_passed');
    if (p.kind === 'collaborator' && !input.acceptTerms) fail('invalid_argument', 'acceptTerms');
    if (await deps.blocks.isBlockedEitherWay(p.studioId, uid)) fail('blocked');
    if ((await tx.activeMembershipStudioOf(uid)) === p.studioId) fail('membership_conflict');
    if (await tx.getApplication(p.id, uid)) fail('conflict');
    const c = await tx.getCounters(uid);
    if (c.openApplicationCount >= MAX_OPEN_APPLICATIONS) fail('limit_exceeded');
    const applyActions = takeRecruitDaily(c.applyActions, now, APPLY_DAILY);
    // ---- writes ----
    tx.putApplication({
      id: recruitApplicationId(p.id, uid),
      postId: p.id,
      studioId: p.studioId,
      applicantId: uid,
      kind: p.kind,
      postTitle: p.title,
      applicant: { name: me.name, avatarUrl: me.avatarUrl },
      status: 'applied',
      message: input.message,
      samplePostIds: input.samplePostIds,
      termsAcceptedAt: p.kind === 'collaborator' ? now : null,
      createdAt: now,
      expiresAt: recruitDaysAfter(now, APPLICATION_TTL_DAYS),
      respondedAt: null,
    });
    tx.putPost({ ...p, applicationCount: p.applicationCount + 1, updatedAt: now });
    tx.putCounters(uid, { ...c, openApplicationCount: c.openApplicationCount + 1, applyActions });
    return p;
  });
  await safely(deps, post.studioId, () => notifyRecruitApplicationNew(deps.notify,
    { studioId: post.studioId, postId: post.id, title: post.title, applicantId: uid }));
  return { applicationId: recruitApplicationId(post.id, uid) };
}

/** The applicant withdraws while `applied` (Decision 23): the open count drops; the daily quota is not refunded. */
export async function withdrawRecruitApplication(deps: RecruitDeps, uid: string, raw: unknown): Promise<void> {
  const postId = idOf(objectOf(raw), 'postId');
  const now = deps.clock.now();
  await deps.store.runTransaction(async (tx) => {
    const a = await tx.getApplication(postId, uid);
    if (!a) return fail('not_found');
    if (a.status !== 'applied' || a.expiresAt <= now) fail('deadline_passed');
    const c = await tx.getCounters(uid);
    tx.putApplication({ ...a, status: 'withdrawn' });
    tx.putCounters(uid, { ...c, openApplicationCount: decrement(c.openApplicationCount) });
  });
}

/**
 * S27.05: the posting studio answers an `applied` application; either answer is one studio collaboration
 * action (Decision 5) and tells the applicant. Accepting a collaborator application makes the pair active
 * (`activateCollaboration`); accepting a member application approves a join exactly as S26 does
 * (`checkMemberActivation`, Decision 21).
 */
export async function respondRecruitApplication(
  deps: RecruitDeps,
  uid: string,
  raw: unknown,
): Promise<{ status: 'accepted' | 'declined' }> {
  const r = objectOf(raw);
  const postId = idOf(r, 'postId');
  const applicantId = idOf(r, 'applicantId');
  if (typeof r.accept !== 'boolean') fail('invalid_argument', 'accept');
  if (r.accept) {
    await acceptApplication(deps, uid, postId, applicantId);
    return { status: 'accepted' };
  }
  const now = deps.clock.now();
  const app = await deps.store.runTransaction(async (tx) => {
    const a = await tx.getApplication(postId, applicantId);
    const answerable = answerableApplication(a, uid, now);
    const studio = await tx.getCounters(uid);
    const applicant = await tx.getCounters(applicantId);
    const collabActions = takeRecruitDaily(studio.collabActions, now, STUDIO_COLLAB_DAILY_ACTIONS);
    // ---- writes ----
    tx.putApplication({ ...answerable, status: 'declined', respondedAt: now });
    tx.putCounters(uid, { ...studio, collabActions });
    tx.putCounters(applicantId, { ...applicant, openApplicationCount: decrement(applicant.openApplicationCount) });
    return answerable;
  });
  await notifyResult(deps, app, 'declined');
  return { status: 'declined' };
}

/** An application of `studioId` still `applied` and not past `expiresAt`. */
function answerableApplication(a: RecruitApplication | null, studioId: string, now: Date): RecruitApplication {
  if (!a) return fail('not_found');
  if (a.studioId !== studioId) fail('permission_denied');
  if (a.status !== 'applied' || a.expiresAt <= now) fail('deadline_passed');
  return a;
}

type Accepted =
  | { readonly app: RecruitApplication; readonly outcome: 'collaborator' }
  | { readonly app: RecruitApplication; readonly outcome: 'member'; readonly relationId: string };

async function acceptApplication(deps: RecruitDeps, uid: string, postId: string, applicantId: string): Promise<void> {
  const now = deps.clock.now();
  const leave = (c: RecruitCounters): RecruitCounters =>
    ({ ...c, openApplicationCount: decrement(c.openApplicationCount) });
  const done = await deps.store.runTransaction(async (tx): Promise<Accepted> => {
    const a = answerableApplication(await tx.getApplication(postId, applicantId), uid, now);
    const studio = await deps.people.provider(uid);
    const applicant = await deps.people.provider(applicantId);
    if (studio === null || applicant === null) return fail('not_found');

    if (a.kind === 'collaborator') {
      if (!isCollabStudio(studio) || !isCollaboratorAccount(applicant)) fail('invalid_argument');
      if (!(await deps.orders.acceptsOrders(uid)) || !(await deps.orders.acceptsOrders(applicantId))) {
        fail('not_accepting_orders');
      }
      const sc = await tx.getCounters(uid);
      if (isRecruitBlocked(sc, now)) fail('recruit_blocked');
      const collabActions = takeRecruitDaily(sc.collabActions, now, STUDIO_COLLAB_DAILY_ACTIONS);
      await activateCollaboration(tx, {
        studio,
        collaborator: applicant,
        initiatedBy: 'application',
        applicationId: a.id,
        termsAcceptedAt: a.termsAcceptedAt ?? now,
        now,
        ids: deps.ids,
        adjust: { studio: (c) => ({ ...c, collabActions }), collaborator: leave },
      });
      tx.putApplication({ ...a, status: 'accepted', respondedAt: now });
      return { app: a, outcome: 'collaborator' };
    }

    // Member kind: S26's join approval, inside this transaction (Decision 21).
    const state = await tx.getMemberState(uid, applicantId);
    const sc = await tx.getCounters(uid);
    const ac = await tx.getCounters(applicantId);
    // ---- all reads above ----
    const refusal = checkMemberActivation(state, now);
    if (refusal !== null) fail(refusal);
    if (state.pairOpen) fail('conflict'); // S26 keeps one open relation per pair
    const collabActions = takeRecruitDaily(sc.collabActions, now, STUDIO_COLLAB_DAILY_ACTIONS);
    const m = memberActivation({
      studio: { uid, name: studio.name, avatarUrl: studio.avatarUrl },
      member: { uid: applicantId, name: applicant.name, avatarUrl: applicant.avatarUrl },
      applicationId: a.id,
      quota: state.quota,
      now,
    });
    tx.putMember(m);
    tx.putApplication({ ...a, status: 'accepted', respondedAt: now });
    tx.putCounters(uid, { ...sc, collabActions });
    tx.putCounters(applicantId, leave(ac));
    return { app: a, outcome: 'member', relationId: m.relation.id };
  });
  if (done.outcome === 'member') {
    await safely(deps, applicantId, () => notifyStudioJoinApproved(deps.notify,
      { photographerId: applicantId, studioId: uid, requestId: done.relationId }));
  }
  await notifyResult(deps, done.app, done.outcome);
}

/** Sweep step (Task 4 calls it): an `applied` application past `expiresAt` expires. False when not due. */
export async function expireRecruitApplication(deps: RecruitDeps, postId: string, applicantId: string): Promise<boolean> {
  return (await settleApplication(deps, postId, applicantId, 'expired', (a, now) => a.expiresAt <= now)) !== null;
}

// ── shared exits ──────────────────────────────────────────────────────────────────────────────

function notifyResult(
  deps: RecruitDeps,
  a: RecruitApplication,
  outcome: 'collaborator' | 'member' | 'declined' | 'expired',
): Promise<void> {
  return safely(deps, a.applicantId, () => notifyRecruitApplicationResult(deps.notify,
    { applicantId: a.applicantId, studioId: a.studioId, postId: a.postId, title: a.postTitle, outcome }));
}

/**
 * Ends one application still `applied` (and `due`) in its own transaction: status `to`, the applicant's open
 * count −1, then the result notification. Null (and nothing written) when it no longer qualifies.
 */
async function settleApplication(
  deps: RecruitDeps,
  postId: string,
  applicantId: string,
  to: 'declined' | 'expired',
  due: (a: RecruitApplication, now: Date) => boolean,
): Promise<RecruitApplication | null> {
  const now = deps.clock.now();
  const app = await deps.store.runTransaction(async (tx) => {
    const a = await tx.getApplication(postId, applicantId);
    if (!a || a.status !== 'applied' || !due(a, now)) return null;
    const c = await tx.getCounters(applicantId);
    tx.putApplication({ ...a, status: to, respondedAt: to === 'declined' ? now : a.respondedAt });
    tx.putCounters(applicantId, { ...c, openApplicationCount: decrement(c.openApplicationCount) });
    return a;
  });
  if (app) await notifyResult(deps, app, to);
  return app;
}

/**
 * Settles every `applied` application of a closed or expired post, a page of 200 at a time. Runs after the
 * post's own commit, so it never throws: a failing application is reported through `onPushError` and
 * skipped (the application sweep expires it after its 7 days).
 */
async function settleApplied(deps: RecruitDeps, postId: string, to: 'declined' | 'expired'): Promise<void> {
  const failed = new Set<string>();
  for (let page = 0; page < CASCADE_MAX_PAGES; page++) {
    let apps: RecruitApplication[];
    try {
      apps = await deps.store.appliedOf(postId, CASCADE_PAGE);
    } catch (e) {
      deps.notify.onPushError?.(postId, e);
      return;
    }
    let settled = 0;
    for (const a of apps) {
      if (failed.has(a.applicantId)) continue;
      try {
        if (await settleApplication(deps, postId, a.applicantId, to, () => true)) settled += 1;
      } catch (e) {
        failed.add(a.applicantId);
        deps.notify.onPushError?.(a.applicantId, e);
      }
    }
    if (settled === 0) return;
  }
}
