import { newUlid, type GetContactLinkDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { firestoreRegistrationReader } from './event_firestore.js';
import {
  firestoreBookingReader,
  firestoreContactAccessLog,
  firestoreInstantContactReader,
  firestorePhotographerContactReader,
} from './firestore.js';
import { liveBlockGate } from './live_safety.js';

/** Production wiring of getContactLink: bookings, event tickets (`registrationId`) and Chụp ngay requests (`instantRequestId`). */
export function liveContactDeps(): GetContactLinkDeps {
  const firestore = db();
  return {
    bookings: firestoreBookingReader(firestore),
    registrations: firestoreRegistrationReader(firestore),
    instantRequests: firestoreInstantContactReader(firestore),
    photographers: firestorePhotographerContactReader(firestore),
    blocks: liveBlockGate(),
    log: firestoreContactAccessLog(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
