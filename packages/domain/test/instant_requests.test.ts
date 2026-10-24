import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { DomainError } from '../src/errors.js';
import type { Payment } from '../src/escrow.js';
import { fakeTransferFor } from '../src/fake_payment_gateway.js';
import { InstantPaymentSettler, instantRefundHandler } from '../src/instant_payments.js';
import { settleTransfer, transferRecordId } from '../src/payment_settlement.js';
import { answerInstantOffer, updateInstantJob } from '../src/instant_jobs.js';
import { offerPushMessage } from '../src/instant_notices.js';
import {
  cancelInstantRequest,
  checkInstantPayment,
  confirmInstantComplete,
  createInstantRequest,
  inviteInstant,
  nextInstantCandidates,
  runInstantSweep,
  tickInstantRequest,
} from '../src/instant_requests.js';
import { HOUR, MIN, SEC, T0, TAO_DAN, aConfig, at, north } from './support/instant_fixtures.js';
import { LAN, MEET, createInstantWorld, inviteAndPay, lanInvites, lanRequests, offerOf, type InstantWorld } from './support/instant_world.js';

const code = (c: string) => (e: unknown) => e instanceof DomainError && e.code === c;

const req = (w: InstantWorld, id: string) => {
  const r = w.store.requests.get(id);
  assert.ok(r, `request ${id}`);
  return r;
};

const accept = (w: InstantWorld, uid: string, requestId: string) =>
  answerInstantOffer(w.deps, { uid }, { offerId: offerOf(w, uid, requestId), action: 'accept' });

const job = (w: InstantWorld, uid: string, requestId: string, action: string, extra: Record<string, unknown> = {}) =>
  updateInstantJob(w.deps, { uid }, { requestId, action, ...extra });

const HERE = { ...TAO_DAN, accuracyM: 10 };

/** After the payment, who got an offer (pending) and who was unavailable, in the order chosen. */
const assertRows = (w: InstantWorld, id: string, invited: readonly string[], unavailable: readonly string[]) => {
  const rows = req(w, id).offers;
  assert.deepEqual(rows.filter((o) => o.outcome === 'pending').map((o) => o.photographerId), invited);
  assert.deepEqual(rows.filter((o) => o.outcome === 'unavailable').map((o) => o.photographerId), unavailable);
};

describe('createInstantRequest', () => {
  test('create: refuses without phone (phone_required)', async () => {
    const w = createInstantWorld();
    w.customer('c-lan', { phone: null });
    await assert.rejects(lanRequests(w), code('phone_required'));
    assert.equal(w.store.requests.size, 0);
  });

  test('create: outside the boxes (outside_service_area)', async () => {
    const w = createInstantWorld();
    await assert.rejects(lanRequests(w, { meetPoint: { lat: 13.7563, lng: 100.5018, name: 'Bangkok' } }), code('outside_service_area'));
  });

  test('create: when disabled (not_eligible)', async () => {
    const w = createInstantWorld();
    w.config = aConfig({ enabled: false });
    await assert.rejects(lanRequests(w), code('not_eligible'));
  });

  test('create: a second active request (conflict)', async () => {
    const w = createInstantWorld();
    await lanRequests(w);
    await assert.rejects(lanRequests(w), code('conflict'));
    assert.equal(w.store.requests.size, 1);
  });

  test('create: an abandoned old request does not block a new one', async () => {
    const w = createInstantWorld();
    const old = await lanRequests(w);
    w.clock.advance(31 * MIN);
    await lanRequests(w);
    assert.equal(req(w, old).status, 'abandoned');
    assert.equal(w.store.requests.size, 2);
  });

  test('create: bad input is invalid_argument', async () => {
    const w = createInstantWorld();
    await assert.rejects(lanRequests(w, { packageCode: 'p999' }), code('invalid_argument'));
    await assert.rejects(lanRequests(w, { genre: 'wedding' }), code('invalid_argument'));
    await assert.rejects(lanRequests(w, { meetPoint: { ...TAO_DAN, name: '  ' } }), code('invalid_argument'));
    await assert.rejects(lanRequests(w, { meetPoint: { ...TAO_DAN, name: 'x'.repeat(81) } }), code('invalid_argument'));
    await assert.rejects(lanRequests(w, { note: 'x'.repeat(141) }), code('invalid_argument'));
  });

  test('create: locks the price and lists ≤ 5 candidates, nearest first', async () => {
    const w = createInstantWorld();
    const res = await createInstantRequest(w.deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET, note: ' Áo dài trắng ' });
    const r = req(w, res.requestId);
    assert.deepEqual(res, { requestId: r.id, amountVnd: 690_000, round: 1, candidateCount: 5 });
    assert.deepEqual(r.candidates.map((c) => c.photographerId), ['p1', 'p2', 'p3', 'p4', 'p5']);
    assert.equal(r.status, 'choosing');
    assert.equal(r.active, true);
    assert.equal(r.amountVnd, 690_000);
    assert.equal(r.earningVnd, 690_000);
    assert.equal(r.priceListVersion, 1);
    assert.equal(r.platformFeeBp, 0);
    assert.equal(r.arrivedCancelPhotographerPercent, 50);
    assert.equal(r.customerName, 'Lan Anh');
    assert.equal(r.note, 'Áo dài trắng');
    assert.equal(r.areaLabel, 'Quận 1, TP.HCM');
    assert.deepEqual(r.lastActivityAt, T0);
    assert.equal(r.committedAt, null);
    assert.equal(r.paidAt, null);
    assert.deepEqual(r.nextDeadlineAt, at(30 * MIN)); // abandon
  });

  test('create: surge and the platform fee are snapshotted', async () => {
    const w = createInstantWorld();
    const cfg = aConfig({ platformFeeBp: 1000, instantArrivedCancelPhotographerPercent: 40 });
    w.config = { ...cfg, cities: cfg.cities.map((c) => (c.id === 'hcm' ? { ...c, surgeBp: 12_500 } : c)) };
    const r = req(w, await lanRequests(w));
    assert.equal(r.amountVnd, 863_000);
    assert.equal(r.earningVnd, 863_000 - 86_300);
    assert.equal(r.platformFeeBp, 1000);
    assert.equal(r.arrivedCancelPhotographerPercent, 40);
  });

  test('create: a photographer whose day is held by a spot, a full studio or a booking is not suggested', async () => {
    const w = createInstantWorld();
    w.day('p2', 'spot');
    w.day('p3', 'full');
    w.day('p4', 'booked');
    w.day('p5', 'pending');
    w.day('p6', 'off');
    const r = req(w, await lanRequests(w));
    assert.deepEqual(r.candidates.map((c) => c.photographerId), ['p1', 'p5', 'p6']);
  });

  test('create and next round: a photographer blocked either way is never suggested', async () => {
    const w = createInstantWorld();
    w.blocks.block('c-lan', 'p1');
    w.blocks.block('p3', 'c-lan');
    const id = await lanRequests(w);
    assert.deepEqual(req(w, id).candidates.map((c) => c.photographerId), ['p2', 'p4', 'p5', 'p6']);
    const res = await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: ['p2'] });
    assert.equal(res.candidateCount, 3);
    assert.deepEqual(req(w, id).candidates.map((c) => c.photographerId), ['p4', 'p5', 'p6']);
  });
});

