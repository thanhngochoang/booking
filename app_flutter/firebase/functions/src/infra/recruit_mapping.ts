/**
 * Firestore mapping of the S27 documents (#151 Contract "Firestore data"): `recruitPosts`, `recruitApplications`,
 * `studio_collaborations` (+ `history`), `collab_jobs` and the server-only counters
 * `photographers/{uid}/private/recruit`. Instants are Timestamps in Firestore and `Date` in the domain; a missing
 * or malformed optional field reads as its default, a document without its identifying fields reads as null.
 * Pure (no store): the booking adapter's assignment transaction and the recruit store both use it.
 */

import { Timestamp, type DocumentData } from 'firebase-admin/firestore';
import {
  APPLICATION_STATUSES,
  COLLAB_PAY_METHODS,
  COLLAB_PAY_STATUSES,
  COLLAB_STATUSES,
  EMPTY_COUNTERS,
  OFFER_STATUSES,
  RECRUIT_FREQUENCIES,
  RECRUIT_KINDS,
  RECRUIT_POST_STATUSES,
  type CollabJob,
  type CollabParty,
  type Collaboration,
  type FeeHint,
  type RecruitApplication,
  type RecruitCounters,
  type RecruitDaily,
  type RecruitNoticeDaily,
  type RecruitPost,
} from '@photobooking/domain';

export const RECRUIT_POSTS_COLLECTION = 'recruitPosts';
export const RECRUIT_APPLICATIONS_COLLECTION = 'recruitApplications';
export const COLLAB_JOBS_COLLECTION = 'collab_jobs';
/** `studio_collaborations/{studioId}_{uid}`: the latest relationship of the pair (+ `history/{id}`). */
export const STUDIO_COLLABORATIONS_COLLECTION = 'studio_collaborations';
export const STAFF_FLAGS_COLLECTION = 'staff_flags';
/** `photographers/{uid}/private/{RECRUIT_COUNTERS_DOC}`. */
export const RECRUIT_COUNTERS_DOC = 'recruit';

// ── helpers ──

export function dateOf(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string' && v !== '') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

const tsOf = (d: Date | null): Timestamp | null => (d === null ? null : Timestamp.fromDate(d));
const textOf = (v: unknown): string => (typeof v === 'string' ? v : '');
const strOrNull = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const numOf = (v: unknown, fallback = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);
const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
const objOf = (v: unknown): Record<string, unknown> =>
  v !== null && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};

function codeOf<T extends string>(v: unknown, codes: readonly T[]): T | null {
  return typeof v === 'string' && (codes as readonly string[]).includes(v) ? (v as T) : null;
}

const partyToDoc = (p: CollabParty): DocumentData => ({ name: p.name, avatarUrl: p.avatarUrl });
const partyOf = (v: unknown): CollabParty => {
  const o = objOf(v);
  return { name: textOf(o.name), avatarUrl: strOrNull(o.avatarUrl) };
};

// ── recruitPosts/{id} ──

export function recruitPostToDoc(p: RecruitPost): DocumentData {
  return {
    studioId: p.studioId,
    studio: { name: p.studio.name, avatarUrl: p.studio.avatarUrl, businessVerified: p.studio.businessVerified },
    kind: p.kind,
    title: p.title,
    specialties: [...p.specialties],
    areas: [...p.areas],
    frequency: p.frequency,
    feeHint: p.feeHint.type === 'per_shoot' ? { type: 'per_shoot', amount: p.feeHint.amount } : { type: 'negotiable' },
    requirements: p.requirements,
    status: p.status,
    renewed: p.renewed,
    applicationCount: p.applicationCount,
    matchKeys: [...p.matchKeys],
    filterKeys: [...p.filterKeys],
    createdAt: tsOf(p.createdAt),
    updatedAt: tsOf(p.updatedAt),
    expiresAt: tsOf(p.expiresAt),
    closedAt: tsOf(p.closedAt),
  };
}

