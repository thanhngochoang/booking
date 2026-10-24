import {
  evaluateUserBadges,
  notifyBookingChange,
  notifyStudioBookingChange,
  syncBookingChat,
  refreshCompletedCount,
  deliveryNotices,
  poachingSignal,
  notifyDeliverySubmitted,
  notifyDeliveryRevisionRequested,
  notifyDeliveryApproved,
  notifyDeliveryExtraRound,
  type BadgeDeps,
  type ChatDeps,
  type NotifyDeps,
  type DiscoveryDeps,
  type Booking,
} from '@photobooking/domain';
import { db } from '../infra/admin.js';
import { bookingFromFirestore } from '../infra/booking_firestore.js';
import type { FirestoreCollabBookingSync } from '../infra/recruit_firestore.js';

/** The S27 reads and writes of this trigger (`FirestoreCollabBookingSync` in production). */
export type CollabBookingSync = Pick<
  FirestoreCollabBookingSync,
  'syncJobs' | 'acceptedJobsWith' | 'personalBookingTimes' | 'createPoachFlag'
>;

export async function handleBookingWrite(
  event: {
    id: string;
    before?: Record<string, unknown>;
    after?: Record<string, unknown>;
  },
  deps: ChatDeps,
  updateChatId?: (bookingId: string, chatId: string) => Promise<void>,
  extras?: {
    notify: NotifyDeps;
    badges: BadgeDeps;
    /** #136 Decision 26: recompute a studio's derived `full` day after a studio booking change. */
    studioDays?: (studioId: string, day: string) => Promise<unknown>;
    /** S27 (#151): collab jobs follow their booking; a new personal booking may raise the poaching flag. */
    collab?: CollabBookingSync;
  },
  discovery?: DiscoveryDeps,
): Promise<{ chatId: string | null; setBookingChatId: boolean }> {
  const before = event.before ? bookingFromFirestore(event.id, event.before) : null;
  const after = event.after ? bookingFromFirestore(event.id, event.after) : null;

  const result = await syncBookingChat(deps, { before, after });
  if (result.setBookingChatId && result.chatId && after) {
    if (updateChatId) {
      await updateChatId(after.id, result.chatId);
    } else {
      await db().collection('bookings').doc(after.id).update({ chatId: result.chatId });
    }
  }

  if (extras) {
    // The studio's derived day first, so a failing notice never leaves a freed or taken day unrecomputed (#136
    // Decision 26); the retry of the event recomputes again, which is idempotent.
    if (extras.studioDays) {
      for (const key of studioDaysOf(before, after)) {
        await extras.studioDays(key.studioId, key.day);
      }
    }
    // Both idempotent: a job re-read in its transaction, a flag created once.
    if (extras.collab) {
      await syncCollabJob(before, after, extras.collab);
      await flagPoaching(before, after, extras.collab, new Date());
    }
    // Idempotent (deterministic notification ids, badge evaluation), so a retry of the event is safe.
    await notifyBookingChange(extras.notify, before, after);
    // Assigned, reassigned, change requested or answered, job returned (#136 Decision 23; #138's hooks).
    await notifyStudioBookingChange(extras.notify, before, after);

    if (after) {
      const dNotices = deliveryNotices(before, after);
      for (const dn of dNotices) {
        if (dn.kind === 'submitted') {
          // Fetch sample count of the round
          const roundDoc = await db().collection('bookings').doc(after.id).collection('deliveries').doc(String(dn.round)).get();
          const count = Number(roundDoc.data()?.photoCount ?? (roundDoc.data()?.samples?.length ?? 0));
          await notifyDeliverySubmitted(extras.notify, {
            bookingId: after.id,
            customerId: after.customerId,
            delivererId: after.photographerId,
            round: dn.round,
            count,
          });
        } else if (dn.kind === 'revision_requested') {
          await notifyDeliveryRevisionRequested(extras.notify, {
            bookingId: after.id,
            customerId: after.customerId,
            delivererId: after.photographerId,
            round: dn.round,
          });
        } else if (dn.kind === 'approved') {
          await notifyDeliveryApproved(extras.notify, {
            bookingId: after.id,
            customerId: after.customerId,
            delivererId: after.photographerId,
          });
        } else if (dn.kind === 'extra_round') {
          await notifyDeliveryExtraRound(extras.notify, {
            bookingId: after.id,
            customerId: after.customerId,
            delivererId: after.photographerId,
            round: dn.round,
            granted: dn.granted,
          });
        }
      }
    }

    if (after && before?.status !== 'completed' && after.status === 'completed') {
      const results = await Promise.allSettled(
        [after.customerId, after.photographerId].map((uid) => evaluateUserBadges(extras.badges, uid)),
      );
      const failed = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
      if (failed) throw new Error(`badge evaluation failed after completion: ${String(failed.reason)}`);
    }
  }

  // Refresh completedCount when a booking enters completed
  if (discovery && after && before?.status !== 'completed' && after.status === 'completed') {
    await refreshCompletedCount(discovery, after.photographerId);
  }

  return result;
}