describe('rounds', () => {
  test('next round excludes skipped and offers no one twice', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.clock.advance(61 * SEC);
    await tickInstantRequest(w.deps, LAN, { requestId: id });
    assert.equal(req(w, id).status, 'choosing');
    assert.equal(req(w, id).roundEnded, true);
    const res = await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: ['p2', 'p3'] });
    const r = req(w, id);
    assert.deepEqual(res, { round: 2, candidateCount: 3, status: 'choosing' });
    assert.deepEqual(r.candidates.map((c) => c.photographerId), ['p4', 'p5', 'p6']);
    assert.deepEqual([...r.excludedIds].sort(), ['p1', 'p2', 'p3']);
    assert.deepEqual(r.offers, []);
    assert.equal(r.roundEnded, false);
    assert.deepEqual(r.lastActivityAt, at(61 * SEC));
    await lanInvites(w, ['p4'], id);
    assert.equal(w.store.offersOf('p1').length, 1);
    assert.equal(w.store.offersOf('p4').length, 1);
  });

  test('committed request with no candidates left goes no_match', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await answerInstantOffer(w.deps, { uid: 'p1' }, { offerId: offerOf(w, 'p1', id), action: 'decline' });
    for (const uid of ['p2', 'p3', 'p4', 'p5', 'p6']) w.online(uid, TAO_DAN, { online: false });
    const res = await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    assert.deepEqual(res, { round: 2, candidateCount: 0, status: 'no_match' });
    assert.equal(req(w, id).nextDeadlineAt, null);
  });

  test('from no_match the customer reopens and the window restarts', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await answerInstantOffer(w.deps, { uid: 'p1' }, { offerId: offerOf(w, 'p1', id), action: 'decline' });
    w.clock.advance(11 * MIN);
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'no_match');
    for (const uid of ['p2', 'p3']) w.online(uid, north(TAO_DAN, 1));
    const res = await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    assert.equal(res.status, 'choosing');
    assert.ok(res.candidateCount > 0);
    assert.deepEqual(req(w, id).searchDeadlineAt, at(21 * MIN));
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'choosing');
  });

  test('uncommitted request with no candidates stays choosing', async () => {
    const w = createInstantWorld();
    for (const uid of ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']) w.online(uid, TAO_DAN, { online: false });
    const id = await lanRequests(w);
    const res = await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    assert.deepEqual(res, { round: 2, candidateCount: 0, status: 'choosing' });
  });
});

