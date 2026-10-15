import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The real callable on the Functions emulator, invoked with an Auth emulator ID token.
// App Check is not enforced locally (CALLABLE_OPTIONS.enforceAppCheck = false).

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'contact-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (uid: string | null, data: unknown) =>
  callCallable('getContactLink', data, uid === null ? undefined : tokens.get(uid));
const logsOf = async (uid: string) =>
  (await db.collection('contact_access_log').where('requesterId', '==', uid).get()).docs.map((d) => d.data());

describe('getContactLink on the emulators', () => {
  test('the customer of an accepted booking gets each URL, and only the URL', async () => {
    const expected: Record<string, string> = {
      call: 'tel:+84912000001',
      zalo: 'https://zalo.me/84912000002',
      whatsapp: 'https://wa.me/14155550101',
    };
    for (const [channel, url] of Object.entries(expected)) {
      const res = await call(LAN, { bookingId: 'seed-booking-accepted', channel });
      assert.equal(res.status, 200, res.text);
      // The whole body is {"result":{"url":…}}: the number travels only inside the URL.
      assert.deepEqual(JSON.parse(res.text), { result: { url } });
    }
  });

  test('a locked booking answers contact_locked exactly as the client expects', async () => {
    for (const bookingId of ['seed-booking-cancelled', 'seed-booking-completed-old']) {
      const res = await call(LAN, { bookingId, channel: 'call' });
      assert.equal(res.error?.status, 'FAILED_PRECONDITION', res.text);
      assert.equal(res.error?.message, 'contact_locked');
      assert.deepEqual(res.error?.details, { code: 'contact_locked' });
      assert.doesNotMatch(res.text, /\d{9}/);
    }
  });

  test('a booking completed 3 days ago is still open', async () => {
    const res = await call(LAN, { bookingId: 'seed-booking-completed-recent', channel: 'call' });
    assert.deepEqual(res.result, { url: 'tel:+84912000001' });
  });

  test('only the customer may ask: the photographer and other customers are refused', async () => {
    for (const uid of [AN, MINH]) {
      const res = await call(uid, { bookingId: 'seed-booking-accepted', channel: 'call' });
      assert.equal(res.error?.status, 'PERMISSION_DENIED', res.text);
      assert.deepEqual(res.error?.details, { code: 'permission_denied' });
    }
  });

  test('signed-out calls are unauthenticated', async () => {
    const res = await call(null, { bookingId: 'seed-booking-accepted', channel: 'call' });
    assert.equal(res.error?.status, 'UNAUTHENTICATED', res.text);
  });

  test('a channel the photographer switched off is not found; the one switched on works', async () => {
    const off = await call(LAN, { bookingId: 'seed-booking-requested-binh', channel: 'zalo' });
    assert.equal(off.error?.status, 'NOT_FOUND', off.text);
    const on = await call(LAN, { bookingId: 'seed-booking-requested-binh', channel: 'call' });
    assert.deepEqual(on.result, { url: 'tel:+84987000001' });
  });

  test('registration links are not found until the events plan', async () => {
    const res = await call(LAN, { registrationId: 'seed-registration-1', channel: 'call' });
    assert.equal(res.error?.status, 'NOT_FOUND', res.text);
  });

  test('malformed requests are invalid and leave no log row', async () => {
    const before = (await logsOf(MINH)).length;
    for (const data of [{}, { bookingId: 'seed-booking-accepted', channel: 'in_app' }, { bookingId: 'a/b', channel: 'call' }]) {
      const res = await call(MINH, data);
      assert.equal(res.error?.status, 'INVALID_ARGUMENT', res.text);
    }
    assert.equal((await logsOf(MINH)).length, before);
  });

  test('every answered request wrote one ContactAccessLog row without any number', async () => {
    const rows = await logsOf(LAN);
    // 3 granted + 2 locked + 1 recent + 2 on Bình's booking (1 refused) + 1 registration.
    assert.equal(rows.length, 9);
    assert.equal(rows.filter((r) => r.granted === true).length, 5);
    for (const r of rows) {
      assert.deepEqual(Object.keys(r).sort(), ['at', 'channel', 'granted', 'requesterId', 'subjectId', 'subjectType']);
      assert.ok(r.at instanceof Timestamp);
      assert.doesNotMatch(JSON.stringify({ ...r, at: null }), /\d{9}/);
    }
  });
});
