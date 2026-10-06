import type { BadgeDefinition, BadgePlan } from './badge.js';
import type { BadgeStore, BadgeTx, EarnedBadge } from './badge_ports.js';

export class MemoryBadgeStore implements BadgeStore {
  /** uid → badgeId → earned. */
  readonly earned = new Map<string, Map<string, EarnedBadge>>();
  readonly progress = new Map<string, BadgePlan['progress']>();
  readonly catalog = new Map<string, BadgeDefinition>();
  /** Committed earned/progress write count. */
  writes = 0;

  earnedIds(uid: string): string[] {
    return [...(this.earned.get(uid)?.keys() ?? [])].sort();
  }

  seedEarned(uid: string, b: EarnedBadge): void {
    this.mine(uid).set(b.badgeId, b);
  }

  private mine(uid: string): Map<string, EarnedBadge> {
    let m = this.earned.get(uid);
    if (!m) {
      m = new Map();
      this.earned.set(uid, m);
    }
    return m;
  }

  async runTransaction<T>(fn: (tx: BadgeTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const stage = (apply: () => void): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        this.writes += 1;
      });
    };
    const tx: BadgeTx = {
      listEarned: async (uid) => {
        if (hasWritten) throw new Error('Transaction read after write: listEarned');
        return [...(this.earned.get(uid)?.values() ?? [])];
      },
      putEarned: (uid, b) => stage(() => void this.mine(uid).set(b.badgeId, b)),
      deleteEarned: (uid, id) => stage(() => void this.mine(uid).delete(id)),
      setProgress: (uid, p) => stage(() => void this.progress.set(uid, p)),
    };
    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }

  async holdersOlderThan(badgeId: string, cutoff: Date, limit: number, after: string | null = null): Promise<string[]> {
    const out: string[] = [];
    for (const [uid, m] of [...this.earned].sort(([a], [b]) => (a < b ? -1 : 1))) {
      if (after !== null && uid <= after) continue;
      const b = m.get(badgeId);
      if (b && b.awardedAt.getTime() < cutoff.getTime()) out.push(uid);
    }
    return out.slice(0, limit);
  }

  async syncCatalog(defs: readonly BadgeDefinition[]): Promise<number> {
    let n = 0;
    for (const d of defs) {
      const cur = this.catalog.get(d.id);
      if (!cur || JSON.stringify(cur) !== JSON.stringify(d)) {
        this.catalog.set(d.id, d);
        n += 1;
      }
    }
    return n;
  }
}
