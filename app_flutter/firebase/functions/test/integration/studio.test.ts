import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import {
  FakePaymentGateway,
  MemoryPushSender,
  formatVnDate,
  newUlid,
  runStudioBookingSweeps,
  type StudioBookingDeps,
} from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';
import {
  AN,
  CUC,
  LAN,
  SEED_PASSWORD,
  SEED_STUDIO_UNASSIGNED,
  SEED_USERS,
} from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestoreAddonCatalog } from '../../src/infra/addon_firestore.js';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
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
// CI runs it (npm run test:integration); written, not run, while executing plans.

let app: App;
let db: Firestore;
let auth: Auth;
const tokens = new Map<string, string>();
const DAY_MS = 86_400_000;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'studio-test');
  db = getFirestore(app);
  auth = getAuth(app);
  await applySeed(db, auth, new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
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

async function until<T>(read: () => Promise<T>, ok: (v: T) => boolean, ms = 10_000): Promise<T> {
  const end = Date.now() + ms;
  let v = await read();
  while (!ok(v) && Date.now() < end) {
    await new Promise((r) => setTimeout(r, 200));
    v = await read();
  }
  return v;
}

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
  test('Cúc with three free members takes three bookings the same day; the fourth createBooking is day_taken', async () => {
    // An is Cúc's seeded member; two more verified members join directly (server-written fields).
    for (const m of ['st_cap_m1', 'st_cap_m2']) {
      await person(m, `Thợ ${m}`, { photographer: { studioId: CUC, studioJoinedAt: new Date() } });
    }
    const customers = ['st_cap_c1', 'st_cap_c2', 'st_cap_c3', 'st_cap_c4'];
    for (const [i, c] of customers.entries()) await person(c, `Khách ${i + 1}`, { phone: `+8490300010${i}` });
    const day = formatVnDate(new Date(Date.now() + 40 * DAY_MS));
    const draft = { photographerId: CUC, serviceId: 'seed-service-studio-family', day, start: '09:00', place: { name: 'Studio Cúc' } };

    for (const c of customers.slice(0, 3)) {
      const res = await call('createBooking', c, draft);
      assert.equal(res.status, 200, res.text);
    }
    const fourth = await call('createBooking', 'st_cap_c4', draft);
    assert.equal(fourth.status, 409, fourth.text);
    assert.equal(codeOf(fourth), 'day_taken');
    const load = (await db.doc(`studio_day_load/${CUC}_${day}`).get()).data();
    assert.equal((load?.unassignedIds as string[]).length, 3);
    // The derived full mark follows (onBookingWrite → recomputeStudioDay).
    const mark = await until(() => db.doc(`availability/${CUC}/days/${day}`).get(), (s) => s.exists);
    assert.equal(mark.data()?.state, 'full');
  });

  test('invite → accept → assign → the booking and its chat carry the assignee', async () => {
    await person('st_new', 'Thợ Mới', { photographer: {} });
    const invited = await call('inviteMember', CUC, { memberId: 'st_new' });
    assert.equal(invited.status, 200, invited.text);
    const { relationId } = invited.result as { relationId: string };
    const accepted = await call('respondInvite', 'st_new', { relationId, accept: true });
    assert.equal(accepted.status, 200, accepted.text);
    assert.deepEqual(accepted.result, { status: 'active' });
    assert.equal((await db.doc('photographers/st_new').get()).get('studioId'), CUC);

    const options = await call('assignmentOptions', CUC, { bookingId: SEED_STUDIO_UNASSIGNED });
    assert.equal(options.status, 200, options.text);
    const rows = (options.result as { options: { uid: string; state: string }[] }).options;
    assert.equal(rows.find((o) => o.uid === 'st_new')?.state, 'free');

    const assigned = await call('assignBooking', CUC, { bookingId: SEED_STUDIO_UNASSIGNED, assigneeId: 'st_new' });
    assert.equal(assigned.status, 200, assigned.text);
    assert.equal((assigned.result as { assigneeId: string }).assigneeId, 'st_new');
    const booking = (await db.doc(`bookings/${SEED_STUDIO_UNASSIGNED}`).get()).data();
    assert.equal(booking?.assigneeId, 'st_new');
    assert.equal((await db.doc(`availability/st_new/days/${booking?.day}`).get()).get('bookingId'), SEED_STUDIO_UNASSIGNED);
    const chat = await until(
      () => db.doc(`chats/${LAN}_${CUC}`).get(),
      (s) => ((s.get('members') as string[] | undefined) ?? []).includes('st_new'),
    );
    assert.deepEqual(chat.get('members'), [LAN, CUC, 'st_new']);
  });

  test('two parallel accepts: one active, the other membership_conflict', async () => {
    // Two fresh studios (Cúc's three seats are taken by now).
    await person('st_studio1', 'Nắng Studio', { photographer: { providerType: 'studio' } });
    await person('st_studio2', 'Mây Studio', { photographer: { providerType: 'studio' } });
    await person('st_both', 'Thợ Hai Nơi', { photographer: {} });
    const a = await call('inviteMember', 'st_studio1', { memberId: 'st_both' });
    const b = await call('inviteMember', 'st_studio2', { memberId: 'st_both' });
    assert.equal(a.status, 200, a.text);
    assert.equal(b.status, 200, b.text);
    const answers = await Promise.all([
      call('respondInvite', 'st_both', { relationId: (a.result as { relationId: string }).relationId, accept: true }),
      call('respondInvite', 'st_both', { relationId: (b.result as { relationId: string }).relationId, accept: true }),
    ]);
    assert.deepEqual(answers.map((r) => r.status).sort(), [200, 400]);
    assert.equal(codeOf(answers.find((r) => r.status === 400) ?? {}), 'membership_conflict');
    const active = await db.collection('studio_members').where('memberId', '==', 'st_both').where('status', '==', 'active').get();
    assert.equal(active.size, 1);
    const studioId = (await db.doc('photographers/st_both').get()).get('studioId');
    assert.equal(active.docs[0]?.get('studioId'), studioId);
  });

  test('reassign: the old member loses the day, the booking and the chat', async () => {
    await person('st_second', 'Thợ Thứ Hai', { photographer: { studioId: CUC, studioJoinedAt: new Date() } });
    const before = (await db.doc(`bookings/${SEED_STUDIO_UNASSIGNED}`).get()).data();
    const old = before?.assigneeId as string;
    const res = await call('assignBooking', CUC, { bookingId: SEED_STUDIO_UNASSIGNED, assigneeId: 'st_second' });
    assert.equal(res.status, 200, res.text);
    const after = (await db.doc(`bookings/${SEED_STUDIO_UNASSIGNED}`).get()).data();
    assert.equal(after?.assigneeId, 'st_second');
    assert.equal((await db.doc(`availability/${old}/days/${after?.day}`).get()).exists, false);
    // The old member no longer matches the booking rule (assigneeId) nor the chat members.
    const chat = await until(
      () => db.doc(`chats/${LAN}_${CUC}`).get(),
      (s) => !((s.get('members') as string[] | undefined) ?? []).includes(old),
    );
    assert.deepEqual(chat.get('members'), [LAN, CUC, 'st_second']);
    // Only the studio assigns.
    const refused = await call('assignBooking', AN, { bookingId: SEED_STUDIO_UNASSIGNED, assigneeId: AN });
    assert.equal(refused.status, 403, refused.text);
  });

  test('overdue sweep then cancel_studio_fault refunds 100%', async () => {
    // A fresh unassigned studio booking whose deadline has passed: a copy of the seeded one, back to unassigned.
    const seeded = (await db.doc(`bookings/${SEED_STUDIO_UNASSIGNED}`).get()).data() ?? {};
    const id = 'st_overdue_1';
    await db.doc(`bookings/${id}`).set({
      ...seeded,
      assigneeId: null,
      assigneeKind: null,
      assignStatus: 'unassigned',
      assignedAt: null,
      assignments: [],
      assignOverdue: false,
      studioFault: null,
      changeRequest: null,
      assignmentReturned: null,
      status: 'accepted',
      chatId: null,
      version: 1,
    });
    const payment = (await db.doc(`payments/seed-payment-${SEED_STUDIO_UNASSIGNED}`).get()).data() ?? {};
    await db.doc(`payments/seed-payment-${id}`).set({ ...payment, subjectId: id, idempotencyKey: `dep_${id}_fake` });

    const notify = { store: new FirestoreNotificationStore(db), push: new MemoryPushSender(), users: new FirestoreUserDirectory(db), clock: { now: () => new Date() } };
    const swept = await runStudioBookingSweeps(sweepDeps(), notify);
    assert.ok(swept.overdue >= 1, JSON.stringify(swept));
    const marked = (await db.doc(`bookings/${id}`).get()).data();
    assert.equal(marked?.assignOverdue, true);
    assert.equal(marked?.studioFault?.kind, 'assign_overdue');

    const cancelled = await call('transitionBooking', LAN, { bookingId: id, action: 'cancel_studio_fault' });
    assert.equal(cancelled.status, 200, cancelled.text);
    const done = (await db.doc(`bookings/${id}`).get()).data();
    assert.equal(done?.status, 'cancelled');
    assert.equal(done?.cancel?.by, 'studio_fault');
    assert.equal(done?.cancel?.refundPercent, 100);
    const refunds = await db.collection('refunds').where('paymentId', '==', `seed-payment-${id}`).get();
    assert.equal(refunds.size, 1);
    assert.equal(refunds.docs[0]?.get('percent'), 100);
    // A second cancel finds nothing to cancel.
    const again = await call('transitionBooking', LAN, { bookingId: id, action: 'cancel_studio_fault' });
    assert.notEqual(again.status, 200, again.text);
  });
});
