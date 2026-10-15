import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
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
  test('payouts batch released ticket payments of the host, never the platform payee', async () => {
    await newPayment('int-pay-ev', AN, 'seed-event-1', 'released', 250_000);
    await db.doc('payments/int-pay-ev').update({ subjectType: 'event_registration', eventId: 'seed-event-1' });
    await newPayment('int-pay-pf', 'platform', 'seed-event-1', 'released', 250_000);
    await db.doc('payments/int-pay-pf').update({ subjectType: 'event_registration', eventId: 'seed-event-1' });
    const store = new FirestorePayoutStore(db);
    const payable = await store.runTransaction((tx) => tx.listPayablePayments(AN));
    assert.ok(payable.some((p) => p.id === 'int-pay-ev'));
    assert.deepEqual(await store.runTransaction((tx) => tx.listPayablePayments('platform')), []);
    const due = await store.listDuePayees();
    assert.ok(!due.some((d) => d.payeeId === 'platform'));
    const before = due.find((d) => d.payeeId === AN)?.amount ?? 0;
    await db.doc('payments/int-pay-ev').delete();
    assert.equal((await store.listDuePayees()).find((d) => d.payeeId === AN)?.amount ?? 0, before - 250_000);
    await db.doc('payments/int-pay-pf').delete();
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
    // Binh has no verified name in the seed; give him one (test value) so the fake lookup echoes it.
    await db.doc(`users/${BINH}/private/identity`).set({ legalName: 'Trần Thị Bình', method: 'fake', provider: 'fake', verifiedAt: now() });
    const res = await callCallable('savePayoutAccount', { bankCode: 'TCB', accountNumber: '1903 555 0001' }, tokens.get(BINH));
    const saved = res.result as { accountLast4: string; nameStatus: string; activeFrom: string };
    assert.equal(saved.accountLast4, '0001', res.text);
    assert.equal(saved.nameStatus, 'matched');
    const view = await data(`payoutAccounts/${BINH}`);
    assert.equal(view.accountLast4, '0001');
    assert.equal(view.holderName, 'TRAN THI BINH');
    assert.equal(view.nameStatus, 'matched');
    const stored = await data(`payoutAccounts/${BINH}/accounts/${view.accountId as string}`);
    assert.equal(stored.active, true);
    assert.doesNotMatch(JSON.stringify(stored), /19035550001/);
    assert.equal(await aesGcmCipher(emulatorPayoutKey()).decrypt(stored.accountNumberEnc as string), '19035550001');
    // The save spent one of the day's 20 lookups.
    assert.equal((await data(`payout_lookups/${BINH}`)).count, 1);
  });

  test('a customer cannot look up, request a code or save an account', async () => {
    const input = { bankCode: 'VCB', accountNumber: '0123456789' };
    for (const name of ['lookupPayoutAccountName', 'requestPayoutOtp', 'savePayoutAccount']) {
      const res = await callCallable(name, input, tokens.get(LAN));
      assert.equal(res.error?.status, 'PERMISSION_DENIED', `${name}: ${res.text}`);
    }
    const anonymous = await callCallable('lookupPayoutAccountName', input);
    assert.equal(anonymous.error?.status, 'UNAUTHENTICATED', anonymous.text);
  });

  test('the lookup compares the bank name with the verified name', async () => {
    const matched = await callCallable('lookupPayoutAccountName', { bankCode: 'MB', accountNumber: '0999888777' }, tokens.get(AN));
    assert.deepEqual(matched.result, { decision: 'matched', holderName: 'NGUYEN VAN AN', verifiedName: 'Nguyễn Văn An' }, matched.text);
    const mismatch = await callCallable('lookupPayoutAccountName', { bankCode: 'MB', accountNumber: '0999884321' }, tokens.get(AN));
    assert.equal((mismatch.result as { decision: string }).decision, 'mismatch', mismatch.text);
  });

  test('a change needs the OTP sent to the photographer phone and starts 72 hours later', async () => {
    const target = { bankCode: 'MB', accountNumber: '0999888777' };
    const noCode = await callCallable('savePayoutAccount', target, tokens.get(AN));
    assert.equal((noCode.error?.details as { code?: string } | undefined)?.code, 'otp_required', noCode.text);

    const sent = await callCallable('requestPayoutOtp', target, tokens.get(AN));
    assert.deepEqual(sent.result, { phoneLast4: '0001', expiresInSeconds: 300, resendInSeconds: 60 }, sent.text);
    const challengePath = `otp_challenges/${AN}_payout_account`;
    const challenge = await data(challengePath);
    assert.equal(challenge.purpose, 'payout_account');
    assert.equal(challenge.attempts, 0);
    assert.doesNotMatch(JSON.stringify(challenge), /0999888777/);
    // The fake sender only logs the code (emulator UI); the test sets a known code on the same salt.
    const code = '135790';
    await db.doc(challengePath).update({
      codeHash: createHash('sha256').update(`${challenge.salt as string}:${code}`).digest('hex'),
    });

    const wrong = await callCallable('savePayoutAccount', { ...target, otpCode: '000001' }, tokens.get(AN));
    assert.equal((wrong.error?.details as { code?: string } | undefined)?.code, 'otp_invalid', wrong.text);
    assert.equal((await data(challengePath)).attempts, 1);
    const elsewhere = await callCallable('savePayoutAccount', { bankCode: 'MB', accountNumber: '0999888766', otpCode: code }, tokens.get(AN));
    assert.equal((elsewhere.error?.details as { code?: string } | undefined)?.code, 'otp_required', elsewhere.text);

    const before = Date.now();
    const res = await callCallable('savePayoutAccount', { ...target, otpCode: code }, tokens.get(AN));
    const saved = res.result as { accountLast4: string; activeFrom: string; nameStatus: string };
    assert.equal(saved.accountLast4, '8777', res.text);
    assert.equal(saved.nameStatus, 'matched');
    assert.ok(Date.parse(saved.activeFrom) >= before + 72 * 3_600_000 - 5_000, saved.activeFrom);
    const view = await data(`payoutAccounts/${AN}`);
    assert.equal(view.accountLast4, '8777');
    const old = await data('payoutAccounts/seed-photographer-an/accounts/seed-account-an-1');
    assert.equal(old.active, false);
    assert.notEqual((await data(challengePath)).consumedAt, null);

    // The same code cannot save again, and the account now active is a conflict.
    const again = await callCallable('savePayoutAccount', { ...target, otpCode: code }, tokens.get(AN));
    assert.equal((again.error?.details as { code?: string } | undefined)?.code, 'conflict', again.text);
  });
});
