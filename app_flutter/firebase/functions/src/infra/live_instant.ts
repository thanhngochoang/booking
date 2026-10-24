/**
 * Production and emulator wiring of InstantDeps (plan #140 Task 4, money #202). `blocks` is set explicitly:
 * #198's `orderBlocker` skips blocks silently when `OrderGateDeps.blocks` is missing.
 */
import { newUlid, type InstantDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreCustomerContactReader, FirestoreProviderOrderGate } from './booking_readers.js';
import { FirestoreInstantStore, FirestorePresenceDirectory } from './instant_firestore.js';
import {
  FirestoreInstantConfigReader,
  FirestoreInstantDayReader,
  FirestoreInstantProfileReader,
  FirestorePhotographerPhoneReader,
} from './instant_readers.js';
import { livePushSender } from './live_notification.js';
import { getSharedFakeGateway, liveAccountCipher } from './live_booking.js';
import { liveBlockGate } from './live_safety.js';
import { FirestorePaymentLookup } from './payment_firestore.js';
import { FirestoreUserDirectory } from './user_directory.js';

/** One per instance, so the 60 s config cache survives across calls. */
let sharedConfig: FirestoreInstantConfigReader | undefined;

export function liveInstantDeps(): InstantDeps {
  const firestore = db();
  sharedConfig ??= new FirestoreInstantConfigReader(firestore);
  return {
    store: new FirestoreInstantStore(firestore),
    presences: new FirestorePresenceDirectory(firestore),
    config: sharedConfig,
    providers: new FirestoreProviderOrderGate(firestore),
    blocks: liveBlockGate(),
    contacts: new FirestoreCustomerContactReader(firestore),
    phones: new FirestorePhotographerPhoneReader(firestore),
    profiles: new FirestoreInstantProfileReader(firestore),
    days: new FirestoreInstantDayReader(firestore),
    users: new FirestoreUserDirectory(firestore),
    // #202: #129's gateway (the instance bookings, tickets and the fee use), V1's cross-subject lookup
    // for fresh transfer codes, V2's cipher (read on first use: only functions bound to PAYMENT_SECRETS refund).
    gateway: getSharedFakeGateway(),
    payments: new FirestorePaymentLookup(firestore),
    cipher: liveAccountCipher(),
    push: livePushSender(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
