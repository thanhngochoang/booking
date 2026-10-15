import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// Tomato/brick review (S05.05) on the Functions + Firestore emulators: submitReview, then the
// onReviewWrite trigger (stats, #138's verdict notice). Needs the emulators; CI runs it
// (npm run test:integration). Written, not run, while executing plans.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'review-test');
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

describe('tomato/brick review on the emulators', () => {
  const BOOKING = 'seed-booking-completed-recent';

  test('a brick review is stored with the server intensity, counted into stats and notified', async () => {
    const res = await callCallable(
      'submitReview',
      {
        bookingId: BOOKING,
        verdict: 'brick',
        hits: 3,
        reasons: ['late', 'slow_delivery'],
        text: 'Đến trễ 30 phút, ảnh giao sau 10 ngày.',
        intensity: 1,
        rating: 5,
      },
      tokens.get(LAN),
    );
    assert.equal(res.status, 200, res.text);
    assert.deepEqual(res.result, { postId: null });

    const review = await data(`reviews/${BOOKING}`);
    assert.equal(review.verdict, 'brick');
    assert.equal(review.hits, 3);
    assert.equal(review.intensity, 0.69);
    assert.deepEqual(review.reasons, ['late', 'slow_delivery']);
    assert.equal(review.subjectType, 'photographer');
    assert.equal(review.subjectId, AN);
    assert.equal(review.bookingDay, '2026-09-27');
    assert.equal('rating' in review, false);

    const booking = await data(`bookings/${BOOKING}`);
    assert.equal(booking.status, 'completed');
    assert.ok(booking.reviewedAt);

    // Seed: 56 tomato, 2 brick, signedSum 54.62 → one more brick of 0.69.
    await waitFor(async () => ((await data(`photographers/${AN}`)).stats?.brickCount ?? 0) === 3, 'the stats');
    const stats = (await data(`photographers/${AN}`)).stats as Record<string, unknown>;
    assert.equal(stats.reviewCount, 59);
    assert.equal(stats.tomatoCount, 56);
    assert.equal(stats.signedSum, 53.93);
    assert.equal(stats.tomatoPct, 95);
    assert.equal('rating' in stats, false);
    assert.ok((await data(`reviews/${BOOKING}`)).countedAt);

    const id = `n_review_brick_${BOOKING}_${AN}`;
    await waitFor(async () => (await db.doc(`users/${AN}/notifications/${id}`).get()).exists, 'the verdict row');
    const row = await data(`users/${AN}/notifications/${id}`);
    assert.equal(row.type, 'review_brick');
    assert.equal(row.title, 'Có góp ý mới về buổi chụp CN 27/9');
    assert.equal(row.target, `/u/${AN}?tab=reviews`);
    const all = (await db.collection(`users/${AN}/notifications`).get()).docs;
    assert.equal(all.some((d) => d.id.startsWith('n_review_new_')), false, 'no review_new is emitted');
  });

  test('a second review of the same booking is a conflict', async () => {
    const res = await callCallable(
      'submitReview',
      { bookingId: BOOKING, verdict: 'tomato', hits: 2, text: 'Lần hai thử gửi lại đánh giá.' },
      tokens.get(LAN),
    );
    assert.equal(res.status, 409, res.text);
    assert.deepEqual(res.error?.details, { code: 'conflict' });
  });

  test('seeded reviews are not recounted or announced', async () => {
    await new Promise((r) => setTimeout(r, 2000));
    const stats = (await data('photographers/seed-photographer-dung')).stats as Record<string, unknown>;
    assert.equal(stats.reviewCount, 6);
    const rows = (await db.collection('users/seed-photographer-dung/notifications').get()).docs;
    assert.equal(rows.some((d) => d.id.startsWith('n_review_')), false);
  });
});
