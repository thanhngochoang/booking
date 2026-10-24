import { collabJobId, isOpenCollabJob, type CollabJob } from './collab_jobs.js';
import { RetryableConflict } from './event_ports.js';
import { EMPTY_COUNTERS, type RecruitApplication, type RecruitCounters, type RecruitPost } from './recruit.js';
import type { RecruitMemberState, RecruitStore, RecruitTx } from './recruit_ports.js';
import { collaborationId, type Collaboration } from './studio_collaboration.js';
import type { DailyQuota, StudioRelation } from './studio_membership.js';

/** Like the Firestore adapter: a transaction that lost a race is run again a few times. */
const MAX_TX_ATTEMPTS = 5;

/**
 * In-memory `RecruitStore` for tests and emulators. Transactions use optimistic concurrency (every
 * document read is checked again at commit) and refuse a read after a write, like `memory_event_store.ts`.
 */
export class MemoryRecruitStore implements RecruitStore {
  readonly posts = new Map<string, RecruitPost>();
  /** Keyed by `${postId}_${applicantId}`. */
  readonly applications = new Map<string, RecruitApplication>();
  readonly counters = new Map<string, RecruitCounters>();
  /** uid → studio the photographer is an active member of (S26). */
  readonly memberships = new Map<string, string>();
  /** uid → `photographers/{uid}.recruitMatchKeys`, in insertion order. */
  readonly matchKeys = new Map<string, readonly string[]>();
  /** Main `studio_collaborations` documents, keyed `${studioId}_${uid}`. */
  readonly collaborations = new Map<string, Collaboration>();
  /** `studio_collaborations/{id}/history/{historyId}` copies, keyed by the main id, oldest first. */
  readonly collabHistory = new Map<string, Array<{ readonly historyId: string; readonly collaboration: Collaboration }>>();
  /** `collab_jobs`, keyed `${bookingId}_${collaboratorId}`. */
  readonly collabJobs = new Map<string, CollabJob>();
  /** S26 `photographers/{uid}.studioCooldownUntil`. */
  readonly cooldowns = new Map<string, string>();
  /** S26 studio facts: `photographers/{studioId}.memberCount` and `businessVerified`. */
  readonly studios = new Map<string, { readonly memberCount: number; readonly businessVerified: boolean }>();
  /** Seed: the studio's S26 invites still open. */
  readonly openInvites = new Map<string, number>();
  /** S26 `studio_quota/{uid}`. */
  readonly studioQuotas = new Map<string, DailyQuota>();
  /** Seed: pairs `${studioId}_${uid}` with an invited or requested S26 relation. */
  readonly openPairs = new Set<string>();
  /** `studio_members` written through `putMember`, by relation id. */
  readonly members = new Map<string, StudioRelation & { readonly applicationId: string | null }>();
  /** Committed write count. */
  writes = 0;
  /** Number of transaction attempts that were retried. */
  retries = 0;
  private readonly revs = new Map<string, number>();

  private rev(key: string): number {
    return this.revs.get(key) ?? 0;
  }

  private bump(key: string): void {
    this.revs.set(key, this.rev(key) + 1);
  }

  /** Counters of `uid` as stored, or EMPTY_COUNTERS. */
  countersOf(uid: string): RecruitCounters {
    return this.counters.get(uid) ?? EMPTY_COUNTERS;
  }

  /** Merges `patch` into the stored counters of `uid`. */
  seedCounters(uid: string, patch: Partial<RecruitCounters>): void {
    this.counters.set(uid, { ...this.countersOf(uid), ...patch });
    this.bump(`counters:${uid}`);
  }

  seedMembership(uid: string, studioId: string): void {
    this.memberships.set(uid, studioId);
    this.bump(`member:${uid}`);
  }

  seedMatchKeys(uid: string, keys: readonly string[]): void {
    this.matchKeys.set(uid, keys);
  }

  seedCollaboration(c: Collaboration): void {
    this.collaborations.set(c.id, c);
    this.bump(`collab:${c.id}`);
  }

  seedCollabJob(j: CollabJob): void {
    this.collabJobs.set(j.id, j);
    this.bump(`job:${j.id}`);
  }

