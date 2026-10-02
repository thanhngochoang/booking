/**
 * Scheduled clock sweep runners (invoked every 15 minutes by bookingClock).
 */

import {
  DRAFT_EXPIRY_MINUTES,
  AUTO_COMPLETE_DELAY_HOURS,
} from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { releaseEscrowPayment } from './escrow.js';
import { transitionBooking } from './transition_booking.js';

export interface BookingSweepResults {
  readonly cleanedDrafts: number;
  readonly expiredRequests: number;
  readonly upcomingTransitions: number;
  readonly autoCompletions: number;
  readonly releasedEscrows: number;
}

export async function runBookingSweeps(deps: BookingDeps): Promise<BookingSweepResults> {
  const now = deps.clock.now();

  // 1. Clean unpaid drafts older than 30 minutes
  let cleanedDrafts = 0;
  const draftCutoff = new Date(now.getTime() - DRAFT_EXPIRY_MINUTES * 60 * 1000);
  const oldDrafts = await deps.store.findUnpaidDraftsOlderThan(draftCutoff);
  for (const draft of oldDrafts) {
    await deps.store.runTransaction(async (tx) => {
      const b = await tx.getBooking(draft.id);
      if (b && b.status === 'draft') {
        await tx.deleteBooking(draft.id);
        await tx.deleteContactSnapshot(draft.id);
        const day = await tx.getAvailabilityDay(draft.photographerId, draft.day);
        if (day && day.bookingId === draft.id) {
          await tx.deleteAvailabilityDay(draft.photographerId, draft.day);
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

  // 4. Auto-complete upcoming bookings 24h after end time
  let autoCompletions = 0;
  const completeCutoff = new Date(now.getTime() - AUTO_COMPLETE_DELAY_HOURS * 60 * 60 * 1000);
  const completions = await deps.store.findAutoCompletions(completeCutoff);
  for (const b of completions) {
    try {
      await transitionBooking(deps, {
        bookingId: b.id,
        action: 'complete',
      });
      autoCompletions += 1;
    } catch {
      // Swallowed
    }
  }

  // 5. Release held escrow payments whose dispute window has passed
  let releasedEscrows = 0;
  const releasable = await deps.store.findReleasableEscrows(now);
  for (const payment of releasable) {
    await deps.store.runTransaction(async (tx) => {
      const p = await tx.getPayment(payment.id);
      if (p && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded')) {
        const refunds = await deps.store.getRefundsForPayment(p.id);
        const totalRefunded = refunds.reduce((sum, r) => sum + r.amount, 0);

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
    });
  }

  return {
    cleanedDrafts,
    expiredRequests,
    upcomingTransitions,
    autoCompletions,
    releasedEscrows,
  };
}
