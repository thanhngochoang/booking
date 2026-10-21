/**
 * The studio-booking steps of bookingClock (#136 Decision 20). Each is idempotent: the marks live on the booking.
 */

import type { AssignReminder, Booking } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import { notifyAssignOverdue, notifyAssignReminder } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { isOpenForAssignment, STUDIO_ASSIGN_LEAD_HOURS, type StudioBookingDeps } from './studio_assignment.js';

/** Bookings handled per sweep step and run. */
export const STUDIO_SWEEP_LIMIT = 200;

const HOUR_MS = 60 * 60 * 1000;
/** The 26 h reminder fires this long before the deadline (deadline = start − 24 h). */
const LAST_REMINDER_HOURS = 2;

export interface StudioBookingSweepResults {
  readonly overdue: number;
  readonly reminders: number;
  readonly changesExpired: number;
  /** Notices whose hook failed; their booking stays unmarked and is sent again on the next run. */
  readonly notifyFailed: number;
}

/** What the assign sweep does with a booking now. `notify` false: overdue after the start (no cancel right left). */
export type AssignSweepAction =
  | { readonly kind: 'overdue'; readonly notify: boolean }
  | { readonly kind: 'reminder'; readonly hours: 48 | 26 }
  | null;

/**
 * Pure. Past the deadline → overdue (once); otherwise the latest due reminder not yet sent: a booking first seen
 * inside the 26 h window gets only that one (the 48 h mark is recorded with it).
 */
export function assignSweepActionOf(b: Booking, now: Date): AssignSweepAction {
  if (
    b.isStudio !== true ||
    b.assignStatus !== 'unassigned' ||
    b.assignOverdue === true ||
    (b.status !== 'requested' && b.status !== 'accepted') ||
    !b.assignDeadline
  ) {
    return null;
  }
  const deadline = Date.parse(b.assignDeadline);
  const t = now.getTime();
  if (t >= deadline) return { kind: 'overdue', notify: t < parseVnDateTime(b.day, b.start).getTime() };
  const sent = b.assignRemindersSent ?? [];
  if (t >= deadline - LAST_REMINDER_HOURS * HOUR_MS) return sent.includes('h26') ? null : { kind: 'reminder', hours: 26 };
  if (t >= deadline - STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS && !sent.includes('h48')) return { kind: 'reminder', hours: 48 };
  return null;
}

function sameAction(a: AssignSweepAction, b: AssignSweepAction): boolean {
  if (a === null || b === null) return a === b;
  if (a.kind === 'overdue') return b.kind === 'overdue';
  return b.kind === 'reminder' && a.hours === b.hours;
}

/**
 * (a) Unassigned bookings near their deadline: the 48 h and 26 h reminders to the studio, then overdue (fault
 * `assign_overdue`, `lateAssignCount`, customer and studio told while the shoot is still ahead). With `notify`,
 * the hook runs BEFORE the mark is committed: a failed notice leaves the booking unmarked, so the next run sends
 * it again, and #138's dedupe keys turn a resend after a lost mark into a duplicate, never a second notice.
 * (b) Pending change requests past `respondBy` expire (fault `change_expired`, `changeDeclinedCount`; the customer
 * hears it through the booking write). A failing item never stops the batch.
 */
export async function runStudioBookingSweeps(
  deps: StudioBookingDeps,
  notify?: NotifyDeps,
): Promise<StudioBookingSweepResults> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  let overdue = 0;
  let reminders = 0;
  let changesExpired = 0;
  let notifyFailed = 0;

  for (const due of await deps.store.findUnassignedStudioBookingsDue(now, STUDIO_SWEEP_LIMIT)) {
    const action = assignSweepActionOf(due, now);
    if (action === null) continue;
    if (notify) {
      try {
        if (action.kind === 'overdue' && action.notify) {
          await notifyAssignOverdue(notify, {
            bookingId: due.id,
            customerId: due.customerId,
            studioId: due.photographerId,
            day: due.day,
            start: due.start,
          });
        } else if (action.kind === 'reminder') {
          await notifyAssignReminder(notify, {
            bookingId: due.id,
            studioId: due.photographerId,
            hours: action.hours,
            day: due.day,
            start: due.start,
          });
        }
      } catch {
        notifyFailed += 1;
        continue;
      }
    }
    try {
      const marked = await deps.store.runTransaction(async (tx) => {
        const b = await tx.getBooking(due.id);
        if (!b || !sameAction(assignSweepActionOf(b, now), action)) return false;
        if (action.kind === 'overdue') {
          tx.incrementStudioCounter(b.photographerId, 'lateAssignCount');
          await tx.setBooking({
            ...b,
            assignOverdue: true,
            studioFault: b.studioFault ?? { kind: 'assign_overdue', at: nowIso },
            assignRemindersSent: ['h48', 'h26'],
            version: b.version + 1,
            updatedAt: nowIso,
          });
        } else {
          const marks: AssignReminder[] =
            action.hours === 26 ? ['h48', 'h26'] : [...(b.assignRemindersSent ?? []), 'h48'];
          await tx.setBooking({ ...b, assignRemindersSent: marks, version: b.version + 1, updatedAt: nowIso });
        }
        return true;
      });
      if (marked && action.kind === 'overdue') overdue += 1;
      if (marked && action.kind === 'reminder') reminders += 1;
    } catch {
      // Swallowed so one failed item does not stop the batch; the next run sees it unmarked.
    }
  }

  for (const due of await deps.store.findDueChangeRequests(now, STUDIO_SWEEP_LIMIT)) {
    try {
      const expired = await deps.store.runTransaction(async (tx) => {
        const b = await tx.getBooking(due.id);
        const cr = b?.changeRequest;
        if (!b || !cr || cr.status !== 'pending' || Date.parse(cr.respondBy) > now.getTime()) return false;
        const open = isOpenForAssignment(b, now);
        if (open) tx.incrementStudioCounter(b.photographerId, 'changeDeclinedCount');
        await tx.setBooking({
          ...b,
          changeRequest: { ...cr, status: 'expired', answeredAt: nowIso },
          studioFault: open ? { kind: 'change_expired', at: nowIso } : (b.studioFault ?? null),
          version: b.version + 1,
          updatedAt: nowIso,
        });
        return true;
      });
      if (expired) changesExpired += 1;
    } catch {
      // Swallowed, as above.
    }
  }

  return { overdue, reminders, changesExpired, notifyFailed };
}
