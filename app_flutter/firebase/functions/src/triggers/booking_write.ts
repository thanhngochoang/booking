import {
  evaluateUserBadges,
  notifyBookingChange,
  syncBookingChat,
  refreshCompletedCount,
  type BadgeDeps,
  type ChatDeps,
  type NotifyDeps,
  type DiscoveryDeps,
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
  extras?: { notify: NotifyDeps; badges: BadgeDeps },
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
