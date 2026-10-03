import { syncBookingChat, type ChatDeps } from '@photobooking/domain';
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

  return result;
}
