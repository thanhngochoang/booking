import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_BOOKING_SHOT_LATE, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { waitFor } from './event_social_support.js';

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'delivery-late-cancel-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));

describe('cancelLateDelivery on the emulators (S05, #207)', () => {
  test('cancels the overdue delivery part of seed-booking-shot-late, refunds milestone 2, and leaves shoot milestone released', async () => {
    const res = await call('cancelLateDelivery', LAN, { bookingId: SEED_BOOKING_SHOT_LATE });
    assert.equal(res.status, 200, res.text);
    assert.deepEqual(res.result, { status: 'completed', refundedAmount: 750_000 });

    const booking = (await db.collection('bookings').doc(SEED_BOOKING_SHOT_LATE).get()).data();
    assert.equal(booking?.status, 'completed');
    // The payment's aggregate over [shoot released, delivery refunded] (#207 Decision 7).
    assert.equal(booking?.escrowStatus, 'released');
    assert.equal(booking?.depositRefunded, 750_000);
    assert.equal(booking?.deliveryCancel?.refundedAmount, 750_000);

    const payment = (await db.collection('payments').doc(`seed-payment-${SEED_BOOKING_SHOT_LATE}`).get()).data();
    assert.equal(payment?.status, 'partially_refunded');
    assert.equal(payment?.escrowStatus, 'released');
    assert.equal(payment?.refundedAmount, 750_000);

    // The milestone read model is written by the onPaymentWritten trigger.
    const deliveryMilestone = await waitFor('the delivery milestone read model', async () => {
      const d = (await db.doc(`bookings/${SEED_BOOKING_SHOT_LATE}/milestones/delivery`).get()).data();
      return d?.status === 'refunded' ? d : null;
    });
    assert.equal(deliveryMilestone.status, 'refunded');
    const shootMilestone = (await db.doc(`bookings/${SEED_BOOKING_SHOT_LATE}/milestones/shoot`).get()).data();
    assert.equal(shootMilestone?.status, 'released');

    // Second call is refused as not_eligible.
    const repeat = await call('cancelLateDelivery', LAN, { bookingId: SEED_BOOKING_SHOT_LATE });
    assert.equal(repeat.status, 400, repeat.text);
    assert.equal((repeat.error?.details as { code?: string })?.code, 'not_eligible');

    // Provider receives delivery_cancelled_late (written by the onBookingWrite trigger; id n_{dedupeKey}).
    const notif = await waitFor('the provider notification', async () => {
      const d = await db.doc(`users/${AN}/notifications/n_delivery_cancelled_late_${SEED_BOOKING_SHOT_LATE}`).get();
      return d.exists ? d : null;
    });
    assert.equal(notif.get('type'), 'delivery_cancelled_late');
  });
});
