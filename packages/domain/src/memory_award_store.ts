import type { Award, AwardProof, ReviewAction } from './award.js';
import type { AwardStore, AwardTx, TierState, TierStore, TierTx } from './award_ports.js';

export interface AuditRow {
  readonly awardId: string;
  readonly actorId: string;
  readonly action: ReviewAction;
  readonly note: string | null;
  readonly at: Date;
}

export class MemoryAwardStore implements AwardStore {
  readonly awards = new Map<string, Award>();
  readonly proofs = new Map<string, AwardProof>();
  readonly audit: AuditRow[] = [];
  readonly ownPosts = new Set<string>();
  /** Committed write count (awards, proofs, audit). */
  writes = 0;
  readonly tierStates = new Map<string, TierState>();
  /** Committed tier write count. */
  tierWrites = 0;

  seedAward(a: Award): void {
    this.awards.set(a.id, a);
  }

  seedProof(p: AwardProof): void {
    this.proofs.set(p.awardId, p);
  }

  /** `${photographerId}/${postId}` is a work post of that photographer. */
  seedOwnPost(photographerId: string, postId: string): void {
    this.ownPosts.add(`${photographerId}/${postId}`);
  }

  seedTier(uid: string, s: TierState): void {
    this.tierStates.set(uid, s);
  }

  readonly tiers: TierStore = {
    runTransaction: async <T>(fn: (tx: TierTx) => Promise<T>): Promise<T> => {
      const staged: Array<() => void> = [];
      let hasWritten = false;
      const guardRead = (name: string): void => {
        if (hasWritten) {
          throw new Error(`Transaction read after write: ${name} called after a write operation`);
        }
      };
      const tx: TierTx = {
        getTierState: async (uid) => {
          guardRead('getTierState');
          return this.tierStates.get(uid) ?? null;
        },
        countApproved: async (uid) => {
          guardRead('countApproved');
          return [...this.awards.values()].filter(
            (a) => a.photographerId === uid && a.status === 'approved',
          ).length;
        },
        setTierState: (uid, s) => {
          hasWritten = true;
          staged.push(() => {
            this.tierStates.set(uid, s);
            this.tierWrites += 1;
          });
        },
      };
      const result = await fn(tx);
      for (const apply of staged) apply();
      return result;
    },
  };

  async runTransaction<T>(fn: (tx: AwardTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const guardRead = (name: string): void => {
      if (hasWritten) {
        throw new Error(`Transaction read after write: ${name} called after a write operation`);
      }
    };
    const stage = (apply: () => void): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        this.writes += 1;
      });
    };

    const tx: AwardTx = {
      getAward: async (id) => {
        guardRead('getAward');
        return this.awards.get(id) ?? null;
      },
      getProof: async (awardId) => {
        guardRead('getProof');
        return this.proofs.get(awardId) ?? null;
      },
      countAwards: async (photographerId) => {
        guardRead('countAwards');
        return [...this.awards.values()].filter((a) => a.photographerId === photographerId).length;
      },
      isOwnWorkPost: async (postId, photographerId) => {
        guardRead('isOwnWorkPost');
        return this.ownPosts.has(`${photographerId}/${postId}`);
      },
      putAward: (a) => stage(() => void this.awards.set(a.id, a)),
      putProof: (p) => stage(() => void this.proofs.set(p.awardId, p)),
      deleteAward: (id) => stage(() => void this.awards.delete(id)),
      deleteProof: (awardId) => stage(() => void this.proofs.delete(awardId)),
      addAudit: (row) => stage(() => void this.audit.push(row)),
    };

    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }
}
