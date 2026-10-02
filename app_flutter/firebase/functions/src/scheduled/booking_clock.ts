import * as logger from 'firebase-functions/logger';
import { runBookingSweeps, type BookingDeps, type BookingSweepResults } from '@photobooking/domain';
import { liveBookingDeps } from '../infra/live_booking.js';

export async function handleBookingClock(
  deps: BookingDeps = liveBookingDeps(),
): Promise<BookingSweepResults> {
  try {
    const results = await runBookingSweeps(deps);
    logger.info('bookingClock sweep completed', results);
    return results;
  } catch (e) {
    logger.error('bookingClock sweep failed', { error: String(e) });
    throw e;
  }
}
