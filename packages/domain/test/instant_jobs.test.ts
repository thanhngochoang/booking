import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { chatIdFor } from '../src/chat.js';
import { DomainError } from '../src/errors.js';
import { encodeGeohash } from '../src/event.js';
import { FakeBlockGate } from '../src/fake_block_gate.js';
import { answerInstantOffer, saveInstantSettings, setLiveShutter, updateInstantJob } from '../src/instant_jobs.js';
import { cancelInstantRequest, createInstantRequest, inviteInstant, runInstantSweep } from '../src/instant_requests.js';
import { BEN_THANH, MIN, SEC, T0, TAO_DAN, aPresence, at, north } from './support/instant_fixtures.js';
import { createInstantWorld, lanInvites, offerOf, type InstantWorld } from './support/instant_world.js';

const code = (c: string) => (e: unknown) => e instanceof DomainError && e.code === c;

const req = (w: InstantWorld, id: string) => {
  const r = w.store.requests.get(id);
  assert.ok(r, `request ${id}`);
  return r;
};
const presence = (w: InstantWorld, uid: string) => {
  const p = w.store.presences.get(uid);
  assert.ok(p, `presence ${uid}`);
  return p;
};

const accept = (w: InstantWorld, uid: string, requestId: string) =>
  answerInstantOffer(w.deps, { uid }, { offerId: offerOf(w, uid, requestId), action: 'accept' });
const decline = (w: InstantWorld, uid: string, requestId: string) =>
  answerInstantOffer(w.deps, { uid }, { offerId: offerOf(w, uid, requestId), action: 'decline' });
const job = (w: InstantWorld, uid: string, requestId: string, action: string, extra: Record<string, unknown> = {}) =>
  updateInstantJob(w.deps, { uid }, { requestId, action, ...extra });

const HERE = { ...TAO_DAN, accuracyM: 10 };
const BANGKOK = { lat: 13.7563, lng: 100.5018, accuracyM: 10 };

/** p1 assigned to Lan's request (invited alone). */
async function assigned(w: InstantWorld): Promise<string> {
  const id = await lanInvites(w, ['p1']);
  await accept(w, 'p1', id);
  return id;
}

