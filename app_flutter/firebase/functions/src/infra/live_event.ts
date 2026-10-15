import { newUlid, notify, type EventDeps, type EventPaymentDeps } from '@photobooking/domain';
import { storageUrlPrefixes } from '../config.js';
import type { EventCallableDeps } from '../callables/event.js';
import { db } from './admin.js';
import { firestoreEventPeople, FirestoreEventStore, ownCoverUpload } from './event_firestore.js';
import { firestoreUserContactReader } from './firestore.js';
import { getSharedFakeGateway, liveAccountCipher } from './live_booking.js';
import { liveNotifyDeps } from './live_notification.js';
import { FirestorePaymentLookup } from './payment_firestore.js';

export function liveEventDeps(): EventDeps {
  const firestore = db();
  const prefixes = storageUrlPrefixes();
  return {
    events: new FirestoreEventStore(firestore),
    people: firestoreEventPeople(firestore),
    contacts: firestoreUserContactReader(firestore),
    media: { isOwnUpload: ownCoverUpload(prefixes) },
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    random: (n) => globalThis.crypto.getRandomValues(new Uint8Array(n)),
  };
}

/** Paid tickets use the booking payment wiring (the same gateway instance as deposits). */
export function liveEventPaymentDeps(): EventPaymentDeps {
  const firestore = db();
  return {
    ...liveEventDeps(),
    gateway: getSharedFakeGateway(),
    payments: new FirestorePaymentLookup(firestore),
    cipher: liveAccountCipher(),
  };
}

export function liveEventCallableDeps(): EventCallableDeps {
  return {
    ...liveEventPaymentDeps(),
    notifyHostInvited: async (hostId, eventId, title, expiresAt) => {
      await notify(liveNotifyDeps(), {
        userId: hostId,
        content: { type: 'event_host_invited', title },
        target: `/events/${eventId}/manage`,
        dedupeKey: `event_host_invited_${eventId}_${expiresAt.getTime()}`,
      });
    },
  };
}