/**
 * The studio days a booking write can change: the studio's day before and after (one when the day did not move),
 * when the booking appeared or went, or its status, day or assignee changed (other writes leave the load alone).
 */
export function studioDaysOf(before: Booking | null, after: Booking | null): { studioId: string; day: string }[] {
  if (
    before !== null &&
    after !== null &&
    before.status === after.status &&
    before.day === after.day &&
    (before.assigneeId ?? null) === (after.assigneeId ?? null)
  ) {
    return [];
  }
  const keys = new Map<string, { studioId: string; day: string }>();
  for (const b of [before, after]) {
    if (b?.isStudio === true) keys.set(`${b.photographerId}_${b.day}`, { studioId: b.photographerId, day: b.day });
  }
  return [...keys.values()];
}

/**
 * S27 (Decision 15): when a studio booking is cancelled, completed or reviewed, each live collab job of it is
 * cancelled (before the shoot ended) or closed (`syncCollabJobOnBooking`). Other writes read nothing.
 */
export async function syncCollabJob(before: Booking | null, after: Booking | null, sync: Pick<CollabBookingSync, 'syncJobs'>): Promise<number> {
  if (after === null || after.isStudio !== true || before?.status === after.status) return 0;
  if (after.status !== 'cancelled' && after.status !== 'completed' && after.status !== 'reviewed') return 0;
  return sync.syncJobs(after);
}

/**
 * S27 Decision 18 (record only): a new non-studio booking whose photographer had an accepted collab job with
 * the same customer in the last 183 days, and now has at least 2 personal bookings with them since, writes
 * `staff_flags/poach_{photographerId}_{customerId}` once.
 */
export async function flagPoaching(
  before: Booking | null,
  after: Booking | null,
  sync: Pick<CollabBookingSync, 'acceptedJobsWith' | 'personalBookingTimes' | 'createPoachFlag'>,
  now: Date,
): Promise<'none' | 'flagged' | 'exists'> {
  if (before !== null || after === null || after.isStudio === true) return 'none';
  const jobs = await sync.acceptedJobsWith(after.photographerId, after.customerId, now);
  if (jobs.length === 0) return 'none';
  const times = await sync.personalBookingTimes(after.photographerId, after.customerId);
  const flagged = poachingSignal({
    customerId: after.customerId,
    jobs,
    personalBookingsSince: (since) => times.filter((t) => t.getTime() >= since.getTime()).length,
    now,
  });
  if (flagged === null) return 'none';
  const earliest = [...flagged].sort((a, b) => (a.acceptedAt?.getTime() ?? 0) - (b.acceptedAt?.getTime() ?? 0))[0];
  const created = await sync.createPoachFlag({
    photographerId: after.photographerId,
    customerId: after.customerId,
    studioId: earliest?.studioId ?? '',
    jobIds: flagged.map((j) => j.id),
    createdAt: now,
  });
  return created ? 'flagged' : 'exists';
}
