import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// S22.04 (#141) on the emulators: a cancelled bank-QR booking's refund waits for Lan's account
// (prefilled with the paying account, 24 hours by default), Lan is told once, Lan confirms the
// paying account and the refund is sent once on the fake gateway. CI runs it (npm run test:integration).

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'refund-account-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data();

async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 20_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

describe('refund account on the emulators', () => {
  test('cancel → awaiting → choose payer → refund done', async () => {
    const created = await call('createBooking', LAN, {
      photographerId: AN,
      serviceId: 'seed-service-portrait',
      day: '2026-11-28',
      start: '09:00',
      place: { name: 'Hồ Gươm', point: { lat: 21.028, lng: 105.852 } },
      expectedPrice: 1_500_000,
    });
    assert.equal(created.status, 200, created.text);
    const bookingId = (created.result as { id: string }).id;
    const payment = await call('createPayment', LAN, { bookingId, method: 'bank_qr' });
    assert.equal(payment.status, 200, payment.text);
    const { paymentId } = payment.result as { paymentId: string };
    const paid = await call('confirmFakePayment', LAN, { paymentId, kind: 'exact' });
    assert.deepEqual(paid.result, { outcome: 'paid' }, paid.text);

    const cancelled = await call('transitionBooking', LAN, { bookingId, action: 'cancel', reason: 'Bận việc' });
    assert.equal(cancelled.status, 200, cancelled.text);

    // Waiting: prefilled with the paying account (FAKE_PAYER), confirmBy +24 h, not sent.
    const refunds = await db.collection('refunds').where('paymentId', '==', paymentId).get();
    assert.equal(refunds.size, 1);
    const refundId = refunds.docs[0]?.id ?? '';
    const waiting = refunds.docs[0]?.data() ?? {};
    assert.equal(waiting.status, 'awaiting_account');
    assert.equal(waiting.destination?.source, 'payer');
    assert.ok(waiting.confirmBy);
    assert.equal((await data(`bookings/${bookingId}`))?.refundAccountNeeded, true);
    await waitFor(
      async () => (await db.collection(`users/${LAN}/notifications`).where('type', '==', 'refund_account_needed').get()).size === 1,
      'refund_account_needed notification',
    );
    await waitFor(async () => (await data(`users/${LAN}/payments/${paymentId}`))?.status === 'refund_account_needed', 'payer row');

    // S22.04: only Lan sees it; the paying account is masked.
    const view = await call('pendingRefund', LAN, { bookingId });
    assert.equal(view.status, 200, view.text);
    const pending = view.result as { refundId: string; amount: number; payer: { accountLast4: string } | null };
    assert.equal(pending.refundId, refundId);
    assert.equal(pending.amount, 1_500_000);
    assert.equal(typeof pending.payer?.accountLast4, 'string');
    assert.equal(JSON.stringify(view.result).includes('accountNumberEnc'), false);
    const foreign = await call('pendingRefund', MINH, { bookingId });
    assert.equal((foreign.error?.details as { code?: string } | undefined)?.code, 'permission_denied', foreign.text);

    const chosen = await call('chooseRefundAccount', LAN, { refundId, use: 'payer' });
    assert.equal(chosen.status, 200, chosen.text);
    assert.deepEqual(chosen.result, { status: 'done' });
    const again = await call('chooseRefundAccount', LAN, { refundId, use: 'payer' });
    assert.deepEqual(again.result, { status: 'done' }, again.text);

    const done = await data(`refunds/${refundId}`);
    assert.equal(done?.status, 'done');
    assert.equal(done?.attempts, 1);
    assert.equal(done?.candidate ?? null, null);
    const booking = await data(`bookings/${bookingId}`);
    assert.equal(booking?.refundAccountNeeded, false);
    assert.ok(booking?.depositRefundedAt);
    await waitFor(async () => (await data(`users/${LAN}/payments/${paymentId}`))?.status === 'refunded', 'refunded row');
    assert.equal((await call('pendingRefund', LAN, { bookingId })).result, null);
  });
});
