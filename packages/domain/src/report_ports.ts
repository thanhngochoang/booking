import type { BlockDeps } from './block_ports.js';
import type { Clock } from './ports.js';
import type { Report, ReportTargetType, ReportTargetView } from './report.js';

export interface ReportTx {
  getReport(id: string): Promise<Report | null>;
  getTarget(type: ReportTargetType, id: string, chatId: string | null): Promise<ReportTargetView | null>;
  isChatMember(chatId: string, uid: string): Promise<boolean>;
  getQuota(uid: string): Promise<{ day: string; count: number } | null>;
  putReport(r: Report): void;
  putQuota(uid: string, q: { day: string; count: number }): void;
}

export interface ReportStore {
  runTransaction<T>(fn: (tx: ReportTx) => Promise<T>): Promise<T>;
  list(status: Report['status'], limit: number): Promise<readonly Report[]>;
  get(id: string): Promise<Report | null>;
  decide(
    id: string,
    patch: Pick<Report, 'status' | 'staffNote' | 'decidedBy' | 'decidedAt'>,
  ): Promise<void>;
}

export interface ReportDeps {
  readonly store: ReportStore;
  readonly blocks: BlockDeps;
  readonly clock: Clock;
}