  /**
   * A collab job written by another store's transaction (the booking store's assignment transaction: on
   * Firestore both are one transaction). Counts as a committed write for this store's concurrency checks.
   */
  writeCollabJob(j: CollabJob): void {
    this.collabJobs.set(j.id, j);
    this.bump(`job:${j.id}`);
    this.writes += 1;
  }

  /** S26 facts of a studio (defaults: 0 members, not business-verified). */
  seedStudio(studioId: string, patch: { memberCount?: number; businessVerified?: boolean; openInvites?: number }): void {
    const cur = this.studioOf(studioId);
    this.studios.set(studioId, {
      memberCount: patch.memberCount ?? cur.memberCount,
      businessVerified: patch.businessVerified ?? cur.businessVerified,
    });
    if (patch.openInvites !== undefined) this.openInvites.set(studioId, patch.openInvites);
    this.bump(`studio:${studioId}`);
  }

  seedCooldown(uid: string, until: string): void {
    this.cooldowns.set(uid, until);
    this.bump(`member:${uid}`);
  }

  seedStudioQuota(uid: string, q: DailyQuota): void {
    this.studioQuotas.set(uid, q);
    this.bump(`quota:${uid}`);
  }

  seedOpenPair(studioId: string, uid: string): void {
    this.openPairs.add(collaborationId(studioId, uid));
  }

  private studioOf(studioId: string): { memberCount: number; businessVerified: boolean } {
    return this.studios.get(studioId) ?? { memberCount: 0, businessVerified: false };
  }

