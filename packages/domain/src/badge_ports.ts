import type { BadgeDefinition, BadgeMetric, BadgePlan, Metrics } from './badge.js';
import type { NotifyDeps } from './notification_ports.js';
import type { Clock } from './ports.js';

export interface EarnedBadge {
  readonly badgeId: string;
  readonly awardedAt: Date;
  readonly snapshotText: string;
}

export interface BadgeTx {
  listEarned(uid: string): Promise<EarnedBadge[]>;
  /** `users/{uid}/badges/{badgeId}` `{badgeId, uid, awardedAt, snapshot:{text}}`. */
  putEarned(uid: string, b: EarnedBadge): void;
  deleteEarned(uid: string, badgeId: string): void;
  /** Overwrites `users/{uid}/private/badgeProgress`. */
  setProgress(uid: string, p: BadgePlan['progress'], at: Date): void;
}

export interface BadgeStore {
  runTransaction<T>(fn: (tx: BadgeTx) => Promise<T>): Promise<T>;
  /** Uids that hold `badgeId` awarded before `cutoff`. */
  holdersOlderThan(badgeId: string, cutoff: Date, limit: number): Promise<string[]>;
  /** Writes only the catalogue docs that differ; returns how many were written. */
  syncCatalog(defs: readonly BadgeDefinition[]): Promise<number>;
}

export interface BadgeMetricsReader {
  isPhotographer(uid: string): Promise<boolean>;
  read(uid: string, metrics: ReadonlySet<BadgeMetric>): Promise<Metrics>;
}

export interface BadgeDeps {
  readonly badges: BadgeStore;
  readonly metrics: BadgeMetricsReader;
  readonly notify: NotifyDeps;
  readonly clock: Clock;
}
