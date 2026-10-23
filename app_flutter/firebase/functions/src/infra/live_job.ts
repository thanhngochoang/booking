import { newUlid, type JobDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreJobStore, firestoreJobPeople, firestoreJobMedia } from './job_firestore.js';
import { FirestoreProviderOrderGate } from './booking_readers.js';
import { liveBlockGate } from './live_safety.js';
import { firestoreUserContactReader } from './firestore.js';

export function liveJobDeps(): JobDeps {
  const firestore = db();
  return {
    jobs: new FirestoreJobStore(firestore),
    people: firestoreJobPeople(firestore),
    contacts: firestoreUserContactReader(firestore),
    media: firestoreJobMedia(),
    providers: new FirestoreProviderOrderGate(firestore),
    blocks: liveBlockGate(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
