import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { MemoryPushSender, notifyBookingChange, sendDueReminders } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, BINH, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { bookingFromFirestore } from '../../src/infra/booking_firestore.js';
import { FirestoreNotificationStore } from '../../src/infra/notification_firestore.js';
import { FirestoreUserDirectory } from '../../src/infra/user_directory.js';

// Inbox rows, unread count, chat grouping and reminders on the Functions + Firestore emulators.
// Needs the emulators; CI runs it (npm run test:integration). Written, not run, while executing plans.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'notification-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const data = async (path: string) => (await db.doc(path).get()).data() ?? {};
const rows = async (uid: string) => (await db.collection(`users/${uid}/notifications`).get()).docs;

async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 20_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

const deps = (now: Date) => ({
  store: new FirestoreNotificationStore(db),
  push: new MemoryPushSender(),
  users: new FirestoreUserDirectory(db),
  clock: { now: () => now },
});

describe('notifications on the emulators', () => {
  const BOOKING = 'seed-booking-requested-binh';

  test('accepting a booking creates one row for the customer', async () => {
    // Count the rows of this booking only: the seed's own dispute, delivery and instant documents fire
    // their triggers for LAN a few seconds after applySeed, so the inbox total is not stable here.
    const ofBooking = async () => (await rows(LAN)).filter((r) => r.id.includes(BOOKING));
    const before = await ofBooking();
    await db.doc(`bookings/${BOOKING}`).update({ status: 'accepted' });
    const id = `n_booking_accepted_${BOOKING}`;
    await waitFor(async () => (await db.doc(`users/${LAN}/notifications/${id}`).get()).exists, 'the accepted row');
    const row = await data(`users/${LAN}/notifications/${id}`);
    assert.equal(row.type, 'booking_accepted');
    assert.equal(row.readAt, null);
    await new Promise((r) => setTimeout(r, 1000));
    assert.equal((await ofBooking()).length, before.length + 1);
  });

  test('a retried booking trigger leaves one row', async () => {
    const snap = await db.doc(`bookings/${BOOKING}`).get();
    const after = bookingFromFirestore(BOOKING, snap.data());
    assert.ok(after);
    const prior = { ...after, status: 'requested' as const };
    const d = deps(new Date());
    await notifyBookingChange(d, prior, after);
    await notifyBookingChange(d, prior, after);
    const same = (await rows(LAN)).filter((r) => r.id === `n_booking_accepted_${BOOKING}`);
    assert.equal(same.length, 1);
  });

  test('unreadCount follows creates and reads', async () => {
    const unread = (await rows(LAN)).filter((r) => r.data().readAt === null);
    await waitFor(async () => (await data(`users/${LAN}/private/inbox`)).unreadCount === unread.length, 'the unread count');
    const first = unread[0];
    assert.ok(first);
    await first.ref.update({ readAt: Timestamp.now() });
    await waitFor(async () => (await data(`users/${LAN}/private/inbox`)).unreadCount === unread.length - 1, 'the count after a read');
    assert.equal('unreadCount' in (await data(`users/${LAN}`)), false, 'the public user doc never holds the count');
  });

  test('markAllNotificationsRead zeroes the count', async () => {
    const res = await callCallable('markAllNotificationsRead', {}, tokens.get(LAN));
    assert.ok(typeof (res.result as { marked: number }).marked === 'number', res.text);
    assert.equal((await rows(LAN)).filter((r) => r.data().readAt === null).length, 0);
    await waitFor(async () => (await data(`users/${LAN}/private/inbox`)).unreadCount === 0, 'a zero count');
  });

  test('a chat message groups into g_chat_{id} and reading the chat clears it', async () => {
    await db.doc('chats/c-int-1').set({ members: [AN, LAN], kind: 'inquiry' });
    const msg = (id: string) =>
      db.doc(`chats/c-int-1/messages/${id}`).set({ senderId: AN, type: 'text', body: 'Chào bạn', createdAt: Timestamp.now() });
    await msg('m1');
    await waitFor(async () => (await db.doc(`users/${LAN}/notifications/g_chat_c-int-1`).get()).exists, 'the chat row');
    await msg('m2');
    await waitFor(async () => (await data(`users/${LAN}/notifications/g_chat_c-int-1`)).count === 2, 'a grouped count of 2');
    await db.doc(`chats/c-int-1/members/${LAN}`).set({ unreadCount: 0, lastReadAt: Timestamp.now() });
    await waitFor(async () => (await data(`users/${LAN}/notifications/g_chat_c-int-1`)).readAt != null, 'the row to be read');
  });

  test('in-app off writes no row', async () => {
    await db.doc(`users/${MINH}/private/notification_prefs`).set({
      channels: { booking: { push: true, inApp: true }, chat: { push: false, inApp: false } },
      quietHours: { enabled: true, from: '22:00', to: '07:00' },
      reminders: { h24: true, h2: true },
      updatedAt: Timestamp.now(),
    });
    await db.doc('chats/c-int-2').set({ members: [AN, MINH], kind: 'inquiry' });
    await db.doc('chats/c-int-2/messages/m1').set({ senderId: AN, type: 'text', body: 'Xin chào', createdAt: Timestamp.now() });
    await new Promise((r) => setTimeout(r, 3000));
    assert.equal((await db.doc(`users/${MINH}/notifications/g_chat_c-int-2`).get()).exists, false);
  });

  test('a counted review notifies the photographer and awards top_rated at 20 reviews', async () => {
    // 19 tomatoes so far (legacy star fields still present: the first verdict write deletes them).
    await db.doc(`photographers/${BINH}`).set(
      { stats: { reviewCount: 19, tomatoCount: 19, brickCount: 0, signedSum: 19, tomatoPct: 100, score: 1, rating: 5, ratingSum: 95 } },
      { merge: true },
    );
    await db.doc('reviews/seed-booking-completed-recent').set({
      bookingId: 'seed-booking-completed-recent',
      subjectType: 'photographer',
      subjectId: BINH,
      customerId: LAN,
      photographerId: BINH,
      serviceId: 'seed-service-family',
      serviceName: 'Gia đình 90 phút',
      bookingDay: '2026-09-27',
      verdict: 'tomato',
      hits: 10,
      intensity: 1,
      reasons: [],
      text: 'Rất tận tâm',
      photoPostId: null,
      createdAt: Timestamp.now(),
      countedAt: null,
    });
    const id = `n_review_tomato_seed-booking-completed-recent_${BINH}`;
    await waitFor(async () => (await db.doc(`users/${BINH}/notifications/${id}`).get()).exists, 'the review row');
    assert.equal((await data(`users/${BINH}/notifications/${id}`)).title, 'Bạn nhận 🍅 ×10 từ buổi chụp CN 27/9');
    await waitFor(async () => (await db.doc(`users/${BINH}/badges/top_rated`).get()).exists, 'the top_rated badge');
    assert.equal((await data(`users/${BINH}/badges/top_rated`)).uid, BINH);
    const stats = (await data(`photographers/${BINH}`)).stats as Record<string, unknown>;
    assert.equal(stats.reviewCount, 20);
    assert.equal('rating' in stats, false);
    assert.equal('ratingSum' in stats, false);
  });

  test('a new user gets new_member', async () => {
    await db.doc('users/new-member-1').set({ displayName: 'Mới', role: 'customer', createdAt: Timestamp.now() });
    await waitFor(async () => (await db.doc('users/new-member-1/badges/new_member').get()).exists, 'new_member');
  });

  test('the reminder sweep sends h2 once', async () => {
    // seed-booking-upcoming starts 2026-10-10 08:00 in Vietnam = 01:00Z.
    const d = deps(new Date('2026-10-09T23:30:00.000Z'));
    const snap = await db.doc('bookings/seed-booking-upcoming').get();
    const booking = bookingFromFirestore('seed-booking-upcoming', snap.data());
    assert.ok(booking);
    assert.equal(await sendDueReminders(d, [booking]), 2);
    assert.equal(await sendDueReminders(d, [booking]), 0);
    assert.equal((await db.doc(`users/${LAN}/notifications/n_shoot_reminder_seed-booking-upcoming_h2`).get()).exists, true);
  });
});
