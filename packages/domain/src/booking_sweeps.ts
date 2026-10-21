/**
 * Scheduled clock sweep runners (invoked every 15 minutes by bookingClock).
 */

import { AUTO_COMPLETE_DELAY_HOURS } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { escrowRefundedTotal, releaseEscrowPayment } from './escrow.js';
import { releaseDueMilestones } from './milestones.js';
import { withoutInterval } from './spot_booking.js';
import { transitionBooking } from './transition_booking.js';
import { approveDelivery } from './delivery_use_cases.js';
import { studioDayLoadWith } from './studio_capacity.js';
import { waitsForAssignee } from './studio_assignment.js';

export interface BookingSweepResults {
  readonly cleanedDrafts: number;
  readonly expiredRequests: number;
  readonly upcomingTransitions: number;
  readonly autoShots: number;
  readonly autoApprovals: number;
  readonly finishedChecks: number;
  readonly releasedEscrows: number;
  /** Legacy alias for backwards compatibility */
  readonly autoCompletions?: number;
}

export async function runBookingSweeps(deps: BookingDeps): Promise<BookingSweepResults> {
  const now = deps.clock.now();

  // 1. Delete unpaid drafts whose payableUntil has passed (30 minutes, longer while a QR is live)
  let cleanedDrafts = 0;
  const oldDrafts = await deps.store.findExpiredDrafts(now);
  for (const draft of oldDrafts) {
    await deps.store.runTransaction(async (tx) => {
      const b = await tx.getBooking(draft.id);
      if (b && b.status === 'draft' && b.payableUntil && Date.parse(b.payableUntil) <= now.getTime()) {
        // Every read before the first write (Firestore transactions refuse reads after writes).
        const day = await tx.getAvailabilityDay(draft.photographerId, draft.day);
        const spotDay = b.spotScheduleId !== undefined ? await tx.getSpotDay(b.spotScheduleId, b.day) : null;
        // A studio spot booking is pre-assigned and never on the studio's day load (#194 Decision 7).
        const load =
          b.isStudio === true && b.spotScheduleId === undefined
            ? await tx.getStudioDayLoad(draft.photographerId, draft.day)
            : null;
        await tx.deleteBooking(draft.id);
        await tx.deleteContactSnapshot(draft.id);
        if (b.spotScheduleId !== undefined && spotDay) {
          await tx.setSpotDay(withoutInterval(spotDay, b, now.toISOString()));
        } else if (day && day.bookingId === draft.id) {
          await tx.deleteAvailabilityDay(draft.photographerId, draft.day);
        }
        if (load) {
          await tx.setStudioDayLoad(
            studioDayLoadWith(load, { studioId: draft.photographerId, day: draft.day }, draft.id, null, now.toISOString()),
          );
        }
        cleanedDrafts += 1;
      }
    });
  }

  // 2. Expire unaccepted requests past deadline
  let expiredRequests = 0;
  const expired = await deps.store.findExpiredRequests(now);
  for (const b of expired) {
    try {
      await transitionBooking(deps, {
        bookingId: b.id,
        action: 'expire',
      });
      expiredRequests += 1;
    } catch {
      // Swallowed so one failed item does not stop the batch
    }
  }

  // 3. Move accepted to upcoming at T-24h
  let upcomingTransitions = 0;
  const upcoming = await deps.store.findUpcomingTransitions(now);
  for (const b of upcoming) {
    try {
      await transitionBooking(deps, {
        bookingId: b.id,
        action: 'upcoming',
      });
      upcomingTransitions += 1;
    } catch {
      // Swallowed
    }
  }

  // 4. Auto mark-shot upcoming bookings 24h after end time. A studio booking without an assignee is never
  // marked shot (no payout); the studio sweep cancels it at its start.
  let autoShots = 0;
  const completeCutoff = new Date(now.getTime() - AUTO_COMPLETE_DELAY_HOURS * 60 * 60 * 1000);
  const completions = await deps.store.findAutoCompletions(completeCutoff);
  for (const b of completions) {
    if (waitsForAssignee(b)) continue;
    try {
      await transitionBooking(deps, {
        bookingId: b.id,
        action: 'mark_shot',
      });
      autoShots += 1;
    } catch {
      // Swallowed
    }
  }

  // 5. Auto-approve delivered bookings past autoApproveAt
  let autoApprovals = 0;
  const dueApprovals = await deps.store.findDueAutoApprovals(now);
  for (const b of dueApprovals) {
    try {
      await approveDelivery(deps, { bookingId: b.id });
      autoApprovals += 1;
    } catch {
      // Swallowed
    }
  }

  // 6. Finish approved bookings past checkUntil
  let finishedChecks = 0;
  const dueChecks = await deps.store.findDueChecks(now);
  for (const b of dueChecks) {
    try {
      await transitionBooking(deps, {
        bookingId: b.id,
        action: 'finish',
      });
      finishedChecks += 1;
    } catch {
      // Swallowed
    }
  }

  // 7. Release held escrow payments whose dispute window has passed
  let releasedEscrows = 0;
  const releasable = await deps.store.findReleasableEscrows(now);
  for (const payment of releasable) {
    await deps.store.runTransaction(async (tx) => {
      const p = await tx.getPayment(payment.id);
      if (p && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded')) {
        if (p.milestones) {
          const { payment: updatedP, ledgerEntries } = releaseDueMilestones(p, now, () => deps.ids.newId());
          if (ledgerEntries.length > 0) {
            await tx.setPayment(updatedP);
            for (const entry of ledgerEntries) {
              await tx.addLedgerEntry(entry);
            }
            const booking = await tx.getBooking(p.subjectId);
            if (booking) {
              await tx.setBooking({
                ...booking,
                escrowStatus: updatedP.escrowStatus,
                updatedAt: now.toISOString(),
              });
            }
            releasedEscrows += 1;
          }
        } else {
          // Only what escrow gave back: an over-transfer's excess or a second transfer never entered it.
          const totalRefunded = escrowRefundedTotal(await deps.store.getRefundsForPayment(p.id));

          const res = releaseEscrowPayment({
            payment: p,
            refundAmount: totalRefunded,
            ledgerEntryId: deps.ids.newId(),
            now,
          });

          await tx.setPayment(res.payment);
          await tx.addLedgerEntry(res.ledgerEntry);

          // Update booking's mirrored escrowStatus
          const booking = await tx.getBooking(p.subjectId);
          if (booking) {
            await tx.setBooking({
              ...booking,
              escrowStatus: 'released',
              updatedAt: now.toISOString(),
            });
          }

          releasedEscrows += 1;
        }
      }
    });
  }

  return {
    cleanedDrafts,
    expiredRequests,
    upcomingTransitions,
    autoShots,
    autoApprovals,
    finishedChecks,
    releasedEscrows,
    autoCompletions: autoShots,
  };
}
