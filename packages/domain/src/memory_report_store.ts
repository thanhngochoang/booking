import type { Report, ReportStatus, ReportTargetType, ReportTargetView } from './report.js';
import type { ReportStore, ReportTx } from './report_ports.js';

export class MemoryReportStore implements ReportStore {
  readonly reports = new Map<string, Report>();
  readonly quotas = new Map<string, { day: string; count: number }>();
  readonly targets = new Map<string, ReportTargetView>(); // key: `${type}_${targetId}` or `${type}_${chatId}~${targetId}`
  readonly chatMembers = new Map<string, Set<string>>(); // chatId -> Set<uid>

  private lock: Promise<void> = Promise.resolve();

  setTarget(target: ReportTargetView): void {
    const key = target.type === 'message'
      ? `${target.type}_${target.chatId}~${target.id}`
      : `${target.type}_${target.id}`;
    this.targets.set(key, target);
  }

  setChatMember(chatId: string, uid: string): void {
    let members = this.chatMembers.get(chatId);
    if (!members) {
      members = new Set();
      this.chatMembers.set(chatId, members);
    }
    members.add(uid);
  }

  async runTransaction<T>(fn: (tx: ReportTx) => Promise<T>): Promise<T> {
    const nextLock = this.lock.then(async () => {
      let hasWritten = false;
      const stagedReports = new Map<string, Report>();
      const stagedQuotas = new Map<string, { day: string; count: number }>();

      const tx: ReportTx = {
        getReport: async (id: string): Promise<Report | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const r = this.reports.get(id);
          return r ? { ...r } : null;
        },
        getTarget: async (type: ReportTargetType, id: string, chatId: string | null): Promise<ReportTargetView | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const key = type === 'message' ? `${type}_${chatId}~${id}` : `${type}_${id}`;
          const t = this.targets.get(key);
          return t ? { ...t } : null;
        },
        isChatMember: async (chatId: string, uid: string): Promise<boolean> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const members = this.chatMembers.get(chatId);
          return members?.has(uid) ?? false;
        },
        getQuota: async (uid: string): Promise<{ day: string; count: number } | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const q = this.quotas.get(uid);
          return q ? { ...q } : null;
        },
        putReport: (r: Report): void => {
          hasWritten = true;
          stagedReports.set(r.id, { ...r });
        },
        putQuota: (uid: string, q: { day: string; count: number }): void => {
          hasWritten = true;
          stagedQuotas.set(uid, { ...q });
        },
      };

      const result = await fn(tx);

      // Commit staged writes
      for (const [id, r] of stagedReports) {
        this.reports.set(id, r);
      }
      for (const [uid, q] of stagedQuotas) {
        this.quotas.set(uid, q);
      }

      return result;
    });

    this.lock = nextLock.then(
      () => {},
      () => {},
    );
    return nextLock;
  }

  async list(status: ReportStatus, limit: number): Promise<readonly Report[]> {
    const matched: Report[] = [];
    for (const r of this.reports.values()) {
      if (r.status === status) {
        matched.push({ ...r });
        if (matched.length >= limit) break;
      }
    }
    return matched;
  }

  async get(id: string): Promise<Report | null> {
    const r = this.reports.get(id);
    return r ? { ...r } : null;
  }

  async decide(
    id: string,
    patch: Pick<Report, 'status' | 'staffNote' | 'decidedBy' | 'decidedAt'>,
  ): Promise<void> {
    const r = this.reports.get(id);
    if (r) {
      this.reports.set(id, {
        ...r,
        ...patch,
      });
    }
  }
}
