import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { NotifyDeps, NotifyResult } from '@photobooking/domain';
import {
  emitQuoteNotices,
  notifyJobMatch,
  notifyJobInvited,
  quoteNotices,
} from '@photobooking/domain';
import { db } from '../infra/admin.js';
import {
  jobFromFirestore,
  quoteFromFirestore,
} from '../infra/job_firestore.js';

interface SendableNotify {
  send(opts: unknown): Promise<unknown>;
}

function hasSend(n: unknown): n is SendableNotify {
  return typeof (n as Record<string, unknown>)?.send === 'function';
}

export interface JobQuoteWriteInput {
  readonly jobId: string;
  readonly photographerId: string;
  readonly before: Record<string, unknown> | undefined;
  readonly after: Record<string, unknown> | undefined;
}

export async function handleJobQuoteWrite(
  input: JobQuoteWriteInput,
  notify: NotifyDeps,
): Promise<number> {
  const before = input.before
    ? quoteFromFirestore(input.photographerId, input.before)
    : null;
  const after = input.after
    ? quoteFromFirestore(input.photographerId, input.after)
    : null;

  if (hasSend(notify)) {
    const notices = quoteNotices(before, after);
    for (const n of notices) {
      if (n.kind === 'new' && after) {
        await notify.send({
          userId: after.customerId,
          content: {
            type: 'quote_new',
            jobTitle: after.jobTitle,
            count: 1,
            names: [after.photographer.name],
          },
          target: `/jobs/${after.jobId}/applications`,
          groupKey: `job:${after.jobId}:quotes`,
        });
      } else if (n.kind === 'not_selected' && after) {
        await notify.send({
          userId: after.photographerId,
          content: {
            type: 'quote_not_selected',
            jobTitle: after.jobTitle,
            reason:
              after.status === 'declined'
                ? 'declined'
                : (after.notSelectedReason ?? 'closed'),
          },
          target: `/jobs/${after.jobId}`,
        });
      }
    }
    return notices.length;
  }

  return await emitQuoteNotices(notify, before, after);
}

export interface JobMatchCreatedInput {
  readonly jobId: string;
  readonly photographerId: string;
  readonly data: Record<string, unknown>;
}

export async function handleJobMatchCreated(
  input: JobMatchCreatedInput,
  notify: NotifyDeps,
  firestore: Firestore = db(),
): Promise<NotifyResult | null> {
  const jobDoc = await firestore.collection('jobs').doc(input.jobId).get();
  if (!jobDoc.exists) return null;
  const data = jobDoc.data();
  if (!data) return null;
  const job = jobFromFirestore(jobDoc.id, data);
  if (!job) return null;
  const day =
    (job.schedule.kind === 'fixed'
      ? job.schedule.day
      : (job.dayFrom ?? job.schedule.from)) ?? '';

  if (hasSend(notify)) {
    await notify.send({
      userId: input.photographerId,
      content: {
        type: 'job_match',
        jobTitle: job.title,
        day,
        area: job.area.name,
      },
      target: `/jobs/${input.jobId}`,
    });
    return 'created' as NotifyResult;
  }

  return await notifyJobMatch(notify, {
    photographerId: input.photographerId,
    jobId: input.jobId,
    jobTitle: job.title,
    day,
    area: job.area.name,
  });
}

export interface JobInviteCreatedInput {
  readonly jobId: string;
  readonly photographerId: string;
  readonly data: Record<string, unknown>;
}

export async function handleJobInviteCreated(
  input: JobInviteCreatedInput,
  notify: NotifyDeps,
  firestore: Firestore = db(),
): Promise<NotifyResult | null> {
  const jobDoc = await firestore.collection('jobs').doc(input.jobId).get();
  if (!jobDoc.exists) return null;
  const data = jobDoc.data();
  if (!data) return null;
  const job = jobFromFirestore(jobDoc.id, data);
  if (!job) return null;

  if (hasSend(notify)) {
    await notify.send({
      userId: input.photographerId,
      content: {
        type: 'job_invited',
        customer: job.customer.name,
        jobTitle: job.title,
      },
      target: `/jobs/${input.jobId}`,
    });
    return 'created' as NotifyResult;
  }

  return await notifyJobInvited(notify, {
    photographerId: input.photographerId,
    customerId: job.customerId,
    jobId: input.jobId,
    jobTitle: job.title,
  });
}

export interface JobViewCreatedInput {
  readonly jobId: string;
  readonly uid: string;
  readonly data: Record<string, unknown>;
}

export async function handleJobViewCreated(
  input: JobViewCreatedInput,
  firestore: Firestore = db(),
): Promise<void> {
  await firestore.collection('jobs').doc(input.jobId).update({
    viewCount: FieldValue.increment(1),
  });
}
