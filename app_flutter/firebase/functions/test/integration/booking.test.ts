import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The booking callables on the emulators, with the packages where the app writes them
// (photographers/{uid}/services/{id}): create → deposit → fake payment → check → accept.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'booking-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const draft = {
  photographerId: AN,
  serviceId: 'seed-service-portrait',
  day: '2026-11-14',
  start: '15:30',
  place: { name: 'Hồ Gươm', point: { lat: 21.028, lng: 105.852 } },
  expectedPrice: 1_500_000,
};

describe('booking callables on the emulators', () => {
  test('a customer without a phone is refused with phone_required', async () => {
    const res = await call('createBooking', MINH, draft);
    assert.equal(res.status, 400, res.text);
    assert.equal((res.error?.details as { code?: string })?.code, 'phone_required');
  });

  test('a package of another photographer is not_found', async () => {
    const res = await call('createBooking', LAN, { ...draft, serviceId: 'seed-service-family' });
    assert.equal(res.status, 404, res.text);
  });

  test('create, deposit, pay with the fake gateway, check, and the photographer accepts', async () => {
    const created = await call('createBooking', LAN, draft);
    assert.equal(created.status, 200, created.text);
    const booking = created.result as { id: string; status: string; serviceId: string };
    assert.equal(booking.status, 'draft');
    assert.equal(booking.serviceId, 'seed-service-portrait');

    const deposit = await call('createDeposit', LAN, { bookingId: booking.id, provider: 'momo' });
    assert.equal(deposit.status, 200, deposit.text);
    const { paymentId } = deposit.result as { paymentId: string };

    const before = await call('checkDeposit', LAN, { bookingId: booking.id });
    assert.equal(before.status, 200, before.text);
    assert.equal((before.result as { paid: boolean }).paid, false);

    const paid = await call('confirmFakePayment', LAN, { paymentId });
    assert.equal(paid.status, 200, paid.text);

    const after = await call('checkDeposit', LAN, { bookingId: booking.id });
    assert.equal((after.result as { paid: boolean }).paid, true, after.text);
    const stored = (await db.collection('bookings').doc(booking.id).get()).data();
    assert.equal(stored?.status, 'requested');

    const accepted = await call('transitionBooking', AN, { bookingId: booking.id, action: 'accept' });
    assert.equal(accepted.status, 200, accepted.text);
  });
});
