import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { formatVnDate, isPassCode } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import {
  AN,
  BINH,
  LAN,
  SEED_EVENT_ENTRY_BAI_DA,
  SEED_ORGANIZER_BAI_DA,
  SEED_PASSWORD,
  SEED_SPOT_BAI_DA,
  SEED_USERS,
} from '../../seed/fixtures.js';
import { handlePaymentClock } from '../../src/scheduled/payment_clock.js';
import { liveSettlementDeps } from '../../src/infra/live_payments.js';

// S30 entry tickets on the emulators (#223, plan Task 6): written here, run by CI (npm run test:integration).
// Review Focus 1 (two buyers, the last seats of a day), the private pass of a paid ticket, closeEntryDay, and the
// Firestore payment_group settler for a booking with tickets (paid, then an expired group).

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();
const DAY = 86_400_000;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'entry-tickets-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, payload: unknown) => callCallable(name, payload, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};
const codeOf = (res: { error?: { details?: unknown } }) => (res.error?.details as { code?: string } | undefined)?.code;

async function makeCustomer(n: number): Promise<string> {
  const uid = `entry-customer-${n}-${Date.now()}`;
  const email = `${uid}@seed.test`;
  await getAuth(app).createUser({ uid, email, password: SEED_PASSWORD, displayName: `Khách ${n}` });
  await db.doc(`users/${uid}`).set({ displayName: `Khách ${n}`, role: 'customer', createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  await db.doc(`users/${uid}/private/contact`).set({ phone: `+8490700${String(1000 + n)}`, phoneVerified: false, allowZalo: true, allowWhatsApp: false });
  tokens.set(uid, await signIn(email, SEED_PASSWORD));
  return uid;
}

/** An open day of the seed entry event `days` from today (its range is today + 89 days, no closed day). */
const visitDay = (days: number) => formatVnDate(new Date(Date.now() + days * DAY));

type Registered = { registrationId: string; status: string; paymentId: string; holdExpiresAt: string };

async function buy(uid: string, day: string, qty: number) {
  return call('registerEntry', uid, {
    eventId: SEED_EVENT_ENTRY_BAI_DA, visitDay: day, items: [{ ticketTypeId: 'adult', qty }], name: 'Khách', method: 'bank_qr',
  });
}

describe('S30 entry tickets on the emulators', () => {
  test('parallel registerEntry on the last seats → one sold_out_day', async () => {
    const day = visitDay(20);
    // 298 of 300 seats already sold that day.
    await db.doc(`entry_days/${SEED_EVENT_ENTRY_BAI_DA}_${day}`).set({
      eventId: SEED_EVENT_ENTRY_BAI_DA, day, sold: 298, held: 0, checkedIn: 0, closed: false, updatedAt: Timestamp.now(),
    });
    const [a, b] = await Promise.all([makeCustomer(1), makeCustomer(2)]);
    const results = await Promise.all([buy(a, day, 2), buy(b, day, 2)]);
    const ok = results.filter((r) => r.status === 200);
    const refused = results.filter((r) => r.status !== 200);
    assert.equal(ok.length, 1, results.map((r) => r.text).join('\n'));
    assert.equal(codeOf(refused[0] ?? {}), 'sold_out_day');
    const row = await data(`entry_days/${SEED_EVENT_ENTRY_BAI_DA}_${day}`);
    assert.deepEqual([row.sold, row.held], [298, 2]);
  });

  test('a paid entry ticket gets its private pass, a passes row and no public code', async () => {
    const buyer = await makeCustomer(3);
    const res = await buy(buyer, visitDay(3), 1);
    assert.equal(res.status, 200, res.text);
    const r = res.result as Registered;
    assert.equal(r.status, 'held');
    assert.equal((await call('confirmFakePayment', buyer, { paymentId: r.paymentId })).status, 200);
    const regPath = `events/${SEED_EVENT_ENTRY_BAI_DA}/registrations/${r.registrationId}`;
    const reg = await data(regPath);
    assert.equal(reg.status, 'paid');
    assert.equal('ticketCode' in reg, false);
    const code = String((await data(`${regPath}/private/pass`)).code);
    assert.ok(isPassCode(code));
    assert.equal(reg.ticketCodeLast4, code.slice(4));
    const pass = await data(`passes/${code}`);
    assert.deepEqual([pass.customerId, pass.eventId, pass.registrationIds], [buyer, SEED_EVENT_ENTRY_BAI_DA, [r.registrationId]]);
    const pay = await data(`payments/${r.paymentId}`);
    assert.deepEqual([pay.lineKind, pay.payeeKind, pay.payeeId, pay.escrowStatus], ['entry_ticket', 'organizer', SEED_ORGANIZER_BAI_DA, 'held']);
  });

  test('closeEntryDay refunds the day\'s tickets 100% and refuses new ones', async () => {
    const day = visitDay(5);
    const buyer = await makeCustomer(4);
    const r = (await buy(buyer, day, 2)).result as Registered;
    await call('confirmFakePayment', buyer, { paymentId: r.paymentId });
    // Only the organizer closes a day.
    assert.equal(codeOf(await call('closeEntryDay', BINH, { eventId: SEED_EVENT_ENTRY_BAI_DA, day })), 'permission_denied');
    const closed = await call('closeEntryDay', SEED_ORGANIZER_BAI_DA, { eventId: SEED_EVENT_ENTRY_BAI_DA, day });
    assert.equal(closed.status, 200, closed.text);
    assert.deepEqual(closed.result, { refunded: 1, left: 0 });
    const reg = await data(`events/${SEED_EVENT_ENTRY_BAI_DA}/registrations/${r.registrationId}`);
    assert.deepEqual([reg.status, reg.refundPercent], ['refunded', 100]);
    assert.equal((await data(`entry_days/${SEED_EVENT_ENTRY_BAI_DA}_${day}`)).closed, true);
    assert.equal(codeOf(await buy(await makeCustomer(5), day, 1)), 'day_closed');
  });

  test('a booking with tickets is paid through its group: the Firestore payment_group settler pays both lines and writes one pass', async () => {
    // An is a resident of the seed spot who waives both tickets; without the residency the booking carries them.
    await db.doc(`spots/${SEED_SPOT_BAI_DA}/residents/${AN}`).delete();
    // Far from An's seeded bookings, events and spot schedule.
    const day = visitDay(40);
    const booking = await call('createBooking', LAN, {
      photographerId: AN, serviceId: 'seed-service-portrait', day, start: '09:00', place: { name: 'Bãi đá sông Hồng' },
      entry: { eventId: SEED_EVENT_ENTRY_BAI_DA, visitDay: day, items: [{ ticketTypeId: 'adult', qty: 1 }] },
    });
    assert.equal(booking.status, 200, booking.text);
    const bookingId = (booking.result as { id: string }).id;
    const pay = await call('createPayment', LAN, { bookingId, method: 'bank_qr' });
    assert.equal(pay.status, 200, pay.text);
    const { paymentId, groupId, lines } = pay.result as { paymentId: string; groupId: string; lines: { paymentId: string; kind: string }[] };
    assert.equal(groupId, paymentId);
    assert.ok(lines.length >= 2);
    // The fake transfer of a line confirms the whole group.
    const line = lines.find((l) => l.kind === 'entry_ticket');
    assert.ok(line);
    assert.equal((await call('confirmFakePayment', LAN, { paymentId: line.paymentId })).status, 200);
    for (const l of lines) assert.equal((await data(`payments/${l.paymentId}`)).status, 'paid', l.kind);
    assert.equal((await data(`payment_groups/${groupId}`)).status, 'paid');
    const code = String((await data(`bookings/${bookingId}/private/pass`)).code);
    assert.ok(isPassCode(code));
    assert.equal((await data(`passes/${code}`)).bookingId, bookingId);
  });

  test('an unpaid group expires with its lines and gives the held tickets back (payment clock)', async () => {
    await db.doc(`spots/${SEED_SPOT_BAI_DA}/residents/${AN}`).delete();
    const day = visitDay(42);
    const booking = await call('createBooking', LAN, {
      photographerId: AN, serviceId: 'seed-service-portrait', day, start: '14:00', place: { name: 'Bãi đá sông Hồng' },
      entry: { eventId: SEED_EVENT_ENTRY_BAI_DA, visitDay: day, items: [{ ticketTypeId: 'adult', qty: 1 }] },
    });
    assert.equal(booking.status, 200, booking.text);
    const bookingId = (booking.result as { id: string }).id;
    const pay = (await call('createPayment', LAN, { bookingId, method: 'bank_qr' })).result as { paymentId: string; lines: { paymentId: string }[] };
    // Expire the QR as if 16 minutes went by, then run the clock that expires overdue payments.
    await db.doc(`payments/${pay.paymentId}`).update({ expiresAt: Timestamp.fromDate(new Date(Date.now() - 60_000)) });
    await handlePaymentClock(liveSettlementDeps());
    assert.equal((await data(`payments/${pay.paymentId}`)).status, 'expired');
    for (const l of pay.lines) assert.equal((await data(`payments/${l.paymentId}`)).status, 'expired');
    assert.equal((await data(`entry_days/${SEED_EVENT_ENTRY_BAI_DA}_${day}`)).held, 0);
  });
});
