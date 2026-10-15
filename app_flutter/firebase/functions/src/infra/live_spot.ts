/**
 * Production and emulator wiring of SpotScheduleDeps.
 */

import { newUlid, type SpotScheduleDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreSpotScheduleStore } from './spot_firestore.js';
import { FirestoreProviderOrderGate } from './booking_readers.js';
import { FirestoreStudioRoster } from './studio_firestore.js';

export function liveSpotScheduleDeps(): SpotScheduleDeps {
  const firestore = db();
  return {
    schedules: new FirestoreSpotScheduleStore(firestore),
    providers: new FirestoreProviderOrderGate(firestore),
    roster: new FirestoreStudioRoster(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