function feeHintOf(v: unknown): FeeHint {
  const o = objOf(v);
  return o.type === 'per_shoot' && typeof o.amount === 'number' ? { type: 'per_shoot', amount: o.amount } : { type: 'negotiable' };
}

export function recruitPostFromDoc(id: string, d: DocumentData | undefined): RecruitPost | null {
  if (!d || typeof d.studioId !== 'string') return null;
  const kind = codeOf(d.kind, RECRUIT_KINDS);
  const createdAt = dateOf(d.createdAt);
  const expiresAt = dateOf(d.expiresAt);
  if (kind === null || createdAt === null || expiresAt === null) return null;
  const studio = objOf(d.studio);
  return {
    id,
    studioId: d.studioId,
    studio: { name: textOf(studio.name), avatarUrl: strOrNull(studio.avatarUrl), businessVerified: studio.businessVerified === true },
    kind,
    title: textOf(d.title),
    specialties: strings(d.specialties),
    areas: strings(d.areas),
    frequency: codeOf(d.frequency, RECRUIT_FREQUENCIES) ?? 'occasional',
    feeHint: feeHintOf(d.feeHint),
    requirements: textOf(d.requirements),
    status: codeOf(d.status, RECRUIT_POST_STATUSES) ?? 'closed',
    renewed: d.renewed === true,
    applicationCount: numOf(d.applicationCount),
    matchKeys: strings(d.matchKeys),
    filterKeys: strings(d.filterKeys),
    createdAt,
    updatedAt: dateOf(d.updatedAt) ?? createdAt,
    expiresAt,
    closedAt: dateOf(d.closedAt),
  };
}

// ── recruitApplications/{postId}_{uid} ──

export function applicationToDoc(a: RecruitApplication): DocumentData {
  return {
    postId: a.postId,
    studioId: a.studioId,
    applicantId: a.applicantId,
    kind: a.kind,
    postTitle: a.postTitle,
    applicant: partyToDoc(a.applicant),
    status: a.status,
    message: a.message,
    samplePostIds: [...a.samplePostIds],
    termsAcceptedAt: tsOf(a.termsAcceptedAt),
    createdAt: tsOf(a.createdAt),
    expiresAt: tsOf(a.expiresAt),
    respondedAt: tsOf(a.respondedAt),
  };
}

export function applicationFromDoc(id: string, d: DocumentData | undefined): RecruitApplication | null {
  if (!d || typeof d.postId !== 'string' || typeof d.studioId !== 'string' || typeof d.applicantId !== 'string') return null;
  const kind = codeOf(d.kind, RECRUIT_KINDS);
  const createdAt = dateOf(d.createdAt);
  const expiresAt = dateOf(d.expiresAt);
  if (kind === null || createdAt === null || expiresAt === null) return null;
  return {
    id,
    postId: d.postId,
    studioId: d.studioId,
    applicantId: d.applicantId,
    kind,
    postTitle: textOf(d.postTitle),
    applicant: partyOf(d.applicant),
    status: codeOf(d.status, APPLICATION_STATUSES) ?? 'expired',
    message: textOf(d.message),
    samplePostIds: strings(d.samplePostIds),
    termsAcceptedAt: dateOf(d.termsAcceptedAt),
    createdAt,
    expiresAt,
    respondedAt: dateOf(d.respondedAt),
  };
}

// ── studio_collaborations/{studioId}_{uid} (+ history/{id}) ──

export function collaborationToDoc(c: Collaboration): DocumentData {
  return {
    studioId: c.studioId,
    collaboratorId: c.collaboratorId,
    studio: partyToDoc(c.studio),
    collaborator: partyToDoc(c.collaborator),
    status: c.status,
    initiatedBy: c.initiatedBy,
    applicationId: c.applicationId,
    defaultFee: c.defaultFee,
    termsAcceptedAt: tsOf(c.termsAcceptedAt),
    createdAt: tsOf(c.createdAt),
    expiresAt: tsOf(c.expiresAt),
    activeAt: tsOf(c.activeAt),
    endedAt: tsOf(c.endedAt),
    endedBy: c.endedBy,
    updatedAt: tsOf(c.updatedAt),
  };
}