describe('Live Shutter and settings', () => {
  test('setLiveShutter dryRun lists reasons in order and writes nothing', async () => {
    const w = createInstantWorld();
    const commits = w.store.commits;
    const res = await setLiveShutter(w.deps, { uid: 'p7' }, { online: true, dryRun: true, location: BANGKOK });
    assert.deepEqual(res, {
      online: false,
      reasons: ['not_accepting_orders', 'phone_required', 'price_list_not_accepted', 'outside_service_area'],
    });
    assert.equal(w.store.presences.has('p7'), false);
    assert.equal(w.store.commits, commits);
    const ok = await setLiveShutter(w.deps, { uid: 'p1' }, { online: true, dryRun: true });
    assert.deepEqual(ok, { online: true, reasons: [] });
  });

  test('online needs a location (invalid_argument)', async () => {
    const w = createInstantWorld();
    await assert.rejects(setLiveShutter(w.deps, { uid: 'p1' }, { online: true }), code('invalid_argument'));
  });

  test('online outside the boxes is refused with outside_service_area', async () => {
    const w = createInstantWorld();
    const before = presence(w, 'p1');
    const res = await setLiveShutter(w.deps, { uid: 'p1' }, { online: true, location: BANGKOK });
    assert.deepEqual(res, { online: true, reasons: ['outside_service_area'] });
    assert.equal(presence(w, 'p1'), before);
  });

  test('online writes geohash5/4, heartbeat and a profile snapshot', async () => {
    const w = createInstantWorld();
    w.store.presences.set('p1', aPresence('p1', { online: false, lat: null, lng: null, heartbeatAt: null }));
    w.profiles.set('p1', { ...presence(w, 'p1').profile, name: 'Hà Trần', photos: ['a.jpg', 'b.jpg'] });
    w.clock.advance(5 * MIN);
    const res = await setLiveShutter(w.deps, { uid: 'p1' }, { online: true, location: { ...BEN_THANH, accuracyM: 12 } });
    assert.deepEqual(res, { online: true, reasons: [] });
    const p = presence(w, 'p1');
    assert.equal(p.online, true);
    assert.deepEqual([p.lat, p.lng, p.accuracyM], [BEN_THANH.lat, BEN_THANH.lng, 12]);
    assert.equal(p.geohash5, encodeGeohash(BEN_THANH.lat, BEN_THANH.lng, 5));
    assert.equal(p.geohash4, encodeGeohash(BEN_THANH.lat, BEN_THANH.lng, 4));
    assert.deepEqual(p.heartbeatAt, at(5 * MIN));
    assert.equal(p.cityId, 'hcm');
    assert.equal(p.profile.name, 'Hà Trần');
    assert.deepEqual(p.profile.photos, ['a.jpg', 'b.jpg']);
  });

  test('offline keeps an active job', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    assert.deepEqual(await setLiveShutter(w.deps, { uid: 'p1' }, { online: false }), { online: false, reasons: [] });
    const p = presence(w, 'p1');
    assert.equal(p.online, false);
    assert.equal(p.activeRequestId, id);
    assert.equal(req(w, id).status, 'assigned');
  });

  test('saveInstantSettings with an old version is price_changed', async () => {
    const w = createInstantWorld();
    await assert.rejects(saveInstantSettings(w.deps, { uid: 'p1' }, { acceptPriceListVersion: 0 }), code('price_changed'));
  });

  test('saveInstantSettings creates an offline presence for a provider and keeps the switch', async () => {
    const w = createInstantWorld();
    w.profiles.set('p7', aPresence('p7').profile);
    assert.deepEqual(await saveInstantSettings(w.deps, { uid: 'p7' }, { acceptPriceListVersion: 1, helpReady: true }),
      { priceListVersion: 1, helpReady: true });
    const p = presence(w, 'p7');
    assert.deepEqual([p.online, p.priceListVersion, p.helpReady, p.activeRequestId], [false, 1, true, null]);
    assert.deepEqual(await saveInstantSettings(w.deps, { uid: 'p7' }, { helpReady: false }), { priceListVersion: 1, helpReady: false });
    await assert.rejects(saveInstantSettings(w.deps, { uid: 'c-lan' }, { helpReady: true }), code('not_eligible'));
  });
});

