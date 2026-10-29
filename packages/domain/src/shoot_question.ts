/**
 * "Buổi chụp có diễn ra không?" (S30, plan #223 Decision 10; spec §6.3, S05.02-askshot): replaces the
 * old automatic `mark_shot` 24 h after the end. An `upcoming` booking nobody scanned is asked at
 * end + 24 h; the customer answers "Có" (→ `shot`, dated at the booking's end) or "Không diễn ra"
 * (`shootDeniedAt`: the booking stays `upcoming` with its money held, and S18.01 opens with the reason
 * preset); no answer within 48 h → `shot` as if "Có". The booking clock runs `askShootHappened`
 * (it notifies) and `runBookingSweeps` runs `expireShootQuestions`.
 */

import type { Booking } from './booking.js';
import { decideTransition } from './booking_machine.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { confirmedAssigneeId } from './collab_jobs.js';
import { commitTransition } from './commit_transition.js';
import { openDisputeAsSystem } from './dispute_use_cases.js';
import type { DisputeDeps } from './dispute_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { notifyShootQuestion } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { waitsForAssignee } from './studio_assignment.js';
import { transitionBooking } from './transition_booking.js';

export const SHOOT_QUESTION_AFTER_HOURS = 24;
export const SHOOT_QUESTION_ANSWER_HOURS = 48;
/** "Không diễn ra" without a dispute after this long: the clock opens it (Task 4 fix 1). */
export const SHOOT_DENIED_DISPUTE_HOURS = 48;
/** The preset of S18.01 for a denied shoot ("Buổi chụp không diễn ra"). */
export const SHOOT_DENIED_REASON = 'no_show';
export const SHOOT_DENIED_DESCRIPTION = 'Buổi chụp không diễn ra';

/** The id of the dispute the clock opens for a denied shoot: one per booking, so a retry finds it. */
export const shootDeniedDisputeId = (bookingId: string): string => `shoot_denied_${bookingId}`;

const HOUR_MS = 3_600_000;

const endsAt = (b: Pick<Booking, 'day' | 'end'>): Date => parseVnDateTime(b.day, b.end);

/** Asked already, or not askable: scanned, not `upcoming`, a studio booking still without its assignee, before end + 24 h. */
function askable(b: Booking, now: Date): boolean {
  return b.status === 'upcoming' && b.checkedInAt === undefined && b.shootQuestionAt === undefined
    && !waitsForAssignee(b)
    && endsAt(b).getTime() + SHOOT_QUESTION_AFTER_HOURS * HOUR_MS <= now.getTime();
}

/**
 * The clock's step: every `upcoming` booking at end + 24 h without a scan gets `shootQuestionAt = now`,
 * `shootQuestionUntil = now + 48 h` (its own transaction), then the customer's `shoot_question`
 * notification (deduped per booking; a failed send does not stop the batch). Returns how many were asked;
 * a second run asks nobody again.
 */
export async function askShootHappened(deps: BookingDeps, notify: NotifyDeps): Promise<number> {
  const now = deps.clock.now();
  const cutoff = new Date(now.getTime() - SHOOT_QUESTION_AFTER_HOURS * HOUR_MS);
  const due = await deps.store.findShootQuestionsDue(cutoff);
  let asked = 0;
  for (const candidate of due) {
    const updated = await deps.store.runTransaction(async (tx): Promise<Booking | null> => {
      const b = await tx.getBooking(candidate.id);
      if (b === null || !askable(b, now)) return null;
      const at = now.toISOString();
      const next: Booking = {
        ...b,
        shootQuestionAt: at,
        shootQuestionUntil: new Date(now.getTime() + SHOOT_QUESTION_ANSWER_HOURS * HOUR_MS).toISOString(),
        version: b.version + 1,
        updatedAt: at,
      };
      await tx.setBooking(next);
      return next;
    });
    if (updated === null) continue;
    asked += 1;
    try {
      await notifyShootQuestion(notify, {
        bookingId: updated.id,
        customerId: updated.customerId,
        providerId: confirmedAssigneeId(updated) ?? updated.photographerId,
        day: updated.day,
      });
    } catch {
      // Best effort: the booking still shows the question on S05.02.
    }
  }
  return asked;
}