export function collaborationFromDoc(id: string, d: DocumentData | undefined): Collaboration | null {
  if (!d || typeof d.studioId !== 'string' || typeof d.collaboratorId !== 'string') return null;
  const status = codeOf(d.status, COLLAB_STATUSES);
  const createdAt = dateOf(d.createdAt);
  if (status === null || createdAt === null) return null;
  return {
    id,
    studioId: d.studioId,
    collaboratorId: d.collaboratorId,
    studio: partyOf(d.studio),
    collaborator: partyOf(d.collaborator),
    status,
    initiatedBy: codeOf(d.initiatedBy, ['studio', 'collaborator', 'application'] as const) ?? 'studio',
    applicationId: strOrNull(d.applicationId),
    defaultFee: typeof d.defaultFee === 'number' ? d.defaultFee : null,
    termsAcceptedAt: dateOf(d.termsAcceptedAt),
    createdAt,
    expiresAt: dateOf(d.expiresAt) ?? createdAt,
    activeAt: dateOf(d.activeAt),
    endedAt: dateOf(d.endedAt),
    endedBy: codeOf(d.endedBy, ['studio', 'collaborator', 'system'] as const),
    updatedAt: dateOf(d.updatedAt) ?? createdAt,
  };
}

// ── collab_jobs/{bookingId}_{uid} ──

/**
 * Every pay field is written, nulls explicit: the sweep queries `pay.overdueFlaggedAt == null` and
 * `pay.disputeFlaggedAt == null` match only stored nulls.
 */
export function collabJobToDoc(j: CollabJob): DocumentData {
  return {
    bookingId: j.bookingId,
    studioId: j.studioId,
    collaboratorId: j.collaboratorId,
    customerId: j.customerId,
    studioName: j.studioName,
    collaboratorName: j.collaboratorName,
    shoot: { ...j.shoot },
    shootEndsAt: tsOf(j.shootEndsAt),
    agreedFee: j.agreedFee,
    offerStatus: j.offerStatus,
    offerAt: tsOf(j.offerAt),
    offerExpiresAt: tsOf(j.offerExpiresAt),
    acceptedAt: tsOf(j.acceptedAt),
    declinedAt: tsOf(j.declinedAt),
    closedAt: tsOf(j.closedAt),
    payStatus: j.payStatus,
    pay: {
      amount: j.pay.amount,
      dueAt: tsOf(j.pay.dueAt),
      paidOn: j.pay.paidOn,
      method: j.pay.method,
      reportedAt: tsOf(j.pay.reportedAt),
      receivedAt: tsOf(j.pay.receivedAt),
      disputedAt: tsOf(j.pay.disputedAt),
      overdueFlaggedAt: tsOf(j.pay.overdueFlaggedAt),
      disputeFlaggedAt: tsOf(j.pay.disputeFlaggedAt),
      checkAfter: tsOf(j.pay.checkAfter),
    },
    createdAt: tsOf(j.createdAt),
    updatedAt: tsOf(j.updatedAt),
  };
}

