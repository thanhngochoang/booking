import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { AN, LAN } from '../../seed/fixtures.js';

// S22.01 (#141): onPaymentWritten and onRefundWritten keep users/{uid}/payments and
// users/{uid}/private/paymentTotals on the Functions emulator. Needs the emulators; CI runs it
// (npm run test:integration). Each test owns new payments of Lan.

let app: App;
let db: Firestore;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'payer-history-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

const data = async (path: string) => (await db.doc(path).get()).data();

async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 20_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

const now = () => Timestamp.now();

describe('payer history on the emulators', () => {
  test('the seed wrote Lan\'s rows and totals', async () => {
    assert.equal((await data(`users/${LAN}/payments/seed-payment-seed-booking-cancelled`))?.status, 'refunded');
    assert.equal(typeof (await data(`users/${LAN}/private/paymentTotals`))?.held, 'number');
  });

  test('paid → held; a refund pending → refunding; done → refunded; the totals follow', async () => {
    const totals = async () => (await data(`users/${LAN}/private/paymentTotals`)) ?? {};
    const before = await totals();
    await db.doc('payments/int-payer-1').set({
      subjectType: 'booking', subjectId: 'seed-booking-accepted', payerId: LAN, payeeId: AN, provider: 'fake',
      amount: 400_000, status: 'created', escrowStatus: 'held', idempotencyKey: 'k_int_payer_1', method: 'momo',
      receivedAmount: 0, refundedAmount: 0, createdAt: now(), updatedAt: now(),
    });
    // Unpaid: no row.
    await new Promise((r) => setTimeout(r, 1_000));
    assert.equal(await data(`users/${LAN}/payments/int-payer-1`), undefined);

    await db.doc('payments/int-payer-1').update({ status: 'paid', receivedAmount: 400_000, paidAt: now(), updatedAt: now() });
    await waitFor(async () => (await data(`users/${LAN}/payments/int-payer-1`))?.status === 'held', 'held row');
    await waitFor(async () => (await totals()).held === (before.held as number) + 400_000, 'held total');

    await db.doc('payments/int-payer-1').update({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: 400_000, updatedAt: now() });
    await db.doc('refunds/int-payer-r1').set({
      paymentId: 'int-payer-1', subjectType: 'booking', amount: 400_000, percent: 100, status: 'pending', method: 'gateway',
      destination: null, attempts: 1, manual: false, fromEscrow: true, createdAt: now(), updatedAt: now(),
    });
    await waitFor(async () => (await data(`users/${LAN}/payments/int-payer-1`))?.status === 'refunding', 'refunding row');
    await waitFor(async () => (await totals()).refunding === (before.refunding as number) + 400_000, 'refunding total');

    await db.doc('refunds/int-payer-r1').update({ status: 'done', updatedAt: now() });
    await waitFor(async () => (await data(`users/${LAN}/payments/int-payer-1`))?.status === 'refunded', 'refunded row');
    await waitFor(async () => (await totals()).refunding === before.refunding && (await totals()).held === before.held, 'totals back');
    const row = await data(`users/${LAN}/payments/int-payer-1`);
    assert.equal(JSON.stringify(row).includes('accountNumberEnc'), false);
  });
});
