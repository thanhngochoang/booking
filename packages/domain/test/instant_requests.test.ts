import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { DomainError } from '../src/errors.js';
import { answerInstantOffer, updateInstantJob } from '../src/instant_jobs.js';
import { offerPushMessage } from '../src/instant_notices.js';
import {
  cancelInstantRequest,
  confirmInstantComplete,
  createInstantRequest,
  inviteInstant,
  nextInstantCandidates,
  runInstantSweep,
  tickInstantRequest,
} from '../src/instant_requests.js';
import { MIN, SEC, T0, TAO_DAN, aConfig, at, north } from './support/instant_fixtures.js';
import { LAN, MEET, createInstantWorld, lanInvites, lanRequests, offerOf, type InstantWorld } from './support/instant_world.js';

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
  test('first invite sends the offers at once to the chosen people only, each with a 60 s expiry and a push, and sets committedAt (#140: no payment, no pending_payment)', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p3'], skipped: ['p2'], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p1', 'p3'], unavailable: [] });
    const r = req(w, id);
    assert.equal(r.status, 'searching');
    assert.deepEqual(r.committedAt, T0);
    assert.equal(r.paymentId, null);
    assert.equal(r.paidAt, null);
    assert.deepEqual(r.pendingInviteIds, []);
    assert.equal(r.invitedTotal, 2);
    assert.equal(r.roundsWithInvites, 1);
    assert.deepEqual(r.searchDeadlineAt, at(10 * MIN));
    assert.deepEqual(r.nextDeadlineAt, at(60 * SEC));
    assert.deepEqual(r.excludedIds, ['p2']);
    assert.deepEqual(r.offers.map((o) => [o.photographerId, o.outcome]), [['p1', 'pending'], ['p3', 'pending']]);
    for (const uid of ['p1', 'p3']) {
      const offer = w.store.offer(uid, offerOf(w, uid, id));
      assert.ok(offer);
      assert.deepEqual(offer.expiresAt, at(60 * SEC));
      assert.equal(offer.invitedCount, 2);
      assert.equal(offer.earningVnd, 690_000);
      assert.deepEqual(w.pushes.get(uid), [offerPushMessage(offer)]);
      const p = w.store.presences.get(uid);
      assert.deepEqual(p?.pendingOffers, [{ offerId: offer.id, requestId: id, expiresAt: at(60 * SEC) }]);
      assert.equal(p?.reliability.offers, 1);
    }
    assert.equal(w.store.offersOf('p2').length, 0);
    assert.equal(w.pushes.get('p2'), undefined);
    assert.equal(w.store.payments.size, 0);
  });

  test('price change returns price_changed with the new amount saved and nothing sent', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const cfg = aConfig();
    w.config = { ...cfg, priceListVersion: 2, cities: cfg.cities.map((c) => (c.id === 'hcm' ? { ...c, surgeBp: 12_000 } : c)) };
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'price_changed', amountVnd: 828_000 });
    const r = req(w, id);
    assert.equal(r.amountVnd, 828_000);
    assert.equal(r.earningVnd, 828_000);
    assert.equal(r.priceListVersion, 2);
    assert.equal(r.status, 'choosing');
    assert.equal(w.store.offers.size, 0);
    assert.equal(w.pushes.size, 0);
  });

  test('a stale expectedAmountVnd returns price_changed without a write', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const before = req(w, id);
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 600_000 });
    assert.deepEqual(res, { kind: 'price_changed', amountVnd: 690_000 });
    assert.equal(req(w, id), before);
    assert.equal(w.store.offers.size, 0);
  });

  test('invite when Chụp ngay was switched off is not_eligible', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.config = aConfig({ enabled: false });
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000 }),
      code('not_eligible'),
    );
    assert.equal(w.store.offers.size, 0);
  });

  test('excludedIds never reach an offer doc or a push', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p3'], skipped: ['p2', 'p4'], expectedAmountVnd: 690_000 });
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
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p6'], skipped: [], expectedAmountVnd: 690_000 }),
      code('not_eligible'),
    );
  });

  test('another customer cannot invite (permission_denied); 6 ids are invalid_argument', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    await assert.rejects(
      inviteInstant(w.deps, { uid: 'c-minh' }, { requestId: id, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000 }),
      code('permission_denied'),
    );
    await assert.rejects(
      inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], skipped: [], expectedAmountVnd: 690_000 }),
      code('invalid_argument'),
    );
  });

  test("a blocked invitee (#198's BlockGate through orderBlocker) is unavailable and not excluded", async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.blocks.block('p2', 'c-lan');
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p1'], unavailable: ['p2'] });
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
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p1'], unavailable: ['p2'] });
    assert.ok(!req(w, id).excludedIds.includes('p2'));
  });

  test('revoked photographer is unavailable at invite', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.gate.set('p2', { verified: false, onboardingComplete: true });
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p1'], unavailable: ['p2'] });
  });

  test('a photographer with 3 live pending offers is unavailable', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    const pending = [1, 2, 3].map((n) => ({ offerId: `o${n}`, requestId: `r${n}`, expiresAt: at(30 * SEC) }));
    w.online('p2', north(TAO_DAN, 1), { pendingOffers: pending });
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p2'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: [], unavailable: ['p2'] });
  });

  test('a photographer whose day became a spot or full day is unavailable at invite', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.day('p2', 'full');
    w.day('p3', 'spot');
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2', 'p3'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: ['p1'], unavailable: ['p2', 'p3'] });
  });

  test('all unavailable on the first invite: choosing with roundEnded and committedAt set', async () => {
    const w = createInstantWorld();
    const id = await lanRequests(w);
    w.blocks.block('c-lan', 'p1');
    w.gate.delete('p2');
    const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000 });
    assert.deepEqual(res, { kind: 'invited', invited: [], unavailable: ['p1', 'p2'] });
    const r = req(w, id);
    assert.equal(r.status, 'choosing');
    assert.equal(r.roundEnded, true);
    assert.deepEqual(r.committedAt, T0);
    assert.deepEqual(r.searchDeadlineAt, at(10 * MIN)); // settle can reach no_match
    assert.deepEqual(r.nextDeadlineAt, at(10 * MIN));
    assert.equal(r.invitedTotal, 0);
    assert.equal(w.store.offers.size, 0);
  });

  test('later round invites send at once', async () => {
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
  });

  test('search window ends in no_match', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.clock.advance(61 * SEC);
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'choosing');
    w.clock.set(at(10 * MIN));
    assert.equal((await tickInstantRequest(w.deps, LAN, { requestId: id })).status, 'no_match');
    assert.equal(req(w, id).active, true);
    assert.equal(w.store.refunds.size, 0);
  });
});