export function collabJobFromDoc(id: string, d: DocumentData | undefined): CollabJob | null {
  if (!d || typeof d.bookingId !== 'string' || typeof d.studioId !== 'string' || typeof d.collaboratorId !== 'string') {
    return null;
  }
  const offerStatus = codeOf(d.offerStatus, OFFER_STATUSES);
  const offerAt = dateOf(d.offerAt);
  const offerExpiresAt = dateOf(d.offerExpiresAt);
  const shootEndsAt = dateOf(d.shootEndsAt);
  if (offerStatus === null || offerAt === null || offerExpiresAt === null || shootEndsAt === null) return null;
  const shoot = objOf(d.shoot);
  const pay = objOf(d.pay);
  const agreedFee = numOf(d.agreedFee);
  return {
    id,
    bookingId: d.bookingId,
    studioId: d.studioId,
    collaboratorId: d.collaboratorId,
    customerId: textOf(d.customerId),
    studioName: textOf(d.studioName),
    collaboratorName: textOf(d.collaboratorName),
    shoot: {
      day: textOf(shoot.day),
      start: textOf(shoot.start),
      end: textOf(shoot.end),
      serviceName: textOf(shoot.serviceName),
      placeName: textOf(shoot.placeName),
    },
    shootEndsAt,
    agreedFee,
    offerStatus,
    offerAt,
    offerExpiresAt,
    acceptedAt: dateOf(d.acceptedAt),
    declinedAt: dateOf(d.declinedAt),
    closedAt: dateOf(d.closedAt),
    payStatus: codeOf(d.payStatus, COLLAB_PAY_STATUSES) ?? 'none',
    pay: {
      amount: numOf(pay.amount, agreedFee),
      dueAt: dateOf(pay.dueAt),
      paidOn: strOrNull(pay.paidOn),
      method: codeOf(pay.method, COLLAB_PAY_METHODS),
      reportedAt: dateOf(pay.reportedAt),
      receivedAt: dateOf(pay.receivedAt),
      disputedAt: dateOf(pay.disputedAt),
      overdueFlaggedAt: dateOf(pay.overdueFlaggedAt),
      disputeFlaggedAt: dateOf(pay.disputeFlaggedAt),
      checkAfter: dateOf(pay.checkAfter),
    },
    createdAt: dateOf(d.createdAt) ?? offerAt,
    updatedAt: dateOf(d.updatedAt) ?? offerAt,
  };
}

// ── photographers/{uid}/private/recruit ──

const dailyToDoc = (d: RecruitDaily | null): DocumentData | null => (d === null ? null : { day: d.day, count: d.count });

function dailyOf(v: unknown): RecruitDaily | null {
  const o = objOf(v);
  return typeof o.day === 'string' && typeof o.count === 'number' ? { day: o.day, count: o.count } : null;
}

function noticesOf(v: unknown): RecruitNoticeDaily | null {
  const d = dailyOf(v);
  return d === null ? null : { ...d, postIds: strings(objOf(v).postIds) };
}

export function countersToDoc(c: RecruitCounters): DocumentData {
  return {
    openPostCount: c.openPostCount,
    postActions: dailyToDoc(c.postActions),
    activeCollabCount: c.activeCollabCount,
    pendingInviteCount: c.pendingInviteCount,
    collabActions: dailyToDoc(c.collabActions),
    openApplicationCount: c.openApplicationCount,
    applyActions: dailyToDoc(c.applyActions),
    // `postIds` makes a replayed fan-out count once (RecruitNoticeDaily).
    notices: c.notices === null ? null : { day: c.notices.day, count: c.notices.count, postIds: [...c.notices.postIds] },
    unpaidFlags: c.unpaidFlags.map((f) => Timestamp.fromDate(f)),
    recruitBlockedUntil: tsOf(c.recruitBlockedUntil),
  };
}

/** EMPTY_COUNTERS for a missing document; each missing field its empty value. */
export function countersFromDoc(d: DocumentData | undefined): RecruitCounters {
  if (!d) return EMPTY_COUNTERS;
  return {
    openPostCount: numOf(d.openPostCount),
    postActions: dailyOf(d.postActions),
    activeCollabCount: numOf(d.activeCollabCount),
    pendingInviteCount: numOf(d.pendingInviteCount),
    collabActions: dailyOf(d.collabActions),
    openApplicationCount: numOf(d.openApplicationCount),
    applyActions: dailyOf(d.applyActions),
    notices: noticesOf(d.notices),
    unpaidFlags: Array.isArray(d.unpaidFlags) ? d.unpaidFlags.map(dateOf).filter((x): x is Date => x !== null) : [],
    recruitBlockedUntil: dateOf(d.recruitBlockedUntil),
  };
}
