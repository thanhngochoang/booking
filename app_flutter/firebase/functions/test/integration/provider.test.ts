import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, BINH, CUC, DUNG, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The real setProviderType / setStudioAddress callables on the Functions emulator, through the
// Firestore adapter (FirestoreProviderStore). Needs the emulators; CI runs it (npm run test:integration).
//
// Seed facts used here: AN has seed-booking-accepted (and an upcoming one); BINH has
// seed-booking-requested-binh with a held deposit; CUC is a studio; DUNG is an artist with no booking.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'provider-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const photographer = async (uid: string) => (await db.doc(`photographers/${uid}`).get()).data() ?? {};

function assertNotEligible(res: Awaited<ReturnType<typeof call>>): void {
  assert.equal(res.error?.status, 'FAILED_PRECONDITION', res.text);
  assert.equal(res.error?.message, 'not_eligible');
  assert.deepEqual(res.error?.details, { code: 'not_eligible' });
}

describe('provider callables on the emulators', () => {
  test('an accepted booking makes the switch not_eligible; the type stays', async () => {
    const res = await call('setProviderType', AN, { type: 'studio' });
    assertNotEligible(res);
    const doc = await photographer(AN);
    assert.equal(doc.providerType, undefined);
  });

  test('a photographer with no open work becomes a studio and loses artistSince', async () => {
    assert.ok((await photographer(DUNG)).artistSince instanceof Timestamp);
    const res = await call('setProviderType', DUNG, { type: 'studio' });
    assert.deepEqual(res.result, { providerType: 'studio' }, res.text);
    const doc = await photographer(DUNG);
    assert.equal(doc.providerType, 'studio');
    assert.equal('artistSince' in doc, false);
  });

  test('setStudioAddress writes the private address and the public district and city', async () => {
    const res = await call('setStudioAddress', CUC, {
      line: '45 Nguyễn Thị Minh Khai',
      ward: 'Phường 6',
      district: 'Quận 3',
      city: 'TP.HCM',
      lat: 10.78,
      lng: 106.69,
    });
    assert.equal(res.status, 200, res.text);
    const priv = (await db.doc(`photographers/${CUC}/private/studioAddress`).get()).data() ?? {};
    assert.equal(priv.line, '45 Nguyễn Thị Minh Khai');
    assert.equal(priv.ward, 'Phường 6');
    assert.equal(priv.district, 'Quận 3');
    assert.equal(priv.city, 'TP.HCM');
    assert.equal(priv.lat, 10.78);
    assert.equal(priv.lng, 106.69);
    assert.ok(priv.updatedAt instanceof Timestamp);
    const pub = await photographer(CUC);
    assert.equal(pub.studioDistrict, 'Quận 3');
    assert.equal(pub.studioCity, 'TP.HCM');
    assert.equal('line' in pub, false);
  });

  test('a partially refunded payment still counts as held money', async () => {
    const ref = db.doc('payments/test-payment-partial-cuc');
    await ref.set({
      subjectType: 'booking',
      subjectId: 'test-booking-partial-cuc',
      payerId: LAN,
      payeeId: CUC,
      provider: 'fake',
      amount: 300_000,
      status: 'paid',
      escrowStatus: 'partially_refunded',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    try {
      const res = await call('setProviderType', CUC, { type: 'individual' });
      assertNotEligible(res);
      assert.equal((await photographer(CUC)).providerType, 'studio');
    } finally {
      await ref.delete();
    }
  });

  test('a requested booking blocks; once it is completed the photographer can switch', async () => {
    assertNotEligible(await call('setProviderType', BINH, { type: 'studio' }));

    // Only a completed booking left: the booking is done and its deposit released.
    await db.doc('bookings/seed-booking-requested-binh').update({ status: 'completed' });
    const payments = await db.collection('payments').where('payeeId', '==', BINH).get();
    assert.ok(payments.size > 0);
    for (const p of payments.docs) await p.ref.update({ escrowStatus: 'released' });

    const res = await call('setProviderType', BINH, { type: 'studio' });
    assert.deepEqual(res.result, { providerType: 'studio' }, res.text);
    assert.equal((await photographer(BINH)).providerType, 'studio');
  });
});
