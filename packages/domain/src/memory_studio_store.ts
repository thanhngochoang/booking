import {
  OPEN_RELATION_STATUSES,
  type DailyQuota,
  type StudioProfile,
  type StudioRelation,
} from './studio_membership.js';
import type { StudioStore, StudioTx } from './studio_ports.js';
import { scheduleReachesDay } from './spot_schedule.js';

const DUE_WINDOW_MS = 24 * 60 * 60 * 1000;

export class MemoryStudioStore implements StudioStore {
  readonly profiles = new Map<string, StudioProfile>();
  /** `photographers/{uid}.studioJoinedAt` (written with `studioId`). */
  readonly studioJoinedAt = new Map<string, string | null>();
  readonly relations = new Map<string, StudioRelation>();
  readonly quotas = new Map<string, DailyQuota>();
  /** Seed: open studio bookings assigned to a member, key `${studioId}/${memberId}`. */
  readonly openAssignments = new Map<string, number>();
  /** Seed (#194): the days of each open spot schedule naming a member, key `${studioId}/${memberId}`. */
  readonly openSpotScheduleDays = new Map<string, string[][]>();
  /** Seed (S27): pairs `${studioId}_${uid}` with an active collaboration. */
  readonly activeCollaborations = new Set<string>();
  /** Committed write count. */
  writes = 0;
  /** Transactions opened (committed or not). */
  transactions = 0;

  private chain: Promise<unknown> = Promise.resolve();

  seedProfile(p: StudioProfile): void {
    this.profiles.set(p.uid, p);
  }

  seedActiveCollaboration(studioId: string, uid: string): void {
    this.activeCollaborations.add(`${studioId}_${uid}`);
  }

  setOpenAssignments(studioId: string, memberId: string, n: number): void {
    this.openAssignments.set(`${studioId}/${memberId}`, n);
  }

  /** Adds one open spot schedule of `studioId` assigned to `memberId` with these days (#194). */
  addOpenSpotSchedule(studioId: string, memberId: string, days: string[]): void {
    const key = `${studioId}/${memberId}`;
    this.openSpotScheduleDays.set(key, [...(this.openSpotScheduleDays.get(key) ?? []), days]);
  }

  async dueRelations(now: Date, limit: number): Promise<StudioRelation[]> {
    const until = now.getTime() + DUE_WINDOW_MS;
    return [...this.relations.values()]
      .filter((r) => {
        const at = Date.parse(r.expiresAt);
        if (r.status !== 'invited' && r.status !== 'requested') return false;
        return at <= now.getTime() || (r.status === 'invited' && r.expiringNotifiedAt === null && at <= until);
      })
      .sort((a, b) => Date.parse(a.expiresAt) - Date.parse(b.expiresAt))
      .slice(0, limit);
  }

  /** Transactions run one at a time, like Firestore retrying a conflict on the member's document. */
  runTransaction<T>(fn: (tx: StudioTx) => Promise<T>): Promise<T> {
    const run = this.chain.then(() => this.execute(fn));
    this.chain = run.catch(() => undefined);
    return run;
  }

  private async execute<T>(fn: (tx: StudioTx) => Promise<T>): Promise<T> {
    this.transactions += 1;
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const guardRead = (name: string): void => {
      if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
    };
    const write = (apply: () => void): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        this.writes += 1;
      });
    };

    const tx: StudioTx = {
      getProfile: async (uid) => {
        guardRead('getProfile');
        return this.profiles.get(uid) ?? null;
      },
      getRelation: async (id) => {
        guardRead('getRelation');
        return this.relations.get(id) ?? null;
      },
      openRelationOf: async (studioId, memberId) => {
        guardRead('openRelationOf');
        return (
          [...this.relations.values()].find(
            (r) => r.studioId === studioId && r.memberId === memberId && OPEN_RELATION_STATUSES.includes(r.status),
          ) ?? null
        );
      },
      countOpenInvites: async (studioId, now) => {
        guardRead('countOpenInvites');
        return [...this.relations.values()].filter(
          (r) => r.studioId === studioId && r.status === 'invited' && Date.parse(r.expiresAt) > now.getTime(),
        ).length;
      },
      countOpenAssignments: async (studioId, memberId) => {
        guardRead('countOpenAssignments');
        return this.openAssignments.get(`${studioId}/${memberId}`) ?? 0;
      },
      countOpenSpotSchedules: async (studioId, memberId, today) => {
        guardRead('countOpenSpotSchedules');
        return (this.openSpotScheduleDays.get(`${studioId}/${memberId}`) ?? []).filter((days) =>
          scheduleReachesDay({ days }, today),
        ).length;
      },
      getQuota: async (uid) => {
        guardRead('getQuota');
        return this.quotas.get(uid) ?? null;
      },
      activeCollaborationOf: async (studioId, uid) => {
        guardRead('activeCollaborationOf');
        return this.activeCollaborations.has(`${studioId}_${uid}`);
      },
      putRelation: (r) => write(() => this.relations.set(r.id, r)),
      setMemberStudio: (memberId, patch) =>
        write(() => {
          const p = this.profiles.get(memberId);
          if (p === undefined) return;
          this.profiles.set(memberId, {
            ...p,
            studioId: patch.studioId,
            studioCooldownUntil:
              patch.studioCooldownUntil === undefined ? p.studioCooldownUntil : patch.studioCooldownUntil,
          });
          this.studioJoinedAt.set(memberId, patch.studioJoinedAt);
        }),
      addMemberCount: (studioId, delta) =>
        write(() => {
          const p = this.profiles.get(studioId);
          if (p === undefined) return;
          this.profiles.set(studioId, { ...p, memberCount: Math.max(0, p.memberCount + delta) });
        }),
      putQuota: (uid, q) => write(() => this.quotas.set(uid, q)),
    };

    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }
}
