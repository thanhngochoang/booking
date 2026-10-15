import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { MemoryPushSender, newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { LAN, SEED_EVENT_SOON, SEED_REGISTRATION_LAN_SOON } from '../../seed/fixtures.js';
import { FirestoreEventStore, firestoreEventPeople, ownCoverUpload } from '../../src/infra/event_firestore.js';
import { firestoreUserContactReader } from '../../src/infra/firestore.js';
import { FirestoreNotificationStore } from '../../src/infra/notification_firestore.js';
import { FirestoreUserDirectory } from '../../src/infra/user_directory.js';
import { storageUrlPrefixes } from '../../src/config.js';
import { handleEventClock } from '../../src/scheduled/event_clock.js';

// S17 event reminder on the Firestore emulator: the seed event starts 36 h after seeding and Lan
// holds a paid ticket; one eventClock run writes one `event_soon` row and stamps `soonNoticeAt`
// (the query needs the events (status, soonNoticeAt, startAt) index). CI runs it
// (npm run test:integration); written, not run, while executing plans.

let app: App;
let db: Firestore;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'event-soon-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

const eventDeps = () => ({
  events: new FirestoreEventStore(db),
  people: firestoreEventPeople(db),
  contacts: firestoreUserContactReader(db),
  media: { isOwnUpload: ownCoverUpload(storageUrlPrefixes()) },
  clock: { now: () => new Date() },
  ids: { newId: () => newUlid(Date.now()) },
  random: (n: number) => globalThis.crypto.getRandomValues(new Uint8Array(n)),
});

describe('eventClock event_soon', () => {
  test('one run notifies the paid ticket once and stamps soonNoticeAt; a second run sends nothing', async () => {
    const push = new MemoryPushSender();
    const notify = { store: new FirestoreNotificationStore(db), push, users: new FirestoreUserDirectory(db), clock: { now: () => new Date() } };

    const first = await handleEventClock(eventDeps(), { notify });
    assert.equal(first.soonEvents, 1);
    assert.equal(first.soonSent, 1);

    const rows = (await db.collection(`users/${LAN}/notifications`).where('type', '==', 'event_soon').get()).docs;
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.id, `n_event_soon_${SEED_EVENT_SOON}_${SEED_REGISTRATION_LAN_SOON}`);
    assert.equal(rows[0]?.data().target, `/e/${SEED_EVENT_SOON}`);
    assert.match(String(rows[0]?.data().title), /^Chụp phố đêm bắt đầu (sau 2 ngày|ngày mai)$/);
    assert.notEqual((await db.doc(`events/${SEED_EVENT_SOON}`).get()).data()?.soonNoticeAt ?? null, null);

    const second = await handleEventClock(eventDeps(), { notify });
    assert.deepEqual([second.soonEvents, second.soonSent], [0, 0]);
    assert.equal((await db.collection(`users/${LAN}/notifications`).where('type', '==', 'event_soon').get()).size, 1);
    assert.equal(push.sent.length, 1);
  });
});
