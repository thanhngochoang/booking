/**
 * Production and emulator wiring of the S30 organizer and scan deps (#223, plan Task 6).
 */

import { newUlid, type ScanDeps, type SuspendOrganizerDeps } from '@photobooking/domain';
import type { OrganizerCallableDeps } from '../callables/organizer.js';
import { storageUrlPrefixes } from '../config.js';
import { auth, db } from './admin.js';
import { FirestoreProviderOrderGate } from './booking_readers.js';
import { liveEventPaymentDeps } from './live_event.js';
import { liveNotifyDeps } from './live_notification.js';
import { liveBlockGate } from './live_safety.js';
import { FirestoreOrganizerStore, firestoreOrganizerPeople } from './organizer_firestore.js';
import { FirestoreScanStore } from './scan_firestore.js';
import { FirestoreDisplayNames } from './support_firestore.js';

/** Staff admin: the Auth custom claim `staffRole == 'admin'` (CLI actors; callables use the caller's token). */
export async function isAdminUser(uid: string): Promise<boolean> {
  try {
    return (await auth().getUser(uid)).customClaims?.staffRole === 'admin';
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/user-not-found') return false;
    throw e;
  }
}

export function liveOrganizerDeps(): OrganizerCallableDeps & SuspendOrganizerDeps {
  const firestore = db();
  return {
    organizers: new FirestoreOrganizerStore(firestore),
    people: firestoreOrganizerPeople(firestore, isAdminUser),
    providers: new FirestoreProviderOrderGate(firestore),
    blocks: liveBlockGate(),
    notify: liveNotifyDeps(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    spotCoverPrefixes: storageUrlPrefixes(),
    eventPayments: liveEventPaymentDeps(),
  };
}

/** `scanPass` over one Firestore transaction; the shooter's result names the customer (no contact data). */
export function liveScanDeps(): ScanDeps {
  const firestore = db();
  return {
    scans: new FirestoreScanStore(firestore),
    names: new FirestoreDisplayNames(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