describe('cancel, confirm, tick', () => {
  test('customer cancel of an unpaid request records rule unpaid, zero money, frees an assigned photographer and withdraws the offers', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    assert.deepEqual(res, { rule: 'unpaid', refundPercent: 0, refundVnd: 0, feeVnd: 0, amountVnd: 0, status: 'cancelled_by_customer' });
    const r = req(w, id);
    assert.deepEqual([r.cancelRule, r.refundPercent, r.feeVnd, r.cancelledBy], ['unpaid', 0, 0, 'customer']);
    assert.deepEqual(r.cancelledAt, T0);
    assert.equal(r.active, false);
    assert.deepEqual(r.offers.map((o) => o.outcome), ['withdrawn', 'withdrawn']);
    for (const uid of ['p1', 'p2']) {
      assert.equal(w.store.offer(uid, offerOf(w, uid, id))?.outcome, 'withdrawn');
      assert.deepEqual(w.store.presences.get(uid)?.pendingOffers, []);
    }

    const w2 = createInstantWorld();
    const id2 = await lanInvites(w2, ['p1']);
    await accept(w2, 'p1', id2);
    assert.equal(w2.store.presences.get('p1')?.activeRequestId, id2);
    await cancelInstantRequest(w2.deps, LAN, { requestId: id2, dryRun: false });
    assert.equal(w2.store.presences.get('p1')?.activeRequestId, null);
    assert.equal(w2.store.presences.get('p1')?.reliability.late, 0);
    assert.equal(req(w2, id2).photographerId, 'p1');
    assert.equal(w2.store.payments.size + w2.store.refunds.size + w2.store.ledger.size, 0);
  });

  test('a customer cancel after lateDeadlineAt before arrival still counts reliability.late', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    await accept(w, 'p1', id);
    assert.deepEqual(req(w, id).lateDeadlineAt, at(18 * MIN)); // ETA 3 min + 15
    await job(w, 'p1', id, 'start_route', { location: HERE });
    w.clock.set(at(18 * MIN + SEC));
    const res = await cancelInstantRequest(w.deps, LAN, { requestId: id, dryRun: false });
    assert.equal(res.rule, 'unpaid');
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
    assert.deepEqual(res, { rule: 'unpaid', refundPercent: 0, refundVnd: 0, feeVnd: 0, amountVnd: 0, status: 'searching' });
    assert.equal(req(w, id), before);
    assert.equal(w.store.commits, commits);
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
    await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: 690_000 });
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

  test('no use case writes a payment, refund or ledger entry', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    await answerInstantOffer(w.deps, { uid: 'p2' }, { offerId: offerOf(w, 'p2', id), action: 'decline' });
    await accept(w, 'p1', id);
    await cancelInstantRequest(w.deps, { uid: 'p1' }, { requestId: id, dryRun: false });
    await nextInstantCandidates(w.deps, LAN, { requestId: id, skipped: [] });
    await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ['p3'], skipped: [], expectedAmountVnd: 0 });
    await accept(w, 'p3', id);
    for (const action of ['start_route', 'arrive', 'start', 'finish']) await job(w, 'p3', id, action, { location: HERE });
    await confirmInstantComplete(w.deps, LAN, { requestId: id });
    w.clock.advance(3 * 60 * MIN);
    await runInstantSweep(w.deps);
    assert.equal(req(w, id).status, 'completed');
    assert.equal(w.store.payments.size, 0);
    assert.equal(w.store.refunds.size, 0);
    assert.equal(w.store.ledger.size, 0);
    assert.equal(w.store.contacts.size, 0);
  });
});
