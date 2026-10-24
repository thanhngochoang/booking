/**
 * Production and emulator wiring of the studio ports (#136). Every StudioBookingDeps starts from
 * `liveBookingDeps()`, so the BlockGate that `orderBlocker` checks on assignment is always wired (#198).
 */

import { newUlid, type MemberDayReader, type StudioBookingDeps, type StudioDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { liveBookingDeps } from './live_booking.js';
import { liveNotifyDeps } from './live_notification.js';
import { FirestoreMemberDayReader, FirestoreStudioRoster, FirestoreStudioStore } from './studio_firestore.js';
import type { BookingClockExtras } from '../scheduled/booking_clock.js';

export function liveStudioDeps(): StudioDeps {
  return {
    studios: new FirestoreStudioStore(db()),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}

/** `notify`: S27 collaborator-offer notices (`collab_assignment_offer` / `_result`) after the commit (#151). */
export function liveStudioBookingDeps(): StudioBookingDeps {
  return { ...liveBookingDeps(), roster: new FirestoreStudioRoster(db()), notify: liveNotifyDeps() };
}

export function liveAssignmentOptionsDeps(): StudioBookingDeps & { readonly availability: MemberDayReader } {
  return { ...liveStudioBookingDeps(), availability: new FirestoreMemberDayReader(db()) };
}

/** The studio steps of bookingClock (Decision 20). */
export function liveStudioClockExtras(): NonNullable<BookingClockExtras['studio']> {
  return { bookings: liveStudioBookingDeps(), members: liveStudioDeps(), notify: liveNotifyDeps() };
}
