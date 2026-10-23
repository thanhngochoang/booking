import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'job-integration-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});

after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));

describe('job and quote lifecycle on the emulators', () => {
  test('post, match, quote, accept, fake-pay, award', async () => {
    // 1. Lan posts in Hoàn Kiếm
    const postRes = await call('createJob', LAN, {
      specialtyId: 'portrait',
      title: 'Chụp ảnh tốt nghiệp tại Bờ Hồ',
      description: 'Cần tìm thợ chụp kỷ yếu tốt nghiệp quanh khu vực Hồ Gươm.',
      references: [],
      schedule: {
        kind: 'fixed',
        day: '2026-11-20',
        start: '08:00',
        end: '10:00',
        durationMinutes: 120,
      },
      area: {
        areaId: 'hn-hoan-kiem',
        name: 'Quận Hoàn Kiếm, Hà Nội',
        lat: 21.0285,
        lng: 105.8542,
      },
      budget: { min: 1_000_000, max: 2_500_000 },
      wants: { editedCount: 30, deliveryDays: 7 },
      allowedProviders: 'all',
      deadlineDays: 3,
    });
    assert.equal(postRes.status, 200, postRes.text);
    const { jobId } = postRes.result as { jobId: string; matched: number };
    assert.ok(jobId);

    // 2. An quotes
    const quoteRes = await call('submitQuote', AN, {
      jobId,
      price: 1_800_000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 1,
      message: 'Chào bạn, mình chuyên chụp chân dung khu vực Hồ Gươm.',
    });
    assert.equal(quoteRes.status, 200, quoteRes.text);

    // 3. Lan accepts (bank_qr)
    const acceptRes = await call('acceptQuote', LAN, {
      jobId,
      photographerId: AN,
      place: { name: 'Tháp Rùa, Hồ Gươm' },
      method: 'bank_qr',
    });
    assert.equal(acceptRes.status, 200, acceptRes.text);
    const { bookingId, paymentId } = acceptRes.result as {
      bookingId: string;
      paymentId: string;
      checkout: unknown;
    };
    assert.ok(bookingId);
    assert.ok(paymentId);

    // 4. Confirm fake payment with kind 'exact'
    const payRes = await call('confirmFakePayment', LAN, {
      paymentId,
      kind: 'exact',
    });
    assert.equal(payRes.status, 200, payRes.text);

    // 5. Booking accepted, job awarded, An's quote accepted
    const jobSnap = await db.collection('jobs').doc(jobId).get();
    assert.equal(jobSnap.data()?.status, 'awarded');
    assert.equal(jobSnap.data()?.awardedQuoteId, AN);

    const quoteSnap = await db.collection('jobs').doc(jobId).collection('quotes').doc(AN).get();
    assert.equal(quoteSnap.data()?.status, 'accepted');
  });

  test('an accepted package booking auto-withdraws Ans quote on that day', async () => {
    // Lan posts for day 2026-11-25
    const postRes = await call('createJob', LAN, {
      specialtyId: 'portrait',
      title: 'Chụp chân dung ngoại cảnh',
      description: 'Chụp ảnh ngoại cảnh Hà Nội.',
      references: [],
      schedule: {
        kind: 'fixed',
        day: '2026-11-25',
        start: '09:00',
        end: '11:00',
        durationMinutes: 120,
      },
      area: {
        areaId: 'hn-hoan-kiem',
        name: 'Quận Hoàn Kiếm, Hà Nội',
        lat: 21.0285,
        lng: 105.8542,
      },
      budget: { min: 1_000_000, max: 2_000_000 },
      wants: { editedCount: 20, deliveryDays: 5 },
      allowedProviders: 'all',
      deadlineDays: 3,
    });
    const { jobId } = postRes.result as { jobId: string };

    // An submits quote for 2026-11-25
    await call('submitQuote', AN, {
      jobId,
      price: 1_500_000,
      editedCount: 20,
      deliveryDays: 5,
      revisions: 1,
      message: 'Báo giá chụp ngoại cảnh chuyên nghiệp.',
    });

    // Another customer books An for a package on 2026-11-25
    const bookRes = await call('createBooking', 'seed-customer-minh', {
      photographerId: AN,
      serviceId: 'seed-service-portrait',
      day: '2026-11-25',
      start: '14:00',
      end: '16:00',
      place: { name: 'Văn Miếu' },
    });
    const { id: pkgBookingId } = bookRes.result as { id: string };

    // Fake payment & accept package booking
    const payRes = await call('createPayment', 'seed-customer-minh', {
      bookingId: pkgBookingId,
      method: 'bank_qr',
    });
    const { paymentId: pkgPayId } = payRes.result as { paymentId: string };
    await call('confirmFakePayment', 'seed-customer-minh', { paymentId: pkgPayId, kind: 'exact' });

    // Quote should now be auto-withdrawn
    const quoteSnap = await db.collection('jobs').doc(jobId).collection('quotes').doc(AN).get();
    assert.equal(quoteSnap.data()?.status, 'withdrawn');
    assert.equal(quoteSnap.data()?.autoWithdrawn, true);
  });
});
