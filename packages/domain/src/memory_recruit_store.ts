import { RetryableConflict } from './event_ports.js';
import { EMPTY_COUNTERS, type RecruitApplication, type RecruitCounters, type RecruitPost } from './recruit.js';
import type { RecruitStore, RecruitTx } from './recruit_ports.js';

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
      putPost: (p) => write(() => { this.posts.set(p.id, p); }, `post:${p.id}`),
      putApplication: (a) => write(() => { this.applications.set(a.id, a); }, `app:${a.id}`),
      putCounters: (uid, c) => write(() => { this.counters.set(uid, c); }, `counters:${uid}`),
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
