import * as logger from 'firebase-functions/logger';
import {
  releaseEventHolds,
  runEventSweeps,
  sendEventSoonNotices,
  type EventDeps,
  type EventPaymentDeps,
  type NotifyDeps,
} from '@photobooking/domain';
import { liveEventDeps, liveEventPaymentDeps } from '../infra/live_event.js';
import { liveNotifyDeps } from '../infra/live_notification.js';

/** Optional dependencies of later clock steps; existing parameters never change (S17 clock rule). */
export interface EventClockExtras {
  /** `event_soon` reminders; default `liveNotifyDeps()`. */
  readonly notify?: NotifyDeps;
}

export interface EventClockResults {
  readonly closed: number;
  readonly completed: number;
  readonly consentExpired: number;
  readonly refunded: number;
  readonly refundsResent: number;
  readonly soonEvents: number;
  readonly soonSent: number;
}

/**
 * Closes registration, completes events (stamping `releaseAfter` on held ticket money), expires
 * unanswered host invitations, retries refunds of cancelled events and sends again ticket refunds
 * left `pending` (the gateway keys them by refund id). Last step: `event_soon` reminders 48 hours
 * before the start (S17), in its own try/catch so a failure never fails the sweeps above.
 */
export async function handleEventClock(
  deps: EventDeps & { readonly gateway?: EventPaymentDeps['gateway'] } = liveEventPaymentDeps(),
  extras: EventClockExtras = {},
): Promise<EventClockResults> {
  let sweeps: Awaited<ReturnType<typeof runEventSweeps>>;
  try {
    sweeps = await runEventSweeps(deps, (eventId, step, error) => {
      logger.error('eventClock step failed', { eventId, step, error: error instanceof Error ? error.name : 'unknown' });
    });
    logger.info('eventClock sweep completed', sweeps);
  } catch (e) {
    logger.error('eventClock sweep failed', { error: String(e) });
    throw e;
  }

  // Step: sendEventSoonNotices (S17). Logs the event id only, never user data.
  let soon = { events: 0, sent: 0 };
  try {
    soon = await sendEventSoonNotices(deps, extras.notify ?? liveNotifyDeps(), (eventId, error) => {
      logger.error('eventClock event_soon failed', { eventId, error: error instanceof Error ? error.name : 'unknown' });
    });
    if (soon.events > 0 || soon.sent > 0) logger.info('eventClock event_soon completed', soon);
  } catch (e) {
    // The query itself failed (e.g. a missing index: its message names the index, no user data).
    logger.error('eventClock event_soon step failed', { error: String(e) });
  }
  return { ...sweeps, soonEvents: soon.events, soonSent: soon.sent };
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
