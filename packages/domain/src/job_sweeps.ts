import type { NotifyDeps } from './notification_ports.js';
import {
  notifyJobExpired,
  notifyJobExpiring,
} from './notification_hooks.js';
import { checkoutActive, deadlinePassed } from './job.js';
import type { JobRecord } from './job.js';
import type { JobDeps } from './job_ports.js';

export async function runJobSweeps(
  deps: JobDeps,
  notifyDeps: NotifyDeps,
): Promise<{ expired: number; noticed: number; purged: number }> {
  const now = deps.clock.now();
  let expired = 0;
  let noticed = 0;
  let purged = 0;

  // 1. Expiry sweep
  const dueExpiry = await deps.jobs.dueForExpiry(now, 50);
  for (const job of dueExpiry) {
    try {
      let didExpire = false;
      await deps.jobs.runTransaction(async (tx) => {
        const fresh = await tx.getJob(job.id);
        if (!fresh) return;
        if (fresh.status !== 'open') return;
        if (!deadlinePassed(fresh, now)) return;
        if (checkoutActive(fresh, now)) return; // skip active checkout

        const quotes = await tx.listQuotes(fresh.id);
        const invites = await tx.listInvites(fresh.id);
        const matches = await tx.listMatches(fresh.id);

        for (const q of quotes) {
          if (q.status === 'submitted') {
            tx.putQuote({
              ...q,
              status: 'not_selected',
              notSelectedReason: 'expired',
              version: q.version + 1,
              updatedAt: now,
            });
          }
        }

        for (const inv of invites) {
          if (inv.jobStatus === 'open') {
            tx.putInvite({ ...inv, jobStatus: 'closed' });
          }
        }

        for (const m of matches) {
          if (m.jobStatus === 'open') {
            tx.putMatch({ ...m, jobStatus: 'closed' });
          }
        }

        const updated: JobRecord = {
          ...fresh,
          status: 'expired',
          closedAt: now,
          referencesPurgeAfter: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000),
          version: fresh.version + 1,
          updatedAt: now,
        };
        tx.putJob(updated);
        didExpire = true;
      });

      if (didExpire) {
        expired++;
        await notifyJobExpired(notifyDeps, {
          customerId: job.customerId,
          jobId: job.id,
          jobTitle: job.title,
        });
      }
    } catch {
      // swallow single job failure
    }
  }

  // 2. Expiring notice sweep (quoteDeadline <= now + 24h)
  const dueNotice = await deps.jobs.dueForExpiringNotice(now, 50);
  for (const job of dueNotice) {
    try {
      let shouldNotify = false;
      await deps.jobs.runTransaction(async (tx) => {
        const fresh = await tx.getJob(job.id);
        if (!fresh) return;
        if (fresh.status !== 'open' || fresh.expiringNotifiedAt !== null) return;

        tx.putJob({
          ...fresh,
          expiringNotifiedAt: now,
          version: fresh.version + 1,
          updatedAt: now,
        });
        if (fresh.quoteCount >= 1) {
          shouldNotify = true;
        }
      });

      if (shouldNotify) {
        noticed++;
        await notifyJobExpiring(notifyDeps, {
          customerId: job.customerId,
          jobId: job.id,
          jobTitle: job.title,
          quoteCount: job.quoteCount,
          quoteDeadline: job.quoteDeadline.toISOString(),
        });
      }
    } catch {
      // swallow single job failure
    }
  }

  // 3. Reference purge sweep
  const duePurge = await deps.jobs.dueForReferencePurge(now, 50);
  for (const job of duePurge) {
    try {
      for (const ref of job.references) {
        try {
          await deps.media.deleteReference(ref.path);
        } catch {
          // log and continue
        }
      }

      await deps.jobs.runTransaction(async (tx) => {
        const fresh = await tx.getJob(job.id);
        if (!fresh) return;
        tx.putJob({
          ...fresh,
          references: [],
          referencesPurgeAfter: null,
          version: fresh.version + 1,
          updatedAt: now,
        });
      });
      purged++;
    } catch {
      // swallow single job failure
    }
  }

  return { expired, noticed, purged };
}
