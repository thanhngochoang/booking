import type {
  JobInviteRecord,
  JobMatchRecord,
  JobRecord,
  QuoteRecord,
} from './job.js';
import type { JobStore, JobTx } from './job_ports.js';

export class MemoryJobStore implements JobStore {
  readonly jobs = new Map<string, JobRecord>();
  readonly quotes = new Map<string, Map<string, QuoteRecord>>(); // jobId -> (photographerId -> QuoteRecord)
  readonly invites = new Map<string, Map<string, JobInviteRecord>>(); // jobId -> (photographerId -> JobInviteRecord)
  readonly matches = new Map<string, Map<string, JobMatchRecord>>(); // jobId -> (photographerId -> JobMatchRecord)

  async runTransaction<T>(fn: (tx: JobTx) => Promise<T>): Promise<T> {
    const stagedJobs = new Map<string, JobRecord>();
    const stagedQuotes = new Map<string, Map<string, QuoteRecord>>();
    const stagedInvites = new Map<string, Map<string, JobInviteRecord>>();
    const stagedMatches = new Map<string, Map<string, JobMatchRecord>>();
    let written = false;

    const tx: JobTx = {
      getJob: async (id: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return stagedJobs.get(id) ?? this.jobs.get(id) ?? null;
      },
      getQuote: async (jobId: string, photographerId: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return (
          stagedQuotes.get(jobId)?.get(photographerId) ??
          this.quotes.get(jobId)?.get(photographerId) ??
          null
        );
      },
      getInvite: async (jobId: string, photographerId: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return (
          stagedInvites.get(jobId)?.get(photographerId) ??
          this.invites.get(jobId)?.get(photographerId) ??
          null
        );
      },
      listQuotes: async (jobId: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return Array.from(this.quotes.get(jobId)?.values() ?? []);
      },
      listInvites: async (jobId: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return Array.from(this.invites.get(jobId)?.values() ?? []);
      },
      listMatches: async (jobId: string) => {
        if (written) throw new Error('Cannot read after write inside transaction');
        return Array.from(this.matches.get(jobId)?.values() ?? []);
      },
      putJob: (j: JobRecord) => {
        written = true;
        stagedJobs.set(j.id, j);
      },
      putQuote: (q: QuoteRecord) => {
        written = true;
        let map = stagedQuotes.get(q.jobId);
        if (!map) {
          map = new Map();
          stagedQuotes.set(q.jobId, map);
        }
        map.set(q.photographerId, q);
      },
      putInvite: (i: JobInviteRecord) => {
        written = true;
        let map = stagedInvites.get(i.jobId);
        if (!map) {
          map = new Map();
          stagedInvites.set(i.jobId, map);
        }
        map.set(i.photographerId, i);
      },
      putMatch: (m: JobMatchRecord) => {
        written = true;
        let map = stagedMatches.get(m.jobId);
        if (!map) {
          map = new Map();
          stagedMatches.set(m.jobId, map);
        }
        map.set(m.photographerId, m);
      },
    };

    const result = await fn(tx);

    for (const [id, j] of stagedJobs) {
      this.jobs.set(id, j);
    }
    for (const [jobId, map] of stagedQuotes) {
      let target = this.quotes.get(jobId);
      if (!target) {
        target = new Map();
        this.quotes.set(jobId, target);
      }
      for (const [pid, q] of map) {
        target.set(pid, q);
      }
    }
    for (const [jobId, map] of stagedInvites) {
      let target = this.invites.get(jobId);
      if (!target) {
        target = new Map();
        this.invites.set(jobId, target);
      }
      for (const [pid, inv] of map) {
        target.set(pid, inv);
      }
    }
    for (const [jobId, map] of stagedMatches) {
      let target = this.matches.get(jobId);
      if (!target) {
        target = new Map();
        this.matches.set(jobId, target);
      }
      for (const [pid, m] of map) {
        target.set(pid, m);
      }
    }

    return result;
  }

  async countOpenJobs(customerId: string): Promise<number> {
    let count = 0;
    for (const j of this.jobs.values()) {
      if (j.customerId === customerId && j.status === 'open') {
        count++;
      }
    }
    return count;
  }

  async countSubmittedQuotes(photographerId: string): Promise<number> {
    let count = 0;
    for (const map of this.quotes.values()) {
      const q = map.get(photographerId);
      if (q && q.status === 'submitted') count++;
    }
    return count;
  }

  async submittedQuotesOnDay(photographerId: string, day: string): Promise<QuoteRecord[]> {
    const res: QuoteRecord[] = [];
    for (const map of this.quotes.values()) {
      const q = map.get(photographerId);
      if (q && q.status === 'submitted' && q.proposal.day === day) {
        res.push(q);
      }
    }
    return res;
  }

  async dueForExpiry(now: Date, limit: number): Promise<JobRecord[]> {
    const res: JobRecord[] = [];
    for (const j of this.jobs.values()) {
      if (j.status === 'open' && j.quoteDeadline.getTime() <= now.getTime()) {
        res.push(j);
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async dueForExpiringNotice(now: Date, limit: number): Promise<JobRecord[]> {
    const res: JobRecord[] = [];
    const threshold = now.getTime() + 24 * 60 * 60 * 1000;
    for (const j of this.jobs.values()) {
      if (
        j.status === 'open' &&
        j.expiringNotifiedAt === null &&
        j.quoteDeadline.getTime() <= threshold
      ) {
        res.push(j);
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async dueForReferencePurge(now: Date, limit: number): Promise<JobRecord[]> {
    const res: JobRecord[] = [];
    for (const j of this.jobs.values()) {
      if (
        j.referencesPurgeAfter !== null &&
        j.referencesPurgeAfter.getTime() <= now.getTime() &&
        j.references.length > 0
      ) {
        res.push(j);
        if (res.length >= limit) break;
      }
    }
    return res;
  }
}
