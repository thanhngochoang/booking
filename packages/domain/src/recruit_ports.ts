/**
 * Ports of the S27 recruit use cases (plan #151 Contract). Task 2 holds posts, applications and counters;
 * Tasks 3–4 add the collaboration, member and collab-job members to `RecruitTx`/`RecruitStore` and the
 * `milestones` reader to `RecruitDeps`.
 */

import type { BlockGate } from './block_ports.js';
import type { ProviderOrderGate } from './booking_ports.js';
import type { NotifyDeps } from './notification_ports.js';
import type { Clock, IdGenerator } from './ports.js';
import type { ProviderType } from './provider_type.js';
import type { RecruitApplication, RecruitCounters, RecruitPost } from './recruit.js';

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

/**
 * One transaction. Every read comes before the first write (Firestore rule; the memory store throws on a
 * read after a write).
 */
export interface RecruitTx {
  getPost(id: string): Promise<RecruitPost | null>;
  getApplication(postId: string, uid: string): Promise<RecruitApplication | null>;
  /** EMPTY_COUNTERS when the document is missing. */
  getCounters(uid: string): Promise<RecruitCounters>;
  /** The studio `uid` is an active member of (S26 `photographers/{uid}.studioId`), or null. */
  activeMembershipStudioOf(uid: string): Promise<string | null>;
  putPost(p: RecruitPost): void;
  putApplication(a: RecruitApplication): void;
  putCounters(uid: string, c: RecruitCounters): void;
}

export interface RecruitStore {
  runTransaction<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T>;
  /** Applications of the post still `applied`, oldest first. */
  appliedOf(postId: string, limit: number): Promise<RecruitApplication[]>;
  /** Posts still `open` with `expiresAt <= now`. */
  duePosts(now: Date, limit: number): Promise<RecruitPost[]>;
  /** Applications still `applied` with `expiresAt <= now`. */
  dueApplications(now: Date, limit: number): Promise<RecruitApplication[]>;
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
  readonly notify: NotifyDeps;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
