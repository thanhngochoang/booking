/**
 * `onInstantRequestWrite` (plan #140 Task 5, Decisions 11, 20, 21): what a write of
 * `instant_requests/{id}` tells people and tidies up. The domain decides (`instantNotices`,
 * `syncInstantChat`, `instantTrackShouldGo`); this adapter calls #138's hooks, the chat sync and the
 * track delete, each in its own try/catch so one failure never stops the others.
 *
 * Replays are safe: #138's dedupe keys (per request and assignment) make a notice sent twice one inbox
 * row, the chat sync finds the chat already open (or already closing), and deleting a missing track is
 * a no-op. So any non-permanent failure (a notice, the chat sync, the track delete) is rethrown after
 * every side effect ran and Functions retries the event (`retry: true`).
 */
import * as logger from 'firebase-functions/logger';
import {
  instantNotices,
  instantTrackShouldGo,
  notifyInstantArrived,
  notifyInstantAssigned,
  notifyInstantCancelled,
  notifyInstantFinished,
  notifyInstantMissed,
  notifyInstantNoMatch,
  notifyInstantRoundEnded,
  syncInstantChat,
  type ChatDeps,
  type InstantNotice,
  type InstantRequest,
  type NotifyDeps,
} from '@photobooking/domain';
import { MAX_EVENT_AGE_MS, isPermanentFirestoreError } from './photographer_write.js';

export interface InstantRequestWriteInput {
  readonly requestId: string;
  readonly before: InstantRequest | null;
  readonly after: InstantRequest | null;
  /** `event.time` (RFC 3339). */
  readonly time: string;
}

export interface InstantRequestWriteDeps {
  readonly notify: NotifyDeps;
  readonly chat: ChatDeps;
  deleteTrack(requestId: string): Promise<void>;
}

export interface InstantRequestWriteResult {
  /** Notices whose hook ran without throwing. */
  readonly notices: number;
  /** `syncInstantChat`'s answer, `failed`, or `expired` for a dropped event. */
  readonly chat: string;
  readonly trackDeleted: boolean;
}

/** Error name and gRPC code only: never the message or the document (it holds a meet point). */
function errorKind(e: unknown): { name: string; code?: unknown } {
  const name = e instanceof Error ? e.name : typeof e;
  return typeof e === 'object' && e !== null && 'code' in e ? { name, code: (e as { code: unknown }).code } : { name };
}

/**
 * The amount the `no_match` notice may call held: only money that was paid. #140 moves no money
 * (`paidAt` stays null), so it passes 0 and the row leaves out the money sentence (#138's render).
 */
export function heldAmountOf(r: InstantRequest): number {
  return r.paidAt === null ? 0 : r.amountVnd;
}

/** The assignment a notice belongs to (its `assignedAt` in ms), keying #138's rows per job. */
const assignmentOf = (r: InstantRequest | null): string | undefined =>
  r?.assignedAt == null ? undefined : String(r.assignedAt.getTime());

/**
 * The #138 hook of one notice; `skipped` when the write lacks the photographer a job notice names
 * (never sent to an empty id).
 */
async function sendNotice(
  deps: NotifyDeps,
  n: InstantNotice,
  before: InstantRequest | null,
  r: InstantRequest,
): Promise<'sent' | 'skipped'> {
  const base = { customerId: r.customerId, requestId: r.id };
  const photographerId = r.photographerId;
  const assignment = assignmentOf(r);
  switch (n.hook) {
    case 'assigned':
      if (photographerId === null) return 'skipped';
      await notifyInstantAssigned(deps, { ...base, photographerId, etaMinutes: r.etaMinutes ?? 0, assignment });
      return 'sent';
    case 'round_ended':
      await notifyInstantRoundEnded(deps, { ...base, round: n.round });
      return 'sent';
    case 'no_match':
      await notifyInstantNoMatch(deps, { ...base, round: n.round, amount: heldAmountOf(r) });
      return 'sent';
    case 'arrived':
      if (photographerId === null) return 'skipped';
      await notifyInstantArrived(deps, { ...base, photographerId, place: r.meetPoint.name, assignment });
      return 'sent';
    case 'finished':
      if (photographerId === null) return 'skipped';
      await notifyInstantFinished(deps, { ...base, photographerId, assignment });
      return 'sent';
    case 'cancelled':
      // A photographer cancel clears the assignment on `after`: the job it ended is `before`'s.
      await notifyInstantCancelled(deps, {
        ...base, by: n.by, photographerId: n.photographerId, feeVnd: n.feeVnd,
        assignment: n.by === 'photographer' ? assignmentOf(before) : assignment ?? assignmentOf(before),
      });
      return 'sent';
    case 'missed':
      await notifyInstantMissed(deps, { photographerId: n.photographerId, offerId: n.offerId });
      return 'sent';
  }
}

export async function handleInstantRequestWrite(
  input: InstantRequestWriteInput,
  deps: InstantRequestWriteDeps,
  now: Date = new Date(),
): Promise<InstantRequestWriteResult> {
  const { requestId, before, after } = input;
  if (now.getTime() - Date.parse(input.time) > MAX_EVENT_AGE_MS) {
    logger.error('onInstantRequestWrite: event older than 1 hour dropped', { requestId });
    return { notices: 0, chat: 'expired', trackDeleted: false };
  }

  const retryable: unknown[] = [];
  let notices = 0;
  if (after !== null) {
    for (const n of instantNotices(before, after)) {
      try {
        if (await sendNotice(deps.notify, n, before, after) === 'sent') {
          notices += 1;
        } else {
          logger.error('onInstantRequestWrite: notice skipped', { requestId, hook: n.hook, reason: 'missing_photographer' });
        }
      } catch (e) {
        logger.error('onInstantRequestWrite: notice failed', { requestId, hook: n.hook, ...errorKind(e) });
        if (!isPermanentFirestoreError(e)) retryable.push(e);
      }
    }
  }

  let chat = 'none';
  try {
    chat = await syncInstantChat(deps.chat, before, after);
  } catch (e) {
    chat = 'failed';
    logger.error('onInstantRequestWrite: chat sync failed', { requestId, ...errorKind(e) });
    if (!isPermanentFirestoreError(e)) retryable.push(e);
  }

  let trackDeleted = false;
  if (instantTrackShouldGo(before, after)) {
    try {
      await deps.deleteTrack(requestId);
      trackDeleted = true;
    } catch (e) {
      logger.error('onInstantRequestWrite: track delete failed', { requestId, ...errorKind(e) });
      if (!isPermanentFirestoreError(e)) retryable.push(e);
    }
  }

  if (retryable.length > 0) throw retryable[0];
  return { notices, chat, trackDeleted };
}
