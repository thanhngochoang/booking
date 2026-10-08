import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import type { Timestamp } from 'firebase-admin/firestore';
import { acceptsOrders, bookingContactUnlocked, computeDeposit, isId, isInternationalE164, isTicketCode, isVnE164, transferCodeFor } from '@photobooking/domain';
import {
  LAN,
  SEED_EVENT_SOON,
  SEED_PASSWORD,
  SEED_PHOTOGRAPHERS,
  SEED_REGISTRATION_LAN_SOON,
  SEED_USERS,
  seedDocuments,
} from '../../seed/fixtures.js';

const NOW = new Date('2026-10-01T12:00:00Z');

function bookingDoc(id: string): { status: string; timeline: { status: string; at: Date }[] } {
  const doc = seedDocuments(NOW).find((d) => d.path === `bookings/${id}`);
  if (doc === undefined) throw new Error(`no seed booking ${id}`);
  return doc.data as { status: string; timeline: { status: string; at: Date }[] };
}

describe('seed fixtures', () => {
  test('seed photographers carry acceptingOrders equal to the rule (An true, Bình false)', () => {
    const accepting = (uid: string) =>
      (seedDocuments(NOW).find((d) => d.path === `photographers/${uid}`)?.data as { acceptingOrders?: boolean }).acceptingOrders;
    for (const p of SEED_PHOTOGRAPHERS) {
      const doc = seedDocuments(NOW).find((d) => d.path === `photographers/${p.uid}`)?.data as Record<string, unknown>;
      assert.equal(doc.acceptingOrders, acceptsOrders(doc), p.uid);
    }
    assert.equal(accepting('seed-photographer-an'), true);
    assert.equal(accepting('seed-photographer-binh'), false);
  });

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

  test('money follows the up-front rule: the whole price is paid, nothing remains, integer VND', () => {
    for (const d of seedDocuments(NOW).filter((x) => x.path.startsWith('bookings/') && !x.path.includes('/private/'))) {
      const data = d.data as { service: { price: number }; deposit: { amount: number }; remaining: number };
      assert.equal(data.deposit.amount, computeDeposit(data.service.price).deposit, d.path);
      assert.equal(data.remaining, 0, d.path);
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

    // Booking payments look like createPayment's: bank QR with the code of their id, fully received.
    for (const d of docs.filter((x) => x.path.startsWith('payments/seed-payment-seed-booking-'))) {
      const pay = d.data as { method?: string; transferCode?: string; receivedAmount?: number; amount: number; expiresAt?: Date; createdAt: Date };
      assert.equal(pay.method, 'bank_qr', d.path);
      assert.equal(pay.transferCode, transferCodeFor(d.path.slice('payments/'.length)), d.path);
      assert.equal(pay.receivedAmount, pay.amount, d.path);
      assert.equal(pay.expiresAt?.getTime(), pay.createdAt.getTime() + 15 * 60_000, d.path);
    }

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

describe('seed notifications and badges', () => {
  const docs = seedDocuments(NOW);
  const unreadOf = (uid: string) =>
    docs.filter((d) => d.path.startsWith(`users/${uid}/notifications/`) && d.data.readAt === null).length;

  test('the stored unread count matches the unread rows', () => {
    for (const uid of ['seed-customer-lan', 'seed-photographer-an']) {
      const inbox = docs.find((d) => d.path === `users/${uid}/private/inbox`);
      assert.equal(inbox?.data.unreadCount, unreadOf(uid));
    }
    assert.equal(docs.filter((d) => d.path.startsWith('users/seed-customer-lan/notifications/')).length, 5);
    assert.equal(docs.filter((d) => d.path.startsWith('users/seed-photographer-an/notifications/')).length, 2);
  });

  test('the catalogue, earned badges and progress are seeded; no prefs doc', () => {
    assert.equal(docs.filter((d) => /^badges\/[^/]+$/.test(d.path)).length, 12);
    assert.ok(docs.some((d) => d.path === 'users/seed-photographer-an/badges/top_rated'));
    assert.ok(docs.some((d) => d.path === 'users/seed-customer-lan/badges/loyal_customer'));
    assert.deepEqual(
      (docs.find((d) => d.path === 'users/seed-photographer-an/private/badgeProgress')?.data.entries as Record<string, unknown>).punctual,
      { current: 3, target: 5 },
    );
    assert.equal(docs.some((d) => d.path.endsWith('/private/notification_prefs')), false);
  });
});

describe('seed payouts and earnings', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;

  test('An has an encrypted payout account and a masked view; Bình has none', () => {
    const view = get('payoutAccounts/seed-photographer-an');
    assert.equal(view?.accountLast4, '6789');
    assert.equal(view?.holderName, 'NGUYEN VAN AN');
    assert.equal('accountNumberEnc' in (view ?? {}), false);
    const stored = get('payoutAccounts/seed-photographer-an/accounts/seed-account-an-1');
    assert.match(String(stored?.accountNumberEnc), /^v1:/);
    assert.doesNotMatch(JSON.stringify(docs.filter((d) => d.path.startsWith('payoutAccounts/'))), /0123456789/);
    assert.equal(docs.some((d) => d.path.startsWith('payoutAccounts/seed-photographer-binh')), false);
  });

  test('the old completed payment is paid out in a paid payout with its ledger entry', () => {
    const pay = get('payments/seed-payment-seed-booking-completed-old');
    assert.equal(pay?.escrowStatus, 'paid_out');
    assert.equal(pay?.payoutId, 'seed-payout-an-1');
    const po = get('payouts/seed-payout-an-1');
    assert.equal(po?.status, 'paid');
    assert.equal(po?.amount, pay?.amount);
    const entry = get('ledger_entries/seed-ledger-seed-payout-an-1-pay');
    assert.equal(entry?.type, 'payout_paid');
    assert.equal(entry?.amount, -(pay?.amount as number));
  });

  test('the disputed booking holds its payment with the reason', () => {
    const pay = get('payments/seed-payment-seed-booking-disputed');
    assert.equal(pay?.escrowStatus, 'disputed');
    assert.equal((pay?.dispute as { reason: string }).reason, 'Ảnh giao thiếu so với gói');
    assert.equal(get('bookings/seed-booking-disputed')?.escrowStatus, 'disputed');
    const item = get('earnings/seed-photographer-an/items/seed-payment-seed-booking-disputed');
    assert.equal(item?.state, 'disputed');
    assert.equal(item?.holdReason, 'dispute');
  });

  test('the earnings projection equals the payments', () => {
    const e = get('earnings/seed-photographer-an');
    const dep = (price: number) => computeDeposit(price).deposit;
    // held: accepted + upcoming + disputed; soon: completed-recent; received: completed-old.
    assert.equal(e?.heldAmount, 3 * dep(1_500_000));
    assert.equal(e?.soonAmount, dep(1_500_000));
    assert.equal(e?.receivedAmount, dep(1_500_000));
    assert.equal((e?.lastPayout as { status: string }).status, 'paid');
    assert.equal(get('earnings/seed-photographer-an/items/seed-payment-seed-booking-completed-old')?.state, 'paid_out');
    assert.equal(get('earnings/seed-photographer-binh')?.heldAmount, dep(1_200_000));
  });
});

describe('seed event reminder (S17)', () => {
  test("SEED_EVENT_SOON starts 36 h after seeding, is open, has soonNoticeAt null and Lan's paid ticket", () => {
    const docs = seedDocuments(NOW);
    const get = (path: string) => docs.find((d) => d.path === path)?.data;
    const ev = get(`events/${SEED_EVENT_SOON}`);
    assert.ok(ev);
    assert.equal((ev.startAt as Timestamp).toMillis(), NOW.getTime() + 36 * 3_600_000);
    assert.equal(ev.status, 'open');
    assert.equal(ev.title, 'Chụp phố đêm');
    assert.equal(ev.type, 'photo_walk');
    assert.equal(ev.price, 0);
    assert.equal('soonNoticeAt' in ev, true);
    assert.equal(ev.soonNoticeAt, null);
    assert.equal(ev.registeredCount, 1);
    const reg = get(`events/${SEED_EVENT_SOON}/registrations/${SEED_REGISTRATION_LAN_SOON}`);
    assert.equal(reg?.userId, LAN);
    assert.equal(reg?.status, 'paid');
    assert.ok(isTicketCode(String(reg?.ticketCode)));
    assert.deepEqual(get(`ticket_codes/${String(reg?.ticketCode)}`), { eventId: SEED_EVENT_SOON, registrationId: SEED_REGISTRATION_LAN_SOON });
    // Every other seed event is still more than 48 hours away (only this one is reminded).
    for (const d of docs.filter((x) => /^events\/[^/]+$/.test(x.path) && x.path !== `events/${SEED_EVENT_SOON}`)) {
      assert.ok((d.data.startAt as Timestamp).toMillis() > NOW.getTime() + 48 * 3_600_000, d.path);
    }
  });

  test('every path is written once, even when an event day falls on a seed booking day', () => {
    // 36 h after this clock is 10 Oct in Vietnam, the day of seed-booking-upcoming.
    const docs = seedDocuments(new Date('2026-10-08T12:00:00Z'));
    const paths = docs.map((d) => d.path);
    assert.equal(new Set(paths).size, paths.length);
    const day = docs.find((d) => d.path === 'availability/seed-photographer-an/days/2026-10-10')?.data;
    assert.equal(day?.bookingId, 'seed-booking-upcoming');
  });
});
