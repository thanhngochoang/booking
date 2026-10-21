import {
  evaluateUserBadges,
  notifyBookingChange,
  notifyStudioBookingChange,
  syncBookingChat,
  refreshCompletedCount,
  deliveryNotices,
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
    // Idempotent (deterministic notification ids, badge evaluation), so a retry of the event is safe.
    await notifyBookingChange(extras.notify, before, after);
    // Assigned, reassigned, change requested or answered, job returned (#136 Decision 23; #138's hooks).
    await notifyStudioBookingChange(extras.notify, before, after);
    if (extras.studioDays) {
      for (const key of studioDaysOf(before, after)) {
        await extras.studioDays(key.studioId, key.day);
      }
    }

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
