import { describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import type { Timestamp } from 'firebase-admin/firestore';
import {
  acceptsOrders,
  addVerdict,
  assignSweepActionOf,
  foldNameKey,
  bookingContactUnlocked,
  computeDeposit,
  intensityOf,
  isId,
  isInquiryClosed,
  isInternationalE164,
  isTicketCode,
  isVnE164,
  MemoryNotificationStore,
  parseInstantConfig,
  MemoryPushSender,
  MemoryUserDirectory,
  mentionsPunctual,
  type NotificationRow,
  previewOf,
  reviewDocId,
  TOMATO_PCT_MIN_REVIEWS,
  transferCodeFor,
} from '@photobooking/domain';
import { fromFirestoreChat } from '../../src/infra/chat_firestore.js';
import { handleChatMessageCreated } from '../../src/triggers/chat_message_created.js';
import {
  AN,
  BINH,
  CUC,
  DUNG,
  HOA,
  LAN,
  MINH,
  ADMIN,
  SEED_ADDONS,
  SEED_CREATED_AT,
  SEED_EVENT_SOON,
  SEED_EVENT_PAST,
  SEED_BOOKING_COMPLETED_WINDOW,
  SEED_DISPUTE_LAN_AN,
  SEED_REGISTRATION_LAN_PAST,
  SEED_PASSWORD,
  SEED_INSTANT_CONFIG,
  SEED_PHOTOGRAPHERS,
  SEED_RECRUIT_POST_CUC,
  SEED_REGISTRATION_LAN_SOON,
  SEED_REVIEWS,
  SEED_USERS,
  SEED_STUDIO_ASSIGNED,
  SEED_STUDIO_UNASSIGNED,
  SEED_SPOT_CAU_DAT,
  SEED_SPOT_HOI_AN,
  SEED_SPOT_HO_TAY,
  SEED_SPOT_CAU_VANG,
  SEED_SPOT_MU_CANG_CHAI,
  SEED_SCHEDULE_AN_HO_TAY,
  SEED_OFFER_AN_BINH_MINH,
  seedDocuments,
} from '../../seed/fixtures.js';
import { bookingFromFirestore } from '../../src/infra/booking_firestore.js';
import { relationFromFirestore } from '../../src/infra/studio_firestore.js';
import {
  applicationFromDoc,
  collaborationFromDoc,
  countersFromDoc,
  recruitPostFromDoc,
} from '../../src/infra/recruit_mapping.js';
import { recruitFilterKeys, recruitMatchKeys, recruitMatchKeysOf } from '@photobooking/domain';

const NOW = new Date('2026-10-01T12:00:00Z');
/** A seeded time: a Date, or a Timestamp when the doc comes from a src/infra mapper. */
const millis = (v: unknown): number => (v instanceof Date ? v.getTime() : (v as Timestamp).toMillis());

function bookingDoc(id: string): { status: string; timeline: { status: string; at: Date }[] } {
  const doc = seedDocuments(NOW).find((d) => d.path === `bookings/${id}`);
  if (doc === undefined) throw new Error(`no seed booking ${id}`);
  return doc.data as { status: string; timeline: { status: string; at: Date }[] };
}

describe('seed fixtures', () => {
  test('seed has a valid instant config', () => {
    const doc = seedDocuments(NOW).find((d) => d.path === 'instant_config/current');
    assert.ok(doc !== undefined);
    const cfg = parseInstantConfig(doc.data);
    assert.equal(cfg.enabled, true);
    assert.equal(cfg.priceListVersion, 1);
    assert.equal(cfg.platformFeeBp, 0);
    assert.equal(cfg.instantArrivedCancelPhotographerPercent, 50);
    assert.deepEqual(cfg.packages.map((p) => [p.code, p.durationMin, p.photos, p.priceVnd]), [
      ['p30', 30, 15, 390_000], ['p60', 60, 30, 690_000], ['p120', 120, 60, 1_190_000],
    ]);
    assert.deepEqual(cfg.cities.map((c) => c.id), ['hcm', 'hn', 'dn']);
    assert.equal(cfg.areas.length, 12);
    assert.equal(SEED_INSTANT_CONFIG.areas[0]?.name, 'Quận 1, TP.HCM');
  });

  test('instant config areas are the built-in areas of the app (names and centres)', () => {
    const dart = readFileSync(new URL('../../../../lib/data/location/area.dart', import.meta.url), 'utf8');
    const list = dart.slice(dart.indexOf('builtInAreas'));
    const areas = [...list.matchAll(/name:\s*'([^']+)',\s*lat:\s*([\d.]+),\s*lng:\s*([\d.]+)/g)].map((m) => ({
      name: m[1],
      lat: Number(m[2]),
      lng: Number(m[3]),
    }));
    assert.deepEqual(SEED_INSTANT_CONFIG.areas, areas);
  });

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

  test('An has three add-ons (makeup per_person, retouch per_item, transport per_booking only for seed-service-portrait) and Cúc one studio add-on; private/addons activeCount matches', () => {
    const docs = seedDocuments(NOW);
    const addonDocs = (uid: string) =>
      docs.filter((d) => d.path.startsWith(`photographers/${uid}/addons/`)).map((d): Record<string, unknown> => ({ id: d.path.split('/').pop(), ...(d.data as Record<string, unknown>) }));
    const an = addonDocs(AN);
    assert.deepEqual(an.map((a) => [a.id, a.kind, a.unit]), [
      ['seed-addon-makeup', 'makeup', 'per_person'],
      ['seed-addon-retouch', 'retouch', 'per_item'],
      ['seed-addon-car', 'transport', 'per_booking'],
    ]);
    assert.deepEqual(an.find((a) => a.id === 'seed-addon-car')?.serviceIds, ['seed-service-portrait']);
    assert.deepEqual(an.find((a) => a.id === 'seed-addon-makeup')?.serviceIds, []);
    assert.equal(an.find((a) => a.id === 'seed-addon-makeup')?.price, 800_000);
    const cuc = addonDocs(CUC);
    assert.deepEqual(cuc.map((a) => [a.id, a.kind, a.unit, a.price, a.maxQty]), [['seed-addon-outfit', 'outfit', 'per_item', 250_000, 4]]);
    for (const [uid, list] of [[AN, an], [CUC, cuc]] as const) {
      const lock = docs.find((d) => d.path === `photographers/${uid}/private/addons`)?.data as { activeCount: number };
      assert.equal(lock.activeCount, list.filter((a) => a.active === true).length, uid);
    }
    assert.equal(SEED_ADDONS.length, 4);
    for (const a of SEED_ADDONS) assert.ok(a.price >= 10_000 && a.price <= 50_000_000, a.id);
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
    for (const d of seedDocuments(NOW).filter((x) => /^bookings\/[^/]+$/.test(x.path))) {
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
      const pay = d.data as {
        method?: string;
        transferCode?: string;
        receivedAmount?: number;
        amount: number;
        expiresAt?: Date;
        createdAt: Date;
        payer?: { accountNumberEnc?: string; accountLast4?: string; holderName?: string };
        refundedAmount?: number;
      };
      assert.equal(pay.method, 'bank_qr', d.path);
      assert.equal(pay.transferCode, transferCodeFor(d.path.slice('payments/'.length)), d.path);
      assert.equal(pay.receivedAmount, pay.amount, d.path);
      assert.equal(pay.expiresAt?.getTime(), pay.createdAt.getTime() + 15 * 60_000, d.path);
      assert.match(String(pay.payer?.accountNumberEnc), /^v1:/, d.path);
      assert.equal(pay.payer?.accountLast4, '3456', d.path);
      assert.equal(pay.payer?.holderName, 'KHACH THU NGHIEM', d.path);
      assert.equal(typeof pay.refundedAmount, 'number', d.path);
    }

    // Cancelled seed refund is done, bank_transfer, to the seed payer
    const cancelledRefund = docs.find((d) => d.path === 'refunds/seed-refund-seed-booking-cancelled');
    assert.ok(cancelledRefund);
    const rData = cancelledRefund.data as {
      status?: string;
      method?: string;
      destination?: { accountLast4?: string; holderName?: string; source?: string; accountNumberEnc?: string };
      attempts?: number;
    };
    assert.equal(rData.status, 'done');
    assert.equal(rData.method, 'bank_transfer');
    assert.equal(rData.destination?.source, 'payer');
    assert.equal(rData.destination?.accountLast4, '3456');
    assert.equal(rData.destination?.holderName, 'KHACH THU NGHIEM');
    assert.match(String(rData.destination?.accountNumberEnc), /^v1:/);
    assert.equal(rData.attempts, 1);

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
    for (const uid of ['seed-customer-lan', 'seed-photographer-an', 'seed-photographer-cuc', 'seed-photographer-dung']) {
      const inbox = docs.find((d) => d.path === `users/${uid}/private/inbox`);
      assert.equal(inbox?.data.unreadCount, unreadOf(uid));
    }
    assert.equal(docs.filter((d) => d.path.startsWith('users/seed-customer-lan/notifications/')).length, 6);
    assert.equal(docs.filter((d) => d.path.startsWith('users/seed-photographer-an/notifications/')).length, 3);
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

  test("Lan's badge progress equals what the evaluator computes from the seeded reviews and posts", () => {
    const lan = LAN;
    const graphemes = (t: string) =>
      Array.from(new Intl.Segmenter('vi', { granularity: 'grapheme' }).segment(t.trim())).length;
    const detailed = SEED_REVIEWS.filter((r) => r.customerId === lan && graphemes(r.text) >= 50).length;
    const shared = docs.filter(
      (d) => d.path.startsWith('posts/') && d.data.authorId === lan && d.data.kind === 'real_shoot',
    ).length;
    const entries = docs.find((d) => d.path === `users/${lan}/private/badgeProgress`)?.data.entries as Record<string, unknown>;
    assert.equal(detailed, 3);
    assert.deepEqual(entries.detailed_reviewer, { current: detailed, target: 5 });
    assert.deepEqual(entries.sharer, { current: shared, target: 5 });
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
    assert.equal(entry?.amount, -(po?.amountNet as number));
  });

  // The brief's 450,000 → 31,500 / 418,500 predates #129 (customers now pay 100% up front): the
  // seeded payment is the full 1,500,000 price, so 7% is 105,000 and the net 1,395,000.
  test("An's seeded payout has tax 105,000 and net 1,395,000 with a tax_withheld ledger entry", () => {
    const po = get('payouts/seed-payout-an-1');
    // An is an individual: 7% of the 1,500,000 payment is withheld; the gross amount stays.
    assert.equal(po?.amount, 1_500_000);
    assert.equal(po?.taxWithheld, 105_000);
    assert.equal(po?.platformFee, 0);
    assert.equal(po?.amountNet, 1_395_000);
    assert.equal(po?.taxRateBp, 700);
    assert.equal(po?.feeRateBp, 0);
    assert.equal(po?.firstPayout, true);
    assert.equal(po?.approvedBy, ADMIN);
    assert.equal(po?.idempotencyKey, 'seed-payout-an-1');
    assert.equal(po?.provider, 'fake');
    assert.deepEqual(po?.items, [
      { paymentId: 'seed-payment-seed-booking-completed-old', amount: 1_500_000, fee: 0, tax: 105_000, net: 1_395_000 },
    ]);
    const pay = get('ledger_entries/seed-ledger-seed-payout-an-1-pay');
    const tax = get('ledger_entries/seed-ledger-seed-payout-an-1-tax');
    assert.equal(pay?.amount, -1_395_000);
    assert.equal(tax?.type, 'tax_withheld');
    assert.equal(tax?.amount, -105_000);
    assert.equal(tax?.payoutId, 'seed-payout-an-1');
    assert.equal(tax?.paymentId, 'seed-payment-seed-booking-completed-old');
    // Per payment the payout entries net to -amount.
    assert.equal((pay?.amount as number) + (tax?.amount as number), -1_500_000);
    assert.equal(get('ledger_entries/seed-ledger-seed-payout-an-1-fee'), undefined);
    const row = get('earnings/seed-photographer-an/items/seed-payment-seed-booking-completed-old');
    assert.equal(row?.amount, 1_500_000);
    assert.equal(row?.taxWithheld, 105_000);
    assert.equal(row?.netAmount, 1_395_000);
    assert.equal(row?.estimated, false);
  });

  test("An's account is matched and active from SEED_CREATED_AT", () => {
    const stored = get('payoutAccounts/seed-photographer-an/accounts/seed-account-an-1');
    const view = get('payoutAccounts/seed-photographer-an');
    assert.equal(stored?.nameStatus, 'matched');
    assert.equal(view?.nameStatus, 'matched');
    assert.equal(millis(stored?.activeFrom), SEED_CREATED_AT.getTime());
    assert.equal(millis(view?.activeFrom), SEED_CREATED_AT.getTime());
  });

  test('An has an identity legalName', () => {
    const identity = get('users/seed-photographer-an/private/identity');
    assert.equal(identity?.legalName, 'Nguyễn Văn An');
    assert.equal(identity?.method, 'fake');
    assert.equal(identity?.provider, 'fake');
    assert.equal(millis(identity?.verifiedAt), SEED_CREATED_AT.getTime());
  });

  test('the disputed booking holds its payment with the reason', () => {
    const pay = get('payments/seed-payment-seed-booking-disputed');
    assert.equal(pay?.escrowStatus, 'disputed');
    // S18 (#142): the reason is the dispute's code; the customer's words are the dispute's description.
    assert.equal((pay?.dispute as { reason: string }).reason, 'photos_missing');
    assert.equal(get('bookings/seed-booking-disputed')?.escrowStatus, 'disputed');
    const item = get('earnings/seed-photographer-an/items/seed-payment-seed-booking-disputed');
    assert.equal(item?.state, 'disputed');
    assert.equal(item?.holdReason, 'dispute');
  });

  test('the earnings projection equals the payments', () => {
    const e = get('earnings/seed-photographer-an');
    const dep = (price: number) => computeDeposit(price).deposit;
    // An has:
    // - Legacy bookings: accepted (held 1.5m), upcoming (held 1.5m), disputed (held 1.5m), completed-window (held 1.5m, S18), completed-recent (soon 1.5m), completed-old (received 1.5m)
    // - Delivery milestone bookings (1.5m deposit each, 750k shoot / 750k delivery):
    //   - shot: shoot held (750k), delivery held (750k) -> held 1.5m
    //   - delivered: shoot released (soon 750k), delivery held (750k) -> held 750k, soon 750k
    //   - revision_requested: shoot released (soon 750k), delivery held (750k) -> held 750k, soon 750k
    //   - approved: shoot released (soon 750k), delivery released (soon 750k) -> soon 1.5m
    // - Lan's paid ticket of the past workshop (S18): held 250k until the end + 24 h
    // Total held = 1.5m * 4 + 1.5m (shot) + 750k (delivered) + 750k (revision) + 250k (ticket) = 9.25m
    // Total soon = 1.5m (recent) + 750k (delivered) + 750k (revision) + 1.5m (approved) = 4.5m
    // Total received = 1.5m (completed-old)
    assert.equal(e?.heldAmount, 9_250_000);
    const ticket = get('earnings/seed-photographer-an/items/seed-payment-ticket-lan-past');
    assert.equal(ticket?.state, 'held');
    assert.equal(ticket?.amount, 250_000);
    assert.equal(ticket?.counterpartName, 'Lan (seed)');
    assert.equal(e?.soonAmount, 4_500_000);
    assert.equal(e?.receivedAmount, dep(1_500_000));
    assert.equal((e?.lastPayout as { status: string }).status, 'paid');
    assert.equal(get('earnings/seed-photographer-an/items/seed-payment-seed-booking-completed-old')?.state, 'paid_out');
    assert.equal(get('earnings/seed-photographer-binh')?.heldAmount, dep(1_200_000));
  });

  test('seed has bookings in shot, delivered (round 1, 3 ready samples), revision_requested, approved with milestone payments', () => {
    const docs = seedDocuments(NOW);
    const shot = docs.find((d) => d.path === 'bookings/seed-booking-shot')?.data;
    assert.ok(shot);
    assert.equal(shot.status, 'shot');

    const delivered = docs.find((d) => d.path === 'bookings/seed-booking-delivered')?.data;
    assert.ok(delivered);
    assert.equal(delivered.status, 'delivered');
    assert.equal(delivered.deliveryRound, 1);
    const round1 = docs.find((d) => d.path === 'bookings/seed-booking-delivered/deliveries/1')?.data;
    assert.ok(round1);
    assert.equal((round1.samples as unknown[]).length, 3);

    const revision = docs.find((d) => d.path === 'bookings/seed-booking-revision')?.data;
    assert.ok(revision);
    assert.equal(revision.status, 'revision_requested');

    const approved = docs.find((d) => d.path === 'bookings/seed-booking-approved')?.data;
    assert.ok(approved);
    assert.equal(approved.status, 'approved');
    const privateDelivery = docs.find((d) => d.path === 'bookings/seed-booking-approved/private/delivery')?.data;
    assert.ok(privateDelivery);
    assert.ok(privateDelivery.unlockedAt !== null);

    const payApproved = docs.find((d) => d.path === 'payments/seed-payment-seed-booking-approved')?.data;
    assert.ok(payApproved);
    assert.equal(payApproved.payableAmount, 1_500_000);
    const shootMilestone = docs.find((d) => d.path === 'bookings/seed-booking-approved/milestones/shoot')?.data;
    assert.equal(shootMilestone?.status, 'released');
    const deliveryMilestone = docs.find((d) => d.path === 'bookings/seed-booking-approved/milestones/delivery')?.data;
    assert.equal(deliveryMilestone?.status, 'released');
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
    // (The S18 past workshop has already ended: no reminder either.)
    for (const d of docs.filter((x) => /^events\/[^/]+$/.test(x.path) && x.path !== `events/${SEED_EVENT_SOON}` && x.path !== `events/${SEED_EVENT_PAST}`)) {
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

describe('seed reviews (tomato/brick)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;
  const reviewsOf = (uid: string): (Record<string, unknown> & { id: string })[] =>
    docs
      .filter((d) => /^reviews\/[^/]+$/.test(d.path) && d.data.subjectId === uid)
      .map((d) => ({ ...d.data, id: d.path.slice('reviews/'.length) }));
  const statsOf = (uid: string) => get(`photographers/${uid}`)?.stats as Record<string, unknown> | undefined;
  const fold = (uid: string) =>
    reviewsOf(uid).reduce<Record<string, unknown>>(
      (acc, r) => ({ ...addVerdict(acc, r.verdict as 'tomato' | 'brick', r.intensity as number, mentionsPunctual(String(r.text))) }),
      {},
    );

  test("An's stats are 56 tomato and 2 brick (97%) and his seeded reviews are verdict docs", () => {
    assert.deepEqual(statsOf(AN), {
      reviewCount: 58,
      tomatoCount: 56,
      brickCount: 2,
      signedSum: 54.62,
      tomatoPct: 97,
      score: 0.942,
      punctualMentions: 3,
      nextFreeDate: '2026-09-01',
      // recent, old, disputed and (S18) the completed-window booking.
      completedCount: 4,
    });
    const an = reviewsOf(AN);
    assert.deepEqual(an.map((r) => r.id).sort(), ['seed-review-an-1', 'seed-review-an-2', 'seed-review-an-3']);
    assert.deepEqual(an.map((r) => `${String(r.verdict)}×${String(r.hits)}`).sort(), ['brick×3', 'tomato×10', 'tomato×6']);
    const brick = an.find((r) => r.verdict === 'brick');
    assert.deepEqual(brick?.reasons, ['late', 'slow_delivery']);
    const topRated = get(`users/${AN}/badges/top_rated`)?.snapshot as { text: string } | undefined;
    assert.equal(topRated?.text, '97% cà chua từ 58 đánh giá');
  });

  test('every seeded review is a counted verdict doc keyed by reviewDocId', () => {
    const all = docs.filter((d) => /^reviews\/[^/]+$/.test(d.path));
    assert.equal(all.length, 12);
    for (const d of all) {
      const r = d.data;
      assert.equal(d.path, `reviews/${reviewDocId(String(r.bookingId), 'photographer')}`);
      assert.equal(r.subjectType, 'photographer');
      assert.equal(r.photographerId, r.subjectId, d.path);
      assert.equal(r.intensity, intensityOf(r.hits as number), d.path);
      assert.ok(r.countedAt instanceof Date, `${d.path} is born counted: the trigger neither recounts nor notifies`);
      assert.match(String(r.bookingDay), /^\d{4}-\d{2}-\d{2}$/);
      assert.ok(String(r.serviceName).length > 0);
      assert.ok([LAN, 'seed-customer-minh'].includes(String(r.customerId)), d.path);
      if (r.verdict === 'tomato') assert.deepEqual(r.reasons, [], d.path);
    }
    // Lan can still review the recent shoot.
    assert.equal(get('reviews/seed-booking-completed-recent'), undefined);
  });

  test('Cúc has 3 reviews and no tomatoPct shown (under 5)', () => {
    const cuc = reviewsOf(CUC);
    assert.equal(cuc.length, 3);
    assert.ok(cuc.every((r) => r.verdict === 'tomato'));
    assert.deepEqual(statsOf(CUC), {
      ...fold(CUC),
      nextFreeDate: '2026-09-01',
      completedCount: 0,
    });
    assert.equal(statsOf(CUC)?.reviewCount, 3);
    assert.ok((statsOf(CUC)?.reviewCount as number) < TOMATO_PCT_MIN_REVIEWS);
  });

  test('Dũng has 6 reviews with 3 bricks, each brick with a reason', () => {
    const dung = reviewsOf(DUNG);
    assert.equal(dung.length, 6);
    const bricks = dung.filter((r) => r.verdict === 'brick');
    assert.equal(bricks.length, 3);
    for (const b of bricks) assert.ok(Array.isArray(b.reasons) && b.reasons.length > 0, b.id);
    assert.deepEqual(statsOf(DUNG), {
      ...fold(DUNG),
      nextFreeDate: '2026-09-01',
      completedCount: 0,
    });
    assert.equal(statsOf(DUNG)?.tomatoPct, 50);
  });

  test('no seed doc carries rating', () => {
    const keys = (v: unknown): string[] =>
      v !== null && typeof v === 'object' && !(v instanceof Date)
        ? Object.entries(v as Record<string, unknown>).flatMap(([k, x]) => [k, ...keys(x)])
        : [];
    for (const d of docs) {
      const k = keys(d.data);
      assert.equal(k.includes('rating'), false, d.path);
      assert.equal(k.includes('ratingSum'), false, d.path);
    }
  });

  test('the seed inbox review row uses the verdict payload', () => {
    const rows = docs.filter((d) => d.path.startsWith(`users/${AN}/notifications/`));
    assert.equal(rows.some((d) => d.data.type === 'review_new'), false);
    const row = rows.find((d) => d.data.type === 'review_tomato');
    assert.ok(row);
    assert.equal(row.data.title, 'Bạn nhận 🍅 ×7 từ buổi chụp CN 27/9');
    assert.equal(row.data.body, '“Rất hài lòng, đúng giờ.”');
    assert.equal(row.data.target, `/u/${AN}?tab=reviews`);
    assert.equal(row.data.category, 'badges');
    assert.equal(row.data.tab, 'system');
    // Not the dedupe id of a real notice for the unreviewed recent shoot (Lan can still review it).
    assert.notEqual(row.path, `users/${AN}/notifications/n_review_tomato_seed-booking-completed-recent_${AN}`);
  });

  test('seed has a booking chat with bookingStatus equal to its booking', () => {
    const chat = docs.find((d) => d.path === `chats/${LAN}_${AN}`)?.data;
    assert.ok(chat);
    assert.equal(chat.kind, 'booking');
    assert.equal(chat.bookingId, 'seed-booking-upcoming');
    assert.equal(chat.bookingStatus, bookingDoc('seed-booking-upcoming').status);
    assert.deepEqual(chat.members, [LAN, AN]);
    const messages = docs.filter((d) => d.path.startsWith(`chats/${LAN}_${AN}/messages/`));
    assert.equal(messages.length, 3);
    assert.ok(messages.every((m) => m.data.type === 'text'));
    assert.equal(chat.lastSenderId, AN);
    const last = messages[messages.length - 1]?.data;
    assert.equal(chat.lastMessagePreview, previewOf({ type: 'text', body: last?.body as string }));
    assert.equal(last?.senderId, AN);
  });

  test('a closed inquiry older than 14 days', () => {
    const doc = docs.find((d) => d.path === `chats/${LAN}_${CUC}`)?.data;
    assert.ok(doc);
    assert.equal(doc.kind, 'inquiry');
    assert.equal(doc.bookingStatus, null);
    const chat = fromFirestoreChat(`${LAN}_${CUC}`, doc);
    assert.equal(isInquiryClosed(chat, NOW), true);
    assert.equal(docs.filter((d) => d.path.startsWith(`chats/${LAN}_${CUC}/messages/`)).length, 2);
    assert.equal(NOW.getTime() - (chat.lastMessageAt as Date).getTime(), 20 * 86_400_000);
  });

  test('an open inquiry with one unread message for the photographer', () => {
    const doc = docs.find((d) => d.path === `chats/${MINH}_${DUNG}`)?.data;
    assert.ok(doc);
    const chat = fromFirestoreChat(`${MINH}_${DUNG}`, doc);
    assert.equal(chat.kind, 'inquiry');
    assert.equal(chat.lastSenderId, MINH);
    assert.equal(isInquiryClosed(chat, NOW), false);
    assert.equal(docs.filter((d) => d.path.startsWith(`chats/${MINH}_${DUNG}/messages/`)).length, 1);
    const unread = (uid: string) =>
      docs.find((d) => d.path === `chats/${MINH}_${DUNG}/members/${uid}`)?.data.unreadCount;
    assert.equal(unread(DUNG), 1);
    assert.equal(unread(MINH), 0);
  });

  test('members docs with unreadCount for both sides', () => {
    for (const [cid, pid, lan, an] of [
      [LAN, AN, 2, 0],
      [LAN, CUC, 0, 0],
      [MINH, DUNG, 0, 1],
    ] as const) {
      const id = `${cid}_${pid}`;
      const customer = docs.find((d) => d.path === `chats/${id}/members/${cid}`)?.data;
      const provider = docs.find((d) => d.path === `chats/${id}/members/${pid}`)?.data;
      assert.ok(customer && provider, id);
      assert.equal(customer.unreadCount, lan, `${id} customer`);
      assert.equal(provider.unreadCount, an, `${id} photographer`);
    }
  });
});

describe('seed chats and the inbox', () => {
  // applySeed writes the chat messages with the Admin SDK, so onChatMessageCreated runs for each of
  // them after the seed returns. The seeded inbox must already hold what those runs would write, or
  // they add rows and counts later (a chat row for a 20-day-old message; Lan's 2 unread becoming 4).
  test('replaying onChatMessageCreated over the seeded messages writes nothing', async () => {
    const docs = seedDocuments(NOW);
    const store = new MemoryNotificationStore();
    for (const d of docs) {
      const m = /^users\/([^/]+)\/notifications\/([^/]+)$/.exec(d.path);
      if (m === null) continue;
      const row = { id: m[2], userId: m[1], ...d.data } as unknown as NotificationRow;
      store.rows.set(`${row.userId}/${row.id}`, row);
    }
    const users = new MemoryUserDirectory();
    for (const u of SEED_USERS) users.users.set(u.uid, { name: u.displayName, avatarUrl: null });
    const push = new MemoryPushSender();
    const deps = { store, push, users, clock: { now: () => NOW } };
    let replayed = 0;
    for (const d of docs) {
      const m = /^chats\/([^/]+)\/messages\/([^/]+)$/.exec(d.path);
      if (m === null) continue;
      const chat = docs.find((c) => c.path === `chats/${m[1]}`)?.data;
      if (chat?.kind === 'event_group') continue;
      await handleChatMessageCreated(
        { chatId: m[1] as string, messageId: m[2] as string, message: d.data, members: chat?.members as string[] },
        deps,
      );
      replayed += 1;
    }
    assert.equal(replayed, 6);
    assert.equal(store.writes, 0, [...store.rows.values()].filter((r) => r.createdAt === NOW).map((r) => `${r.userId}/${r.id}`).join(', '));
    assert.equal(push.sent.length, 0);
  });

  test('chat rows match the members unread counts', () => {
    const docs = seedDocuments(NOW);
    for (const d of docs) {
      const m = /^chats\/([^/]+)\/members\/([^/]+)$/.exec(d.path);
      if (m === null || !(m[1] as string).includes('_') || (m[1] as string).startsWith('event_')) continue;
      const row = docs.find((r) => r.path === `users/${m[2]}/notifications/g_chat_${m[1]}`)?.data;
      const unread = d.data.unreadCount as number;
      if (unread > 0) {
        assert.equal(row?.readAt, null, `${d.path} unread row`);
        assert.equal(row?.count, unread, `${d.path} count`);
      } else {
        assert.ok(row === undefined || row.readAt !== null, `${d.path} has no unread row`);
      }
    }
  });

  test('seed follows give An followerCount 2 and Dũng 1, equal to the follows', () => {
    const docs = seedDocuments(NOW);
    const follows = docs.filter((d) => d.path.startsWith('follows/'));
    const anFollows = follows.filter((d) => (d.data as { photographerId: string }).photographerId === 'seed-photographer-an');
    const dungFollows = follows.filter((d) => (d.data as { photographerId: string }).photographerId === 'seed-photographer-dung');

    const anDoc = docs.find((d) => d.path === 'photographers/seed-photographer-an')?.data as Record<string, unknown>;
    const dungDoc = docs.find((d) => d.path === 'photographers/seed-photographer-dung')?.data as Record<string, unknown>;

    assert.equal(anFollows.length, 2);
    assert.equal(dungFollows.length, 1);
    assert.equal(anDoc.followerCount, anFollows.length);
    assert.equal(dungDoc.followerCount, dungFollows.length);
    assert.ok(anDoc.followerCountAt instanceof Date);
    assert.ok(dungDoc.followerCountAt instanceof Date);
  });

  test('Lan has saved posts seed-post-an-1, -2 and saved photographer Cúc', () => {
    const docs = seedDocuments(NOW);
    const lanSaves = docs.filter(
      (d) => d.path.startsWith('saves/') && (d.data as { userId: string }).userId === 'seed-customer-lan',
    );
    const lanSavedPosts = lanSaves.map((d) => (d.data as { postId: string }).postId).sort();
    assert.deepEqual(lanSavedPosts, ['seed-post-an-1', 'seed-post-an-2']);

    const lanSavedPhotographers = docs.filter(
      (d) => d.path.startsWith('savedPhotographers/') && (d.data as { userId: string }).userId === 'seed-customer-lan',
    );
    assert.equal(lanSavedPhotographers.length, 1);
    const lanSavedPhotographer = lanSavedPhotographers[0];
    assert.ok(lanSavedPhotographer);
    assert.equal((lanSavedPhotographer.data as { photographerId: string }).photographerId, 'seed-photographer-cuc');
  });
});

describe('seed discovery stats (S02)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;

  test('seed photographers carry nextFreeDate, startingPrice and completedCount from the domain rules', () => {
    const an = get(`photographers/${AN}`);
    assert.ok(an);
    assert.equal(an.startingPrice, 1_500_000);
    const anStats = an.stats as Record<string, unknown>;
    assert.equal(anStats.completedCount, 4);
    assert.ok(typeof anStats.nextFreeDate === 'string');
    assert.match(anStats.nextFreeDate as string, /^\d{4}-\d{2}-\d{2}$/);
    assert.equal(anStats.reviewCount, 58);
    assert.equal(anStats.score, 0.942);

    const binh = get(`photographers/${BINH}`);
    assert.ok(binh);
    assert.equal(binh.startingPrice, 1_200_000);
    const binhStats = binh.stats as Record<string, unknown>;
    assert.equal(binhStats.completedCount, 0);
    assert.ok(typeof binhStats.nextFreeDate === 'string');
    assert.equal(binhStats.reviewCount, 0);
    assert.equal(binhStats.score, 0);

    const cuc = get(`photographers/${CUC}`);
    assert.ok(cuc);
    // Cúc's studio package (S26 seed, #136).
    assert.equal(cuc.startingPrice, 2_500_000);
    const cucStats = cuc.stats as Record<string, unknown>;
    assert.equal(cucStats.completedCount, 0);
    assert.ok(typeof cucStats.nextFreeDate === 'string');

    const dung = get(`photographers/${DUNG}`);
    assert.ok(dung);
    assert.equal(dung.startingPrice, null);
    const dungStats = dung.stats as Record<string, unknown>;
    assert.equal(dungStats.completedCount, 0);
    assert.ok(typeof dungStats.nextFreeDate === 'string');
  });

  test('seed posts carry likeCount and saveCount equal to their seeded markers', () => {
    const post1 = get('posts/seed-post-an-1');
    assert.ok(post1);
    assert.equal(post1.likeCount, 2);
    assert.equal(post1.saveCount, 1);

    const post2 = get('posts/seed-post-an-2');
    assert.ok(post2);
    assert.equal(post2.likeCount, 0);
    assert.equal(post2.saveCount, 1);

    const likes = docs.filter((d) => d.path.startsWith('likes/'));
    assert.equal(likes.length, 2);
  });

  test('catalog/explore matches the seeded services', () => {
    const explore = get('catalog/explore') as { specialties: Record<string, { serviceCount: number }> } | undefined;
    assert.ok(explore);
    assert.equal(explore.specialties.portrait?.serviceCount, 1);
    assert.equal(explore.specialties.family?.serviceCount, 1);
  });

  test('Minh has blocked Bình (record and both indexes)', () => {
    const blockDoc = get(`blocks/${MINH}_${BINH}`);
    assert.ok(blockDoc);
    assert.equal(blockDoc.blockerId, MINH);
    assert.equal(blockDoc.blockedId, BINH);
    assert.equal(blockDoc.source, 'menu');

    const minhIdx = get(`users/${MINH}/private/blocks`) as { blockedIds: string[]; blockedByIds: string[] } | undefined;
    assert.ok(minhIdx);
    assert.deepEqual(minhIdx.blockedIds, [BINH]);
    assert.deepEqual(minhIdx.blockedByIds, []);

    const binhIdx = get(`users/${BINH}/private/blocks`) as { blockedIds: string[]; blockedByIds: string[] } | undefined;
    assert.ok(binhIdx);
    assert.deepEqual(binhIdx.blockedIds, []);
    assert.deepEqual(binhIdx.blockedByIds, [MINH]);
  });

  test('one open report by Lan on seed-post-an-5', () => {
    const rep = get(`reports/${LAN}_post_seed-post-an-5`);
    assert.ok(rep);
    assert.equal(rep.reporterId, LAN);
    assert.equal(rep.targetType, 'post');
    assert.equal(rep.targetId, 'seed-post-an-5');
    assert.equal(rep.targetOwnerId, AN);
    assert.equal(rep.status, 'open');
  });
});


describe('seed studio (S26, #136)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;

  test('Cúc is a verified studio with one member, An, active since 30 days', () => {
    const cuc = get(`photographers/${CUC}`);
    assert.equal(cuc?.providerType, 'studio');
    assert.equal(cuc?.verified, true);
    assert.equal(cuc?.memberCount, 1);
    assert.equal(cuc?.assignableMembers, 1);
    const an = get(`photographers/${AN}`);
    assert.equal(an?.studioId, CUC);
    assert.equal(millis(an?.studioJoinedAt), NOW.getTime() - 30 * 86_400_000);
  });

  test('relations: An active, Bình invited (expires in 5 days), Dũng requested', () => {
    const rels = docs
      .filter((d) => d.path.startsWith('studio_members/'))
      .map((d) => relationFromFirestore(d.path.slice('studio_members/'.length), d.data));
    const of = (uid: string) => rels.find((r) => r?.memberId === uid);
    assert.equal(rels.length, 3);
    for (const r of rels) {
      assert.ok(r);
      assert.equal(r.studioId, CUC);
      assert.match(r.id, new RegExp(`^${CUC}_${r.memberId}_\\d+$`));
      assert.equal(r.expiringNotifiedAt, null);
    }
    assert.equal(of(AN)?.status, 'active');
    assert.equal(of(BINH)?.status, 'invited');
    assert.equal(Date.parse(of(BINH)?.expiresAt ?? ''), NOW.getTime() + 5 * 86_400_000);
    assert.equal(of(DUNG)?.status, 'requested');
    assert.equal(of(DUNG)?.initiatedBy, 'member');
  });

  test('every seeded photographer carries its nameKey', () => {
    for (const p of SEED_PHOTOGRAPHERS) {
      const name = SEED_USERS.find((u) => u.uid === p.uid)?.displayName ?? '';
      assert.equal(get(`photographers/${p.uid}`)?.nameKey, foldNameKey(name), p.uid);
    }
  });

  test('studio bookings: assigned to An (An\'s day booked) and unassigned past its deadline', () => {
    const assigned = bookingFromFirestore(SEED_STUDIO_ASSIGNED, get(`bookings/${SEED_STUDIO_ASSIGNED}`));
    assert.ok(assigned);
    assert.equal(assigned.isStudio, true);
    assert.equal(assigned.assigneeId, AN);
    assert.equal(assigned.assignStatus, 'assigned');
    assert.equal(assigned.status, 'accepted');
    assert.equal(get(`availability/${AN}/days/${assigned.day}`)?.bookingId, SEED_STUDIO_ASSIGNED);
    assert.equal(get(`availability/${CUC}/days/${assigned.day}`)?.state, 'full', 'its one member is taken');

    const unassigned = bookingFromFirestore(SEED_STUDIO_UNASSIGNED, get(`bookings/${SEED_STUDIO_UNASSIGNED}`));
    assert.ok(unassigned);
    assert.equal(unassigned.assignStatus, 'unassigned');
    assert.equal(unassigned.assigneeId, null);
    // The first bookingClock after seeding marks it overdue (the customer gains the 100% cancel right).
    assert.deepEqual(assignSweepActionOf(unassigned, NOW), { kind: 'overdue', notify: true });

    const loads = docs.filter((d) => d.path.startsWith(`studio_day_load/${CUC}_`)).map((d) => d.data);
    assert.deepEqual(
      loads.map((l) => [l.day, l.unassignedIds, l.assignedIds]).sort(),
      [[assigned.day, [], [SEED_STUDIO_ASSIGNED]], [unassigned.day, [SEED_STUDIO_UNASSIGNED], []]].sort(),
    );
    // A studio booking never writes the studio's own day as booked or pending.
    for (const d of docs.filter((x) => x.path.startsWith(`availability/${CUC}/days/`))) assert.equal(d.data.state, 'full');
  });
});
describe('seed photo spots (S29)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data as Record<string, unknown> | undefined;

  test('five spots: Đồi chè Cầu Đất (da-lat, 10–12), Phố cổ Hội An (hoi-an), Hồ Tây (hn), Cầu Vàng (dn), Mù Cang Chải (yen-bai, 9–10), all active', () => {
    const cauDat = get(`spots/${SEED_SPOT_CAU_DAT}`);
    assert.ok(cauDat);
    assert.equal(cauDat.name, 'Đồi chè Cầu Đất');
    assert.equal(cauDat.areaCode, 'da-lat');
    assert.deepEqual(cauDat.seasonMonths, [10, 11, 12]);
    assert.equal(cauDat.status, 'active');

    const hoiAn = get(`spots/${SEED_SPOT_HOI_AN}`);
    assert.ok(hoiAn);
    assert.equal(hoiAn.name, 'Phố cổ Hội An');
    assert.equal(hoiAn.areaCode, 'hoi-an');
    assert.deepEqual(hoiAn.seasonMonths, []);
    assert.equal(hoiAn.status, 'active');

    const hoTay = get(`spots/${SEED_SPOT_HO_TAY}`);
    assert.ok(hoTay);
    assert.equal(hoTay.name, 'Hồ Tây');
    assert.equal(hoTay.areaCode, 'hn');
    assert.deepEqual(hoTay.seasonMonths, []);
    assert.equal(hoTay.status, 'active');
    assert.equal(hoTay.pinned, true);

    const cauVang = get(`spots/${SEED_SPOT_CAU_VANG}`);
    assert.ok(cauVang);
    assert.equal(cauVang.name, 'Cầu Vàng');
    assert.equal(cauVang.areaCode, 'dn');
    assert.deepEqual(cauVang.seasonMonths, []);
    assert.equal(cauVang.status, 'active');

    const muCangChai = get(`spots/${SEED_SPOT_MU_CANG_CHAI}`);
    assert.ok(muCangChai);
    assert.equal(muCangChai.name, 'Mù Cang Chải');
    assert.equal(muCangChai.areaCode, 'yen-bai');
    assert.deepEqual(muCangChai.seasonMonths, [9, 10]);
    assert.equal(muCangChai.status, 'active');
  });

  test('An has an open schedule at Hồ Tây on the next two Saturdays and Sundays 06:00–11:00 with the offer "Bình minh Hồ Tây 30 phút" 490.000₫ 30/10, and spot availability records on those days', () => {
    const schedule = get(`spot_schedules/${SEED_SCHEDULE_AN_HO_TAY}`);
    assert.ok(schedule);
    assert.equal(schedule.providerId, AN);
    assert.equal(schedule.spotId, SEED_SPOT_HO_TAY);
    assert.equal(schedule.status, 'open');
    assert.deepEqual(schedule.window, { start: '06:00', end: '11:00' });
    const days = schedule.days as string[];
    assert.equal(days.length, 4);

    const offer = get(`spot_slot_offers/${SEED_OFFER_AN_BINH_MINH}`);
    assert.ok(offer);
    assert.equal(offer.providerId, AN);
    assert.equal(offer.scheduleId, SEED_SCHEDULE_AN_HO_TAY);
    assert.equal(offer.spotId, SEED_SPOT_HO_TAY);
    assert.equal(offer.name, 'Bình minh Hồ Tây 30 phút');
    assert.equal(offer.price, 490_000);
    assert.equal(offer.slotMinutes, 30);
    assert.equal(offer.gapMinutes, 10);
    assert.equal(offer.status, 'open');

    for (const day of days) {
      const avail = get(`availability/${AN}/days/${day}`);
      assert.ok(avail, `availability record on ${day}`);
      assert.equal(avail.state, 'spot');
      assert.equal(avail.scheduleId, SEED_SCHEDULE_AN_HO_TAY);
      assert.equal(avail.spotId, SEED_SPOT_HO_TAY);
    }
  });

  test('Bình has an open schedule at Cầu Vàng next Saturday 15:00–18:00 (only when Bình accepts orders in the seed; else the test asserts none)', () => {
    const binhP = SEED_PHOTOGRAPHERS.find((p) => p.uid === BINH);
    const binhAccepts = binhP ? acceptsOrders({ verified: binhP.verified, onboardingComplete: true }) : false;
    const schedule = docs.find((d) => d.path.startsWith('spot_schedules/seed-schedule-binh'));
    if (binhAccepts) {
      assert.ok(schedule);
      assert.equal(schedule.data.providerId, BINH);
      assert.equal(schedule.data.spotId, SEED_SPOT_CAU_VANG);
    } else {
      assert.equal(schedule, undefined);
    }
  });

  test('seed-post-an-1 has spotId of Hồ Tây', () => {
    const post = get('posts/seed-post-an-1');
    assert.ok(post);
    assert.equal(post.spotId, SEED_SPOT_HO_TAY);
  });

  test('no seed spot_days doc contains a booking or customer field', () => {
    const spotDays = docs.filter((d) => d.path.startsWith('spot_days/'));
    assert.ok(spotDays.length >= 4);
    for (const sd of spotDays) {
      const data = sd.data as Record<string, unknown>;
      assert.equal(data.customerId, undefined);
      assert.equal(data.bookingId, undefined);
      assert.equal(data.customer, undefined);
      assert.equal(data.booking, undefined);
      assert.ok(Array.isArray(data.taken));
      for (const t of data.taken as Record<string, unknown>[]) {
        assert.equal(t.customerId, undefined);
        assert.equal(t.bookingId, undefined);
      }
    }
  });
});


describe('seed recruiting (S27, #151)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;
  const under = (prefix: string) => docs.filter((d) => d.path.startsWith(prefix));

  test('seeds one open collaborator post by Cúc Studio with matchKeys and filterKeys from the domain', () => {
    const posts = under('recruitPosts/').map((d) => recruitPostFromDoc(d.path.slice('recruitPosts/'.length), d.data));
    assert.equal(posts.length, 1);
    const post = posts[0];
    assert.ok(post);
    assert.equal(post.studioId, CUC);
    assert.equal(post.kind, 'collaborator');
    assert.equal(post.status, 'open');
    assert.equal(post.studio.name, SEED_USERS.find((u) => u.uid === CUC)?.displayName);
    assert.ok(post.expiresAt.getTime() > NOW.getTime());
    assert.deepEqual(post.matchKeys, recruitMatchKeys(post.areas, post.specialties));
    assert.deepEqual(post.filterKeys, recruitFilterKeys(post));
    assert.ok(isId(post.id));
    assert.equal(countersFromDoc(get(`photographers/${CUC}/private/recruit`)).openPostCount, 1);
  });

  test('seeds two applied applications to the post: An (Cúc\'s member, the refusal case) and Hòa', () => {
    const apps = under('recruitApplications/').map((d) => applicationFromDoc(d.path.slice('recruitApplications/'.length), d.data));
    assert.deepEqual(apps.map((a) => a?.applicantId).sort(), [AN, HOA].sort());
    for (const app of apps) {
      assert.ok(app);
      assert.equal(app.studioId, CUC);
      assert.equal(app.status, 'applied');
      assert.ok(app.termsAcceptedAt, 'a collaborator application carries the accepted terms');
      assert.equal(app.id, `${app.postId}_${app.applicantId}`);
      assert.equal(countersFromDoc(get(`photographers/${app.applicantId}/private/recruit`)).openApplicationCount, 1);
    }
    const post = recruitPostFromDoc(SEED_RECRUIT_POST_CUC, get(`recruitPosts/${SEED_RECRUIT_POST_CUC}`));
    assert.equal(post?.applicationCount, 2);
  });

  test('Hòa is a verified individual in no studio, accepting orders, matching the post (Cúc can accept her)', () => {
    const doc = get(`photographers/${HOA}`) as Record<string, unknown> | undefined;
    assert.ok(doc);
    assert.equal(doc.verified, true);
    assert.equal(doc.acceptingOrders, true);
    assert.equal(doc.providerType, undefined, 'individual');
    assert.equal(doc.studioId, undefined, 'member of no studio');
    const memberOf = (uid: string) => under('studio_members/').some((d) => (d.data as { memberId?: string }).memberId === uid);
    assert.equal(memberOf(AN), true, 'control: An is in a studio_members doc');
    assert.equal(memberOf(HOA), false);
    assert.equal((get(`verifications/${HOA}`) as { status?: string } | undefined)?.status, 'approved');
    const post = recruitPostFromDoc(SEED_RECRUIT_POST_CUC, get(`recruitPosts/${SEED_RECRUIT_POST_CUC}`));
    const keys = doc.recruitMatchKeys as string[];
    assert.ok(post?.matchKeys.some((k) => keys.includes(k)), 'her TP.HCM keys meet the post');
  });

  test('seeds an active collaboration Cúc–Dũng with defaultFee 600000 and both counters', () => {
    const c = collaborationFromDoc(`${CUC}_${DUNG}`, get(`studio_collaborations/${CUC}_${DUNG}`));
    assert.ok(c);
    assert.equal(c.status, 'active');
    assert.equal(c.defaultFee, 600_000);
    assert.equal(c.collaboratorId, DUNG);
    assert.ok(c.termsAcceptedAt && c.activeAt);
    assert.equal(countersFromDoc(get(`photographers/${CUC}/private/recruit`)).activeCollabCount, 1);
    assert.equal(countersFromDoc(get(`photographers/${DUNG}/private/recruit`)).activeCollabCount, 1);
  });

  test('every seeded photographer carries the recruitMatchKeys the trigger would write', () => {
    for (const p of SEED_PHOTOGRAPHERS) {
      const doc = get(`photographers/${p.uid}`);
      const role = SEED_USERS.find((u) => u.uid === p.uid)?.role;
      const expected = [...recruitMatchKeysOf({ role, providerType: doc?.providerType, serviceArea: doc?.serviceArea, specialties: p.specialties })].sort();
      assert.deepEqual(doc?.recruitMatchKeys, expected, p.uid);
    }
    assert.deepEqual(get(`photographers/${CUC}`)?.recruitMatchKeys, []);
  });
});

