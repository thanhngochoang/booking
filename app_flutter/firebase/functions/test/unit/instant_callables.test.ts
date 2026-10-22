import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  FakeBlockGate,
  FakePaymentGateway,
  MemoryAddonStore,
  MemoryBookingStore,
  type BookingDeps,
  type InstantDeps,
} from '@photobooking/domain';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { TEST_CIPHER, captureLogs } from './support/payment_world.js';
import {
  handleAnswerInstantOffer,
  handleCancelInstantRequest,
  handleConfirmInstantComplete,
  handleCreateInstantRequest,
  handleInviteInstant,
  handleNextInstantCandidates,
  handleSaveInstantSettings,
  handleSetLiveShutter,
  handleTickInstantRequest,
  handleUpdateInstantJob,
  type InstantCallableInput,
} from '../../src/callables/instant.js';
import { liveInstantDeps } from '../../src/infra/live_instant.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import {
  LAN,
  MEET,
  createInstantWorld,
  lanInvites,
  lanRequests,
  offerOf,
  type InstantWorld,
} from '../../../../../packages/domain/test/support/instant_world.js';
import { TAO_DAN, north } from '../../../../../packages/domain/test/support/instant_fixtures.js';

/** A `demo-*` emulator: the only place (with the dev project) where #140's free dispatch runs. */
const DEMO_ENV = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' };

const as = (uid: string, data: unknown): InstantCallableInput => ({ auth: { uid }, data });

/** Asserts an HttpsError with the transport code and `details.code`. */
async function refused(p: Promise<unknown>, transport: string, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof HttpsError, String(e));
    assert.equal(e.code, transport);
    assert.equal((e.details as { code?: string }).code, code);
    return true;
  });
}

async function accepted(w: InstantWorld, uid: string, requestId: string): Promise<void> {
  const res = await handleAnswerInstantOffer(as(uid, { offerId: offerOf(w, uid, requestId), action: 'accept' }), w.deps);
  assert.equal(res.outcome, 'accepted');
}

describe('instant callables', () => {
  it('createInstantRequest maps phone_required to failed-precondition with details.code', async () => {
    const w = createInstantWorld();
    w.customer('c-minh', { phone: null });
    await refused(
      handleCreateInstantRequest(as('c-minh', { packageCode: 'p60', genre: 'portrait', meetPoint: MEET }), w.deps),
      'failed-precondition',
      'phone_required',
    );
    assert.equal(w.store.requests.size, 0);
  });

  it('outside_service_area maps to failed-precondition', async () => {
    const w = createInstantWorld();
    const farAway = { lat: 13.7563, lng: 100.5018, name: 'Bangkok' };
    await refused(
      handleCreateInstantRequest(as(LAN.uid, { packageCode: 'p60', genre: 'portrait', meetPoint: farAway }), w.deps),
      'failed-precondition',
      'outside_service_area',
    );
  });

  it('createInstantRequest answers the request id, price and round', async () => {
    const w = createInstantWorld();
    const res = await handleCreateInstantRequest(as(LAN.uid, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET }), w.deps);
    assert.equal(res.amountVnd, 690_000);
    assert.equal(res.round, 1);
    assert.equal(res.candidateCount, 5);
    assert.ok(w.store.requests.has(res.requestId));
  });

  it('unauthenticated calls are refused', async () => {
    const w = createInstantWorld();
    const anonymous: InstantCallableInput = { data: {} };
    const handlers: Array<(r: InstantCallableInput, d: InstantDeps) => Promise<unknown>> = [
      handleCreateInstantRequest, handleNextInstantCandidates, (r, d) => handleInviteInstant(r, d, DEMO_ENV),
      handleCancelInstantRequest, handleConfirmInstantComplete, handleTickInstantRequest, handleSetLiveShutter,
      handleSaveInstantSettings, handleAnswerInstantOffer, handleUpdateInstantJob,
    ];
    for (const handle of handlers) await refused(handle(anonymous, w.deps), 'unauthenticated', 'permission_denied');
    assert.equal(w.store.commits, 0);
  });

  it('inviteInstant returns invited rows', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const amount = w.store.requests.get(requestId)?.amountVnd;
    const res = await handleInviteInstant(
      as(LAN.uid, { requestId, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: amount }),
      w.deps,
      DEMO_ENV,
    );
    assert.deepEqual(res, { kind: 'invited', invited: ['p1', 'p2'], unavailable: [] });
    assert.equal(w.store.requests.get(requestId)?.status, 'searching');
    assert.equal(w.store.offersOf('p1').length, 1);
  });

  it('inviteInstant outside the dev project or a demo emulator is not_eligible', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const data = { requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000 };
    for (const env of [{ GCLOUD_PROJECT: 'booking-prod' }, { GCLOUD_PROJECT: 'demo-nag' }, { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'other' }]) {
      await refused(handleInviteInstant(as(LAN.uid, data), w.deps, env), 'failed-precondition', 'not_eligible');
    }
    assert.equal(w.store.offers.size, 0);
    assert.equal(w.store.requests.get(requestId)?.status, 'choosing');
    // The dev project runs it.
    const res = await handleInviteInstant(as(LAN.uid, data), w.deps, { GCLOUD_PROJECT: 'booking-c1922' });
    assert.equal(res.kind, 'invited');
  });

  it('liveInstantDeps wires a BlockGate', () => {
    const deps = liveInstantDeps();
    assert.ok(deps.blocks instanceof FirestoreBlockGate);
    assert.ok(deps.providers);
    assert.ok(deps.days);
  });

  it('answerInstantOffer offer_expired and already_assigned keep their codes', async () => {
    const late = createInstantWorld();
    const r1 = await lanInvites(late, ['p1']);
    late.clock.advance(60_500);
    await refused(
      handleAnswerInstantOffer(as('p1', { offerId: offerOf(late, 'p1', r1), action: 'accept' }), late.deps),
      'failed-precondition',
      'offer_expired',
    );

    const race = createInstantWorld();
    const r2 = await lanInvites(race, ['p1', 'p2']);
    await accepted(race, 'p1', r2);
    await refused(
      handleAnswerInstantOffer(as('p2', { offerId: offerOf(race, 'p2', r2), action: 'accept' }), race.deps),
      'failed-precondition',
      'already_assigned',
    );
  });

  it('updateInstantJob passes force and location through', async () => {
    const w = createInstantWorld();
    const requestId = await lanInvites(w, ['p1']);
    await accepted(w, 'p1', requestId);
    const route = await handleUpdateInstantJob(
      as('p1', { requestId, action: 'start_route', location: { ...north(TAO_DAN, 0.5), accuracyM: 20 } }),
      w.deps,
    );
    assert.equal(route.status, 'en_route');
    assert.equal(w.store.tracks.get(requestId)?.accuracyM, 20);
    // 1 km away with a poor fix: refused without force, accepted with it.
    const far = { ...north(TAO_DAN, 1), accuracyM: 150 };
    await refused(
      handleUpdateInstantJob(as('p1', { requestId, action: 'arrive', location: far }), w.deps),
      'failed-precondition',
      'not_eligible',
    );
    const res = await handleUpdateInstantJob(as('p1', { requestId, action: 'arrive', location: far, force: true }), w.deps);
    assert.equal(res.status, 'arrived');
    assert.equal(w.store.requests.get(requestId)?.forcedArrivalAccuracyM, 150);
    await refused(handleUpdateInstantJob(as('p1', { requestId, action: 'fly' }), w.deps), 'invalid-argument', 'invalid_argument');
  });

  it('setLiveShutter returns reasons, not an error', async () => {
    const w = createInstantWorld();
    const res = await handleSetLiveShutter(
      as('p-new', { online: true, location: { ...TAO_DAN, accuracyM: 20 } }),
      w.deps,
    );
    assert.deepEqual(res, { online: false, reasons: ['not_accepting_orders', 'phone_required', 'price_list_not_accepted'] });
    assert.equal(w.store.presences.has('p-new'), false);
  });

  it('cancel, tick and confirm answer the domain results', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const quote = await handleCancelInstantRequest(as(LAN.uid, { requestId, dryRun: true }), w.deps);
    assert.equal(quote.rule, 'unpaid');
    assert.equal(quote.status, 'choosing');
    assert.deepEqual(await handleTickInstantRequest(as(LAN.uid, { requestId }), w.deps), { status: 'choosing' });
    await refused(handleTickInstantRequest(as('p9', { requestId }), w.deps), 'permission-denied', 'permission_denied');
    await refused(handleConfirmInstantComplete(as(LAN.uid, { requestId }), w.deps), 'aborted', 'conflict');
  });
});

