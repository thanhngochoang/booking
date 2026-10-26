// Chụp ngay on the emulators (#140 Task 4; money #202 Task 11). Written, not run locally: CI runs `npm run test:integration`.
import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { FakePaymentGateway, newUlid, runBookingSweeps, type BookingDeps } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn, type CallableResponse } from '../../seed/emulator_client.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';
import { LAN, SEED_PASSWORD } from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestoreAddonCatalog } from '../../src/infra/addon_firestore.js';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreCustomerContactReader,
  FirestoreProviderOrderGate,
  FirestoreServiceCatalog,
} from '../../src/infra/booking_readers.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';

let app: App;
let db: Firestore;
let auth: Auth;
const tokens = new Map<string, string>();

/** Công viên Tao Đàn, Quận 1 (inside the seed city `hcm`). */
const TAO_DAN = { lat: 10.7746, lng: 106.6924 };
const north = (km: number) => ({ lat: TAO_DAN.lat + km / 111.19508, lng: TAO_DAN.lng });
const PHOTOGRAPHERS = ['it-inst-p1', 'it-inst-p2', 'it-inst-p3', 'it-inst-p4', 'it-inst-p5'];
const CUSTOMERS = Array.from({ length: 50 }, (_, i) => `it-inst-c${String(i + 1).padStart(2, '0')}`);

async function account(uid: string, email: string, displayName: string): Promise<void> {
  await auth.createUser({ uid, email, password: SEED_PASSWORD, displayName, emailVerified: true });
  await db.doc(`users/${uid}`).set({ displayName, createdAt: new Date(), updatedAt: new Date() });
  tokens.set(uid, await signIn(email, SEED_PASSWORD));
}

const call = (name: string, uid: string, data: unknown): Promise<CallableResponse> => callCallable(name, data, tokens.get(uid));

function ok<T>(res: CallableResponse): T {
  assert.equal(res.status, 200, res.text);
  return res.result as T;
}

const codeOf = (res: CallableResponse): string | undefined => (res.error?.details as { code?: string } | undefined)?.code;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'instant-test');
  db = getFirestore(app);
  auth = getAuth(app);
  await applySeed(db, auth, new Date());
  tokens.set(LAN, await signIn('lan.customer@seed.test', SEED_PASSWORD));
  // Five verified photographers with a phone, 0,3–1,5 km north of Tao Đàn, in Live Shutter.
  for (const [i, uid] of PHOTOGRAPHERS.entries()) {
    await account(uid, `${uid}@seed.test`, `Nhiếp ảnh gia ${i + 1}`);
    await db.doc(`photographers/${uid}`).set({
      displayName: `Nhiếp ảnh gia ${i + 1}`, verified: true, onboardingComplete: true, providerType: 'individual',
      specialties: ['portrait'], stats: { tomatoPct: 0, score: 0, reviewCount: 0, completedCount: 0 },
    });
    await db.doc(`photographers/${uid}/private/contact`).set({ phone: `+8490600000${i + 1}` });
    ok(await call('saveInstantSettings', uid, { acceptPriceListVersion: 1 }));
    const on = ok<{ online: boolean; reasons: string[] }>(
      await call('setLiveShutter', uid, { online: true, location: { ...north(0.3 * (i + 1)), accuracyM: 20 } }),
    );
    assert.deepEqual(on, { online: true, reasons: [] });
  }
});

after(async () => {
  await deleteApp(app);
});

async function create(uid: string): Promise<{ requestId: string; amountVnd: number; candidateCount: number }> {
  return ok(await call('createInstantRequest', uid, {
    packageCode: 'p60', genre: 'portrait', meetPoint: { ...TAO_DAN, name: 'Cổng Trương Định, Công viên Tao Đàn' },
  }));
}

