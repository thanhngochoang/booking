/**
 * Which of #138's studio-booking hooks a booking write calls (#136 Decision 23). The decider is pure; the
 * sender is what `onBookingWrite` runs next to `notifyBookingChange`. Overdue and reminder notices come from
 * the sweep (`runStudioBookingSweeps`), and a `studio_fault` cancel goes through `bookingNotices`.
 */

import type { Booking } from './booking.js';
import { formatVnDate, formatVnTime } from './booking_policy.js';
import { confirmedAssigneeId } from './collab_jobs.js';
import {
  notifyAssignmentReturned,
  notifyBookingAssigned,
  notifyBookingReassigned,
  notifyChangeAnswered,
  notifyChangeRequested,
} from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';

/**
 * `offer_replaced` (S27): a collaborator offer took the booking from its confirmed assignee, who is told at
 * once; the customer hears `reassigned` when the collaborator accepts (or S26's overdue notice if nobody does).
 */
export type StudioNotice =
  | 'assigned'
  | 'reassigned'
  | 'offer_replaced'
  | 'change_requested'
  | 'change_answered'
  | 'assignment_returned';

const LIVE_AFTER_DRAFT: ReadonlySet<Booking['status']> = new Set(['requested', 'accepted', 'upcoming']);

/** The latest confirmed entry of the log before the latest entry of `current` (a member, or a collaborator who accepted). */
function confirmedBefore(b: Booking, current: string): string | null {
  const log = b.assignments ?? [];
  let i = log.length - 1;
  while (i >= 0 && log[i]?.assigneeId !== current) i -= 1;
  for (i -= 1; i >= 0; i -= 1) {
    const e = log[i];
    if (e !== undefined && (e.assigneeKind !== 'collaborator' || e.acceptedAt !== undefined)) return e.assigneeId;
  }
  return null;
}

/**
 * The confirmed assignee the customer last knew before `current` (S27): the latest earlier entry of the log that
 * was confirmed (a member, or a collaborator who accepted), unless it is `current` itself; else null.
 */
export function replacedAssigneeOf(b: Booking, current: string): string | null {
  const prev = confirmedBefore(b, current);
  return prev === current ? null : prev;
}

/**
 * S27: `current` was already the confirmed assignee before its latest entry (a collaborator offer replaced them,
 * the offer was declined or lapsed, and they were put back): they were told of the replacement, so they are told
 * again; the customer never heard of the offer.
 */
export function putBackAfterOffer(b: Booking, current: string): boolean {
  return confirmedBefore(b, current) === current;
}

/** A collaborator offer waiting on the booking. */
const pendingOfferOf = (b: Booking): string | null =>
  b.assigneeKind === 'collaborator' && b.assigneeAccepted !== true ? (b.assigneeId ?? null) : null;

/**
 * Creation and deletion send nothing; neither does an individual booking. The assignee is the confirmed one
 * (S27): a collaborator's offer is announced to the customer only once accepted, as a reassignment when it
 * replaced someone the customer knew.
 */
export function studioBookingNotices(before: Booking | null, after: Booking | null): StudioNotice[] {
  if (!before || !after || after.isStudio !== true) return [];
  const out: StudioNotice[] = [];
  const was = confirmedAssigneeId(before);
  const now = confirmedAssigneeId(after);
  if (now !== null && now !== was) {
    out.push(was !== null || replacedAssigneeOf(after, now) !== null ? 'reassigned' : 'assigned');
  } else if (was !== null && now === null && pendingOfferOf(after) !== null) {
    out.push('offer_replaced');
  }
  // A studio spot booking is created already assigned (#194 Decision 7): the member is told when the paid
  // booking leaves the draft (a draft is only a hold), through the same hook and dedupe key.
  else if (now !== null && now === was && before.status === 'draft' && LIVE_AFTER_DRAFT.has(after.status)) {
    out.push('assigned');
  }
  const wasStatus = before.changeRequest?.status ?? null;
  const nowStatus = after.changeRequest?.status ?? null;
  if (wasStatus === null && nowStatus === 'pending') out.push('change_requested');
  // A reassignment answers the request through `booking_reassigned` alone.
  if (wasStatus === 'pending' && (nowStatus === 'declined' || nowStatus === 'expired')) out.push('change_answered');
  if (!before.assignmentReturned && after.assignmentReturned) out.push('assignment_returned');
  return out;
}

