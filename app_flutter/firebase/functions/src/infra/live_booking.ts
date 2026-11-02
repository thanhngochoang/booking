/**
 * Production and emulator wiring of BookingDeps.
 */

import {
  bookingTicketLines,
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

/** `store` is the Firestore store, which also runs the studio sweep queries (StudioBookingStore). */
export function liveBookingDeps(): BookingDeps & { readonly store: FirestoreBookingStore } {
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
    // S30 (#223 Decision 15): a declined, expired or cancelled booking with tickets settles its ticket line at once
    // (the event clock retries a failure). The event deps are built only when a line is settled.
    tickets: {
      settle: async (line) => {
        const { liveEventPaymentDeps } = await import('./live_event.js');
        await bookingTicketLines(liveEventPaymentDeps()).settle(line);
      },
    },
  };
}