/** "Thanh toán … và gửi lời mời" (#202): the first invite answers how to pay, the fake transfer pays it. */
async function inviteAndPay(uid: string, requestId: string, photographerIds: string[], amountVnd: number): Promise<string> {
  const res = ok<{ kind: string; instructions: { paymentId: string; transferCode: string; qrPayload?: string } }>(
    await call('inviteInstant', uid, { requestId, photographerIds, skipped: [], expectedAmountVnd: amountVnd, payMethod: 'bank_qr' }),
  );
  assert.equal(res.kind, 'payment');
  // The callable answers only the outcome (the webhook path); the subject is read back.
  const paid = ok<{ outcome: string }>(await call('confirmFakePayment', uid, { paymentId: res.instructions.paymentId }));
  const payment = (await db.doc(`payments/${res.instructions.paymentId}`).get()).data() ?? {};
  assert.deepEqual([paid.outcome, payment.subjectType], ['paid', 'instant_request']);
  return res.instructions.paymentId;
}

/** The booking clock's sweeps (release step) at an injected time. */
function sweepDeps(now: Date): BookingDeps {
  return {
    store: new FirestoreBookingStore(db),
    services: new FirestoreServiceCatalog(db),
    addons: new FirestoreAddonCatalog(db),
    contacts: new FirestoreCustomerContactReader(db),
    providers: new FirestoreProviderOrderGate(db),
    blocks: new FirestoreBlockGate(db),
    gateway: new FakePaymentGateway(),
    cipher: aesGcmCipher(emulatorPayoutKey()),
    clock: { now: () => now },
    ids: { newId: () => newUlid(Date.now()) },
  };
}

async function pendingOffersOf(uid: string): Promise<number> {
  const snap = await db.collection(`instant_offers/${uid}/offers`).where('outcome', '==', 'pending').get();
  return snap.docs.filter((d) => d.get('expiresAt').toMillis() > Date.now()).length;
}

