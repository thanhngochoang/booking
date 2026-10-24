import type { Clock, IdGenerator } from './ports.js';
import type { DailyQuota, StudioProfile, StudioRelation } from './studio_membership.js';

/**
 * One membership transaction. All reads come before the first write (Firestore rule). The member's
 * `photographers/{memberId}` document is the lock both studios write, so two accepts cannot both win.
 */
export interface StudioTx {
  /** `photographers/{uid}` + `users/{uid}` name/avatar; null when there is no photographer document. */
  getProfile(uid: string): Promise<StudioProfile | null>;
  getRelation(id: string): Promise<StudioRelation | null>;
  /** The pair's relation in invited | requested | active, if any (at most one by construction). */
  openRelationOf(studioId: string, memberId: string): Promise<StudioRelation | null>;
  /** Relations of the studio in `invited` with expiresAt > now (a stale invite frees its seat before the sweep). */
  countOpenInvites(studioId: string, now: Date): Promise<number>;
  /** Bookings with photographerId == studio, assigneeId == member, isOpenBookingStatus (Decision 6). */
  countOpenAssignments(studioId: string, memberId: string): Promise<number>;
  /**
   * #194 Decision 7: the studio's `open` spot schedules naming the member as assignee with a day >= `today`
   * (yyyy-MM-dd, Vietnam). At most 8 open schedules per provider.
   */
  countOpenSpotSchedules(studioId: string, memberId: string, today: string): Promise<number>;
  getQuota(uid: string): Promise<DailyQuota | null>;
  /**
   * S27 (#151 Decision 12): whether `uid` is an `active` collaborator of `studioId`
   * (`studio_collaborations/{studioId}_{uid}`); such a photographer cannot become a member of that studio.
   */
  activeCollaborationOf(studioId: string, uid: string): Promise<boolean>;
  putRelation(r: StudioRelation): void;
  /** `studioCooldownUntil` left out keeps the stored value. */
  setMemberStudio(
    memberId: string,
    patch: { studioId: string | null; studioJoinedAt: string | null; studioCooldownUntil?: string | null },
  ): void;
  addMemberCount(studioId: string, delta: 1 | -1): void;
  putQuota(uid: string, q: DailyQuota): void;
}

export interface StudioStore {
  runTransaction<T>(fn: (tx: StudioTx) => Promise<T>): Promise<T>;
  /**
   * Relations with sweep work, soonest `expiresAt` first: invited | requested with expiresAt <= now (to expire),
   * and invited with expiringNotifiedAt == null and expiresAt <= now + 24 h (to announce). An adapter runs one
   * query for each and merges them; the domain filters again (`sweepActionOf`).
   */
  dueRelations(now: Date, limit: number): Promise<StudioRelation[]>;
}

/** `member` (S26) or `collaborator` (S27 #151: an active collaboration, offer accepted within 6 hours). */
export type AssigneeKind = 'member' | 'collaborator';

export interface StudioRoster {
  /**
   * How `uid` may work for `studioId` today; null = may not be assigned. `assignBooking` uses it for members only:
   * a collaborator offer names its kind and is checked against the collaboration inside the transaction.
   */
  relationOf(studioId: string, uid: string): Promise<AssigneeKind | null>;
  person(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>;
}

export interface StudioDeps {
  readonly studios: StudioStore;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
