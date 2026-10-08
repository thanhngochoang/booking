import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import {
  DEFAULT_PAYOUT_POLICY,
  FakePayoutGateway,
  approvePayout,
  newUlid,
  type PayoutDeps,
} from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';
import { ADMIN, BINH, LAN } from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestorePayoutStore, accountToFirestore, accountViewToFirestore } from '../../src/infra/payout_firestore.js';
import { handleCreatePayouts } from '../../src/scheduled/create_payouts.js';

// The daily createPayouts job against the Firestore emulator, through FirestorePayoutStore: the
// first payout to an account waits for staff, an approved one is sent on the next run, and the
// onPayoutWritten trigger (Functions emulator) moves the money to "Đã nhận". It also runs the
// bounded, account-scoped history queries (hasApprovedOrPaidPayout: `status in` + `approvedBy !=
// null`; lastFinishedPayouts: `status in` + orderBy createdAt desc), whose composite indexes are
// declared in firestore.indexes.json (the emulator does not enforce indexes; a unit test pins the
// declarations). Needs the emulators; CI runs it (npm run test:integration). Written, not run,
// while executing plans.

let app: App;
let db: Firestore;
const ACCOUNT = 'int-account-binh-1';
/** Test value; the fake gateway pays any number not ending in 0000. */
const NUMBER = '0987654321';
/** The emulator on a `demo-*` project: where fake payouts may run (Ruling 11). */
const FAKE_ENV = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-photobooking' };

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'create-payouts-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
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

async function releasedPayment(id: string, amount: number): Promise<void> {
  const now = Timestamp.now();
  await db.doc(`payments/${id}`).set({
    subjectType: 'booking', subjectId: 'seed-booking-requested-binh', payerId: LAN, payeeId: BINH, provider: 'fake', amount,
    status: 'paid', escrowStatus: 'released', idempotencyKey: `k_${id}`, createdAt: now, updatedAt: now,
  });
}

function deps(store: FirestorePayoutStore): PayoutDeps {
  return {
    store,
    cipher: aesGcmCipher(emulatorPayoutKey()),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    gateway: new FakePayoutGateway(),
    policy: DEFAULT_PAYOUT_POLICY,
    notices: { accountNeeded: async () => undefined, accountChanged: async () => undefined },
  };
}