describe('Chụp ngay on the emulators', () => {
  test('full flow on the emulator: create → invite → fake pay → accept → start_route → arrive → start → finish → confirm → clock releases after 24 h (clock injected)', async () => {
    const { requestId, amountVnd, candidateCount } = await create(LAN);
    assert.equal(candidateCount, 5);
    const pay = ok<{ kind: string; amountVnd: number; instructions: { paymentId: string; transferCode: string; qrPayload?: string; subjectType: string } }>(
      await call('inviteInstant', LAN, { requestId, photographerIds: ['it-inst-p1'], skipped: [], expectedAmountVnd: amountVnd, payMethod: 'bank_qr' }),
    );
    assert.equal(pay.kind, 'payment');
    assert.equal(pay.instructions.subjectType, 'instant_request');
    assert.match(pay.instructions.transferCode, /^PB /);
    assert.ok(pay.instructions.qrPayload);
    // Nothing goes out before the money is in.
    assert.equal((await db.doc(`instant_requests/${requestId}`).get()).get('status'), 'pending_payment');
    assert.equal((await db.collection('instant_offers/it-inst-p1/offers').where('requestId', '==', requestId).get()).size, 0);
    assert.deepEqual(ok(await call('checkInstantPayment', LAN, { requestId })), { paid: false, status: 'pending_payment' });
    const paymentId = pay.instructions.paymentId;
    const paid = ok<{ outcome: string }>(await call('confirmFakePayment', LAN, { paymentId }));
    assert.equal(paid.outcome, 'paid');
    assert.equal((await db.doc(`instant_requests/${requestId}`).get()).get('status'), 'searching');

    const offers = await db.collection('instant_offers/it-inst-p1/offers').where('requestId', '==', requestId).get();
    assert.equal(offers.size, 1);
    const offerId = offers.docs[0]?.id;
    // The offer carries the area and distance, never the meet point (spec §9).
    assert.equal(offers.docs[0]?.get('meetPoint'), undefined);

    assert.deepEqual(ok(await call('answerInstantOffer', 'it-inst-p1', { offerId, action: 'accept' })), { outcome: 'accepted', requestId });
    assert.equal((await db.doc(`payments/${paymentId}`).get()).get('payeeId'), 'it-inst-p1');
    assert.ok((await db.doc(`instant_requests/${requestId}/private/contact`).get()).exists, 'paid: the customer contact copy');
    const at = { ...TAO_DAN, accuracyM: 15 };
    for (const [action, status] of [['start_route', 'en_route'], ['arrive', 'arrived'], ['start', 'in_progress'], ['finish', 'finished']] as const) {
      assert.deepEqual(ok(await call('updateInstantJob', 'it-inst-p1', { requestId, action, location: at })), { status }, action);
    }
    // Spec §2.2 item 5: free for new offers right after "Hoàn thành", before the customer confirms.
    assert.equal((await db.doc('instant_presence/it-inst-p1').get()).get('activeRequestId'), null);
    assert.deepEqual(ok(await call('confirmInstantComplete', LAN, { requestId })), { status: 'completed' });

    const r = await db.doc(`instant_requests/${requestId}`).get();
    assert.equal(r.get('status'), 'completed');
    assert.equal(r.get('active'), false);
    assert.ok(r.get('paidAt') !== null);
    assert.equal(r.get('excludedIds'), undefined);
    assert.equal((await db.doc(`instant_customers/${LAN}`).get()).get('activeRequestId'), null);
    assert.equal((await db.doc(`instant_tracks/${requestId}`).get()).exists, false);
    const held = (await db.doc(`payments/${paymentId}`).get()).data() ?? {};
    assert.deepEqual([held.status, held.escrowStatus, held.payeeId], ['paid', 'held', 'it-inst-p1']);
    const releaseAfter = (held.releaseAfter as { toMillis(): number }).toMillis();
    assert.ok(Math.abs(releaseAfter - (Date.now() + 24 * 3_600_000)) < 5 * 60_000, 'released 24 h after completion');

    // The clock one hour before: still held; one minute after: released to the photographer.
    await runBookingSweeps(sweepDeps(new Date(releaseAfter - 3_600_000)));
    assert.equal((await db.doc(`payments/${paymentId}`).get()).get('escrowStatus'), 'held');
    await runBookingSweeps(sweepDeps(new Date(releaseAfter + 60_000)));
    const released = (await db.doc(`payments/${paymentId}`).get()).data() ?? {};
    assert.equal(released.escrowStatus, 'released');
    const entries = await db.collection('ledger_entries').where('paymentId', '==', paymentId).get();
    const byType = Object.fromEntries(entries.docs.map((d) => [d.get('type'), d.get('amount')]));
    assert.deepEqual(byType, { payment_received: amountVnd, escrow_released: amountVnd });
  });

  test('a paid cancel en route refunds 80% on the fake gateway and releases the 20% after 24 h', async () => {
    const { requestId, amountVnd } = await create(LAN);
    const paymentId = await inviteAndPay(LAN, requestId, ['it-inst-p2'], amountVnd);
    const offers = await db.collection('instant_offers/it-inst-p2/offers').where('requestId', '==', requestId).get();
    ok(await call('answerInstantOffer', 'it-inst-p2', { offerId: offers.docs[0]?.id, action: 'accept' }));
    // The free window is 2 minutes of server time: shift the assignment back instead of waiting.
    await db.doc(`instant_requests/${requestId}`).update({ freeCancelUntil: new Date(Date.now() - 1000) });
    const quote = ok<{ rule: string; refundVnd: number }>(await call('cancelInstantRequest', LAN, { requestId, dryRun: true }));
    assert.equal(quote.rule, 'en_route');
    const res = ok<{ rule: string; refundVnd: number; feeVnd: number }>(
      await call('cancelInstantRequest', LAN, { requestId, dryRun: false, expectedRule: quote.rule, expectedRefundVnd: quote.refundVnd }),
    );
    assert.equal(res.refundVnd + res.feeVnd, amountVnd);
    const refunds = await db.collection('refunds').where('paymentId', '==', paymentId).get();
    assert.deepEqual(refunds.docs.map((d) => [d.get('amount'), d.get('status'), d.get('subjectType')]), [[res.refundVnd, 'done', 'instant_request']]);
    const p = (await db.doc(`payments/${paymentId}`).get()).data() ?? {};
    assert.equal(p.escrowStatus, 'partially_refunded');
    assert.equal((await db.doc(`instant_requests/${requestId}`).get()).get('refundStatus'), 'done');

    // The photographer's 20% waits 24 h: the clock an hour before keeps it, a minute after releases it.
    const releaseAfter = (p.releaseAfter as { toMillis(): number }).toMillis();
    await runBookingSweeps(sweepDeps(new Date(releaseAfter - 3_600_000)));
    assert.equal((await db.doc(`payments/${paymentId}`).get()).get('escrowStatus'), 'partially_refunded');
    await runBookingSweeps(sweepDeps(new Date(releaseAfter + 60_000)));
    assert.equal((await db.doc(`payments/${paymentId}`).get()).get('escrowStatus'), 'released');
    const released = await db.collection('ledger_entries').where('paymentId', '==', paymentId).where('type', '==', 'escrow_released').get();
    assert.deepEqual(released.docs.map((d) => [d.get('amount'), d.get('accountOwnerId')]), [[res.feeVnd, 'it-inst-p2']]);
  });

  test('five parallel accepts, one winner', async () => {
    const { requestId, amountVnd } = await create(LAN);
    await inviteAndPay(LAN, requestId, PHOTOGRAPHERS, amountVnd);
    const offerIds = await Promise.all(PHOTOGRAPHERS.map(async (uid) => {
      const snap = await db.collection(`instant_offers/${uid}/offers`).where('requestId', '==', requestId).get();
      return snap.docs[0]?.id;
    }));
    const answers = await Promise.all(
      PHOTOGRAPHERS.map((uid, i) => call('answerInstantOffer', uid, { offerId: offerIds[i], action: 'accept' })),
    );
    const winners = answers.filter((a) => a.status === 200);
    assert.equal(winners.length, 1, answers.map((a) => a.text).join('\n'));
    for (const a of answers.filter((x) => x.status !== 200)) assert.equal(codeOf(a), 'already_assigned', a.text);
    const r = await db.doc(`instant_requests/${requestId}`).get();
    assert.equal(r.get('status'), 'assigned');
    assert.deepEqual(r.get('offers'), [], 'the round is emptied at assignment (Decision 15)');
    // Free the winner for the next test.
    ok(await call('cancelInstantRequest', LAN, { requestId, dryRun: false }));
  });

  test('fifty customers inviting the same photographer never exceed 3 live pending offers', async () => {
    for (const [i, uid] of CUSTOMERS.entries()) {
      await account(uid, `${uid}@seed.test`, `Khách ${i + 1}`);
      await db.doc(`users/${uid}/private/contact`).set({ phone: `+849070${String(i).padStart(5, '0')}`, allowZalo: false, allowWhatsApp: false });
    }
    const target = 'it-inst-p3';
    // Every request is created first, while the target is free, so the target is a candidate of each.
    const requests = await Promise.all(CUSTOMERS.map(async (uid) => ({ uid, ...(await create(uid)) })));
    // Ten at a time contend on the target's presence document (the emulator's lock waits stay short);
    // after each batch the target never holds more than 3 live pending offers (an expired one frees a slot).
    for (let i = 0; i < requests.length; i += 10) {
      // Each pays first (#202); the offer goes out inside the payment's settlement.
      await Promise.all(requests.slice(i, i + 10).map((r) => inviteAndPay(r.uid, r.requestId, [target], r.amountVnd)));
      assert.ok((await pendingOffersOf(target)) <= 3);
      const presence = await db.doc(`instant_presence/${target}`).get();
      const live = (presence.get('pendingOffers') as { expiresAt: { toMillis(): number } }[]).filter((o) => o.expiresAt.toMillis() > Date.now());
      assert.ok(live.length <= 3, `${live.length} live pending offers`);
    }
    const rows = await Promise.all(requests.map(async (r) => (await db.doc(`instant_requests/${r.requestId}`).get()).get('offers') as { photographerId: string; outcome: string }[]));
    const invited = rows.filter((offers) => offers.some((o) => o.photographerId === target && o.outcome !== 'unavailable')).length;
    assert.ok(invited >= 1 && invited < CUSTOMERS.length, `${invited} offers went out`);
  });
});
