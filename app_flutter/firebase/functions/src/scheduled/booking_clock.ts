import * as logger from 'firebase-functions/logger';
import { runBookingSweeps, sendDueReminders, type Booking, type BookingDeps, type BookingSweepResults, type NotifyDeps } from '@photobooking/domain';
import { db } from '../infra/admin.js';
import { FirestoreBookingStore } from '../infra/booking_firestore.js';
import { liveBookingDeps } from '../infra/live_booking.js';
import { liveNotifyDeps } from '../infra/live_notification.js';

export const REMINDER_BOOKING_LIMIT = 200;

export interface ReminderDeps {
  readonly notify: NotifyDeps;
  /** Bookings with status `upcoming` (they exist only within 24 h of the start). */
  upcoming(limit: number): Promise<readonly Booking[]>;
}

export function liveReminderDeps(): ReminderDeps {
  const store = new FirestoreBookingStore(db());
  return { notify: liveNotifyDeps(), upcoming: (limit) => store.findUpcoming(limit) };
}

export async function handleBookingClock(
  deps: BookingDeps = liveBookingDeps(),
  reminders?: ReminderDeps,
): Promise<BookingSweepResults> {
  let results: BookingSweepResults;
  try {
    results = await runBookingSweeps(deps);
    logger.info('bookingClock sweep completed', results);
  } catch (e) {
    logger.error('bookingClock sweep failed', { error: String(e) });
    throw e;
  }
  if (reminders) {
    try {
      const sent = await sendDueReminders(reminders.notify, await reminders.upcoming(REMINDER_BOOKING_LIMIT));
      logger.info('bookingClock reminders completed', { sent });
    } catch (e) {
      logger.error('bookingClock reminders failed', { error: String(e) });
      throw e;
    }
  }
  return results;
}
