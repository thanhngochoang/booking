import { newUlid, type BookingStore, type ChatDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreBookingStore } from './booking_firestore.js';
import { FirestoreChatStore, FirestorePhotographerInquiryReader } from './chat_firestore.js';
import { liveBlockGate } from './live_safety.js';

export function liveChatDeps(): ChatDeps & { bookings: BookingStore } {
  const firestore = db();
  return {
    chats: new FirestoreChatStore(firestore),
    photographers: new FirestorePhotographerInquiryReader(firestore),
    bookings: new FirestoreBookingStore(firestore),
    blocks: liveBlockGate(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