describe('inviteInstant', () => {
  test('first invite creates one payment and pending_payment, no offer yet, and returns PaymentInstructions with the VietQR payload for bank_qr', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, {
      requestId: id, photographerIds: ['p1', 'p3'], skipped: ['p2'], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
    });
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    assert.equal(res.amountVnd, 690_000);
    const { instructions } = res;
    assert.equal(w.store.payments.size, 1);
    const p = w.store.payments.get(instructions.paymentId);
    assert.ok(p);
    assert.deepEqual(
      [p.subjectType, p.subjectId, p.payerId, p.payeeId, p.amount, p.method, p.status, p.escrowStatus, p.idempotencyKey],
      ['instant_request', id, 'c-lan', '', 690_000, 'bank_qr', 'created', 'held', `inst_${id}_1`],
    );
    assert.equal(p.expiresAt, at(15 * MIN).toISOString());
    assert.deepEqual(
      [instructions.subjectType, instructions.subjectId, instructions.method, instructions.amount, instructions.transferCode],
      ['instant_request', id, 'bank_qr', 690_000, p.transferCode],
    );
    assert.equal(instructions.expiresAt, at(15 * MIN).toISOString());
    assert.match(instructions.qrPayload ?? '', /^000201/);
    assert.ok((instructions.qrPayload ?? '').includes(String(690_000)));
    assert.equal(instructions.payUrl, undefined);
    assert.equal(w.gateway.createPaymentCalls.length, 1);
    const r = req(w, id);
    assert.equal(r.status, 'pending_payment');
    assert.deepEqual([r.paymentId, r.payMethod, r.provider], [p.id, 'bank_qr', 'fake']);
    assert.deepEqual(r.paymentDeadlineAt, at(15 * MIN));
    assert.deepEqual(r.pendingInviteIds, ['p1', 'p3']);
    assert.deepEqual(r.excludedIds, ['p2']);
    assert.equal(r.committedAt, null);
    assert.equal(r.paidAt, null);
    assert.deepEqual(r.nextDeadlineAt, at(15 * MIN));
    assert.equal(w.store.offers.size, 0);
    assert.equal(w.pushes.size, 0);
  });

  test('a wallet answers a payUrl and no QR', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'momo' });
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    assert.match(res.instructions.payUrl ?? '', /momo/);
    assert.equal(res.instructions.qrPayload, undefined);
  });

  test('the first invite without a payment method is invalid_argument', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000 }),
      code('invalid_argument'),
    );
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'card' }),
      code('invalid_argument'),
    );
    assert.equal(w.store.payments.size, 0);
  });

  test('a second invite tap reuses the created payment', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const input = { requestId: id, photographerIds: ['p1', 'p3'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' };
    const first = await inviteInstant(w.deps, LAN, input);
    w.clock.advance(MIN);
    const second = await inviteInstant(w.deps, LAN, { ...input, photographerIds: ['p1'] });
    assert.equal(first.kind, 'payment');
    assert.equal(second.kind, 'payment');
    if (first.kind !== 'payment' || second.kind !== 'payment') return;
    assert.deepEqual(second.instructions, first.instructions);
    assert.equal(w.store.payments.size, 1);
    assert.equal(w.gateway.createPaymentCalls.length, 1);
    const r = req(w, id);
    assert.equal(r.status, 'pending_payment');
    assert.deepEqual(r.pendingInviteIds, ['p1']);
    assert.deepEqual(r.paymentDeadlineAt, at(15 * MIN));
    // Another method opens a new payment and closes the first.
    const third = await inviteInstant(w.deps, LAN, { ...input, payMethod: 'zalopay' });
    assert.equal(third.kind, 'payment');
    if (third.kind !== 'payment') return;
    assert.notEqual(third.instructions.paymentId, first.instructions.paymentId);
    assert.equal(w.store.payments.get(first.instructions.paymentId)?.status, 'expired');
    assert.equal(w.store.payments.get(third.instructions.paymentId)?.idempotencyKey, `inst_${id}_2`);
    assert.equal(req(w, id).paymentId, third.instructions.paymentId);
  });

  test('payment confirmed (V1\'s confirmFakePayment through subjects.instant_request) sends offers to the chosen people only, each with a 60 s expiry and a push', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, {
      requestId: id, photographerIds: ['p1', 'p3'], skipped: ['p2'], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
    });
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    w.clock.advance(2 * MIN);
    const paid = await w.pay(res.instructions.paymentId);
    assert.deepEqual(paid, { outcome: 'paid', subjectType: 'instant_request', paymentStatus: 'paid', subjectStatus: 'searching' });
    const r = req(w, id);
    assert.equal(r.status, 'searching');
    assert.deepEqual(r.paidAt, at(2 * MIN));
    assert.deepEqual(r.committedAt, at(2 * MIN));
    assert.deepEqual(r.pendingInviteIds, []);
    assert.equal(r.invitedTotal, 2);
    assert.equal(r.roundsWithInvites, 1);
    assert.deepEqual(r.searchDeadlineAt, at(12 * MIN));
    assert.deepEqual(r.nextDeadlineAt, at(2 * MIN + 60 * SEC));
    assert.deepEqual(r.offers.map((o) => [o.photographerId, o.outcome]), [['p1', 'pending'], ['p3', 'pending']]);
    for (const uid of ['p1', 'p3']) {
      const offer = w.store.offer(uid, offerOf(w, uid, id));
      assert.ok(offer);
      assert.deepEqual(offer.expiresAt, at(2 * MIN + 60 * SEC));
      assert.equal(offer.invitedCount, 2);
      assert.equal(offer.earningVnd, 690_000);
      assert.deepEqual(w.pushes.get(uid), [offerPushMessage(offer)]);
      const p = w.store.presences.get(uid);
      assert.deepEqual(p?.pendingOffers, [{ offerId: offer.id, requestId: id, expiresAt: at(2 * MIN + 60 * SEC) }]);
      assert.equal(p?.reliability.offers, 1);
    }
    assert.equal(w.store.offersOf('p2').length, 0);
    assert.equal(w.pushes.get('p2'), undefined);
    const p = w.store.payments.get(res.instructions.paymentId);
    assert.deepEqual([p?.status, p?.escrowStatus, p?.payeeId], ['paid', 'held', '']);
    assert.deepEqual([...w.store.ledger.values()].map((e) => [e.type, e.amount]), [['payment_received', 690_000]]);
  });

  test('checkInstantPayment applies a transfer the gateway reports (payer only)', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' });
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    const check = (uid: string) => checkInstantPayment({ ...w.deps, settlement: w.settlement }, { uid }, { requestId: id });
    assert.deepEqual(await check('c-lan'), { paid: false, status: 'pending_payment' });
    await assert.rejects(check('c-minh'), code('permission_denied'));
    const payment = w.store.payments.get(res.instructions.paymentId);
    assert.ok(payment);
    w.gateway.pushTransfer(payment.id, fakeTransferFor(payment as typeof payment & { transferCode: string }, 'exact', T0));
    assert.deepEqual(await check('c-lan'), { paid: true, status: 'searching' });
    assert.equal(w.store.offersOf('p1').length, 1);
  });

  test('price change returns price_changed with the new amount saved and no payment', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const cfg = aConfig();
    w.config = { ...cfg, priceListVersion: 2, cities: cfg.cities.map((c) => (c.id === 'hcm' ? { ...c, surgeBp: 12_000 } : c)) };
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' });
    assert.deepEqual(res, { kind: 'price_changed', amountVnd: 828_000 });
    const r = req(w, id);
    assert.equal(r.amountVnd, 828_000);
    assert.equal(r.earningVnd, 828_000);
    assert.equal(r.priceListVersion, 2);
    assert.equal(r.status, 'choosing');
    assert.equal(w.store.offers.size, 0);
    assert.equal(w.pushes.size, 0);
    assert.equal(w.store.payments.size, 0);
    assert.equal(w.gateway.createPaymentCalls.length, 0);
  });

  test('a stale expectedAmountVnd returns price_changed without a write', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const before = req(w, id);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 600_000, payMethod: 'bank_qr' });
    assert.deepEqual(res, { kind: 'price_changed', amountVnd: 690_000 });
    assert.equal(req(w, id), before);
    assert.equal(w.store.offers.size, 0);
    assert.equal(w.store.payments.size, 0);
  });

  test('invite when Chụp ngay was switched off is not_eligible', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.config = aConfig({ enabled: false });
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' }),
      code('not_eligible'),
    );
    assert.equal(w.store.offers.size, 0);
  });

  test('excludedIds never reach an offer doc or a push', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await inviteAndPay(w, LAN, id, ['p1', 'p3'], { skipped: ['p2', 'p4'] });
    assert.deepEqual(req(w, id).excludedIds, ['p2', 'p4']);
    for (const uid of ['p1', 'p3']) {
      const offer = w.store.offer(uid, offerOf(w, uid, id));
      assert.ok(offer);
      assert.ok(!('excludedIds' in offer));
      const text = JSON.stringify([offer, w.pushes.get(uid)]);
      for (const skipped of ['p2', 'p4']) assert.ok(!text.includes(`"${skipped}"`), skipped);
    }
  });

  test('an id outside the round is not_eligible', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p6'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' }),
      code('not_eligible'),
    );
  });

  test('another customer cannot invite (permission_denied); 6 ids are invalid_argument', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await assert.rejects(
      inviteInstant(w.deps, { uid: 'c-minh' }, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' }),
      code('permission_denied'),
    );
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' }),
      code('invalid_argument'),
    );
  });

  test("a blocked invitee (#198's BlockGate through orderBlocker) is unavailable and not excluded", async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.blocks.block('p2', 'c-lan');
    await inviteAndPay(w, LAN, id, ['p1', 'p2']);
    assertRows(w, id, ['p1'], ['p2']);
    const r = req(w, id);
    const row = r.offers.find((o) => o.photographerId === 'p2');
    assert.deepEqual([row?.outcome, row?.offerId, row?.expiresAt], ['unavailable', null, null]);
    assert.ok(!r.excludedIds.includes('p2'));
    assert.ok(w.blocks.calls.some(([a, b]) => a === 'c-lan' && b === 'p2'));
    assert.equal(w.store.offersOf('p2').length, 0);
  });

  test('offer doc has no meet point', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    const offer = w.store.offer('p1', offerOf(w, 'p1', id));
    assert.ok(offer);
    for (const key of ['meetPoint', 'lat', 'lng']) assert.ok(!(key in offer), key);
    assert.ok(!JSON.stringify(offer).includes(MEET.name));
    assert.equal(offer.areaLabel, 'Quận 1, TP.HCM');
    assert.equal(offer.distanceKm, 0.5);
    assert.equal(offer.etaMinutes, 3);
  });

  test('a chosen photographer who went busy is unavailable and not excluded', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.online('p2', north(TAO_DAN, 1), { activeRequestId: 'ir_other' });
    await inviteAndPay(w, LAN, id, ['p1', 'p2']);
    assertRows(w, id, ['p1'], ['p2']);
    assert.ok(!req(w, id).excludedIds.includes('p2'));
  });

  test('revoked photographer is unavailable at invite', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.gate.set('p2', { verified: false, onboardingComplete: true });
    await inviteAndPay(w, LAN, id, ['p1', 'p2']);
    assertRows(w, id, ['p1'], ['p2']);
  });

  test('a photographer with 3 live pending offers is unavailable', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const pending = [1, 2, 3].map((n) => ({ offerId: `o${n}`, requestId: `r${n}`, expiresAt: at(30 * SEC) }));
    w.online('p2', north(TAO_DAN, 1), { pendingOffers: pending });
    await inviteAndPay(w, LAN, id, ['p2']);
    assertRows(w, id, [], ['p2']);
  });

  test('a photographer whose day became a spot or full day is unavailable at invite', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.day('p2', 'full');
    w.day('p3', 'spot');
    await inviteAndPay(w, LAN, id, ['p1', 'p2', 'p3']);
    assertRows(w, id, ['p1'], ['p2', 'p3']);
  });

  test('all unavailable after payment: choosing with roundEnded, money held', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.blocks.block('c-lan', 'p1');
    w.gate.delete('p2');
    await inviteAndPay(w, LAN, id, ['p1', 'p2']);
    assertRows(w, id, [], ['p1', 'p2']);
    const r = req(w, id);
    assert.equal(r.status, 'choosing');
    assert.equal(r.roundEnded, true);
    assert.deepEqual(r.committedAt, T0);
    assert.deepEqual(r.searchDeadlineAt, at(10 * MIN)); // settle can reach no_match
    assert.deepEqual(r.nextDeadlineAt, at(10 * MIN));
    assert.equal(r.invitedTotal, 0);
    assert.equal(w.store.offers.size, 0);
    assert.deepEqual(r.paidAt, T0);
    const p = w.store.payments.get(r.paymentId ?? '');
    assert.deepEqual([p?.status, p?.escrowStatus], ['paid', 'held']);
    assert.equal(w.store.refunds.size, 0);
  });

  test('later round invites without a new payment', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await answerInstantOffer(w.deps, { uid: 'p1' }, { offerId: offerOf(w, 'p1', id), action: 'decline' });
    w.clock.advance(2 * MIN);
    await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p4'], skipped: [], expectedAmountVnd: 0 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p4'], unavailable: [] });
    const r = req(w, id);
    assert.equal(r.status, 'searching');
    assert.equal(r.roundsWithInvites, 2);
    assert.deepEqual(r.committedAt, T0);
    assert.deepEqual(r.searchDeadlineAt, at(12 * MIN));
    assert.deepEqual(r.lastActivityAt, at(2 * MIN));
    assert.equal(w.pushes.get('p4')?.length, 1);
    assert.equal(w.store.payments.size, 1);
    assert.equal(w.gateway.createPaymentCalls.length, 1);
  });

  test('search window ends in no_match without a refund', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.clock.advance(61 * SEC);
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'choosing');
    w.clock.set(at(10 * MIN));
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'no_match');
    assert.equal(req(w, id).active, true);
    assert.equal(w.store.refunds.size, 0);
    assert.equal(w.store.payments.get(req(w, id).paymentId ?? '')?.escrowStatus, 'held');
    assert.equal(w.gateway.refundCalls.length, 0);
  });
});

