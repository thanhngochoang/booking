/**
 * Ports of the S27 recruit use cases (plan #151 Contract): posts, applications and counters (Task 2),
 * collaborations and member-kind acceptance (Task 3), collab jobs, their sweep queries and the
 * `milestones` reader (Task 4).
 */

import type { BlockGate } from './block_ports.js';
import type { ProviderOrderGate } from './booking_ports.js';
import type { CollabJob, ShootMilestoneState } from './collab_jobs.js';
import type { NotifyDeps } from './notification_ports.js';
import type { Clock, IdGenerator } from './ports.js';
import type { ProviderType } from './provider_type.js';
import type { RecruitApplication, RecruitCounters, RecruitPost } from './recruit.js';
import type { Collaboration } from './studio_collaboration.js';
import type { MemberActivation, MemberActivationState } from './studio_membership.js';

/** `users/{uid}.role` + `photographers/{uid}` facts a recruit rule needs. */
export interface ProviderFacts {
  readonly uid: string;
  /** `users/{uid}.role` (`customer` | `photographer`); null when unknown. */
  readonly role: string | null;
  readonly providerType: ProviderType;
  readonly acceptsOrders: boolean;
  /** `photographers/{uid}.businessVerified === true` (#135); missing is false. */
  readonly businessVerified: boolean;
  readonly name: string;
  readonly avatarUrl: string | null;
}

/** S26's activation inputs for a pair, plus whether the pair already has an S26 invite or join request. */
export interface RecruitMemberState extends MemberActivationState {
  /** An `invited` or `requested` `studio_members` relation of the pair (S26 keeps one open relation per pair). */
  readonly pairOpen: boolean;
}

/**
 * One transaction. Every read comes before the first write (Firestore rule; the memory store throws on a
 * read after a write).
 */
export interface RecruitTx {
  getPost(id: string): Promise<RecruitPost | null>;
  getApplication(postId: string, uid: string): Promise<RecruitApplication | null>;
  /** The main `studio_collaborations/{studioId}_{uid}` document (the latest relationship), or null. */
  getCollaboration(studioId: string, uid: string): Promise<Collaboration | null>;
  /** EMPTY_COUNTERS when the document is missing. */
  getCounters(uid: string): Promise<RecruitCounters>;
  /** The studio `uid` is an active member of (S26 `photographers/{uid}.studioId`), or null. */
  activeMembershipStudioOf(uid: string): Promise<string | null>;
  /**
   * S26 state for making `uid` an active member of `studioId` (Decision 21): the member's lock and cooldown,
   * the studio's member count, business verification, open invites and quota, whether `uid` is an active
   * collaborator of the studio (read from `getCollaboration`'s document) and whether the pair has an open
   * S26 relation.
   */
  getMemberState(studioId: string, uid: string): Promise<RecruitMemberState>;
  /** `collab_jobs/{bookingId}_{uid}`, or null. */
  getCollabJob(bookingId: string, uid: string): Promise<CollabJob | null>;
  putPost(p: RecruitPost): void;
  putApplication(a: RecruitApplication): void;
  /** Writes the main collaboration document. */
  putCollaboration(c: Collaboration): void;
  /** Copies a terminal relationship to `studio_collaborations/{id}/history/{historyId}` (Decision 4). */
  archiveCollaboration(previous: Collaboration, historyId: string): void;
  putCounters(uid: string, c: RecruitCounters): void;
  /** S26's join writes (see `MemberActivation`): relation, member lock, studio memberCount +1, studio quota. */
  putMember(m: MemberActivation): void;
  putCollabJob(j: CollabJob): void;
}

export interface RecruitStore {
  runTransaction<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T>;
  /** Applications of the post still `applied`, oldest first. */
  appliedOf(postId: string, limit: number): Promise<RecruitApplication[]>;
  /** Posts still `open` with `expiresAt <= now`. */
  duePosts(now: Date, limit: number): Promise<RecruitPost[]>;
  /** Applications still `applied` with `expiresAt <= now`. */
  dueApplications(now: Date, limit: number): Promise<RecruitApplication[]>;
  /** Collaborations still `invited` with `expiresAt <= now`. */
  dueInvites(now: Date, limit: number): Promise<Collaboration[]>;
  /**
   * The pair's collab jobs that keep the collaboration from ending (`isOpenCollabJob`): `pending` or `accepted`
   * with `closedAt` null, or `payStatus` `disputed` ("đang khiếu nại", spec §4).
   */
  openJobCount(studioId: string, uid: string): Promise<number>;
  /** Jobs still `pending` with `offerExpiresAt <= now`, soonest first. */
  dueOffers(now: Date, limit: number): Promise<CollabJob[]>;
  /**
   * Jobs `accepted` with `payStatus` `none` and `pay.checkAfter <= now`, soonest `checkAfter` first (the sweep
   * then asks `milestones` and pushes a waiting job's `checkAfter` on, so newer jobs are reached).
   */
  payPending(now: Date, limit: number): Promise<CollabJob[]>;
  /** Jobs `due` with `pay.dueAt <= cutoff` and `pay.overdueFlaggedAt` null. */
  overduePay(cutoff: Date, limit: number): Promise<CollabJob[]>;
  /** Jobs `disputed` with `pay.disputeFlaggedAt` null. */
  unflaggedDisputes(limit: number): Promise<CollabJob[]>;
  /** Provider uids whose `recruitMatchKeys` contain any of `matchKeys` (≤ 20 values), at most `limit`. */
  matchingProviders(matchKeys: readonly string[], limit: number): Promise<string[]>;
}

export interface RecruitDeps {
  readonly store: RecruitStore;
  readonly people: { provider(uid: string): Promise<ProviderFacts | null> };
  readonly orders: ProviderOrderGate;
  /** #198's gate; the live deps use `liveBlockGate()`. */
  readonly blocks: BlockGate;
  /** Whether every id is a portfolio post of `uid` (an empty list is true). */
  readonly posts: { ownedBy(uid: string, postIds: readonly string[]): Promise<boolean> };
  /**
   * Where the booking's first (shoot) milestone stands (Decision 15): the adapter reads the booking's payments
   * with `shootMilestoneState`.
   */
  readonly milestones: { shootMilestone(bookingId: string): Promise<ShootMilestoneState> };
  readonly notify: NotifyDeps;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
