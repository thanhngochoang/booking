/**
 * Production and emulator wiring of BookingDeps.
 */

import {
  newUlid,
  type BookingDeps,
  FakePaymentGateway,
} from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreAddonCatalog } from './addon_firestore.js';
import { FirestoreBookingStore } from './booking_firestore.js';
import { liveBlockGate } from './live_safety.js';
import { FirestoreCustomerContactReader, FirestoreProviderOrderGate, FirestoreServiceCatalog } from './booking_readers.js';

import { PAYOUT_ACCOUNT_KEY } from '../config.js';
import { lazyAccountCipher } from './account_cipher.js';
import type { AccountCipher } from '@photobooking/domain';

let sharedFakeGateway: FakePaymentGateway | undefined;

export function getSharedFakeGateway(): FakePaymentGateway {
  if (!sharedFakeGateway) {
    sharedFakeGateway = new FakePaymentGateway();
  }
  return sharedFakeGateway;
}

export function liveAccountCipher(): AccountCipher {
  return lazyAccountCipher(() => PAYOUT_ACCOUNT_KEY.value());
}

export function liveBookingDeps(): BookingDeps {
  const firestore = db();
  return {
    store: new FirestoreBookingStore(firestore),
    services: new FirestoreServiceCatalog(firestore),
    addons: new FirestoreAddonCatalog(firestore),
    contacts: new FirestoreCustomerContactReader(firestore),
    providers: new FirestoreProviderOrderGate(firestore),
    blocks: liveBlockGate(),
    gateway: getSharedFakeGateway(),
    cipher: liveAccountCipher(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
