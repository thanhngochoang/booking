import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, BINH, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestorePayoutStore } from '../../src/infra/payout_firestore.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';

// The earnings triggers (onPaymentWritten, onPayoutWritten) and savePayoutAccount on the Functions
// emulator, through the Firestore adapters. Needs the emulators; CI runs it (npm run test:integration).
// The seed (applySeed) already writes a projection; each test owns new payments of BINH or AN.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'earnings-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const data = async (path: string) => (await db.doc(path).get()).data() ?? {};

async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 20_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

const now = () => Timestamp.now();
async function newPayment(id: string, payeeId: string, bookingId: string, escrowStatus: string, amount = 300_000): Promise<void> {
  await db.doc(`payments/${id}`).set({
    subjectType: 'booking', subjectId: bookingId, payerId: LAN, payeeId, provider: 'fake', amount,
    status: 'paid', escrowStatus, idempotencyKey: `k_${id}`, createdAt: now(), updatedAt: now(),
  });
}

describe('earnings on the emulators', () => {
  test('payouts batch only booking payments (event tickets wait for 10c Task 9)', async () => {
    await newPayment('int-pay-ev', AN, 'seed-event-1', 'released');
    await db.doc('payments/int-pay-ev').update({ subjectType: 'event_ticket' });
    const store = new FirestorePayoutStore(db);
    const payable = await store.runTransaction((tx) => tx.listPayablePayments(AN));
    assert.ok(!payable.some((p) => p.id === 'int-pay-ev'));
    const due = await store.listDuePayees();
    const before = due.find((d) => d.payeeId === AN)?.amount ?? 0;
    await db.doc('payments/int-pay-ev').update({ amount: before + 999_000_000 });
    assert.equal((await store.listDuePayees()).find((d) => d.payeeId === AN)?.amount ?? 0, before);
    await db.doc('payments/int-pay-ev').delete();
  });

  test('a released payment appears in Sắp nhận', async () => {
    const before = (await data(`earnings/${BINH}`)).soonAmount as number;
    await newPayment('int-pay-1', BINH, 'seed-booking-requested-binh', 'released');
    await waitFor(async () => (await data(`earnings/${BINH}`)).soonAmount === before + 300_000, 'soonAmount');
    const row = await data(`earnings/${BINH}/items/int-pay-1`);
    assert.equal(row.state, 'released');
    assert.equal(row.counterpartName, 'Lan (seed)');
  });

  test('two payments released together give one consistent summary', async () => {
    const before = await data(`earnings/${BINH}`);
    await Promise.all([
      newPayment('int-pay-2', BINH, 'seed-booking-requested-binh', 'released', 100_000),
      newPayment('int-pay-3', BINH, 'seed-booking-requested-binh', 'released', 200_000),
    ]);
    await waitFor(async () => (await data(`earnings/${BINH}`)).soonAmount === (before.soonAmount as number) + 300_000, 'both payments in the summary');
    const items = await db.collection(`earnings/${BINH}/items`).where('state', '==', 'released').get();
    const sum = items.docs.reduce((n, d) => n + (d.data().amount as number), 0);
    assert.equal((await data(`earnings/${BINH}`)).soonAmount, sum);
  });

  test('a dispute updates the row with its reason code', async () => {
    await db.doc('payments/int-pay-1').update({
      escrowStatus: 'disputed', dispute: { reason: 'Ảnh giao thiếu', openedAt: now() }, updatedAt: now(),
    });
    await waitFor(async () => (await data(`earnings/${BINH}/items/int-pay-1`)).state === 'disputed', 'disputed row');
    const row = await data(`earnings/${BINH}/items/int-pay-1`);
    assert.equal(row.holdReason, 'dispute');
    assert.doesNotMatch(JSON.stringify(row), /Ảnh giao thiếu/);
  });

  test('savePayoutAccount stores ciphertext and the masked view', async () => {
    const res = await callCallable('savePayoutAccount', { bankCode: 'TCB', accountNumber: '1903 555 0001', holderName: 'Trần Thị Bình' }, tokens.get(BINH));
    assert.equal((res.result as { accountLast4: string }).accountLast4, '0001', res.text);
    const view = await data(`payoutAccounts/${BINH}`);
    assert.equal(view.accountLast4, '0001');
    assert.equal(view.holderName, 'TRAN THI BINH');
    const stored = await data(`payoutAccounts/${BINH}/accounts/${view.accountId as string}`);
    assert.equal(stored.active, true);
    assert.doesNotMatch(JSON.stringify(stored), /19035550001/);
    assert.equal(await aesGcmCipher(emulatorPayoutKey()).decrypt(stored.accountNumberEnc as string), '19035550001');
  });

  test('a customer cannot save an account', async () => {
    const res = await callCallable('savePayoutAccount', { bankCode: 'VCB', accountNumber: '0123456789', holderName: 'LAN' }, tokens.get(LAN));
    assert.equal(res.error?.status, 'PERMISSION_DENIED', res.text);
  });

  test('a fresh sign-in may change the account', async () => {
    const fresh = await signIn(SEED_USERS.find((u) => u.uid === AN)?.email ?? '', SEED_PASSWORD);
    const res = await callCallable('savePayoutAccount', { bankCode: 'MB', accountNumber: '0999888777', holderName: 'Nguyen Van An' }, fresh);
    assert.equal((res.result as { accountLast4: string }).accountLast4, '8777', res.text);
    assert.equal((await data(`payoutAccounts/${AN}`)).accountLast4, '8777');
    const old = await data('payoutAccounts/seed-photographer-an/accounts/seed-account-an-1');
    assert.equal(old.active, false);
  });
});
