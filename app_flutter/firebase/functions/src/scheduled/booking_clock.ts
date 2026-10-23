import * as logger from 'firebase-functions/logger';
import {
  runBookingSweeps,
  sendDueReminders,
  sendVerificationNudges,
  notifyDeliveryAutoApproveSoon,
  runAssignDeadlineSweep,
  runChangeRequestSweep,
  runMembershipSweeps,
  runUnassignedStartSweep,
  runInstantSweep,
  type Booking,
  type BookingDeps,
  type BookingSweepResults,
  type InstantDeps,
  type NotifyDeps,
  type StudioBookingDeps,
  type StudioDeps,
  type VerificationDeps,
} from '@photobooking/domain';
import { db } from '../infra/admin.js';
import { FirestoreBookingStore } from '../infra/booking_firestore.js';
import { liveBookingDeps } from '../infra/live_booking.js';
import { liveInstantDeps } from '../infra/live_instant.js';
import { liveNotifyDeps } from '../infra/live_notification.js';
import { purgeDeliverySamples, type PurgeDeliverySamplesDeps } from './purge_delivery_samples.js';

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
 * (S21, Decision 18). `delivery`: auto-approve reminder and sample purge.
 */
export interface BookingClockExtras {
  readonly verification?: { readonly deps: VerificationDeps; readonly notify: NotifyDeps };
  readonly delivery?: { readonly notify: NotifyDeps; readonly purge?: PurgeDeliverySamplesDeps };
  /**
   * S26 studio sweeps (#136 Decision 20): assignment deadlines, change requests, unassigned bookings at their
   * start, then membership expiry.
   */
  readonly studio?: { readonly bookings: StudioBookingDeps; readonly members: StudioDeps; readonly notify: NotifyDeps };
  /**
   * Chụp ngay (#140 Decision 3): settles up to 100 active requests whose `nextDeadlineAt` has passed and
   * nobody is looking at. Default `liveInstantDeps()` when the clock runs live (`bookingDeps` omitted); a test that
   * passes its own BookingDeps and no `instant` skips the step, so it never reaches Firestore.
   */
  readonly instant?: InstantDeps;
}

export async function remindAutoApprovals(deps: BookingDeps, notify: NotifyDeps, limit = 50): Promise<number> {
  const due = await deps.store.findDueAutoApproveNotices(deps.clock.now(), limit);
  let count = 0;
  for (const b of due) {
    const now = deps.clock.now();
    await deps.store.runTransaction(async (tx) => {
      const live = await tx.getBooking(b.id);
      if (!live || live.status !== 'delivered' || live.autoApproveNoticeAt !== null) return;
      await tx.setBooking({
        ...live,
        autoApproveNoticeAt: now.toISOString(),
        version: live.version + 1,
        updatedAt: now.toISOString(),
      });
      await notifyDeliveryAutoApproveSoon(notify, {
        bookingId: live.id,
        customerId: live.customerId,
        delivererId: live.photographerId,
        round: live.deliveryRound ?? 1,
      });
      count++;
    });
  }
  return count;
}

export function liveReminderDeps(): ReminderDeps {
  const store = new FirestoreBookingStore(db());
  return { notify: liveNotifyDeps(), upcoming: (limit, after) => store.findUpcomingPage(limit, after) };
}

export async function handleBookingClock(
  bookingDeps?: BookingDeps,
  reminders?: ReminderDeps,
  extras: BookingClockExtras = {},
): Promise<BookingSweepResults> {
  const live = bookingDeps === undefined;
  const deps = bookingDeps ?? liveBookingDeps();
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

  // Delivery auto-approval notice step
  if (extras.delivery?.notify) {
    try {
      const notices = await remindAutoApprovals(deps, extras.delivery.notify);
      logger.info('bookingClock remindAutoApprovals completed', { notices });
    } catch (e) {
      logger.error('bookingClock remindAutoApprovals failed', { error: String(e) });
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

  // Delivery sample purge step
  if (extras.delivery?.purge) {
    try {
      const purged = await purgeDeliverySamples(extras.delivery.purge);
      logger.info('bookingClock purgeDeliverySamples completed', { purged });
    } catch (e) {
      logger.error('bookingClock purgeDeliverySamples failed', { error: String(e) });
    }
  }

  // Studio steps, last, each in its own try: a failure is logged and the next tick runs it again.
  if (extras.studio) await runStudioSteps(extras.studio);

  // Chụp ngay, last, its own try: a failure is logged, never thrown (the booking sweeps above must not run twice).
  const instant = extras.instant;
  if (instant !== undefined || live) await runInstantStep(() => instant ?? liveInstantDeps());

  if (reminderError !== null) throw reminderError;
  return results;
}

/**
 * The studio steps (#136 Decision 20), each in its own try so one failing query never skips the others:
 * `studioAssignSweeps` (48 h / 26 h reminders and overdue marks, 20a), `studioChangeSweeps` (expired change
 * requests, 20b), `studioStartCancels` (a booking still unassigned at its start is cancelled with 100% back,
 * #136 ruling), `studioMembershipSweeps` (expired invites and requests, and the one-time "invite expiring" notice,
 * 20c). Notices are sent before their mark; failed ones are logged as errors and retried next tick.
 */
export async function runStudioSteps(studio: NonNullable<BookingClockExtras['studio']>): Promise<void> {
  try {
    const r = await runAssignDeadlineSweep(studio.bookings, studio.notify);
    logger.info('bookingClock studioAssignSweeps completed', r);
    if (r.notifyFailed > 0) {
      logger.error('bookingClock studioAssignSweeps notices failed; the bookings stay unmarked and are retried', {
        notifyFailed: r.notifyFailed,
      });
    }
  } catch (e) {
    logger.error('bookingClock studioAssignSweeps failed', { error: String(e) });
  }
  try {
    const r = await runChangeRequestSweep(studio.bookings);
    logger.info('bookingClock studioChangeSweeps completed', r);
  } catch (e) {
    logger.error('bookingClock studioChangeSweeps failed', { error: String(e) });
  }
  try {
    const r = await runUnassignedStartSweep(studio.bookings);
    logger.info('bookingClock studioStartCancels completed', r);
    if (r.failed > 0) logger.error('bookingClock studioStartCancels items failed; retried next tick', { failed: r.failed });
  } catch (e) {
    logger.error('bookingClock studioStartCancels failed', { error: String(e) });
  }
  try {
    const { expired, expiring, notifyFailed, failed } = await runMembershipSweeps(studio.members, studio.notify);
    logger.info('bookingClock studioMembershipSweeps completed', { expired: expired.length, expiring: expiring.length });
    if (failed > 0) {
      logger.error('bookingClock studioMembershipSweeps relations failed; retried next tick', { failed });
    }
    if (notifyFailed > 0) {
      logger.error('bookingClock studioMembershipSweeps expiring notices failed; the invites stay unmarked and are retried', {
        notifyFailed,
      });
    }
  } catch (e) {
    logger.error('bookingClock studioMembershipSweeps failed', { error: String(e) });
  }
}

/** The `instantSweep` step: each failing request is logged with its id and retried next tick. */
export async function runInstantStep(deps: () => InstantDeps): Promise<void> {
  try {
    const { settled, errors } = await runInstantSweep(deps());
    logger.info('bookingClock instantSweep completed', { settled, failed: errors.length });
    for (const e of errors) {
      logger.error('bookingClock instantSweep request failed; retried next tick', { requestId: e.requestId, error: String(e.error) });
    }
  } catch (e) {
    logger.error('bookingClock instantSweep failed', { error: String(e) });
  }
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
