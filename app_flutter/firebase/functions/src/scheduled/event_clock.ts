import * as logger from 'firebase-functions/logger';
import { runEventSweeps, type EventDeps } from '@photobooking/domain';
import { liveEventDeps } from '../infra/live_event.js';

/** Closes registration, completes events and expires unanswered host invitations. */
export async function handleEventClock(
  deps: EventDeps = liveEventDeps(),
): Promise<{ closed: number; completed: number; consentExpired: number }> {
  try {
    const results = await runEventSweeps(deps, (eventId, step, error) => {
      logger.error('eventClock step failed', { eventId, step, error: error instanceof Error ? error.name : 'unknown' });
    });
    logger.info('eventClock sweep completed', results);
    return results;
  } catch (e) {
    logger.error('eventClock sweep failed', { error: String(e) });
    throw e;
  }
}