/** 'HH:mm dd/MM' in Vietnam time (#138's change_requested copy). */
export function vnHourDay(iso: string): string {
  const at = new Date(iso);
  const [, m, d] = formatVnDate(at).split('-');
  return `${formatVnTime(at)} ${d}/${m}`;
}

/** Calls the hooks of one studio booking change. A failing hook never blocks the others; one error is thrown at the end. */
export async function notifyStudioBookingChange(
  deps: NotifyDeps,
  before: Booking | null,
  after: Booking | null,
): Promise<void> {
  const notices = studioBookingNotices(before, after);
  if (notices.length === 0 || !before || !after) return;
  const common = { bookingId: after.id, customerId: after.customerId, studioId: after.photographerId };
  const slot = { day: after.day, start: after.start };
  const oldAssignee = confirmedAssigneeId(before);
  const assignee = confirmedAssigneeId(after);
  const change = after.changeRequest ?? null;
  const jobs: Promise<unknown>[] = [];
  for (const n of notices) {
    if (n === 'assigned' && assignee && oldAssignee === null && putBackAfterOffer(after, assignee)) {
      const at = after.assignedAt ?? after.assignments?.[after.assignments.length - 1]?.at;
      jobs.push(
        notifyBookingAssigned(deps, {
          ...common,
          ...slot,
          assigneeId: assignee,
          ...(at ? { assignedAt: at } : {}),
          recipients: ['assignee'],
        }),
      );
    } else if (n === 'assigned' && assignee) {
      jobs.push(notifyBookingAssigned(deps, { ...common, ...slot, assigneeId: assignee }));
    } else if (n === 'reassigned' && oldAssignee && assignee) {
      jobs.push(
        notifyBookingReassigned(deps, {
          ...common,
          ...slot,
          oldAssigneeId: oldAssignee,
          newAssigneeId: assignee,
          ...(after.assignedAt ? { reassignedAt: after.assignedAt } : {}),
        }),
      );
    } else if (n === 'reassigned' && assignee) {
      // S27: a collaborator accepted an offer that had replaced a confirmed assignee, already told then.
      const replaced = replacedAssigneeOf(after, assignee);
      if (replaced) {
        jobs.push(
          notifyBookingReassigned(deps, {
            ...common,
            ...slot,
            oldAssigneeId: replaced,
            newAssigneeId: assignee,
            ...(after.assignedAt ? { reassignedAt: after.assignedAt } : {}),
            recipients: ['customer', 'new'],
          }),
        );
      }
    } else if (n === 'offer_replaced' && oldAssignee) {
      const offeredTo = pendingOfferOf(after);
      const entry = [...(after.assignments ?? [])].reverse().find((e) => e.assigneeId === offeredTo);
      if (offeredTo) {
        jobs.push(
          notifyBookingReassigned(deps, {
            ...common,
            ...slot,
            oldAssigneeId: oldAssignee,
            newAssigneeId: offeredTo,
            ...(entry ? { reassignedAt: entry.at } : {}),
            recipients: ['old'],
          }),
        );
      }
    } else if (n === 'change_requested' && change) {
      jobs.push(notifyChangeRequested(deps, { ...common, day: after.day, respondBy: vnHourDay(change.respondBy) }));
    } else if (n === 'change_answered' && (change?.status === 'declined' || change?.status === 'expired')) {
      jobs.push(notifyChangeAnswered(deps, { ...common, outcome: change.status }));
    } else if (n === 'assignment_returned' && assignee) {
      jobs.push(notifyAssignmentReturned(deps, { bookingId: after.id, studioId: after.photographerId, assigneeId: assignee, ...slot }));
    }
  }
  const results = await Promise.allSettled(jobs);
  const failed = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failed.length > 0) {
    throw new Error(`studio booking notification failed for ${failed.length} notice(s): ${String(failed[0]?.reason)}`);
  }
}
