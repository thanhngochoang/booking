import { newUlid, type BookingStore, type ChatDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreBookingStore } from './booking_firestore.js';
import { FirestoreChatStore, FirestorePhotographerInquiryReader } from './chat_firestore.js';

export function liveChatDeps(): ChatDeps & { bookings: BookingStore } {
  const firestore = db();
  return {
    chats: new FirestoreChatStore(firestore),
    photographers: new FirestorePhotographerInquiryReader(firestore),
    bookings: new FirestoreBookingStore(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
