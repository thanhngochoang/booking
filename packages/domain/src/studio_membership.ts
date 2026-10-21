import { foldVietnamese } from './event_hashtag.js';
import type { ProviderType } from './provider_type.js';
import { vnDayKey } from './verification.js';

// S26 studio membership rules (spec 2026-10-06-studio-members-design.md §3.3). One place to change the numbers.

export const INVITE_TTL_DAYS = 7,
  COOLDOWN_DAYS = 7,
  MAX_MEMBERS_UNVERIFIED = 3,
  MAX_MEMBERS_VERIFIED = 30,
  MAX_PENDING_INVITES = 5,
  STUDIO_DAILY_ACTIONS = 5,
  MEMBER_DAILY_ACTIONS = 3;

export const RELATION_STATUSES = [
  'invited',
  'requested',
  'active',
  'declined',
  'cancelled',
  'expired',
  'left',
  'removed',
] as const;
export type RelationStatus = (typeof RELATION_STATUSES)[number];
export const OPEN_RELATION_STATUSES: readonly RelationStatus[] = ['invited', 'requested', 'active'];

/** `studio_members/{id}`: one document per relation; a relation that ends and starts again gets a new id. */
export interface StudioRelation {
  id: string;
  studioId: string;
  memberId: string;
  status: RelationStatus;
  initiatedBy: 'studio' | 'member';
  createdAt: string;
  expiresAt: string;
  respondedAt: string | null;
  joinedAt: string | null;
  endedAt: string | null;
  endedBy: 'member' | 'studio' | 'system' | null;
  expiringNotifiedAt: string | null;
  studioName: string;
  studioAvatarUrl: string | null;
  memberName: string;
  memberAvatarUrl: string | null;
  version: number;
}

/** `photographers/{uid}` membership fields + `users/{uid}` name and avatar. */
export interface StudioProfile {
  uid: string;
  providerType: ProviderType;
  onboardingComplete: boolean;
  businessVerified: boolean;
  /** Studio: active members. */
  memberCount: number;
  /** Member: the studio they are active in (the lock both studios write). */
  studioId: string | null;
  studioCooldownUntil: string | null;
  name: string;
  avatarUrl: string | null;
}

/** `studio_quota/{uid}`: actions counted on the Vietnam day `dayKey`. */
export interface DailyQuota {
  dayKey: string;
  studioActions: number;
  memberActions: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;

const CLOSED_BOOKING_STATUSES: readonly string[] = ['declined', 'expired', 'cancelled', 'completed', 'reviewed'];

/** `{studioId}_{memberId}_{createdAtMs}` (Decision 1). Longer than `isId`'s 64 characters with real uids. */
export function relationId(studioId: string, memberId: string, createdAt: Date): string {
  return `${studioId}_${memberId}_${createdAt.getTime()}`;
}

export function maxMembers(studio: Pick<StudioProfile, 'businessVerified'>): number {
  return studio.businessVerified ? MAX_MEMBERS_VERIFIED : MAX_MEMBERS_UNVERIFIED;
}

/** individual or artist, with a finished profile. */
export function canJoinAsMember(p: StudioProfile): boolean {
  return (p.providerType === 'individual' || p.providerType === 'artist') && p.onboardingComplete;
}

/** A studio that may invite and approve. */
export function isStudio(p: StudioProfile): boolean {
  return p.providerType === 'studio' && p.onboardingComplete;
}

export function inCooldown(p: Pick<StudioProfile, 'studioCooldownUntil'>, now: Date): boolean {
  return p.studioCooldownUntil !== null && now.getTime() < Date.parse(p.studioCooldownUntil);
}

/** The instant a member who left or was removed at `endedAt` may be active again. */
export function cooldownUntil(endedAt: Date): string {
  return new Date(endedAt.getTime() + COOLDOWN_DAYS * DAY_MS).toISOString();
}

export function inviteExpiresAt(createdAt: Date): string {
  return new Date(createdAt.getTime() + INVITE_TTL_DAYS * DAY_MS).toISOString();
}

const dailyMax = (side: 'studio' | 'member'): number =>
  side === 'studio' ? STUDIO_DAILY_ACTIONS : MEMBER_DAILY_ACTIONS;

/** Actions left today (Vietnam day; a stored quota of another day counts as unused). */
export function quotaLeft(q: DailyQuota | null, side: 'studio' | 'member', now: Date): number {
  if (q === null || q.dayKey !== vnDayKey(now)) return dailyMax(side);
  const used = side === 'studio' ? q.studioActions : q.memberActions;
  return Math.max(0, dailyMax(side) - used);
}

/** The quota after one more action of `side` today. */
export function spendQuota(q: DailyQuota | null, side: 'studio' | 'member', now: Date): DailyQuota {
  const dayKey = vnDayKey(now);
  const base = q !== null && q.dayKey === dayKey ? q : { dayKey, studioActions: 0, memberActions: 0 };
  return side === 'studio'
    ? { ...base, studioActions: base.studioActions + 1 }
    : { ...base, memberActions: base.memberActions + 1 };
}

/** A studio booking still holding its assignee (Decision 6): every status but the closed ones. */
export function isOpenBookingStatus(s: string): boolean {
  return !CLOSED_BOOKING_STATUSES.includes(s);
}

/** `photographers.nameKey` for the invite search (Decision 19). */
export function foldNameKey(displayName: string): string {
  return foldVietnamese(displayName.trim()).toLowerCase();
}

/** A photographer row of the invite search (S26.02, Decision 19). */
export type InviteCandidateState = 'invitable' | 'in_studio' | 'cooldown' | 'invited' | 'member';

/**
 * Whether studio `studioId` can invite this photographer now: already ours, active elsewhere, in the 7-day
 * cooldown, or with an open invite or join request of the pair (an unswept invite past `expiresAt` no longer
 * counts). `open` is the pair's invited or requested relation, if any.
 */
export function inviteCandidateState(
  studioId: string,
  p: Pick<StudioProfile, 'studioId' | 'studioCooldownUntil'>,
  open: Pick<StudioRelation, 'status' | 'expiresAt'> | null,
  now: Date,
): InviteCandidateState {
  if (p.studioId === studioId) return 'member';
  if (p.studioId !== null) return 'in_studio';
  if (inCooldown(p, now)) return 'cooldown';
  if (open !== null && (open.status === 'invited' || open.status === 'requested') && Date.parse(open.expiresAt) > now.getTime()) {
    return 'invited';
  }
  return 'invitable';
}