describe('bookingClock instantSweep step', () => {
  function bookingDeps(now: Date): BookingDeps {
    return {
      store: new MemoryBookingStore(),
      services: { getService: async () => null },
      addons: new MemoryAddonStore(),
      contacts: { get: async () => null },
      providers: { acceptsOrders: async () => true, orderProfile: async () => ({ acceptsOrders: true, providerType: 'individual' }) },
      blocks: new FakeBlockGate(),
      gateway: new FakePaymentGateway(),
      cipher: TEST_CIPHER,
      clock: { now: () => now },
      ids: { newId: () => '01ARZ3NDEKTSV4RRFFQ69G5F01' },
    };
  }

  it('settles a due request nobody is looking at (offers expired → round ended)', async () => {
    const w = createInstantWorld();
    const requestId = await lanInvites(w, ['p1', 'p2']);
    w.clock.advance(61_000);
    await handleBookingClock(bookingDeps(w.clock.now()), undefined, { instant: w.deps });
    const r = w.store.requests.get(requestId);
    assert.equal(r?.status, 'choosing');
    assert.equal(r?.roundEnded, true);
    assert.equal(w.store.offersOf('p1')[0]?.outcome, 'expired');
  });

  it('a failing instant step is logged, not thrown, and the booking sweeps keep their result', async (t) => {
    const w = createInstantWorld();
    const broken: InstantDeps = {
      ...w.deps,
      store: { runTransaction: w.deps.store.runTransaction.bind(w.deps.store), findDue: async () => { throw new Error('index missing'); } },
    };
    let results: unknown;
    const lines = await captureLogs(t, async () => {
      results = await handleBookingClock(bookingDeps(w.clock.now()), undefined, { instant: broken });
    });
    assert.ok(results !== undefined);
    assert.ok(lines.some((l) => l.includes('bookingClock instantSweep failed')));
  });

  it('without extras.instant a test clock never reaches Firestore', async (t) => {
    const lines = await captureLogs(t, () => handleBookingClock(bookingDeps(new Date())));
    assert.ok(!lines.some((l) => l.includes('instantSweep')));
  });
});
