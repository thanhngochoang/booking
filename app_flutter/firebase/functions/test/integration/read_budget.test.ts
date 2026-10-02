import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getContactLink, type GetContactLinkDeps } from '@photobooking/domain';
import {
  firestoreBookingReader,
  firestoreContactAccessLog,
  firestorePhotographerContactReader,
} from '../../src/infra/firestore.js';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { LAN } from '../../seed/fixtures.js';

let app: App;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'budget-test');
  await applySeed(getFirestore(app), getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

/** Counts what the real adapters read; they read only through getAll (asserted below). */
function counted(db: Firestore): { documents: number; roundTrips: number } {
  const reads = { documents: 0, roundTrips: 0 };
  const getAll = db.getAll.bind(db);
  Object.assign(db, {
    getAll: (...refs: Parameters<Firestore['getAll']>) => {
      reads.roundTrips += 1;
      reads.documents += refs.length;
      return getAll(...refs);
    },
  });
  return reads;
}

test('an unlocked call reads 3 documents in 2 round trips; a locked one reads 1', async () => {
  const db = getFirestore(app);
  const reads = counted(db);
  let n = 0;
  const deps: GetContactLinkDeps = {
    bookings: firestoreBookingReader(db),
    photographers: firestorePhotographerContactReader(db),
    log: firestoreContactAccessLog(db),
    clock: { now: () => new Date() },
    ids: { newId: () => `budget-${++n}` },
  };
  assert.deepEqual(
    await getContactLink(LAN, { bookingId: 'seed-booking-accepted', channel: 'zalo' }, deps),
    { url: 'https://zalo.me/84912000002' },
  );
  assert.deepEqual(reads, { documents: 3, roundTrips: 2 });
  reads.documents = 0;
  reads.roundTrips = 0;
  await assert.rejects(getContactLink(LAN, { bookingId: 'seed-booking-cancelled', channel: 'zalo' }, deps));
  assert.deepEqual(reads, { documents: 1, roundTrips: 1 });
});

test('the adapters read only through getAll, so the count above is complete', () => {
  const src = readFileSync('src/infra/firestore.ts', 'utf8');
  assert.doesNotMatch(src, /\.get\(\)/);
  assert.doesNotMatch(src, /\.where\(|\.collectionGroup\(|runTransaction|\.listDocuments\(/);
});
