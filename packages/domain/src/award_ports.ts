import type { Award, AwardProof, AwardStatus, ReviewAction } from './award.js';
import type { Clock } from './ports.js';
import type { ProviderType } from './provider_type.js';

export interface TierState {
  readonly providerType: ProviderType;
  readonly artistSince: Date | null;
  readonly approvedAwardCount: number;
}

export interface AwardTx {
  getAward(id: string): Promise<Award | null>;
  getProof(awardId: string): Promise<AwardProof | null>;
  countAwards(photographerId: string): Promise<number>;
  isOwnWorkPost(postId: string, photographerId: string): Promise<boolean>;
  putAward(a: Award): void;
  putProof(p: AwardProof): void;
  deleteAward(id: string): void;
  deleteProof(awardId: string): void;
  addAudit(row: { awardId: string; actorId: string; action: ReviewAction; note: string | null; at: Date }): void;
}

export interface TierTx {
  getTierState(uid: string): Promise<TierState | null>;
  countApproved(uid: string): Promise<number>;
  setTierState(uid: string, s: TierState): void;
}

export interface AwardStore {
  runTransaction<T>(fn: (tx: AwardTx) => Promise<T>): Promise<T>;
}

export interface TierStore {
  runTransaction<T>(fn: (tx: TierTx) => Promise<T>): Promise<T>;
}

export interface AwardDeps {
  readonly awards: AwardStore;
  readonly tiers: TierStore;
  readonly files: { delete(paths: readonly string[]): Promise<void> };
  readonly notify: {
    tierChanged(uid: string, to: 'artist' | 'individual'): Promise<void>;
    awardReviewed(uid: string, awardId: string, status: AwardStatus): Promise<void>;
  };
  readonly clock: Clock;
}
