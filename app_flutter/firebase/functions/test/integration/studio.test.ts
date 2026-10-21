import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import {
  FakePaymentGateway,
  MemoryPushSender,
  assignDeadlineFor,
  formatVnDate,
  formatVnTime,
  newUlid,
  parseVnDateTime,
  runAssignDeadlineSweep,
  type Booking,
  type StudioBookingDeps,
} from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';
import { SEED_PASSWORD, SEED_STUDIO_UNASSIGNED } from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestoreAddonCatalog } from '../../src/infra/addon_firestore.js';
import { FirestoreBookingStore, bookingToFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreCustomerContactReader,
  FirestoreProviderOrderGate,
  FirestoreServiceCatalog,
} from '../../src/infra/booking_readers.js';
import { FirestoreNotificationStore } from '../../src/infra/notification_firestore.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import { FirestoreStudioRoster } from '../../src/infra/studio_firestore.js';
import { FirestoreUserDirectory } from '../../src/infra/user_directory.js';

// S26 studio members (#136) on the emulators: capacity per free member (Decision 26), invite → accept →
// assign, two parallel accepts, reassign, and the overdue sweep followed by the customer's 100% cancel.
// Every test builds its own studio, members, customer and booking, so they pass in any order.
// CI runs it (npm run test:integration); written, not run, while executing plans.

let app: App;
let db: Firestore;
let auth: Auth;
const tokens = new Map<string, string>();
const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;
const PRICE = 2_000_000;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'studio-test');
  db = getFirestore(app);
  auth = getAuth(app);
  await applySeed(db, auth, new Date());
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const codeOf = (res: { error?: { details?: unknown } }) => (res.error?.details as { code?: string } | undefined)?.code;

/** A signed-in test account: users doc, optional photographer doc, optional customer phone. */
async function person(
  uid: string,
  name: string,
  opts: { photographer?: Record<string, unknown>; phone?: string } = {},
): Promise<void> {
  const email = `${uid}@studio.seed.test`;
  await auth.createUser({ uid, email, password: SEED_PASSWORD });
  await db.doc(`users/${uid}`).set({ displayName: name, role: opts.photographer ? 'photographer' : 'customer' });
  if (opts.photographer) {
    await db.doc(`photographers/${uid}`).set({ onboardingComplete: true, verified: true, acceptingOrders: true, ...opts.photographer });
  }
  if (opts.phone) await db.doc(`users/${uid}/private/contact`).set({ phone: opts.phone, allowZalo: false, allowWhatsApp: false });
  tokens.set(uid, await signIn(email, SEED_PASSWORD));
}

let phones = 0;
const customer = (uid: string) => person(uid, `Khách ${uid}`, { phone: `+849030002${String(phones++).padStart(2, '0')}` });

/** A verified studio with one package `{uid}_svc`. */
async function studio(uid: string): Promise<void> {
  await person(uid, `Studio ${uid}`, { photographer: { providerType: 'studio', memberCount: 0 } });
  await db.doc(`photographers/${uid}/services/${uid}_svc`).set({
    name: 'Gói studio', price: PRICE, currency: 'VND', durationMinutes: 120, active: true, createdAt: new Date(),
  });
}

/** An active member written directly (the server fields a joined member carries). */
const member = (uid: string, studioId: string) =>
  person(uid, `Thợ ${uid}`, { photographer: { studioId, studioJoinedAt: new Date() } });

/**
 * An accepted, paid studio booking starting `hoursAhead` from now (whole hour, Vietnam time), made two days
 * ago (so its assign deadline is start − 24 h), assigned to `assigneeId` or not; with its held payment.
 */
async function studioBooking(
  id: string,
  o: { customerId: string; studioId: string; hoursAhead: number; assigneeId?: string },
): Promise<Booking> {
  const at = new Date(Math.floor((Date.now() + o.hoursAhead * HOUR_MS) / HOUR_MS) * HOUR_MS);
  const day = formatVnDate(at);
  const start = formatVnTime(at);
  const createdAt = new Date(Date.now() - 2 * DAY_MS);
  const assigneeId = o.assigneeId ?? null;
  const b: Booking = {
    id,
    customerId: o.customerId,
    photographerId: o.studioId,
    serviceId: `${o.studioId}_svc`,
    serviceSnapshot: { name: 'Gói studio', price: PRICE, durationMinutes: 120 },
    day,
    start,
    end: formatVnTime(new Date(at.getTime() + 2 * HOUR_MS)),
    place: { name: 'Studio' },
    status: 'accepted',
    deposit: PRICE,
    remaining: 0,
    escrowStatus: 'held',
    isStudio: true,
    assigneeId,
    assigneeKind: assigneeId === null ? null : 'member',
    assignStatus: assigneeId === null ? 'unassigned' : 'assigned',
    assignDeadline: assignDeadlineFor(parseVnDateTime(day, start), createdAt).toISOString(),
    assignOverdue: false,
    assignedAt: assigneeId === null ? null : createdAt.toISOString(),
    assignments:
      assigneeId === null
        ? []
        : [{ assigneeId, assigneeKind: 'member', at: createdAt.toISOString(), by: o.studioId, reason: null, late: false }],
    assignRemindersSent: [],
    changeRequest: null,
    studioFault: null,
    assignmentReturned: null,
    version: 1,
    createdAt: createdAt.toISOString(),
    updatedAt: createdAt.toISOString(),
  };
  await db.doc(`bookings/${id}`).set(bookingToFirestore(b));
  await db.doc(`studio_day_load/${o.studioId}_${day}`).set({
    studioId: o.studioId, day, unassignedIds: assigneeId === null ? [id] : [], assignedIds: assigneeId === null ? [] : [id],
    updatedAt: createdAt,
  });
  if (assigneeId !== null) await db.doc(`availability/${assigneeId}/days/${day}`).set({ state: 'booked', bookingId: id });
  // The held payment: the seed's studio payment, re-pointed at this booking.
  const seeded = (await db.doc(`payments/seed-payment-${SEED_STUDIO_UNASSIGNED}`).get()).data() ?? {};
  await db.doc(`payments/seed-payment-${id}`).set({
    ...seeded, subjectId: id, payerId: o.customerId, payeeId: o.studioId, amount: PRICE, receivedAmount: PRICE,
    idempotencyKey: `dep_${id}_fake`,
  });
  return b;
}

