import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { REGION } from '../../src/config.js';
import { FAKE_SIGNATURE_HEADER, signFakeWebhook } from '../../src/infra/fake_webhook.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The booking callables on the emulators, with the packages where the app writes them
// (photographers/{uid}/services/{id}): create → createPayment → fake exact transfer (signed
// webhook, in-process) → checkPayment → accept.

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

  test('a block document either way makes createBooking answer failed-precondition blocked', async () => {
    const ref = db.doc(`blocks/${AN}_${LAN}`);
    await ref.set({ blockerId: AN, blockedId: LAN, createdAt: new Date() });
    try {
      const refused = await call('createBooking', LAN, draft);
      assert.equal(refused.status, 400, refused.text);
      assert.equal((refused.error?.details as { code?: string })?.code, 'blocked');
    } finally {
      await ref.delete();
    }
    // Another day, so this draft does not hold the day the next test books.
    const allowed = await call('createBooking', LAN, { ...draft, day: '2026-11-21' });
    assert.equal(allowed.status, 200, allowed.text);
  });

  test('create, pay the full price by bank QR with a fake exact transfer, check, and the photographer accepts', async () => {
    const created = await call('createBooking', LAN, draft);
    assert.equal(created.status, 200, created.text);
    const booking = created.result as { id: string; status: string; serviceId: string };
    assert.equal(booking.status, 'draft');
    assert.equal(booking.serviceId, 'seed-service-portrait');

    const payment = await call('createPayment', LAN, { bookingId: booking.id, method: 'bank_qr' });
    assert.equal(payment.status, 200, payment.text);
    const { paymentId, checkout } = payment.result as { paymentId: string; checkout: { amount: number; transferCode: string; expiresAt: string } };
    assert.equal(checkout.amount, 1_500_000);
    assert.match(checkout.transferCode, /^PB [2-9A-Z]{6}$/);
    const mirrored = (await db.collection('bookings').doc(booking.id).get()).data();
    assert.equal(mirrored?.checkout?.paymentId, paymentId);

    const before = await call('checkPayment', LAN, { bookingId: booking.id });
    assert.equal(before.status, 200, before.text);
    assert.equal((before.result as { paid: boolean }).paid, false);

    // Another customer cannot pay (or probe) Lan's payment.
    const foreign = await call('confirmFakePayment', MINH, { paymentId, kind: 'exact' });
    assert.equal(foreign.status, 403, foreign.text);

    const paid = await call('confirmFakePayment', LAN, { paymentId, kind: 'exact' });
    assert.equal(paid.status, 200, paid.text);
    assert.deepEqual(paid.result, { outcome: 'paid' });

    const after = await call('checkPayment', LAN, { bookingId: booking.id });
    assert.equal((after.result as { paid: boolean }).paid, true, after.text);
    const stored = (await db.collection('bookings').doc(booking.id).get()).data();
    assert.equal(stored?.status, 'requested');
    const notifications = await db.collection('payment_notifications').where('paymentId', '==', paymentId).get();
    assert.equal(notifications.size, 1);
    assert.equal(notifications.docs[0]?.get('outcome'), 'paid');

    const accepted = await call('transitionBooking', AN, { bookingId: booking.id, action: 'accept' });
    assert.equal(accepted.status, 200, accepted.text);
  });

  test('the webhook takes signed POSTs only and refuses an unknown provider', async () => {
    const url = (provider: string) =>
      `http://${process.env.FUNCTIONS_EMULATOR_HOST}/${emulatorProject()}/${REGION}/paymentWebhook?provider=${provider}`;
    const raw = JSON.stringify({ txnId: 'txn_int_1', amount: 1_500_000, content: 'PB 222222', receivedAt: new Date().toISOString() });
    const get = await fetch(url('fake'));
    assert.equal(get.status, 405);
    const unsigned = await fetch(url('fake'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: raw });
    assert.equal(unsigned.status, 401);
    // Signed with the emulator's test secret (.env.local): no payment uses this code, so staff review it.
    const signedHeaders = { 'Content-Type': 'application/json', [FAKE_SIGNATURE_HEADER]: signFakeWebhook(raw, 'pb-fake-webhook-test-secret') };
    const ok = await fetch(url('fake'), { method: 'POST', headers: signedHeaders, body: raw });
    assert.equal(ok.status, 200, await ok.clone().text());
    assert.deepEqual(await ok.json(), { ok: true, outcome: 'needs_review' });
    assert.equal((await db.collection('payment_notifications').doc('fake_txn_int_1').get()).get('raw'), raw);
    const other = await fetch(url('momo'), { method: 'POST', headers: signedHeaders, body: raw });
    assert.equal(other.status, 404);
  });
});