  async runTransaction<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await this.attempt(fn);
      } catch (e) {
        if (!(e instanceof RetryableConflict) || attempt >= MAX_TX_ATTEMPTS) throw e;
        this.retries += 1;
      }
    }
  }

  private async attempt<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    const seen = new Map<string, number>();
    let hasWritten = false;
    const read = (name: string, key: string): void => {
      if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
      if (!seen.has(key)) seen.set(key, this.rev(key));
    };
    const write = (apply: () => void, key: string): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        this.bump(key);
        this.writes += 1;
      });
    };

    const tx: RecruitTx = {
      getPost: async (id) => {
        read('getPost', `post:${id}`);
        return this.posts.get(id) ?? null;
      },
      getApplication: async (postId, uid) => {
        read('getApplication', `app:${postId}_${uid}`);
        return this.applications.get(`${postId}_${uid}`) ?? null;
      },
      getCounters: async (uid) => {
        read('getCounters', `counters:${uid}`);
        return this.countersOf(uid);
      },
      activeMembershipStudioOf: async (uid) => {
        read('activeMembershipStudioOf', `member:${uid}`);
        return this.memberships.get(uid) ?? null;
      },
      getCollaboration: async (studioId, uid) => {
        const id = collaborationId(studioId, uid);
        read('getCollaboration', `collab:${id}`);
        return this.collaborations.get(id) ?? null;
      },
      getMemberState: async (studioId, uid): Promise<RecruitMemberState> => {
        const pair = collaborationId(studioId, uid);
        for (const key of [`member:${uid}`, `studio:${studioId}`, `quota:${studioId}`, `collab:${pair}`]) {
          read('getMemberState', key);
        }
        return {
          member: { studioId: this.memberships.get(uid) ?? null, studioCooldownUntil: this.cooldowns.get(uid) ?? null },
          studio: this.studioOf(studioId),
          openInvites: this.openInvites.get(studioId) ?? 0,
          quota: this.studioQuotas.get(studioId) ?? null,
          activeCollabWithStudio: this.collaborations.get(pair)?.status === 'active',
          pairOpen: this.openPairs.has(pair),
        };
      },
      getCollabJob: async (bookingId, uid) => {
        const id = collabJobId(bookingId, uid);
        read('getCollabJob', `job:${id}`);
        return this.collabJobs.get(id) ?? null;
      },
      putPost: (p) => write(() => { this.posts.set(p.id, p); }, `post:${p.id}`),
      putApplication: (a) => write(() => { this.applications.set(a.id, a); }, `app:${a.id}`),
      putCollaboration: (c) => write(() => { this.collaborations.set(c.id, c); }, `collab:${c.id}`),
      archiveCollaboration: (previous, historyId) => write(() => {
        this.collabHistory.set(previous.id, [...(this.collabHistory.get(previous.id) ?? []), { historyId, collaboration: previous }]);
      }, `collabHistory:${previous.id}/${historyId}`),
      putCounters: (uid, c) => write(() => { this.counters.set(uid, c); }, `counters:${uid}`),
      putMember: (m) => {
        const { studioId, memberId } = m.relation;
        write(() => { this.members.set(m.relation.id, { ...m.relation, applicationId: m.applicationId }); }, `relation:${m.relation.id}`);
        write(() => { this.memberships.set(memberId, studioId); }, `member:${memberId}`);
        write(() => {
          const cur = this.studioOf(studioId);
          this.studios.set(studioId, { ...cur, memberCount: cur.memberCount + 1 });
        }, `studio:${studioId}`);
        write(() => { this.studioQuotas.set(studioId, m.quota); }, `quota:${studioId}`);
      },
      putCollabJob: (j) => write(() => { this.collabJobs.set(j.id, j); }, `job:${j.id}`),
    };

    const result = await fn(tx);
    // Commit: nothing read may have changed under us, then apply without yielding.
    for (const [k, r] of seen) if (this.rev(k) !== r) throw new RetryableConflict();
    for (const apply of staged) apply();
    return result;
  }

  async appliedOf(postId: string, limit: number): Promise<RecruitApplication[]> {
    return [...this.applications.values()]
      .filter((a) => a.postId === postId && a.status === 'applied')
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
      .slice(0, limit);
  }

  async duePosts(now: Date, limit: number): Promise<RecruitPost[]> {
    return [...this.posts.values()]
      .filter((p) => p.status === 'open' && p.expiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async dueApplications(now: Date, limit: number): Promise<RecruitApplication[]> {
    return [...this.applications.values()]
      .filter((a) => a.status === 'applied' && a.expiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async dueInvites(now: Date, limit: number): Promise<Collaboration[]> {
    return [...this.collaborations.values()]
      .filter((c) => c.status === 'invited' && c.expiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async openJobCount(studioId: string, uid: string): Promise<number> {
    return [...this.collabJobs.values()]
      .filter((j) => j.studioId === studioId && j.collaboratorId === uid && isOpenCollabJob(j)).length;
  }

  async dueOffers(now: Date, limit: number): Promise<CollabJob[]> {
    return [...this.collabJobs.values()]
      .filter((j) => j.offerStatus === 'pending' && j.offerExpiresAt.getTime() <= now.getTime())
      .sort((a, b) => a.offerExpiresAt.getTime() - b.offerExpiresAt.getTime())
      .slice(0, limit);
  }

  async payPending(now: Date, limit: number): Promise<CollabJob[]> {
    return [...this.collabJobs.values()]
      .filter((j) => j.offerStatus === 'accepted' && j.payStatus === 'none' && j.pay.checkAfter !== null
        && j.pay.checkAfter.getTime() <= now.getTime())
      .sort((a, b) => (a.pay.checkAfter?.getTime() ?? 0) - (b.pay.checkAfter?.getTime() ?? 0))
      .slice(0, limit);
  }

  async overduePay(cutoff: Date, limit: number): Promise<CollabJob[]> {
    return [...this.collabJobs.values()]
      .filter((j) => j.payStatus === 'due' && j.pay.dueAt !== null && j.pay.dueAt.getTime() <= cutoff.getTime()
        && j.pay.overdueFlaggedAt === null)
      .slice(0, limit);
  }

  async unflaggedDisputes(limit: number): Promise<CollabJob[]> {
    return [...this.collabJobs.values()]
      .filter((j) => j.payStatus === 'disputed' && j.pay.disputeFlaggedAt === null)
      .slice(0, limit);
  }

  async matchingProviders(matchKeys: readonly string[], limit: number): Promise<string[]> {
    const wanted = new Set(matchKeys);
    const uids: string[] = [];
    for (const [uid, keys] of this.matchKeys) {
      if (uids.length >= limit) break;
      if (keys.some((k) => wanted.has(k))) uids.push(uid);
    }
    return uids;
  }
}