/** Unanswered questions past `shootQuestionUntil` → `shot` by the system (shotAt = the booking's end). */
export async function expireShootQuestions(deps: BookingDeps): Promise<number> {
  const now = deps.clock.now();
  const due = await deps.store.findExpiredShootQuestions(now);
  let shot = 0;
  for (const b of due) {
    if (b.shootQuestionUntil === undefined || Date.parse(b.shootQuestionUntil) > now.getTime()) continue;
    try {
      await transitionBooking(deps, { bookingId: b.id, action: 'mark_shot' });
      shot += 1;
    } catch {
      // Swallowed: answered (or denied) meanwhile, or retried by the next run.
    }
  }
  return shot;
}

/**
 * The customer's answer (S05.02-askshot) while the question is open: `true` → `shot` with
 * `shotAt = endsAt` (milestones split as for any shot); `false` → `shootDeniedAt = now`, still
 * `upcoming`, money held for the dispute the app opens next (`openDispute` accepts it, `dispute.ts`).
 * `permission_denied` for anyone but the customer, `not_eligible` when no question is open (not asked,
 * already answered, scanned or no longer `upcoming`), `deadline_passed` from `shootQuestionUntil` on.
 */
export async function answerShootHappened(
  deps: BookingDeps,
  input: { readonly bookingId: string; readonly customerId: string; readonly happened: boolean },
): Promise<Booking> {
  if (!isId(input.bookingId) || typeof input.happened !== 'boolean') throw new DomainError('invalid_argument');
  const now = deps.clock.now();
  const b = await deps.store.getBooking(input.bookingId);
  if (b === null) throw new DomainError('not_found');
  assertAnswerable(b, input.customerId, now);

  if (input.happened) {
    const decision = decideTransition(b, 'mark_shot', { role: 'system' }, now);
    return commitTransition(deps, b, decision, input.customerId);
  }
  return deps.store.runTransaction(async (tx) => {
    const cur = await tx.getBooking(b.id);
    if (cur === null) throw new DomainError('not_found');
    if (cur.version !== b.version) throw new DomainError('conflict');
    assertAnswerable(cur, input.customerId, now);
    const at = now.toISOString();
    const next: Booking = { ...cur, shootDeniedAt: at, version: cur.version + 1, updatedAt: at };
    await tx.setBooking(next);
    return next;
  });
}

function assertAnswerable(b: Booking, customerId: string, now: Date): void {
  if (b.customerId !== customerId) throw new DomainError('permission_denied');
  if (b.status !== 'upcoming' || b.shootQuestionAt === undefined || b.shootDeniedAt !== undefined
    || b.checkedInAt !== undefined || b.shootQuestionUntil === undefined) {
    throw new DomainError('not_eligible');
  }
  if (now.getTime() >= Date.parse(b.shootQuestionUntil)) throw new DomainError('deadline_passed');
}

/**
 * The booking clock's exit for a denied shoot (Task 4 fix 1): a booking whose customer answered "Không diễn ra"
 * 48 h ago and opened no dispute gets one, opened by the system with the preset reason through
 * `openDisputeAsSystem` (the whole held payment freezes; staff resolve it as any dispute). One per booking
 * (`shootDeniedDisputeId`); a booking the customer disputed meanwhile is skipped. Returns how many were opened.
 */
export async function openDeniedShootDisputes(
  deps: Pick<BookingDeps, 'store' | 'clock'>,
  disputes: DisputeDeps,
): Promise<number> {
  const now = deps.clock.now();
  const cutoff = new Date(now.getTime() - SHOOT_DENIED_DISPUTE_HOURS * HOUR_MS);
  let opened = 0;
  for (const b of await deps.store.findDeniedShootsDue(cutoff)) {
    if (b.disputeId || b.shootDeniedAt === undefined || Date.parse(b.shootDeniedAt) > cutoff.getTime()) continue;
    try {
      await openDisputeAsSystem(disputes, {
        disputeId: shootDeniedDisputeId(b.id),
        subjectType: 'booking',
        subjectId: b.id,
        eventId: null,
        reason: SHOOT_DENIED_REASON,
        description: SHOOT_DENIED_DESCRIPTION,
      });
      opened += 1;
    } catch {
      // Disputed meanwhile (`conflict`), or retried by the next run.
    }
  }
  return opened;
}