describe('cancel, confirm, tick', () => {
  test('customer cancel of an unpaid request records rule unpaid, zero money and leaves the open payment to expire', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res0 = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' });
    assert.equal(res0.kind, 'payment');
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    assert.deepEqual(res, { rule: 'unpaid', refundPercent: 0, refundVnd: 0, feeVnd: 0, amountVnd: 0, status: 'cancelled_by_customer' });
    const r = req(w, id);
    assert.deepEqual([r.cancelRule, r.refundPercent, r.feeVnd, r.cancelledBy], ['unpaid', 0, 0, 'customer']);
    assert.deepEqual(r.cancelledAt, T0);
    assert.equal(r.active, false);
    assert.equal(w.store.payments.get(r.paymentId ?? '')?.status, 'created');
    assert.equal(w.store.refunds.size + w.store.ledger.size, 0);
  });

  test('customer cancel of a paid search withdraws the offers and refunds 100%; of an assignment frees the photographer', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    assert.deepEqual(res, { rule: 'full_refund', refundPercent: 100, refundVnd: 690_000, feeVnd: 0, amountVnd: 690_000, status: 'cancelled_by_customer' });
    const r = req(w, id);
    assert.deepEqual(r.offers.map((o) => o.outcome), ['withdrawn', 'withdrawn']);
    for (const uid of ['p1', 'p2']) {
      assert.equal(w.store.offer(uid, offerOf(w, uid, id))?.outcome, 'withdrawn');
      assert.deepEqual(w.store.presences.get(uid)?.pendingOffers, []);
    }

    const w2 = createInstantWorld();
    const id2 = await lanInvites(w2, ['p1']);
    await accept(w2, 'p1', id2);
    assert.equal(w2.store.presences.get('p1')?.activeRequestId, id2);
    const res2 = await cancelInstantRequest(w2.deps, LAN, { requestId: id2, dryRun: false });
    assert.equal(res2.rule, 'free_window');
    assert.equal(w2.store.presences.get('p1')?.activeRequestId, null);
    assert.equal(w2.store.presences.get('p1')?.reliability.late, 0);
    assert.equal(req(w2, id2).photographerId, 'p1');
  });

  test('a customer cancel after lateDeadlineAt before arrival refunds 100% (photographer_late) and counts reliability.late', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    assert.deepEqual(req(w, id).lateDeadlineAt, at(18 * MIN)); // ETA 3 min + 15
    await job(w, 'p1', id, 'start_route', { location: HERE });
    w.clock.set(at(18 * MIN + SEC));
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    assert.deepEqual([res.rule, res.refundVnd, res.feeVnd], ['photographer_late', 690_000, 0]);
    const p = w.store.presences.get('p1');
    assert.equal(p?.reliability.late, 1);
    assert.equal(p?.activeRequestId, null);
    assert.equal(w.store.tracks.has(id), false);
  });

  test('cancel dryRun writes nothing', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    const before = req(w, id);
    const commits = w.store.commits;
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: true });
    assert.deepEqual(res, { rule: 'full_refund', refundPercent: 100, refundVnd: 690_000, feeVnd: 0, amountVnd: 690_000, status: 'searching' });
    assert.equal(req(w, id), before);
    assert.equal(w.store.commits, commits);
    assert.equal(w.store.refunds.size, 0);
  });

  test('cancel in_progress is conflict', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await job(w, 'p1', id, 'arrive', { location: HERE });
    await job(w, 'p1', id, 'start');
    await assert.rejects(cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false }), code('conflict'));
    await assert.rejects(cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: true }), code('conflict'));
  });

  test('confirm complete frees the photographer', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await job(w, 'p1', id, 'arrive', { location: HERE });
    await job(w, 'p1', id, 'start');
    w.clock.advance(20 * MIN);
    assert.deepEqual(await confirmInstantComplete(w.deps, LAN, { requestId: id }), { status: 'completed' });
    const r = req(w, id);
    assert.deepEqual([r.status, r.active], ['completed', false]);
    assert.deepEqual(r.completedAt, at(20 * MIN));
    assert.deepEqual(r.finishedAt, at(20 * MIN));
    const p = w.store.presences.get('p1');
    assert.equal(p?.activeRequestId, null);
    assert.equal(p?.reliability.accepted, 1);
    await assert.rejects(confirmInstantComplete(w.deps, { uid: 'p1' }, { requestId: id }), code('permission_denied'));
  });

  test('auto-complete 2 hours after finish frees the photographer through the sweep', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await job(w, 'p1', id, 'arrive', { location: HERE });
    await job(w, 'p1', id, 'start');
    await job(w, 'p1', id, 'finish');
    w.clock.advance(2 * 60 * MIN);
    await runInstantSweep(w.deps);
    assert.equal(req(w, id).status, 'completed');
    assert.equal(w.store.presences.get('p1')?.activeRequestId, null);
  });

  test('tick by a stranger is permission_denied', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.gate.delete('p2');
    await inviteAndPay(w, LAN, id, ['p1', 'p2']);
    await assert.rejects(tickInstantRequest(w.deps, { uid: 'p5' }, { requestId: id }), code('permission_denied'));
    // An `unavailable` row is not an offer.
    await assert.rejects(tickInstantRequest(w.deps, { uid: 'p2' }, { requestId: id }), code('permission_denied'));
    assert.deepEqual(await tickInstantRequest(w.deps, { uid: 'p1' }, { requestId: id }), { status: 'searching' });
    assert.deepEqual(await tickInstantRequest(w.deps, LAN, { requestId: id }), { status: 'searching' });
  });
});

