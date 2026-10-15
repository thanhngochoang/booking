import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { MemoryPushSender, newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { eventFromFirestore, FirestoreEventStore } from '../../src/infra/event_firestore.js';
import { handleEventClock } from '../../src/scheduled/event_clock.js';
import { firestoreEventPeople, ownCoverUpload } from '../../src/infra/event_firestore.js';
import { firestoreUserContactReader } from '../../src/infra/firestore.js';
import { storageUrlPrefixes } from '../../src/config.js';
import { FirestoreNotificationStore } from '../../src/infra/notification_firestore.js';
import { FirestoreUserDirectory } from '../../src/infra/user_directory.js';
import { eventStartInDays } from './event_social_support.js';

// The real event callables on the Functions emulator through FirestoreEventStore. Needs the
// emulators; CI runs it (npm run test:integration). Each test builds its own events.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'event-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};
const bucketUrl = (path: string): string =>
  `http://127.0.0.1:9199/v0/b/${emulatorProject()}.firebasestorage.app/o/${encodeURIComponent(path)}?alt=media&token=t`;

/** A customer with a phone, created through the Admin SDK (the seed has only one). */
async function makeCustomer(n: number): Promise<string> {
  const uid = `evt-customer-${n}-${Date.now()}`;
  const email = `${uid}@seed.test`;
  await getAuth(app).createUser({ uid, email, password: SEED_PASSWORD, displayName: `Khách ${n}` });
  await db.doc(`users/${uid}`).set({ displayName: `Khách ${n}`, role: 'customer', createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  await db.doc(`users/${uid}/private/contact`).set({ phone: `+8490500${String(1000 + n)}`, phoneVerified: false, allowZalo: false, allowWhatsApp: false });
  tokens.set(uid, await signIn(email, SEED_PASSWORD));
  return uid;
}

// Publishing reserves the host's availability day, so every event gets its own day.
let nextDay = 30;

async function publish(host: string, over: Record<string, unknown> = {}, daysAhead = nextDay++): Promise<string> {
  const eventId = newUlid(Date.now());
  const path = `eventCovers/${host}/${eventId}/cover.jpg`;
  const start = eventStartInDays(daysAhead);
  const res = await call('saveEventDraft', host, {
    eventId, title: `Photo walk ${eventId.slice(-6)}`, type: 'photo_walk',
    coverUrl: bucketUrl(path), coverPath: path,
    startAt: start.toISOString(), endAt: new Date(start.getTime() + 3 * 3_600_000).toISOString(),
    location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 },
    capacity: 5, price: 0, ...over,
  });
  assert.ok((res.result as { eventId?: string } | undefined)?.eventId, res.text);
  const pub = await call('publishEvent', host, { eventId });
  assert.equal(pub.status, 200, pub.text);
  return eventId;
}

describe('events on the emulators', () => {
  test('draft, publish and list', async () => {
    const eventId = await publish(AN);
    const ev = await data(`events/${eventId}`);
    assert.equal(ev.status, 'open');
    assert.equal(ev.hostId, AN);
    assert.ok(ev.startAt instanceof Timestamp);
    const open = await db.collection('events').where('status', 'in', ['open', 'full']).get();
    assert.ok(open.docs.some((d) => d.id === eventId));
    assert.equal((await data(`chats/event_${eventId}`)).kind, 'event_group');
  });

  test('free registration appears in the user\'s tickets', async () => {
    const eventId = await publish(AN);
    const res = await call('registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    assert.equal(res.status, 200, res.text);
    const regId = (res.result as { registrationId: string }).registrationId;
    const mine = await db.collectionGroup('registrations').where('userId', '==', LAN).orderBy('createdAt', 'desc').get();
    assert.ok(mine.docs.some((d) => d.id === regId));
    const reg = await data(`events/${eventId}/registrations/${regId}`);
    assert.equal(reg.status, 'paid');
    assert.equal(reg.contactEligible, false);
    assert.equal((await db.doc(`events/${eventId}/registrations/${regId}/private/contact`).get()).exists, false);
  });

  test('check-in twice is conflict', async () => {
    // Check-in opens at 00:00 of the event day only; move the day to today. (Not on day 1: the seed's
    // S17 event 36 h ahead may hold An's availability tomorrow.)
    const eventId = await publish(AN);
    const res = await call('registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    const regId = (res.result as { registrationId: string }).registrationId;
    const code = (await data(`events/${eventId}/registrations/${regId}`)).ticketCode as string;
    await db.doc(`events/${eventId}`).update({ dayKey: new Date().toISOString().slice(0, 10) });
    await db.doc(`events/${eventId}`).update({ endAt: Timestamp.fromMillis(Date.now() + 3_600_000) });
    const first = await call('checkInRegistration', AN, { eventId, ticketCode: code });
    assert.equal(first.status, 200, first.text);
    const second = await call('checkInRegistration', AN, { eventId, ticketCode: code });
    assert.equal(second.status, 409);
    assert.equal((second.error?.details as { code?: string } | undefined)?.code, 'conflict');
  });

  test('cancel event frees the availability day', async () => {
    const eventId = await publish(AN);
    const day = (await data(`events/${eventId}`)).dayKey as string;
    assert.equal((await data(`availability/${AN}/days/${day}`)).eventId, eventId);
    const res = await call('cancelEvent', AN, { eventId });
    assert.equal(res.status, 200, res.text);
    assert.equal((await db.doc(`availability/${AN}/days/${day}`).get()).exists, false);
    assert.equal((await data(`events/${eventId}`)).status, 'cancelled');
  });

  test('eventClock closes and completes', async () => {
    const closing = await publish(AN);
    const finishing = await publish(AN);
    await db.doc(`events/${closing}`).update({ registrationDeadline: Timestamp.fromMillis(Date.now() - 1000) });
    await db.doc(`events/${finishing}`).update({ endAt: Timestamp.fromMillis(Date.now() - 1000) });
    const store = new FirestoreEventStore(db);
    const results = await handleEventClock({
      events: store,
      people: firestoreEventPeople(db),
      contacts: firestoreUserContactReader(db),
      media: { isOwnUpload: ownCoverUpload(storageUrlPrefixes()) },
      clock: { now: () => new Date() },
      ids: { newId: () => newUlid(Date.now()) },
      random: (n) => globalThis.crypto.getRandomValues(new Uint8Array(n)),
    }, {
      // The S17 reminder step runs too (the seed has an event 36 h ahead): this app's Firestore, no FCM.
      notify: { store: new FirestoreNotificationStore(db), push: new MemoryPushSender(), users: new FirestoreUserDirectory(db), clock: { now: () => new Date() } },
    });
    assert.ok(results.closed >= 1 && results.completed >= 1);
    assert.equal(eventFromFirestore(closing, await data(`events/${closing}`)).status, 'closed');
    assert.equal((await data(`events/${finishing}`)).status, 'completed');
    assert.ok((await data(`chats/event_${finishing}`)).readOnlyAt instanceof Timestamp);
  });

  test('getContactLink stays locked for a free registration (O3) and unlocks when contactEligible is set', async () => {
    const eventId = await publish(AN);
    const res = await call('registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    const regId = (res.result as { registrationId: string }).registrationId;
    // The attendee asks for the host's number; a free ticket does not unlock it.
    const locked = await call('getContactLink', LAN, { registrationId: regId, channel: 'call' });
    assert.equal((locked.error?.details as { code?: string } | undefined)?.code, 'contact_locked', locked.text);
    // A paid ticket (contactEligible true, set here as the paid path will) unlocks it.
    await db.doc(`events/${eventId}/registrations/${regId}`).update({ contactEligible: true });
    const open = await call('getContactLink', LAN, { registrationId: regId, channel: 'call' });
    assert.equal(open.status, 200, open.text);
    assert.match((open.result as { url: string }).url, /^tel:/);
  });

  // Last on purpose: the emulator serialises the transactions' queries, so heavy contention is slow;
  // 6 callers on 3 seats still proves no oversell without timing out the callables.
  test('parallel registrations never oversell', async () => {
    const eventId = await publish(AN, { capacity: 3 });
    const users = await Promise.all(Array.from({ length: 6 }, (_, i) => makeCustomer(i)));
    const results = await Promise.all(users.map((u) => call('registerEvent', u, { eventId, quantity: 1, name: 'Khách' })));
    const ok = results.filter((r) => r.status === 200).length;
    assert.equal(ok, 3, results.map((r) => r.text).join('\n'));
    const ev = await data(`events/${eventId}`);
    assert.equal(ev.registeredCount, 3);
    assert.equal(ev.status, 'full');
    const regs = await db.collection(`events/${eventId}/registrations`).get();
    assert.equal(regs.size, 3);
  });
});