describe('answerInstantOffer', () => {
  test('accept: assigned, round emptied, chatId set, no contact copy while the request is unpaid (assignment empties the round)', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2', 'p3']);
    w.clock.advance(20 * SEC);
    assert.deepEqual(await accept(w, 'p2', id), { outcome: 'accepted', requestId: id });
    const r = req(w, id);
    assert.equal(r.status, 'assigned');
    assert.deepEqual(r.candidates, []);
    assert.deepEqual(r.offers, []);
    assert.deepEqual(r.pendingInviteIds, []);
    assert.equal(r.photographerId, 'p2');
    assert.deepEqual(r.photographer, {
      id: 'p2', name: 'Nhiếp ảnh gia p2', avatarUrl: null, verified: true, tomatoPct: 0, reviewCount: 0, completedCount: 0,
    });
    assert.equal(r.chatId, chatIdFor('c-lan', 'p2'));
    assert.equal(r.etaMinutes, 5); // 1 km
    assert.deepEqual(r.assignedAt, at(20 * SEC));
    assert.deepEqual(r.freeCancelUntil, at(20 * SEC + 2 * MIN));
    assert.deepEqual(r.lateDeadlineAt, at(20 * SEC + 20 * MIN));
    assert.equal(r.nextDeadlineAt, null);
    assert.equal(w.store.contacts.size, 0);
    assert.equal(w.store.offer('p2', offerOf(w, 'p2', id))?.outcome, 'accepted');
    for (const uid of ['p1', 'p3']) {
      assert.equal(w.store.offer(uid, offerOf(w, uid, id))?.outcome, 'withdrawn');
      assert.deepEqual(presence(w, uid).pendingOffers, []);
    }
    const p = presence(w, 'p2');
    assert.deepEqual([p.activeRequestId, p.pendingOffers.length, p.reliability.accepted], [id, 0, 1]);
  });

  test('two accepts on one request: one winner', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    const results = await Promise.allSettled([accept(w, 'p1', id), accept(w, 'p2', id)]);
    const won = results.filter((x) => x.status === 'fulfilled');
    const lost = results.filter((x): x is PromiseRejectedResult => x.status === 'rejected');
    assert.equal(won.length, 1);
    assert.equal(lost.length, 1);
    assert.ok(code('already_assigned')(lost[0]?.reason));
    const winner = req(w, id).photographerId;
    const loser = winner === 'p1' ? 'p2' : 'p1';
    assert.equal(presence(w, loser).activeRequestId, null);
    assert.equal(presence(w, loser).reliability.accepted, 0);
    assert.equal(w.store.offer(loser, offerOf(w, loser, id))?.outcome, 'withdrawn');
  });

  test('one photographer, two requests: one accept', async () => {
    const w = createInstantWorld();
    const a = await lanInvites(w, ['p1']);
    w.customer('c-minh', { name: 'Minh' });
    const { requestId: b } = await createInstantRequest(w.deps, { uid: 'c-minh' },
      { packageCode: 'p30', genre: 'couple', meetPoint: { ...north(TAO_DAN, 0.3), name: 'Nhà thờ Đức Bà' } });
    await inviteInstant(w.deps, { uid: 'c-minh' }, { requestId: b, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 390_000 });
    assert.equal(presence(w, 'p1').pendingOffers.length, 2);
    const offerB = offerOf(w, 'p1', b);
    const results = await Promise.allSettled([
      accept(w, 'p1', a),
      answerInstantOffer(w.deps, { uid: 'p1' }, { offerId: offerB, action: 'accept' }),
    ]);
    assert.equal(results[0]?.status, 'fulfilled');
    assert.ok(results[1]?.status === 'rejected' && code('already_assigned')(results[1].reason));
    assert.equal(req(w, a).status, 'assigned');
    const rb = req(w, b);
    assert.deepEqual([rb.status, rb.roundEnded], ['choosing', true]);
    assert.equal(rb.offers[0]?.outcome, 'withdrawn');
    assert.equal(w.store.offer('p1', offerB)?.outcome, 'withdrawn');
    assert.equal(presence(w, 'p1').activeRequestId, a);
  });

  test('accept after expiry is offer_expired and the row reads expired', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    w.clock.set(new Date(T0.getTime() + 60_500));
    await assert.rejects(accept(w, 'p1', id), code('offer_expired'));
    const r = req(w, id);
    assert.deepEqual(r.offers.map((o) => o.outcome), ['expired', 'expired']);
    assert.equal(r.status, 'choosing');
    assert.equal(w.store.offer('p1', offerOf(w, 'p1', id))?.outcome, 'expired');
    assert.equal(presence(w, 'p1').activeRequestId, null);
  });

  test('revoked photographer cannot accept (not_accepting_orders)', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.gate.set('p1', { verified: true, onboardingComplete: false });
    await assert.rejects(accept(w, 'p1', id), code('not_accepting_orders'));
    assert.equal(req(w, id).status, 'searching');
  });

  test('a photographer blocked by the customer cannot accept (blocked)', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.blocks.block('c-lan', 'p1');
    await assert.rejects(accept(w, 'p1', id), code('blocked'));
    assert.equal(presence(w, 'p1').activeRequestId, null);
  });

  test('a photographer whose day just became a spot day cannot accept (not_eligible)', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1']);
    w.day('p1', 'spot');
    await assert.rejects(accept(w, 'p1', id), code('not_eligible'));
    assert.equal(req(w, id).status, 'searching');
  });

  test('an offer withdrawn by a customer cancel answers offer_expired to accept and decline', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    await cancelInstantRequest(w.deps, { uid: 'c-lan' }, { requestId: id, dryRun: false });
    await assert.rejects(accept(w, 'p1', id), code('offer_expired'));
    await assert.rejects(decline(w, 'p2', id), code('offer_expired'));
    assert.equal(presence(w, 'p1').activeRequestId, null);
  });

  test('an offer withdrawn because someone else won stays already_assigned on decline', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    await accept(w, 'p1', id);
    await assert.rejects(decline(w, 'p2', id), code('already_assigned'));
  });

  test('decline of the last pending row ends the round', async () => {
    const w = createInstantWorld();
    const id = await lanInvites(w, ['p1', 'p2']);
    assert.deepEqual(await decline(w, 'p1', id), { outcome: 'declined', requestId: id });
    assert.equal(req(w, id).status, 'searching');
    await decline(w, 'p2', id);
    const r = req(w, id);
    assert.deepEqual([r.status, r.roundEnded], ['choosing', true]);
    assert.deepEqual(r.offers.map((o) => o.outcome), ['declined', 'declined']);
    assert.deepEqual([...r.excludedIds].sort(), ['p1', 'p2']);
    assert.equal(w.store.offer('p2', offerOf(w, 'p2', id))?.outcome, 'declined');
    assert.deepEqual(presence(w, 'p2').pendingOffers, []);
    assert.equal(presence(w, 'p2').reliability.declined, 1);
  });
});