describe('createPayouts on the emulators', () => {
  test('a first payout waits for approval, then the next run sends it and earnings show it received', async () => {
    // Bình's first account (written directly: the save callable is S06.06's), active an hour ago.
    const at = new Date(Date.now() - 3_600_000).toISOString();
    const account = {
      id: ACCOUNT, userId: BINH, bankCode: 'TCB', accountNumberEnc: await aesGcmCipher(emulatorPayoutKey()).encrypt(NUMBER),
      accountLast4: '4321', holderName: 'TRAN THI BINH', active: true, createdAt: at, nameStatus: 'matched' as const, activeFrom: at,
    };
    await db.doc(`payoutAccounts/${BINH}/accounts/${ACCOUNT}`).set(accountToFirestore(account));
    await db.doc(`payoutAccounts/${BINH}`).set(accountViewToFirestore({
      accountId: ACCOUNT, bankCode: 'TCB', accountLast4: '4321', holderName: 'TRAN THI BINH', updatedAt: at,
      nameStatus: 'matched', activeFrom: at,
    }));
    await releasedPayment('int-po-pay-1', 1_000_000);
    const store = new FirestorePayoutStore(db);
    const receivedBefore = ((await data(`earnings/${BINH}`)).receivedAmount as number | undefined) ?? 0;

    // Run 1: Bình's payout is created and waits for staff (the seed's An is paid on the way).
    const first = await handleCreatePayouts(deps(store), FAKE_ENV);
    assert.ok(first !== null);
    assert.equal(first.errors, 0, JSON.stringify(first));
    const waiting = await db.collection('payouts').where('payeeId', '==', BINH).get();
    assert.equal(waiting.size, 1);
    const a = waiting.docs[0];
    assert.ok(a !== undefined);
    assert.equal(a.data().status, 'needs_approval');
    assert.equal(a.data().firstPayout, true);
    assert.equal(a.data().taxWithheld, 70_000);
    assert.equal(a.data().amountNet, 930_000);
    assert.equal(a.data().idempotencyKey, a.id);
    assert.equal((await data('payments/int-po-pay-1')).payoutId, a.id);

    // Staff approve; before the next run more money arrives. The approved, unsent payout clears
    // the account (Ruling 3), so the second payout needs no approval of its own.
    await approvePayout(deps(store), { uid: ADMIN, isAdmin: true }, a.id);
    assert.equal(await store.runTransaction((tx) => tx.hasApprovedOrPaidPayout(ACCOUNT)), true);
    await releasedPayment('int-po-pay-2', 500_000);

    // Run 2: the second payout is created `pending`, and both are sent.
    const second = await handleCreatePayouts(deps(store), FAKE_ENV);
    assert.ok(second !== null);
    assert.equal(second.errors, 0, JSON.stringify(second));
    assert.equal(second.needsApproval, 0, JSON.stringify(second));
    const sent = await db.collection('payouts').where('payeeId', '==', BINH).get();
    assert.equal(sent.size, 2);
    for (const d of sent.docs) assert.equal(d.data().status, 'paid', d.id);
    const b = sent.docs.find((d) => d.id !== a.id);
    assert.equal(b?.data().firstPayout, false);
    assert.equal(b?.data().approvedBy ?? null, null);
    assert.equal((await data('payments/int-po-pay-1')).escrowStatus, 'paid_out');
    assert.equal((await data('payments/int-po-pay-2')).escrowStatus, 'paid_out');

    // Ledger per payment: payout_paid −net and tax_withheld −tax, together −amount.
    const ledger = await db.collection('ledger_entries').where('payoutId', '==', a.id).get();
    const byType = new Map(ledger.docs.map((d) => [d.data().type as string, d.data().amount as number]));
    assert.equal(byType.get('payout_paid'), -930_000);
    assert.equal(byType.get('tax_withheld'), -70_000);

    // The history queries on the emulator: two paid payouts, newest first.
    const finished = await store.runTransaction((tx) => tx.lastFinishedPayouts(ACCOUNT, 3));
    assert.deepEqual(finished.map((p) => p.status), ['paid', 'paid']);
    assert.ok((finished[0]?.createdAt ?? '') >= (finished[1]?.createdAt ?? ''));
    assert.equal(await store.runTransaction((tx) => tx.hasApprovedOrPaidPayout(ACCOUNT)), true);
    assert.equal(await store.runTransaction((tx) => tx.hasApprovedOrPaidPayout('int-account-none')), false);

    // onPayoutWritten refreshes the projection: "Đã nhận" is gross, the row carries the tax.
    await waitFor(
      async () => (await data(`earnings/${BINH}`)).receivedAmount === receivedBefore + 1_500_000,
      'earnings received',
    );
    const row = await data(`earnings/${BINH}/items/int-po-pay-1`);
    assert.equal(row.state, 'paid_out');
    assert.equal(row.taxWithheld, 70_000);
    assert.equal(row.netAmount, 930_000);
    assert.equal(row.estimated, false);

    // A third run the same day creates nothing new.
    const third = await handleCreatePayouts(deps(store), FAKE_ENV);
    assert.equal((await db.collection('payouts').where('payeeId', '==', BINH).get()).size, 2);
    assert.equal(third?.executed, 0);
  });

  test('off mode creates nothing', async () => {
    await releasedPayment('int-po-pay-off', 200_000);
    assert.equal(await handleCreatePayouts(deps(new FirestorePayoutStore(db)), {}), null);
    assert.equal((await data('payments/int-po-pay-off')).payoutId ?? null, null);
  });
});
