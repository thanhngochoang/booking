import { newUlid, type GetContactLinkDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { firestoreBookingReader, firestoreContactAccessLog, firestorePhotographerContactReader } from './firestore.js';

/**
 * Production wiring of getContactLink. `registrations` is left out on purpose: event registrations
 * do not exist yet, so registration requests answer `not_found` until the events plan adds a reader.
 */
export function liveContactDeps(): GetContactLinkDeps {
  const firestore = db();
  return {
    bookings: firestoreBookingReader(firestore),
    photographers: firestorePhotographerContactReader(firestore),
    log: firestoreContactAccessLog(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
