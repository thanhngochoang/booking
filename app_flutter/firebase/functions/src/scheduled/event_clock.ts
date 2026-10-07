import * as logger from 'firebase-functions/logger';
import { releaseEventHolds, runEventSweeps, type EventDeps, type EventPaymentDeps } from '@photobooking/domain';
import { liveEventDeps, liveEventPaymentDeps } from '../infra/live_event.js';

/**
 * Closes registration, completes events (stamping `releaseAfter` on held ticket money), expires
 * unanswered host invitations, retries refunds of cancelled events and sends again ticket refunds
 * left `pending` (the gateway keys them by refund id).
 */
export async function handleEventClock(
  deps: EventDeps & { readonly gateway?: EventPaymentDeps['gateway'] } = liveEventPaymentDeps(),
): Promise<{ closed: number; completed: number; consentExpired: number; refunded: number; refundsResent: number }> {
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

/** Every minute: expired 10-minute ticket holds give their seats back. */
export async function handleReleaseEventHolds(deps: EventDeps = liveEventDeps()): Promise<number> {
  try {
    const released = await releaseEventHolds(deps, (eventId, error) => {
      logger.error('releaseEventHolds event failed', { eventId, error: error instanceof Error ? error.name : 'unknown' });
    });
    if (released > 0) logger.info('releaseEventHolds completed', { released });
    return released;
  } catch (e) {
    logger.error('releaseEventHolds failed', { error: String(e) });
    throw e;
  }
}
