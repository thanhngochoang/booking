import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { DomainError } from '@photobooking/domain';
import { makeRequirePhone } from '../../src/infra/require_phone.js';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { LAN, MINH } from '../../seed/fixtures.js';

let app: App;
const phoneRequired = (e: unknown) => e instanceof DomainError && e.code === 'phone_required';

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'phone-test');
  await applySeed(getFirestore(app), getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

test('requirePhone returns the stored number or refuses with phone_required', async () => {
  const requirePhone = makeRequirePhone(getFirestore(app));
  assert.equal(await requirePhone(LAN), '+84903000001');
  await assert.rejects(requirePhone(MINH), phoneRequired);
  await assert.rejects(requirePhone('seed-nobody'), phoneRequired);
});

test('a malformed stored number is phone_required too', async () => {
  const db = getFirestore(app);
  await db.doc('users/seed-bad-phone/private/contact').set({ phone: '0903000001' });
  await assert.rejects(makeRequirePhone(db)('seed-bad-phone'), phoneRequired);
});
