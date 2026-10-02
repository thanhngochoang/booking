/**
 * Production and emulator wiring of BookingDeps.
 */

import {
  newUlid,
  type BookingDeps,
  FakePaymentGateway,
} from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreBookingStore } from './booking_firestore.js';
import { FirestoreCustomerContactReader, FirestoreServiceCatalog } from './booking_readers.js';

let sharedFakeGateway: FakePaymentGateway | undefined;

export function getSharedFakeGateway(): FakePaymentGateway {
  if (!sharedFakeGateway) {
    sharedFakeGateway = new FakePaymentGateway();
  }
  return sharedFakeGateway;
}

export function liveBookingDeps(): BookingDeps {
  const firestore = db();
  return {
    store: new FirestoreBookingStore(firestore),
    services: new FirestoreServiceCatalog(firestore),
    contacts: new FirestoreCustomerContactReader(firestore),
    gateway: getSharedFakeGateway(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
