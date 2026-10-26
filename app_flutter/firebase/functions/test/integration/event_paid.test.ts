import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { FirestoreEventStore, firestoreEventPeople, ownCoverUpload } from '../../src/infra/event_firestore.js';
import { firestoreUserContactReader } from '../../src/infra/firestore.js';
import { storageUrlPrefixes } from '../../src/config.js';
import { handleReleaseEventHolds } from '../../src/scheduled/event_clock.js';
import { eventStartInDays } from './event_social_support.js';

// Paid tickets on the Functions emulator (plan 10c Task 9): hold, fake confirmation (`confirmFakePayment`, allowed on the
// emulator), hold expiry, event cancellation with refunds. CI runs it (npm run test:integration).

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();
const PRICE = 150_000;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'event-paid-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, payload: unknown) => callCallable(name, payload, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};
const bucketUrl = (path: string): string =>
  `http://127.0.0.1:9199/v0/b/${emulatorProject()}.firebasestorage.app/o/${encodeURIComponent(path)}?alt=media&token=t`;

async function makeCustomer(n: number): Promise<string> {
  const uid = `paid-customer-${n}-${Date.now()}`;
  const email = `${uid}@seed.test`;
  await getAuth(app).createUser({ uid, email, password: SEED_PASSWORD, displayName: `Khách ${n}` });
  await db.doc(`users/${uid}`).set({ displayName: `Khách ${n}`, role: 'customer', createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  await db.doc(`users/${uid}/private/contact`).set({ phone: `+8490600${String(1000 + n)}`, phoneVerified: false, allowZalo: true, allowWhatsApp: false });
  tokens.set(uid, await signIn(email, SEED_PASSWORD));
  return uid;
}

let nextDay = 60;

async function publishPaid(over: Record<string, unknown> = {}): Promise<string> {
  const eventId = newUlid(Date.now());
  const path = `eventCovers/${AN}/${eventId}/cover.jpg`;
  const start = eventStartInDays(nextDay++);
  const res = await call('saveEventDraft', AN, {
    eventId, title: `Workshop ${eventId.slice(-6)}`, type: 'workshop',
    coverUrl: bucketUrl(path), coverPath: path,
    startAt: start.toISOString(), endAt: new Date(start.getTime() + 3 * 3_600_000).toISOString(),
    location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 },
    capacity: 5, price: PRICE, ...over,
  });
  assert.ok((res.result as { eventId?: string } | undefined)?.eventId, res.text);
  assert.equal((await call('publishEvent', AN, { eventId })).status, 200);
  return eventId;
}

type Registered = { registrationId: string; status: string; paymentId: string; instructions: { paymentId: string; method: string; amount: number; transferCode: string }; holdExpiresAt: string };

async function waitFor(check: () => Promise<boolean>, ms = 10_000): Promise<void> {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail('condition not met in time');
}

describe('paid tickets on the emulators', () => {
  test('paid register, fake confirm, ticket', async () => {
    const eventId = await publishPaid();
    const buyer = await makeCustomer(1);
    const res = await call('registerEvent', buyer, { eventId, quantity: 2, name: 'Khách 1', method: 'momo' });
    assert.equal(res.status, 200, res.text);
    const r = res.result as Registered;
    assert.equal(r.status, 'held');
    assert.ok(r.holdExpiresAt.length > 0);
    assert.deepEqual([r.instructions.paymentId, r.instructions.method, r.instructions.amount], [r.paymentId, 'momo', 2 * PRICE]);
    assert.match(r.instructions.transferCode, /^PB /);
    assert.equal((await data(`events/${eventId}`)).heldCount, 2);
    const payment = await data(`payments/${r.paymentId}`);
    assert.deepEqual([payment.subjectType, payment.eventId, payment.status, payment.amount], ['event_registration', eventId, 'created', 2 * PRICE]);

    const paid = await call('confirmFakePayment', buyer, { paymentId: r.paymentId });
    assert.equal(paid.status, 200, paid.text);
    assert.deepEqual(paid.result, { outcome: 'paid' });
    const reg = await data(`events/${eventId}/registrations/${r.registrationId}`);
    assert.deepEqual([reg.status, reg.contactEligible], ['paid', true]);
    const ev = await data(`events/${eventId}`);
    assert.deepEqual([ev.heldCount, ev.registeredCount], [0, 2]);
    assert.equal((await data(`payments/${r.paymentId}`)).status, 'paid');
    const ledger = await db.collection('ledger_entries').where('paymentId', '==', r.paymentId).get();
    assert.deepEqual(ledger.docs.map((d) => d.data().type), ['ticket_received']);
    // The attendee joins the group chat once the ticket is paid (onRegistrationWrite).
    await waitFor(async () => ((await data(`chats/event_${eventId}`)).members as string[] | undefined)?.includes(buyer) === true);
    // Host-side phone snapshot exists for a paid ticket.
    assert.equal((await data(`events/${eventId}/registrations/${r.registrationId}/private/contact`)).phone, '+84906001001');
  });

  test('hold expiry frees the seat for the next buyer', async () => {
    const eventId = await publishPaid({ capacity: 1 });
    const first = await makeCustomer(2);
    const second = await makeCustomer(3);
    const r = (await call('registerEvent', first, { eventId, quantity: 1, name: 'Khách 2', method: 'zalopay' })).result as Registered;
    const blocked = await call('registerEvent', second, { eventId, quantity: 1, name: 'Khách 3', method: 'momo' });
    assert.equal((blocked.error?.details as { code?: string } | undefined)?.code, 'sold_out', blocked.text);
    // The 10 minutes pass.
    await db.doc(`events/${eventId}/registrations/${r.registrationId}`).update({ holdExpiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    const released = await handleReleaseEventHolds({
      events: new FirestoreEventStore(db),
      people: firestoreEventPeople(db),
      contacts: firestoreUserContactReader(db),
      media: { isOwnUpload: ownCoverUpload(storageUrlPrefixes()) },
      clock: { now: () => new Date() },
      ids: { newId: () => newUlid(Date.now()) },
      random: (n) => globalThis.crypto.getRandomValues(new Uint8Array(n)),
    });
    assert.ok(released >= 1);
    assert.equal((await data(`events/${eventId}/registrations/${r.registrationId}`)).status, 'cancelled');
    const ok = await call('registerEvent', second, { eventId, quantity: 1, name: 'Khách 3', method: 'momo' });
    assert.equal(ok.status, 200, ok.text);
    // The first buyer's late payment is refunded in full.
    const late = await call('confirmFakePayment', first, { paymentId: r.paymentId });
    assert.deepEqual(late.result, { outcome: 'refunded' });
    assert.equal((await data(`payments/${r.paymentId}`)).status, 'refunded');
    // The cancelled ticket shows the refund ("Đã huỷ · đã hoàn tiền").
    assert.equal((await data(`events/${eventId}/registrations/${r.registrationId}`)).refundStatus, 'done');
  });

  test('cancel event refunds and removes members', async () => {
    const eventId = await publishPaid();
    const buyer = await makeCustomer(4);
    const r = (await call('registerEvent', buyer, { eventId, quantity: 1, name: 'Khách 4', method: 'momo' })).result as Registered;
    await call('confirmFakePayment', buyer, { paymentId: r.paymentId });
    await waitFor(async () => ((await data(`chats/event_${eventId}`)).members as string[] | undefined)?.includes(buyer) === true);

    const res = await call('cancelEvent', AN, { eventId });
    assert.equal(res.status, 200, res.text);
    assert.deepEqual(res.result, { paidRegistrationIds: [r.registrationId], refunded: 1, failed: 0 });
    const reg = await data(`events/${eventId}/registrations/${r.registrationId}`);
    assert.deepEqual([reg.status, reg.refundPercent, reg.refundDue, reg.refundStatus], ['refunded', 100, false, 'done']);
    const payment = await data(`payments/${r.paymentId}`);
    assert.deepEqual([payment.status, payment.escrowStatus], ['refunded', 'refunded']);
    const refunds = await db.collection('refunds').where('paymentId', '==', r.paymentId).get();
    assert.deepEqual(refunds.docs.map((d) => [d.data().percent, d.data().reason, d.data().subjectType, d.data().status]),
      [[100, 'event_cancelled', 'event_registration', 'done']]);
    assert.equal(reg.refundId, refunds.docs[0]?.id);
    await waitFor(async () => ((await data(`chats/event_${eventId}`)).members as string[] | undefined)?.includes(buyer) === false);
    assert.equal((await db.doc(`events/${eventId}/registrations/${r.registrationId}/private/contact`).get()).exists, false);
  });
});
