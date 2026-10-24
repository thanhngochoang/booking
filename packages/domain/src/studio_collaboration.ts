/**
 * S27 studio ↔ collaborator relationships (spec 2026-10-07-studio-recruiting-design.md §4; plan #151 Decisions
 * 4, 5, 12). Pure rules and the numbers; the use cases are in `collab_use_cases.ts`. The studio's daily action
 * cap `STUDIO_COLLAB_DAILY_ACTIONS` lives in `recruit.ts` (declining an application counts too).
 */

import { DomainError } from './errors.js';
import { isId } from './ids.js';
import type { ProviderFacts } from './recruit_ports.js';

export const COLLAB_STATUSES = ['invited', 'requested', 'active', 'declined', 'cancelled', 'expired', 'ended'] as const;
export type CollabStatus = (typeof COLLAB_STATUSES)[number];

export const COLLAB_INVITE_TTL_DAYS = 7,
  COLLAB_REINVITE_DAYS = 3,
  MAX_COLLABS_PER_COLLABORATOR = 5,
  MAX_COLLABORATORS_UNVERIFIED_BUSINESS = 5,
  MAX_COLLABORATORS_VERIFIED_BUSINESS = 50,
  MAX_PENDING_COLLAB_INVITES = 5,
  COLLABORATOR_DAILY_ACTIONS = 5,
  /** An ended collaboration keeps its chat readable this long (Decision 16). */
  COLLAB_CHAT_READ_DAYS = 30;

/** `invited` and the reserved `requested` wait for an answer; `active` is the relationship. */
export const OPEN_COLLAB_STATUSES: readonly CollabStatus[] = ['invited', 'requested', 'active'];

export interface CollabParty {
  readonly name: string;
  readonly avatarUrl: string | null;
}

/**
 * `studio_collaborations/{studioId}_{collaboratorId}`: always the latest relationship of the pair; an earlier
 * terminal one is copied to `history/{ulid}` when a new one starts (Decision 4).
 */
export interface Collaboration {
  readonly id: string;
  readonly studioId: string;
  readonly collaboratorId: string;
  readonly studio: CollabParty;
  readonly collaborator: CollabParty;
  readonly status: CollabStatus;
  /** `collaborator` is reserved with `requested` (no use case creates it yet). */
  readonly initiatedBy: 'studio' | 'collaborator' | 'application';
  readonly applicationId: string | null;
  /** Integer VND suggested when the studio assigns a booking; null = none. */
  readonly defaultFee: number | null;
  readonly termsAcceptedAt: Date | null;
  readonly createdAt: Date;
  /** createdAt + 7 days: when an unanswered invite expires. */
  readonly expiresAt: Date;
  readonly activeAt: Date | null;
  readonly endedAt: Date | null;
  readonly endedBy: 'studio' | 'collaborator' | 'system' | null;
  readonly updatedAt: Date;
}

export const collaborationId = (studioId: string, collaboratorId: string): string => `${studioId}_${collaboratorId}`;

/** Active collaborators a studio may have: 5, or 50 once its business is verified (#135). */
export function collaboratorLimit(businessVerified: boolean): number {
  return businessVerified ? MAX_COLLABORATORS_VERIFIED_BUSINESS : MAX_COLLABORATORS_UNVERIFIED_BUSINESS;
}

export const isOpenCollab = (c: Pick<Collaboration, 'status'>): boolean => OPEN_COLLAB_STATUSES.includes(c.status);

const DAY_MS = 24 * 60 * 60 * 1000;

/** A studio may invite the same photographer again 3 days after the collaboration ended (not after a decline). */
export function inCollabCooldown(c: Pick<Collaboration, 'status' | 'endedAt'>, now: Date): boolean {
  return c.status === 'ended' && c.endedAt !== null && now.getTime() < c.endedAt.getTime() + COLLAB_REINVITE_DAYS * DAY_MS;
}

/** An invite still `invited` past `expiresAt` (the sweep may not have reached it yet). */
export function isStaleInvite(c: Pick<Collaboration, 'status' | 'expiresAt'>, now: Date): boolean {
  return c.status === 'invited' && c.expiresAt.getTime() <= now.getTime();
}

/** A studio in photographer mode (Decision 12; verification is `ProviderOrderGate`'s). */
export const isCollabStudio = (p: ProviderFacts | null): p is ProviderFacts =>
  p !== null && p.role === 'photographer' && p.providerType === 'studio';

/** An individual or artist in photographer mode: the only ones who apply or collaborate (Decision 12). */
export const isCollaboratorAccount = (p: ProviderFacts | null): p is ProviderFacts =>
  p !== null && p.role === 'photographer' && (p.providerType === 'individual' || p.providerType === 'artist');

export const collabPartyOf = (p: ProviderFacts): CollabParty => ({ name: p.name, avatarUrl: p.avatarUrl });

/** The pair a caller names: `{studioId}` from the collaborator, `{collaboratorId}` from the studio. */
export interface CollabPair {
  readonly studioId: string;
  readonly collaboratorId: string;
  /** Which side the caller is on. */
  readonly side: 'studio' | 'collaborator';
}

/** Exactly one of `studioId` / `collaboratorId`, an id other than the caller's; `invalid_argument` otherwise. */
export function collabPairOf(callerId: string, raw: unknown): CollabPair {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) throw new DomainError('invalid_argument');
  const { studioId, collaboratorId } = raw as { studioId?: unknown; collaboratorId?: unknown };
  if (studioId !== undefined && collaboratorId === undefined) {
    if (!isId(studioId) || studioId === callerId) throw new DomainError('invalid_argument', 'studioId');
    return { studioId, collaboratorId: callerId, side: 'collaborator' };
  }
  if (collaboratorId !== undefined && studioId === undefined) {
    if (!isId(collaboratorId) || collaboratorId === callerId) throw new DomainError('invalid_argument', 'collaboratorId');
    return { studioId: callerId, collaboratorId, side: 'studio' };
  }
  throw new DomainError('invalid_argument');
}