async function until<T>(read: () => Promise<T>, ok: (v: T) => boolean, ms = 10_000): Promise<T> {
  const end = Date.now() + ms;
  let v = await read();
  while (!ok(v) && Date.now() < end) {
    await new Promise((r) => setTimeout(r, 200));
    v = await read();
  }
  return v;
}

const chatMembers = (customerId: string, studioId: string) =>
  db.doc(`chats/${customerId}_${studioId}`).get().then((s) => (s.get('members') as string[] | undefined) ?? []);

function sweepDeps(): StudioBookingDeps {
  return {
    store: new FirestoreBookingStore(db),
    services: new FirestoreServiceCatalog(db),
    addons: new FirestoreAddonCatalog(db),
    contacts: new FirestoreCustomerContactReader(db),
    providers: new FirestoreProviderOrderGate(db),
    blocks: new FirestoreBlockGate(db),
    roster: new FirestoreStudioRoster(db),
    gateway: new FakePaymentGateway(),
    cipher: aesGcmCipher(emulatorPayoutKey()),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}

describe('studio members on the emulators', () => {
  test('a studio with three free members takes three bookings the same day; the fourth createBooking is day_taken', async () => {
    await studio('cap_studio');
    for (const m of ['cap_m1', 'cap_m2', 'cap_m3']) await member(m, 'cap_studio');
    const customers = ['cap_c1', 'cap_c2', 'cap_c3', 'cap_c4'];
    for (const c of customers) await customer(c);
    const day = formatVnDate(new Date(Date.now() + 40 * DAY_MS));
    const draft = { photographerId: 'cap_studio', serviceId: 'cap_studio_svc', day, start: '09:00', place: { name: 'Studio' } };

    for (const c of customers.slice(0, 3)) {
      const res = await call('createBooking', c, draft);
      assert.equal(res.status, 200, res.text);
    }
    const fourth = await call('createBooking', 'cap_c4', draft);
    assert.equal(fourth.status, 409, fourth.text);
    assert.equal(codeOf(fourth), 'day_taken');
    const load = (await db.doc(`studio_day_load/cap_studio_${day}`).get()).data();
    assert.equal((load?.unassignedIds as string[]).length, 3);
    // The derived full mark follows (onBookingWrite → recomputeStudioDay).
    const mark = await until(() => db.doc(`availability/cap_studio/days/${day}`).get(), (s) => s.exists);
    assert.equal(mark.data()?.state, 'full');
    // onPhotographerWrite keeps the public count of members the studio can assign.
    const studioDoc = await until(() => db.doc('photographers/cap_studio').get(), (s) => s.get('assignableMembers') === 3);
    assert.equal(studioDoc.get('assignableMembers'), 3);
  });

  test('invite → accept → assign → the booking and its chat carry the assignee', async () => {
    await studio('inv_studio');
    await customer('inv_c1');
    await person('inv_new', 'Thợ Mới', { photographer: {} });
    await studioBooking('inv_booking', { customerId: 'inv_c1', studioId: 'inv_studio', hoursAhead: 72 });

    const invited = await call('inviteMember', 'inv_studio', { memberId: 'inv_new' });
    assert.equal(invited.status, 200, invited.text);
    const { relationId } = invited.result as { relationId: string };
    const accepted = await call('respondInvite', 'inv_new', { relationId, accept: true });
    assert.equal(accepted.status, 200, accepted.text);
    assert.deepEqual(accepted.result, { status: 'active' });
    assert.equal((await db.doc('photographers/inv_new').get()).get('studioId'), 'inv_studio');

    const options = await call('assignmentOptions', 'inv_studio', { bookingId: 'inv_booking' });
    assert.equal(options.status, 200, options.text);
    const rows = (options.result as { options: { uid: string; state: string }[] }).options;
    assert.equal(rows.find((o) => o.uid === 'inv_new')?.state, 'free');

    const assigned = await call('assignBooking', 'inv_studio', { bookingId: 'inv_booking', assigneeId: 'inv_new' });
    assert.equal(assigned.status, 200, assigned.text);
    assert.equal((assigned.result as { assigneeId: string }).assigneeId, 'inv_new');
    const booking = (await db.doc('bookings/inv_booking').get()).data();
    assert.equal(booking?.assigneeId, 'inv_new');
    assert.equal((await db.doc(`availability/inv_new/days/${booking?.day}`).get()).get('bookingId'), 'inv_booking');
    const members = await until(() => chatMembers('inv_c1', 'inv_studio'), (m) => m.includes('inv_new'));
    assert.deepEqual(members, ['inv_c1', 'inv_studio', 'inv_new']);
  });

  test('two parallel accepts: one active, the other membership_conflict', async () => {
    await studio('par_studio1');
    await studio('par_studio2');
    await person('par_both', 'Thợ Hai Nơi', { photographer: {} });
    const a = await call('inviteMember', 'par_studio1', { memberId: 'par_both' });
    const b = await call('inviteMember', 'par_studio2', { memberId: 'par_both' });
    assert.equal(a.status, 200, a.text);
    assert.equal(b.status, 200, b.text);
    const answers = await Promise.all([
      call('respondInvite', 'par_both', { relationId: (a.result as { relationId: string }).relationId, accept: true }),
      call('respondInvite', 'par_both', { relationId: (b.result as { relationId: string }).relationId, accept: true }),
    ]);
    assert.deepEqual(answers.map((r) => r.status).sort(), [200, 400]);
    assert.equal(codeOf(answers.find((r) => r.status === 400) ?? {}), 'membership_conflict');
    const active = await db.collection('studio_members').where('memberId', '==', 'par_both').where('status', '==', 'active').get();
    assert.equal(active.size, 1);
    const studioId = (await db.doc('photographers/par_both').get()).get('studioId');
    assert.equal(active.docs[0]?.get('studioId'), studioId);
  });

  test('reassign: the old member loses the day, the booking and the chat', async () => {
    await studio('re_studio');
    await customer('re_c1');
    await member('re_old', 're_studio');
    await member('re_new', 're_studio');
    const b = await studioBooking('re_booking', { customerId: 're_c1', studioId: 're_studio', hoursAhead: 72, assigneeId: 're_old' });
    await until(() => chatMembers('re_c1', 're_studio'), (m) => m.includes('re_old'));

    const res = await call('assignBooking', 're_studio', { bookingId: 're_booking', assigneeId: 're_new' });
    assert.equal(res.status, 200, res.text);
    const stored = (await db.doc('bookings/re_booking').get()).data();
    assert.equal(stored?.assigneeId, 're_new');
    assert.equal((await db.doc(`availability/re_old/days/${b.day}`).get()).exists, false);
    assert.equal((await db.doc(`availability/re_new/days/${b.day}`).get()).get('bookingId'), 're_booking');
    // The old member no longer matches the booking rule (assigneeId) nor the chat members.
    const members = await until(() => chatMembers('re_c1', 're_studio'), (m) => !m.includes('re_old') && m.includes('re_new'));
    assert.deepEqual(members, ['re_c1', 're_studio', 're_new']);
    // Only the studio assigns.
    const refused = await call('assignBooking', 're_old', { bookingId: 're_booking', assigneeId: 're_old' });
    assert.equal(refused.status, 403, refused.text);
  });

  test('overdue sweep then cancel_studio_fault refunds 100%', async () => {
    await studio('od_studio');
    await customer('od_c1');
    // Starts in about 20 hours, made two days ago: the assign deadline (start − 24 h) has passed.
    await studioBooking('od_booking', { customerId: 'od_c1', studioId: 'od_studio', hoursAhead: 20 });

    const notify = { store: new FirestoreNotificationStore(db), push: new MemoryPushSender(), users: new FirestoreUserDirectory(db), clock: { now: () => new Date() } };
    const swept = await runAssignDeadlineSweep(sweepDeps(), notify);
    assert.ok(swept.overdue >= 1, JSON.stringify(swept));
    const marked = (await db.doc('bookings/od_booking').get()).data();
    assert.equal(marked?.assignOverdue, true);
    assert.equal(marked?.studioFault?.kind, 'assign_overdue');

    const cancelled = await call('transitionBooking', 'od_c1', { bookingId: 'od_booking', action: 'cancel_studio_fault' });
    assert.equal(cancelled.status, 200, cancelled.text);
    const done = (await db.doc('bookings/od_booking').get()).data();
    assert.equal(done?.status, 'cancelled');
    assert.equal(done?.cancel?.by, 'studio_fault');
    assert.equal(done?.cancel?.refundPercent, 100);
    const refunds = await db.collection('refunds').where('paymentId', '==', 'seed-payment-od_booking').get();
    assert.equal(refunds.size, 1);
    assert.equal(refunds.docs[0]?.get('percent'), 100);
    // A second cancel finds nothing to cancel.
    const again = await call('transitionBooking', 'od_c1', { bookingId: 'od_booking', action: 'cancel_studio_fault' });
    assert.notEqual(again.status, 200, again.text);
  });
});