describe('updateInstantJob', () => {
  test('start_route creates the track; arrive within 200 m deletes it', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    const from = { ...north(TAO_DAN, 0.5), accuracyM: 15 };
    assert.deepEqual(await job(w, 'p1', id, 'start_route', { location: from }), { status: 'en_route' });
    assert.deepEqual(w.store.tracks.get(id), {
      customerId: 'c-lan', photographerId: 'p1', active: true, lat: from.lat, lng: from.lng, accuracyM: 15, heading: null, at: T0,
    });
    assert.deepEqual(req(w, id).startedRouteAt, T0);
    w.clock.advance(4 * MIN);
    assert.deepEqual(await job(w, 'p1', id, 'arrive', { location: { ...north(TAO_DAN, 0.15), accuracyM: 15 } }), { status: 'arrived' });
    assert.equal(w.store.tracks.has(id), false);
    const r = req(w, id);
    assert.deepEqual(r.arrivedAt, at(4 * MIN));
    assert.equal(r.forcedArrivalAccuracyM, null);
  });

  test('start_route needs a location', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await assert.rejects(job(w, 'p1', id, 'start_route'), code('invalid_argument'));
  });

  test('arrive at 350 m is not_eligible; with force and accuracy 150 m it passes and stores the accuracy', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    const far = north(TAO_DAN, 0.35);
    await assert.rejects(job(w, 'p1', id, 'arrive', { location: { ...far, accuracyM: 150 } }), code('not_eligible'));
    assert.equal(req(w, id).status, 'en_route');
    await job(w, 'p1', id, 'arrive', { location: { ...far, accuracyM: 150 }, force: true });
    const r = req(w, id);
    assert.equal(r.status, 'arrived');
    assert.equal(r.forcedArrivalAccuracyM, 150);
  });

  test('force with good accuracy is still not_eligible', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await assert.rejects(job(w, 'p1', id, 'arrive', { location: { ...north(TAO_DAN, 0.35), accuracyM: 30 }, force: true }), code('not_eligible'));
  });

  test('start sets shootEndsAt from the package', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await job(w, 'p1', id, 'arrive', { location: HERE });
    w.clock.advance(3 * MIN);
    assert.deepEqual(await job(w, 'p1', id, 'start'), { status: 'in_progress' });
    const r = req(w, id);
    assert.deepEqual(r.startedAt, at(3 * MIN));
    assert.deepEqual(r.shootEndsAt, at(63 * MIN));
    assert.deepEqual(r.nextDeadlineAt, at(63 * MIN));
    assert.deepEqual(await job(w, 'p1', id, 'finish'), { status: 'finished' });
    assert.deepEqual(req(w, id).finishedAt, at(3 * MIN));
  });

  test('no_show before 15 minutes is deadline_passed; after, no_show_customer with rule no_show recorded (zero money while unpaid)', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    await job(w, 'p1', id, 'arrive', { location: HERE });
    w.clock.advance(14 * MIN);
    await assert.rejects(job(w, 'p1', id, 'no_show'), code('deadline_passed'));
    w.clock.advance(MIN);
    assert.deepEqual(await job(w, 'p1', id, 'no_show'), { status: 'no_show_customer' });
    const r = req(w, id);
    assert.deepEqual([r.active, r.cancelRule, r.refundPercent, r.feeVnd], [false, 'no_show', 0, 0]);
    const p = presence(w, 'p1');
    assert.equal(p.activeRequestId, null);
    assert.deepEqual(p.reliability, { offers: 1, accepted: 1, declined: 0, expired: 0, cancelled: 0, late: 0, noShow: 0 });
    assert.equal(w.store.payments.size + w.store.refunds.size + w.store.ledger.size, 0);
  });

  test('photographer cancel returns the request to choosing, excludes them, clears contact and track, resets the 10-minute window', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await job(w, 'p1', id, 'start_route', { location: HERE });
    w.store.contacts.set(id, { name: 'Lan Anh', phone: '+84901234567', allowZalo: false, allowWhatsApp: false });
    w.clock.advance(5 * MIN);
    const res = await cancelInstantRequest(w.deps, { uid: 'p1' }, { requestId: id, dryRun: false });
    assert.deepEqual(res, { rule: 'unpaid', refundPercent: 0, refundVnd: 0, feeVnd: 0, amountVnd: 0, status: 'choosing' });
    const r = req(w, id);
    assert.equal(r.status, 'choosing');
    assert.ok(r.excludedIds.includes('p1'));
    assert.deepEqual([r.photographerId, r.photographer, r.chatId, r.etaMinutes, r.assignedAt, r.startedRouteAt], [null, null, null, null, null, null]);
    assert.equal(r.roundEnded, true);
    assert.equal(r.cancelledBy, 'photographer');
    assert.deepEqual(r.searchDeadlineAt, at(15 * MIN));
    assert.deepEqual(r.nextDeadlineAt, at(15 * MIN));
    assert.equal(w.store.contacts.has(id), false);
    assert.equal(w.store.tracks.has(id), false);
    const p = presence(w, 'p1');
    assert.deepEqual([p.activeRequestId, p.reliability.cancelled], [null, 1]);
    w.clock.set(at(15 * MIN));
    await runInstantSweep(w.deps);
    assert.equal(req(w, id).status, 'no_match');
  });

  test("the world's deps carry a BlockGate (blocks is set)", () => {
    const w = createInstantWorld();
    assert.ok(w.deps.blocks instanceof FakeBlockGate);
    assert.equal(w.deps.blocks, w.blocks);
  });

  test('an unrelated photographer cannot update the job (permission_denied)', async () => {
    const w = createInstantWorld();
    const id = await assigned(w);
    await assert.rejects(job(w, 'p2', id, 'start_route', { location: HERE }), code('permission_denied'));
    await assert.rejects(cancelInstantRequest(w.deps, { uid: 'p2' }, { requestId: id, dryRun: true }), code('permission_denied'));
    await assert.rejects(job(w, 'p1', id, 'fly', { location: HERE }), code('invalid_argument'));
  });
});