describe('runInstantSweep', () => {
  test('sweep settles a forgotten round', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    w.clock.advance(61 * SEC);
    const res = await runInstantSweep(w.deps);
    assert.deepEqual(res, { settled: 1, errors: [] });
    const r = req(w, id);
    assert.deepEqual([r.status, r.roundEnded], ['choosing', true]);
    assert.deepEqual(r.offers.map((o) => o.outcome), ['expired', 'expired']);
    for (const uid of ['p1', 'p2']) {
      assert.equal(w.store.offer(uid, offerOf(w, uid, id))?.outcome, 'expired');
      const p = w.store.presences.get(uid);
      assert.deepEqual(p?.pendingOffers, []);
      assert.equal(p?.reliability.expired, 1);
    }
    assert.deepEqual(r.nextDeadlineAt, at(10 * MIN));
    assert.deepEqual(await runInstantSweep(w.deps), { settled: 0, errors: [] });
  });

  test('sweep turns a 10-minute-old search into no_match', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.clock.advance(61 * SEC);
    await runInstantSweep(w.deps);
    w.clock.set(at(10 * MIN));
    await runInstantSweep(w.deps);
    const r = req(w, id);
    assert.equal(r.status, 'no_match');
    assert.equal(r.nextDeadlineAt, null);
    assert.equal(w.store.refunds.size, 0);
  });

  test('abandoned uncommitted request after 30 minutes', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.clock.advance(29 * MIN);
    assert.deepEqual(await runInstantSweep(w.deps), { settled: 0, errors: [] });
    w.clock.advance(MIN);
    assert.deepEqual(await runInstantSweep(w.deps), { settled: 1, errors: [] });
    const r = req(w, id);
    assert.deepEqual([r.status, r.active, r.nextDeadlineAt], ['abandoned', false, null]);
  });

  test('a failing request does not stop the batch', async () => {
    const w = createInstantWorld();
    const a = await lanRequests(w);
    w.customer('c-minh', { name: 'Minh' });
    const b = req(w, await createInstantRequest(w.deps, { uid: 'c-minh' }, { packageCode: 'p30', genre: 'family', meetPoint: MEET })
      .then((x) => x.requestId));
    w.store.requests.set(a, { ...req(w, a), offers: null as never, status: 'searching' });
    w.clock.advance(31 * MIN);
    const res = await runInstantSweep(w.deps);
    assert.equal(res.settled, 1);
    assert.deepEqual(res.errors.map((e) => e.requestId), [a]);
    assert.equal(req(w, b.id).status, 'abandoned');
  });

  test('committedAt is never set without paidAt (invariant over a full flow)', async () => {
    const w = createInstantWorld();
    const seen: string[] = [];
    const check = (step: string) => {
      for (const r of w.store.requests.values()) {
        assert.ok(r.committedAt === null || r.paidAt !== null, `${step}: committed without payment`);
        seen.push(`${step}:${r.status}`);
      }
    };
    const id = await lanRequests(w);
    check('create');
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' });
    check('invite');
    if (res.kind !== 'payment') throw new Error(res.kind);
    await w.pay(res.instructions.paymentId);
    check('pay');
    await answerInstantOffer(w.deps, { uid: 'p2' }, { offerId: offerOf(w, 'p2', id), action: 'decline' });
    await accept(w, 'p1', id);
    check('accept');
    await cancelInstantRequest(w.deps, { uid: 'p1' }, { requestId: id, dryRun: false });
    check('photographer cancel');
    await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p3'], skipped: [], expectedAmountVnd: 0 });
    check('second round');
    await accept(w, 'p3', id);
    for (const action of ['start_route', 'arrive', 'start', 'finish']) await job(w, 'p3', id, action, { location: HERE });
    check('finish');
    await confirmInstantComplete(w.deps, LAN, { requestId: id });
    w.clock.advance(3 * 60 * MIN);
    await runInstantSweep(w.deps);
    check('done');
    assert.equal(req(w, id).status, 'completed');
    assert.equal(w.store.payments.size, 1);
    assert.equal(w.store.refunds.size, 0);
    assert.ok(seen.includes('invite:pending_payment'));
  });
});

