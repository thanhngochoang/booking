import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, MINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'spot-booking-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});

after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));

describe('spot bookings and spot schedules on the emulators', () => {
  test('parallel createBooking on one slot: exactly one succeeds, the other is slot_taken', async () => {
    // Save schedule and offer for AN
    const spotId = 'seed-spot-ho-tay';
    const day = '2026-11-21';
    const schedRes = await call('saveSpotSchedule', AN, {
      spotId,
      days: [day],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['seed-service-portrait'],
    });
    assert.equal(schedRes.status, 200, schedRes.text);
    const scheduleId = (schedRes.result as { scheduleId: string }).scheduleId;

    const offerRes = await call('saveSlotOffer', AN, {
      scheduleId,
      name: 'Bình minh Hồ Tây 30 phút',
      price: 490_000,
      slotMinutes: 30,
      gapMinutes: 10,
      photoCount: 30,
      editedCount: 5,
      deliveryDays: 3,
    });
    assert.equal(offerRes.status, 200, offerRes.text);
    const slotOfferId = (offerRes.result as { offerId: string }).offerId;

    const slotDraft = {
      photographerId: AN,
      // A slot booking names the offer as its service and still sends a place (the spot decides it).
      serviceId: slotOfferId,
      place: { name: 'Hồ Tây' },
      day,
      start: '06:00',
      spotScheduleId: scheduleId,
      slotOfferId,
      expectedPrice: 490_000,
    };

    // Minh has no phone in the seed and booking needs one (phone_required).
    await db.doc(`users/${MINH}/private/contact`).set({ phone: '+84906002002', phoneVerified: false, allowZalo: true, allowWhatsApp: false });

    // Parallel attempts from two customers. (The same customer's second call is idempotent: the slot
    // already held by their own draft is not "taken" for them, so only different customers contend.)
    const [res1, res2] = await Promise.all([
      call('createBooking', LAN, slotDraft),
      call('createBooking', MINH, slotDraft),
    ]);

    const statuses = [res1.status, res2.status].sort();
    assert.deepEqual(statuses, [200, 400]);

    const failed = res1.status === 400 ? res1 : res2;
    assert.equal((failed.error?.details as { code?: string })?.code, 'slot_taken');
  });

  test('saveSpotSchedule on a day with a paid booking is day_conflict', async () => {
    const day = '2026-11-22';
    // Book a normal booking on that day and mark paid
    const bookingRef = db.collection('bookings').doc('booking_paid_day_conflict');
    await bookingRef.set({
      customerId: LAN,
      photographerId: AN,
      serviceId: 'seed-service-portrait',
      serviceSnapshot: { name: 'Chân dung', price: 1_500_000, durationMinutes: 120 },
      day,
      start: '09:00',
      end: '11:00',
      place: { name: 'Hồ Gươm' },
      status: 'accepted',
      deposit: 1_500_000,
      remaining: 0,
      version: 1,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await db.doc(`availability/${AN}/days/${day}`).set({
      state: 'booked',
      bookingId: 'booking_paid_day_conflict',
    });

    const res = await call('saveSpotSchedule', AN, {
      spotId: 'seed-spot-ho-tay',
      days: [day],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['seed-service-portrait'],
    });

    assert.equal(res.status, 400, res.text);
    assert.equal((res.error?.details as { code?: string })?.code, 'day_conflict');
  });

  test('cancelSpotSchedule with a paid booking is schedule_has_bookings', async () => {
    const day = '2026-11-28';
    const schedRes = await call('saveSpotSchedule', AN, {
      spotId: 'seed-spot-ho-tay',
      days: [day],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['seed-service-portrait'],
    });
    assert.equal(schedRes.status, 200, schedRes.text);
    const scheduleId = (schedRes.result as { scheduleId: string }).scheduleId;

    // Simulate an existing interval in spot_days doc
    await db.collection('spot_days').doc(`${scheduleId}_${day}`).set({
      scheduleId,
      spotId: 'seed-spot-ho-tay',
      providerId: AN,
      day,
      taken: [{ start: '06:00', end: '08:00' }],
      updatedAt: new Date(),
    });

    const cancelRes = await call('cancelSpotSchedule', AN, { scheduleId });
    assert.equal(cancelRes.status, 400, cancelRes.text);
    assert.equal((cancelRes.error?.details as { code?: string })?.code, 'schedule_has_bookings');
  });
});
