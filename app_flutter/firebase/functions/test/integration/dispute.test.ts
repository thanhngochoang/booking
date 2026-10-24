import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { FakePaymentGateway, newUlid, runBookingSweeps, type BookingDeps } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { emulatorPayoutKey } from '../../seed/emulator_key.js';
import { ADMIN, AN, LAN, SEED_BOOKING_COMPLETED_WINDOW, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { FirestoreAddonCatalog } from '../../src/infra/addon_firestore.js';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreCustomerContactReader,
  FirestoreProviderOrderGate,
  FirestoreServiceCatalog,
} from '../../src/infra/booking_readers.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';

// S18 (#142) on the emulators: Lan opens a dispute on the seeded booking completed 2 hours ago
// (money held), the booking clock runs past its release time and leaves the money frozen, then
// staff split 40/60: the refund goes out on the fake gateway and the rest is released to An.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();
const HOUR = 3_600_000;
const PAYMENT = `seed-payment-${SEED_BOOKING_COMPLETED_WINDOW}`;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'dispute-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};

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

describe('disputes on the emulators', () => {
  test('openDispute then bookingClock leaves the payment disputed; resolveDispute split releases and refunds on the fake gateway', async () => {
    const disputeId = newUlid(Date.now());
    const input = {
      disputeId,
      subjectType: 'booking',
      subjectId: SEED_BOOKING_COMPLETED_WINDOW,
      reason: 'not_as_agreed',
      description: 'Ảnh không đúng phong cách đã thoả thuận trước buổi chụp.',
      evidencePaths: [],
    };
    const opened = await call('openDispute', LAN, input);
    assert.equal(opened.status, 200, opened.text);
    assert.deepEqual(opened.result, { disputeId });

    const dispute = await data(`disputes/${disputeId}`);
    assert.equal(dispute.status, 'open');
    assert.deepEqual(dispute.parties, [LAN, AN]);
    assert.equal(dispute.amountHeld, 1_500_000);
    assert.equal((await data(`payments/${PAYMENT}`)).escrowStatus, 'disputed');
    const booking = await data(`bookings/${SEED_BOOKING_COMPLETED_WINDOW}`);
    assert.equal(booking.disputeId, disputeId);
    assert.equal(booking.escrowStatus, 'disputed');
    assert.equal((await data(`support_threads/dispute_${disputeId}`)).kind, 'dispute');

    // The same id again by Lan: the same dispute; a second dispute on the booking: conflict.
    const again = await call('openDispute', LAN, input);
    assert.deepEqual(again.result, { disputeId }, again.text);
    const second = await call('openDispute', LAN, {
      disputeId: newUlid(Date.now()), subjectType: 'booking', subjectId: SEED_BOOKING_COMPLETED_WINDOW,
      reason: 'other', description: 'Một khiếu nại thứ hai cho cùng buổi chụp.', evidencePaths: [],
    });
    assert.equal((second.error?.details as { code?: string } | undefined)?.code, 'conflict', second.text);

    // Two days later the booking clock's release step skips the frozen payment.
    await runBookingSweeps(sweepDeps(new Date(Date.now() + 48 * HOUR)));
    const frozen = await data(`payments/${PAYMENT}`);
    assert.equal(frozen.escrowStatus, 'disputed');
    assert.equal(frozen.releasedAt, null);

    // Only staff decide.
    const refused = await call('resolveDispute', LAN, { disputeId, outcome: 'refund', note: 'Tự hoàn cho mình.' });
    assert.equal((refused.error?.details as { code?: string } | undefined)?.code, 'permission_denied', refused.text);

    const resolved = await call('resolveDispute', ADMIN, { disputeId, outcome: 'split', refundPercent: 40, note: 'Một phần ảnh không đúng thoả thuận.' });
    assert.equal(resolved.status, 200, resolved.text);
    assert.deepEqual(resolved.result, { disputeId, refundAmount: 600_000, releaseAmount: 900_000 });

    const after = await data(`disputes/${disputeId}`);
    assert.equal(after.status, 'resolved');
    const outcome = after.outcome as { kind: string; decidedBy: string; refundId: string };
    assert.equal(outcome.kind, 'split');
    assert.equal(outcome.decidedBy, ADMIN);
    const refund = await data(`refunds/${outcome.refundId}`);
    assert.equal(refund.amount, 600_000);
    assert.equal(refund.status, 'done');
    assert.equal(refund.fromEscrow, true);
    const pay = await data(`payments/${PAYMENT}`);
    assert.equal(pay.escrowStatus, 'released');
    const ledger = (await db.collection('ledger_entries').where('paymentId', '==', PAYMENT).get()).docs.map((d) => d.data());
    assert.ok(ledger.some((e) => e.type === 'refund_issued' && e.amount === -600_000));
    assert.ok(ledger.some((e) => e.type === 'escrow_released' && e.amount === 900_000 && e.accountOwnerId === AN));
    // Mirrors: the refund on the booking (the refund notice), the thread closed.
    const b = await data(`bookings/${SEED_BOOKING_COMPLETED_WINDOW}`);
    assert.equal(b.disputeId, disputeId);
    assert.equal(b.depositRefunded, 600_000);
    assert.ok(b.depositRefundedAt);
    assert.equal((await data(`support_threads/dispute_${disputeId}`)).status, 'closed');
    // A second decision is refused.
    const twice = await call('resolveDispute', ADMIN, { disputeId, outcome: 'release', note: 'Đổi ý.' });
    assert.equal((twice.error?.details as { code?: string } | undefined)?.code, 'conflict', twice.text);
  });
});
