import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { bookingContactUnlocked, isId, isInternationalE164, isVnE164 } from '@photobooking/domain';
import { SEED_PASSWORD, SEED_PHOTOGRAPHERS, SEED_USERS, seedDocuments } from '../../seed/fixtures.js';

const NOW = new Date('2026-10-01T12:00:00Z');

function bookingDoc(id: string): { status: string; timeline: { status: string; at: Date }[] } {
  const doc = seedDocuments(NOW).find((d) => d.path === `bookings/${id}`);
  if (doc === undefined) throw new Error(`no seed booking ${id}`);
  return doc.data as { status: string; timeline: { status: string; at: Date }[] };
}

describe('seed fixtures', () => {
  test('every path segment is a valid opaque id', () => {
    for (const d of seedDocuments(NOW)) {
      for (const segment of d.path.split('/')) assert.ok(isId(segment), d.path);
    }
  });

  test('accounts are test-only', () => {
    for (const u of SEED_USERS) assert.match(u.email, /@seed\.test$/);
    assert.ok(SEED_PASSWORD.length >= 6, 'the Auth emulator needs at least 6 characters');
  });

  test('numbers are valid and only in private documents', () => {
    for (const d of seedDocuments(NOW)) {
      if (d.path.includes('/private/')) continue;
      assert.doesNotMatch(JSON.stringify(d.data), /\+\d{8,15}/, d.path);
      assert.ok(!Object.keys(d.data).some((k) => /phone/i.test(k)), d.path);
    }
    for (const p of SEED_PHOTOGRAPHERS) {
      assert.ok(isVnE164(p.numbers.phone), p.uid);
      if (p.numbers.zaloPhone !== undefined) assert.ok(isVnE164(p.numbers.zaloPhone), p.uid);
      if (p.numbers.whatsappPhone !== undefined) assert.ok(isInternationalE164(p.numbers.whatsappPhone), p.uid);
    }
  });

  test('money follows the deposit rule: floor(30%) and the rest, integer VND', () => {
    for (const d of seedDocuments(NOW).filter((x) => x.path.startsWith('bookings/') && !x.path.includes('/private/'))) {
      const data = d.data as { service: { price: number }; deposit: { amount: number }; remaining: number };
      assert.equal(data.deposit.amount, Math.floor(data.service.price * 0.3), d.path);
      assert.equal(data.deposit.amount + data.remaining, data.service.price, d.path);
      assert.ok(Number.isInteger(data.remaining), d.path);
    }
  });

  test('the bookings cover unlocked and locked contact', () => {
    const unlocked = (id: string) => {
      const b = bookingDoc(id);
      const completedAt = b.timeline.filter((e) => e.status === 'completed').at(-1)?.at ?? null;
      return bookingContactUnlocked({ status: b.status, completedAt }, NOW);
    };
    assert.equal(unlocked('seed-booking-accepted'), true);
    assert.equal(unlocked('seed-booking-upcoming'), true);
    assert.equal(unlocked('seed-booking-requested-binh'), true);
    assert.equal(unlocked('seed-booking-completed-recent'), true);
    assert.equal(unlocked('seed-booking-cancelled'), false);
    assert.equal(unlocked('seed-booking-completed-old'), false);
  });

  test('seed payments, ledger entries, and availability days match booking state', () => {
    const docs = seedDocuments(NOW);

    // Payments exist for bookings
    const acceptedPayment = docs.find((d) => d.path === 'payments/seed-payment-seed-booking-accepted');
    assert.ok(acceptedPayment);
    assert.equal((acceptedPayment.data as { escrowStatus: string }).escrowStatus, 'held');

    const completedPayment = docs.find((d) => d.path === 'payments/seed-payment-seed-booking-completed-recent');
    assert.ok(completedPayment);
    assert.equal((completedPayment.data as { escrowStatus: string }).escrowStatus, 'released');

    // Availability exists
    const anBookedDay = docs.find((d) => d.path === 'availability/seed-photographer-an/days/2026-10-20');
    assert.ok(anBookedDay);
    assert.equal((anBookedDay.data as { state: string }).state, 'booked');

    const binhPendingDay = docs.find((d) => d.path === 'availability/seed-photographer-binh/days/2026-10-25');
    assert.ok(binhPendingDay);
    assert.equal((binhPendingDay.data as { state: string }).state, 'pending');

    // Contact snapshot exists
    const contactSnap = docs.find((d) => d.path === 'bookings/seed-booking-accepted/private/contact');
    assert.ok(contactSnap);
    assert.equal((contactSnap.data as { phone: string }).phone, '+84903000001');
  });

  test('deterministic for a given clock', () => {
    assert.deepEqual(seedDocuments(NOW), seedDocuments(NOW));
  });
});