describe('seed disputes (S18, #142)', () => {
  const docs = seedDocuments(NOW);
  const get = (path: string) => docs.find((d) => d.path === path)?.data;
  const HOUR = 3_600_000;

  test('seed-dispute-lan-an is open on seed-booking-disputed with a thread', () => {
    const d = get(`disputes/${SEED_DISPUTE_LAN_AN}`);
    assert.ok(d);
    assert.equal(d.id, SEED_DISPUTE_LAN_AN);
    assert.equal(d.status, 'open');
    assert.equal(d.subjectType, 'booking');
    assert.equal(d.subjectId, 'seed-booking-disputed');
    assert.equal(d.paymentId, 'seed-payment-seed-booking-disputed');
    assert.equal(d.customerId, LAN);
    assert.equal(d.providerId, AN);
    assert.deepEqual(d.parties, [LAN, AN]);
    assert.equal(d.reason, 'photos_missing');
    assert.equal(d.amountHeld, computeDeposit(1_500_000).deposit);
    assert.equal(d.outcome, null);
    assert.equal(d.threadId, `dispute_${SEED_DISPUTE_LAN_AN}`);
    assert.equal((d.snapshot as { title: string }).title, 'An Studio (seed) · Chân dung 2 giờ');
    // The mirrors and the frozen payment point at it.
    assert.equal(get('bookings/seed-booking-disputed')?.disputeId, SEED_DISPUTE_LAN_AN);
    const pay = get('payments/seed-payment-seed-booking-disputed');
    assert.equal(pay?.escrowStatus, 'disputed');
    assert.deepEqual(
      { ...(pay?.dispute as Record<string, unknown>), openedAt: undefined },
      { reason: 'photos_missing', openedAt: undefined, disputeId: SEED_DISPUTE_LAN_AN, milestone: null, prevEscrowStatus: 'held' },
    );
    assert.equal(millis((pay?.dispute as { openedAt: unknown }).openedAt), millis(d.createdAt));
    // Opened inside the 24-hour window after completion.
    const completedAt = millis(get('bookings/seed-booking-disputed')?.completedAt);
    assert.ok(millis(d.createdAt) > completedAt && millis(d.createdAt) < completedAt + 24 * HOUR);

    const thread = get(`support_threads/dispute_${SEED_DISPUTE_LAN_AN}`);
    assert.ok(thread);
    assert.equal(thread.kind, 'dispute');
    assert.equal(thread.disputeId, SEED_DISPUTE_LAN_AN);
    assert.deepEqual(thread.participants, [LAN, AN]);
    assert.equal(thread.status, 'open');
    const messages = docs
      .filter((x) => x.path.startsWith(`support_threads/dispute_${SEED_DISPUTE_LAN_AN}/messages/`))
      .map((x) => x.data)
      .sort((a, b) => millis(a.createdAt) - millis(b.createdAt));
    assert.deepEqual(messages.map((m) => m.senderRole), ['system', 'customer', 'staff', 'provider']);
    assert.equal(messages[1]?.body, d.description);
    // Like openDispute: only the description carries the opening marker (no dispute_message for it).
    assert.deepEqual(messages.map((m) => m.opening === true), [false, true, false, false]);
    assert.equal(messages[2]?.senderId, ADMIN);
    assert.equal(messages[3]?.senderId, AN);
    // The last word is the provider's: support has something to read.
    assert.equal(thread.lastSenderRole, 'provider');
    assert.equal(thread.awaitingStaff, true);
    assert.equal(millis(thread.lastMessageAt), millis(messages[3]?.createdAt));
  });

  test('seed-booking-completed-window is completed 2 hours before seeding with a held payment', () => {
    const b = get(`bookings/${SEED_BOOKING_COMPLETED_WINDOW}`);
    assert.equal(b?.status, 'completed');
    assert.equal(b?.customerId, LAN);
    assert.equal(millis(b?.completedAt), NOW.getTime() - 2 * HOUR);
    assert.equal(b?.escrowStatus, 'held');
    assert.equal(b?.disputeId, undefined);
    const pay = get(`payments/seed-payment-${SEED_BOOKING_COMPLETED_WINDOW}`);
    assert.equal(pay?.status, 'paid');
    assert.equal(pay?.escrowStatus, 'held');
    assert.equal(pay?.milestones, undefined);
    // Released by the booking clock once the dispute window is over, not before.
    assert.equal(millis(pay?.releaseAfter), NOW.getTime() + 22 * HOUR);
    assert.equal(get(`ledger_entries/seed-ledger-${SEED_BOOKING_COMPLETED_WINDOW}-rel`), undefined);
  });

  test('the past paid ticket ended 3 hours before seeding with a held payment', () => {
    const ev = get(`events/${SEED_EVENT_PAST}`);
    assert.ok(ev);
    assert.equal(millis(ev.endAt), NOW.getTime() - 3 * HOUR);
    assert.equal(ev.status, 'completed');
    assert.ok((ev.price as number) > 0);
    const reg = get(`events/${SEED_EVENT_PAST}/registrations/${SEED_REGISTRATION_LAN_PAST}`);
    assert.equal(reg?.userId, LAN);
    assert.equal(reg?.status, 'paid');
    assert.equal(reg?.amount, ev.price);
    assert.equal(reg?.disputeId, null);
    assert.ok(isTicketCode(String(reg?.ticketCode)));
    assert.deepEqual(get(`ticket_codes/${String(reg?.ticketCode)}`), { eventId: SEED_EVENT_PAST, registrationId: SEED_REGISTRATION_LAN_PAST });
    const pay = get(`payments/${String(reg?.paymentId)}`);
    assert.equal(pay?.subjectType, 'event_registration');
    assert.equal(pay?.subjectId, SEED_REGISTRATION_LAN_PAST);
    assert.equal(pay?.eventId, SEED_EVENT_PAST);
    assert.equal(pay?.payerId, LAN);
    assert.equal(pay?.payeeId, AN);
    assert.equal(pay?.amount, ev.price);
    assert.equal(pay?.status, 'paid');
    assert.equal(pay?.escrowStatus, 'held');
    assert.equal(millis(pay?.releaseAfter), NOW.getTime() + 21 * HOUR);
    // A paid ticket has its private contact snapshot (O3), never on the public registration.
    assert.equal(get(`events/${SEED_EVENT_PAST}/registrations/${SEED_REGISTRATION_LAN_PAST}/private/contact`)?.phone, '+84903000001');
    assert.equal(JSON.stringify(reg).includes('+849'), false);
  });
});
