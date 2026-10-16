import * as logger from 'firebase-functions/logger';
import {
  runBookingSweeps,
  sendDueReminders,
  sendVerificationNudges,
  type Booking,
  type BookingDeps,
  type BookingSweepResults,
  type NotifyDeps,
  type VerificationDeps,
} from '@photobooking/domain';
import { db } from '../infra/admin.js';
import { FirestoreBookingStore } from '../infra/booking_firestore.js';
import { liveBookingDeps } from '../infra/live_booking.js';
import { liveNotifyDeps } from '../infra/live_notification.js';

export const REMINDER_PAGE = 200;
export const REMINDER_BATCH = 20;
const REMINDER_MAX_PAGES = 50;

export interface ReminderDeps {
  readonly notify: NotifyDeps;
  /** One page of `upcoming` bookings (they exist only within 24 h of the start); `next` is null at the end. */
  upcoming(limit: number, after: unknown): Promise<{ bookings: readonly Booking[]; next: unknown }>;
}

/**
 * Optional steps of the same 15-minute job that are not booking sweeps (no existing parameter
 * changes for them). `verification`: the one-time reminder of an unfinished verification
 * (S21, Decision 18).
 */
export interface BookingClockExtras {
  readonly verification?: { readonly deps: VerificationDeps; readonly notify: NotifyDeps };
}

export function liveReminderDeps(): ReminderDeps {
  const store = new FirestoreBookingStore(db());
  return { notify: liveNotifyDeps(), upcoming: (limit, after) => store.findUpcomingPage(limit, after) };
}

export async function handleBookingClock(
  deps: BookingDeps = liveBookingDeps(),
  reminders?: ReminderDeps,
  extras: BookingClockExtras = {},
): Promise<BookingSweepResults> {
  let results: BookingSweepResults;
  try {
    results = await runBookingSweeps(deps);
    logger.info('bookingClock sweep completed', results);
  } catch (e) {
    logger.error('bookingClock sweep failed', { error: String(e) });
    throw e;
  }
  let reminderError: unknown = null;
  if (reminders) {
    try {
      const sent = await sweepReminders(reminders);
      logger.info('bookingClock reminders completed', { sent });
    } catch (e) {
      logger.error('bookingClock reminders failed', { error: String(e) });
      reminderError = e;
    }
  }
  // Last step, its own try: a failure is logged and retried on the next tick, never thrown.
  if (extras.verification) {
    try {
      const nudged = await sendVerificationNudges(extras.verification.deps, extras.verification.notify);
      logger.info('bookingClock verificationNudges completed', { nudged });
    } catch (e) {
      logger.error('bookingClock verificationNudges failed', { error: String(e) });
    }
  }
  if (reminderError !== null) throw reminderError;
  return results;
}

/** Walks every page of upcoming bookings; each page runs in batches so concurrency stays bounded. */
export async function sweepReminders(reminders: ReminderDeps): Promise<number> {
  let sent = 0;
  let after: unknown = null;
  for (let page = 0; page < REMINDER_MAX_PAGES; page++) {
    const { bookings, next } = await reminders.upcoming(REMINDER_PAGE, after);
    for (let i = 0; i < bookings.length; i += REMINDER_BATCH) {
      sent += await sendDueReminders(reminders.notify, bookings.slice(i, i + REMINDER_BATCH));
    }
    if (next === null) break;
    after = next;
  }
  return sent;
}
