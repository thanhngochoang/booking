import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { SEED_BOOKINGS, SEED_PASSWORD, SEED_USERS, seedDocuments } from '../../seed/fixtures.js';

let app: App;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'seed-test');
});
after(async () => {
  await deleteApp(app);
});

describe('seed on the emulators', () => {
  test('writes every document and can run twice', async () => {
    const now = new Date();
    await applySeed(getFirestore(app), getAuth(app), now);
    await applySeed(getFirestore(app), getAuth(app), now);
    const db = getFirestore(app);
    for (const d of seedDocuments(now)) assert.ok((await db.doc(d.path).get()).exists, d.path);
    assert.equal((await db.collection('bookings').count().get()).data().count, SEED_BOOKINGS.length);
    assert.equal((await getAuth(app).listUsers()).users.length, SEED_USERS.length);
  });

  test('every seed account signs in with the documented password', async () => {
    for (const u of SEED_USERS) assert.ok((await signIn(u.email, SEED_PASSWORD)).length > 100, u.email);
  });
});