describe('money (#202)', () => {
  const paymentOf = (w: InstantWorld, id: string): Payment => {
    const p = w.store.payments.get(req(w, id).paymentId ?? '');
    assert.ok(p, `payment of ${id}`);
    return p;
  };
  const transfer = (p: Payment, kind: 'exact' | 'over', receivedAt: Date) =>
    fakeTransferFor(p as Payment & { transferCode: string }, kind, receivedAt);
  /** Lan's request with an open payment for p1 (first invite, unpaid). */
  const unpaid = async (w: InstantWorld): Promise<string> => {
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' });
    assert.equal(res.kind, 'payment');
    return id;
  };
  const ledgerOf = (w: InstantWorld, paymentId: string) =>
    [...w.store.ledger.values()].filter((e) => e.paymentId === paymentId);

  test('payment window passes: choosing, then a late transfer refunds 100% (late_payment)', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    const payment = paymentOf(w, id);
    w.clock.set(at(16 * MIN));
    assert.deepEqual(await tickInstantRequest(w.deps, LAN, { requestId: id }), { status: 'choosing' });
    assert.deepEqual(req(w, id).pendingInviteIds, []);
    // The bank received it in time; the notification arrives after the window.
    const n = transfer(payment, 'exact', at(14 * MIN));
    assert.deepEqual(await settleTransfer(w.settlement, n), { outcome: 'refunded', paymentId: payment.id });
    const r = req(w, id);
    assert.equal(r.status, 'choosing');
    assert.equal(r.paidAt, null);
    assert.equal(r.committedAt, null);
    assert.equal(w.store.offers.size, 0);
    const refunds = [...w.store.refunds.values()];
    assert.deepEqual(refunds.map((x) => [x.reason, x.amount, x.percent, x.fromEscrow]), [['late_payment', 690_000, 100, true]]);
    assert.equal(paymentOf(w, id).status, 'refunded');
    assert.deepEqual([r.refundId, r.refundStatus], [refunds[0]?.id, 'done']);
    // A transfer after the window closed is sent straight back by #129's rules.
    const late = { ...transfer(payment, 'exact', at(16 * MIN)), txnId: 'late_2' };
    assert.equal((await settleTransfer(w.settlement, late)).outcome, 'refunded');
  });

  test('payment confirmed after cancel is refunded in full', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    const out = await w.pay(req(w, id).paymentId ?? '');
    assert.deepEqual(out, { outcome: 'refunded', subjectType: 'instant_request', paymentStatus: 'refunded', subjectStatus: 'cancelled_by_customer' });
    const refund = [...w.store.refunds.values()][0];
    assert.deepEqual([refund?.reason, refund?.amount, refund?.status], ['late_payment', 690_000, 'done']);
    assert.deepEqual(w.gateway.refundCalls, [refund?.id]);
    const r = req(w, id);
    assert.deepEqual([r.status, r.paidAt, r.committedAt, r.refundId], ['cancelled_by_customer', null, null, refund?.id]);
    assert.equal(w.store.offers.size, 0);
    const sum = ledgerOf(w, refund?.paymentId ?? '').reduce((s, e) => s + e.amount, 0);
    assert.equal(sum, 0);
  });

  test('offers after payment carry the price list the customer paid for, even if the config moved', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    // A new price list went live while Lan was paying; nobody accepted it yet.
    w.config = aConfig({ priceListVersion: 2, cities: aConfig().cities.map((c) => ({ ...c, surgeBp: 12_000 })) });
    await w.pay(req(w, id).paymentId ?? '');
    const r = req(w, id);
    assert.equal(r.status, 'searching');
    assertRows(w, id, ['p1'], []);
    const offer = w.store.offer('p1', offerOf(w, 'p1', id));
    assert.deepEqual([offer?.earningVnd, r.amountVnd, r.priceListVersion], [690_000, 690_000, 1]);
  });

  test('a choice changed after the plain reads is checked again, never marked unavailable for it', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w); // p1 chosen
    const payment = paymentOf(w, id);
    // The settler's first (plain) read sees p1; before its transaction a second tap chose p2.
    let calls = 0;
    const store = w.deps.store;
    const racing = {
      ...w.deps,
      store: {
        findDue: store.findDue.bind(store),
        runTransaction: <T>(fn: Parameters<typeof store.runTransaction<T>>[0]) => {
          calls += 1;
          if (calls === 2) w.store.requests.set(id, { ...req(w, id), pendingInviteIds: ['p2'] });
          return store.runTransaction(fn);
        },
      },
    };
    assert.equal(await new InstantPaymentSettler(racing).settle(payment.id, transfer(payment, 'exact', T0)), 'paid');
    assertRows(w, id, ['p2'], []);
    assert.equal(w.store.offersOf('p2').length, 1);
    assert.equal(w.store.offersOf('p1').length, 0);
  });

  test('a refund whose outcome cannot be stored after the commit leaves the cancel done and the refund pending', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    let calls = 0;
    const store = w.deps.store;
    const flaky = {
      ...w.deps,
      store: {
        findDue: store.findDue.bind(store),
        runTransaction: <T>(fn: Parameters<typeof store.runTransaction<T>>[0]) => {
          calls += 1;
          // 1: the cancel; 2: storing the refund's outcome.
          if (calls === 2) return Promise.reject(new Error('firestore unavailable'));
          return store.runTransaction(fn);
        },
      },
    };
    const res = await cancelInstantRequest(flaky, LAN, { requestId: id, dryRun: false });
    assert.equal(res.status, 'cancelled_by_customer');
    const refund = [...w.store.refunds.values()][0];
    assert.equal(refund?.status, 'pending');
    assert.equal(w.gateway.refundCalls.length, 1);
    assert.equal(req(w, id).refundStatus, 'pending');
  });

  test('the same transaction id applies once', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    const n = transfer(paymentOf(w, id), 'exact', T0);
    assert.equal((await settleTransfer(w.settlement, n)).outcome, 'paid');
    assert.equal((await settleTransfer(w.settlement, n)).outcome, 'duplicate');
    assert.equal(ledgerOf(w, paymentOf(w, id).id).length, 1);
    assert.equal(w.store.offersOf('p1').length, 1);
  });

  test('a webhook transfer for an instant payment is settled through SettlementDeps.subjects, not unmatched', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    const p = paymentOf(w, id);
    const n = { provider: 'fake' as const, txnId: 'bank_123', amount: 690_000, content: `CK ${p.transferCode} Lan`, receivedAt: T0.toISOString() };
    assert.deepEqual(await settleTransfer(w.settlement, n), { outcome: 'paid', paymentId: p.id });
    assert.equal(w.store.transferRecords.get(transferRecordId(n))?.outcome, 'paid');
    assert.equal(req(w, id).status, 'searching');
  });

  test('an over transfer refunds the excess', async () => {
    const w = createInstantWorld();
    const id = await unpaid(w);
    const out = await w.pay(req(w, id).paymentId ?? '', 'c-lan', 'over');
    assert.equal(out.outcome, 'paid_with_refund');
    const refunds = [...w.store.refunds.values()];
    assert.deepEqual(refunds.map((x) => [x.reason, x.amount, x.fromEscrow, x.status]), [['overpaid_excess', 50_000, false, 'done']]);
    const p = paymentOf(w, id);
    assert.deepEqual([p.status, p.escrowStatus, p.receivedAmount], ['paid', 'held', 690_000]);
    assert.equal(req(w, id).status, 'searching');
    // The excess never entered escrow, so the request mirrors no refund.
    assert.equal(req(w, id).refundId, null);
  });

  test("a throwing refund stays pending and is re-sent by V2's re-send, not by runInstantSweep", async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.gateway.refundThrowCount = 1;
    await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    const refund = [...w.store.refunds.values()][0];
    assert.ok(refund);
    assert.deepEqual([refund.status, refund.attempts, refund.manual], ['pending', 1, false]);
    assert.equal(req(w, id).refundStatus, 'pending');
    const calls = w.gateway.refundCalls.length;
    w.clock.advance(HOUR);
    await runInstantSweep(w.deps);
    assert.equal(w.gateway.refundCalls.length, calls);
    const resent = await instantRefundHandler(w.deps).resend(refund);
    assert.equal(resent.status, 'done');
    assert.deepEqual(w.gateway.refundCalls, [refund.id, refund.id]);
    assert.equal(w.gateway.issuedRefunds.get(refund.id), 690_000);
    assert.equal(req(w, id).refundStatus, 'done');
  });

  test('customer cancel in each state applies the Decision 9 percent and writes refund + ledger lines that sum to the amount', async () => {
    type Case = { name: string; setup: (w: InstantWorld, id: string) => Promise<void>; rule: string; percent: number };
    const assign = (w: InstantWorld, id: string) => accept(w, 'p1', id).then(() => undefined);
    const enRoute = async (w: InstantWorld, id: string) => {
      await assign(w, id);
      await job(w, 'p1', id, 'start_route', { location: HERE });
    };
    const cases: Case[] = [
      { name: 'searching', setup: async () => undefined, rule: 'full_refund', percent: 100 },
      { name: 'no_match', setup: async (w) => { w.clock.set(at(10 * MIN)); }, rule: 'full_refund', percent: 100 },
      { name: 'free window', setup: async (w, id) => { await assign(w, id); w.clock.advance(MIN); }, rule: 'free_window', percent: 100 },
      { name: 'en_route', setup: async (w, id) => { await enRoute(w, id); w.clock.set(at(5 * MIN)); }, rule: 'en_route', percent: 80 },
      { name: 'late', setup: async (w, id) => { await enRoute(w, id); w.clock.set(at(19 * MIN)); }, rule: 'photographer_late', percent: 100 },
      {
        name: 'arrived',
        setup: async (w, id) => { await enRoute(w, id); await job(w, 'p1', id, 'arrive', { location: HERE }); w.clock.set(at(6 * MIN)); },
        rule: 'arrived', percent: 50,
      },
    ];
    for (const c of cases) {
      const w = createInstantWorld();
      const id = await lanInvites(w, ['p1']);
      await c.setup(w, id);
      const quote = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: true });
      const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false, expectedRule: quote.rule, expectedRefundVnd: quote.refundVnd });
      assert.equal(res.rule, c.rule, c.name);
      assert.equal(res.refundPercent, c.percent, c.name);
      assert.equal(res.refundVnd + res.feeVnd, 690_000, c.name);
      const p = paymentOf(w, id);
      const refunds = [...w.store.refunds.values()];
      assert.deepEqual(refunds.map((x) => [x.amount, x.percent, x.reason, x.fromEscrow]), [[res.refundVnd, c.percent, c.rule, true]], c.name);
      const lines = ledgerOf(w, p.id);
      assert.deepEqual(lines.map((e) => e.type), ['payment_received', 'refund_issued'], c.name);
      // What stays in escrow for the photographer is exactly the fee.
      assert.equal(lines.reduce((s, e) => s + e.amount, 0), res.feeVnd, c.name);
      if (res.feeVnd > 0) {
        assert.equal(p.releaseAfter, new Date(w.clock.now().getTime() + 24 * HOUR).toISOString(), c.name);
        assert.deepEqual([p.status, p.escrowStatus, p.payeeId], ['partially_refunded', 'partially_refunded', 'p1'], c.name);
      } else {
        assert.equal(p.releaseAfter, undefined, c.name);
        assert.deepEqual([p.status, p.escrowStatus], ['refunded', 'refunded'], c.name);
      }
      const r = req(w, id);
      assert.deepEqual([r.refundId, r.refundStatus, r.feeVnd, r.refundPercent], [refunds[0]?.id, 'done', res.feeVnd, c.percent], c.name);
    }
  });

  test('a real cancel whose quote changed since the dry run is conflict and moves no money', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    const quote = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: true });
    assert.equal(quote.rule, 'free_window');
    w.clock.set(at(3 * MIN)); // the 2-minute free window ended between the sheet and the tap
    await assert.rejects(
      cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false, expectedRule: quote.rule, expectedRefundVnd: quote.refundVnd }),
      code('conflict'),
    );
    assert.equal(req(w, id).status, 'assigned');
    assert.equal(w.store.refunds.size, 0);
  });

  test('confirm complete stamps releaseAfter + 24 h and frees the photographer', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    for (const action of ['start_route', 'arrive', 'start']) await job(w, 'p1', id, action, { location: HERE });
    w.clock.advance(40 * MIN);
    await confirmInstantComplete(w.deps, LAN, { requestId: id });
    const p = paymentOf(w, id);
    assert.equal(p.releaseAfter, at(40 * MIN + 24 * HOUR).toISOString());
    assert.deepEqual([p.status, p.escrowStatus, p.payeeId], ['paid', 'held', 'p1']);
    assert.equal(w.store.presences.get('p1')?.activeRequestId, null);
    assert.equal(w.store.refunds.size, 0);
  });

  test('auto-complete 2 h after finish stamps releaseAfter', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    for (const action of ['start_route', 'arrive', 'start', 'finish']) await job(w, 'p1', id, action, { location: HERE });
    w.clock.advance(2 * HOUR);
    await runInstantSweep(w.deps);
    const r = req(w, id);
    assert.equal(r.status, 'completed');
    assert.deepEqual(r.completedAt, at(2 * HOUR));
    assert.equal(paymentOf(w, id).releaseAfter, at(26 * HOUR).toISOString());
  });

  test('sweep never sends a refund', async () => {
    const w = createInstantWorld();
    const searching = await lanInvites(w, ['p1']);
    w.customer('c-mai', { name: 'Mai' });
    const mai = { uid: 'c-mai' };
    const other = (await createInstantRequest(w.deps, mai, { packageCode: 'p30', genre: 'family', meetPoint: MEET })).requestId;
    await inviteInstant(w.deps, mai, { requestId: other, photographerIds: ['p2'], skipped: [], expectedAmountVnd: 390_000, payMethod: 'momo' });
    for (const ms of [61 * SEC, 10 * MIN, 31 * MIN, 3 * HOUR]) {
      w.clock.set(at(ms));
      await runInstantSweep(w.deps);
    }
    assert.equal(req(w, searching).status, 'no_match');
    assert.equal(req(w, other).status, 'abandoned');
    assert.equal(w.store.refunds.size, 0);
    assert.equal(w.gateway.refundCalls.length, 0);
    assert.equal(paymentOf(w, searching).escrowStatus, 'held');
  });
});
