/**
 * Production and emulator wiring of DisputeDeps (S18, #142).
 */

import { newUlid, type DisputeDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreDisputeStore } from './dispute_firestore.js';
import { getSharedFakeGateway, liveAccountCipher } from './live_booking.js';
import { FirestoreDisplayNames } from './support_firestore.js';

/** `store` is the Firestore store, which also lists thread messages (the disputes staff CLI). */
export function liveDisputeDeps(): DisputeDeps & { readonly store: FirestoreDisputeStore } {
  const firestore = db();
  return {
    store: new FirestoreDisputeStore(firestore),
    // #129's live gateway (the fake rails until a licensed intermediary is wired).
    gateway: getSharedFakeGateway(),
    // Created on first use, like livePayoutAccountDeps: the secret is read only when a refund is sent.
    cipher: liveAccountCipher(),
    names: new FirestoreDisplayNames(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
