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
import * as allExports from '../../src/index.js';
import { CALLABLE_OPTIONS, CONTENDED_CALLABLE_OPTIONS, PAYOUT_ACCOUNT_KEY } from '../../src/config.js';
import { liveSettlementDeps } from '../../src/infra/live_payments.js';
import { liveRefundSubjects } from '../../src/infra/live_refunds.js';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { TEST_CIPHER, captureLogs } from './support/payment_world.js';
import {
  handleAnswerInstantOffer,
  handleCancelInstantRequest,
  handleCheckInstantPayment,
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
import { instantCloudLog, liveInstantDeps } from '../../src/infra/live_instant.js';
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

/** A `demo-*` emulator: with the dev project, where the fake checkout gateway is available (payments on). */
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

/** The secret names a deployed callable binds (firebase-functions v2 `__endpoint`). */
const secretsOf = (fn: unknown): string[] =>
  ((fn as { __endpoint?: { secretEnvironmentVariables?: { key: string }[] } }).__endpoint?.secretEnvironmentVariables ?? [])
    .map((s) => s.key);

describe('instant callable options', () => {
  it('CONTENDED_CALLABLE_OPTIONS has the 30 s of the contended transactions and no secrets', () => {
    assert.equal(CONTENDED_CALLABLE_OPTIONS.timeoutSeconds, 30);
    assert.equal(CONTENDED_CALLABLE_OPTIONS.region, CALLABLE_OPTIONS.region);
    assert.equal('secrets' in CONTENDED_CALLABLE_OPTIONS, false);
  });

  it('the callables that move money bind PAYOUT_ACCOUNT_KEY (#202); answerInstantOffer stays without secrets', () => {
    for (const name of ['inviteInstant', 'checkInstantPayment', 'cancelInstantRequest', 'confirmInstantComplete', 'updateInstantJob'] as const) {
      assert.deepEqual(secretsOf(allExports[name]), [PAYOUT_ACCOUNT_KEY.name], name);
    }
    assert.deepEqual(secretsOf(allExports.answerInstantOffer), []);
  });

  it('instant_request is registered in V1 settlement and V2 refund subjects', () => {
    assert.ok(liveSettlementDeps().subjects.instant_request !== undefined);
    const handler = liveRefundSubjects().instant_request;
    assert.equal(typeof handler?.resend, 'function');
    assert.equal(typeof handler?.record, 'function');
  });
});

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
      (r, d) => handleCheckInstantPayment(r, { ...d, settlement: createInstantWorld().settlement }), handleCancelInstantRequest, handleConfirmInstantComplete, handleTickInstantRequest, handleSetLiveShutter,
      handleSaveInstantSettings, handleAnswerInstantOffer, handleUpdateInstantJob,
    ];
    for (const handle of handlers) await refused(handle(anonymous, w.deps), 'unauthenticated', 'permission_denied');
    assert.equal(w.store.commits, 0);
  });

  it("inviteInstant returns V1's flat PaymentInstructions (bank_qr has transferCode and qrPayload)", async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const amount = w.store.requests.get(requestId)?.amountVnd;
    const res = await handleInviteInstant(
      as(LAN.uid, { requestId, photographerIds: ['p1', 'p2'], skipped: [], expectedAmountVnd: amount, payMethod: 'bank_qr' }),
      w.deps,
      DEMO_ENV,
    );
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    assert.equal(res.amountVnd, 690_000);
    const i = res.instructions;
    assert.deepEqual([i.subjectType, i.subjectId, i.method, i.amount], ['instant_request', requestId, 'bank_qr', 690_000]);
    assert.match(i.transferCode, /^PB [2-9A-Z]{6}$/);
    assert.match(i.qrPayload ?? '', /^000201/);
    assert.equal(typeof i.expiresAt, 'string');
    assert.equal(w.store.requests.get(requestId)?.status, 'pending_payment');
    assert.equal(w.store.offers.size, 0);
    // The flat shape is what a callable returns: JSON round trip keeps every field.
    assert.deepEqual(JSON.parse(JSON.stringify(res)), res);
  });

  it('inviteInstant in payments-off mode is not_eligible', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const data = { requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' };
    for (const env of [{ GCLOUD_PROJECT: 'booking-prod' }, { GCLOUD_PROJECT: 'demo-nag' }, { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'other' }]) {
      await refused(handleInviteInstant(as(LAN.uid, data), w.deps, env), 'failed-precondition', 'not_eligible');
    }
    assert.equal(w.store.payments.size, 0);
    assert.equal(w.store.requests.get(requestId)?.status, 'choosing');
    // The dev project has the fake checkout gateway.
    const res = await handleInviteInstant(as(LAN.uid, data), w.deps, { GCLOUD_PROJECT: 'booking-c1922' });
    assert.equal(res.kind, 'payment');
  });

  it('checkInstantPayment maps to the payer only', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    const res = await handleInviteInstant(
      as(LAN.uid, { requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr' }),
      w.deps,
      DEMO_ENV,
    );
    assert.equal(res.kind, 'payment');
    const deps = { ...w.deps, settlement: w.settlement };
    assert.deepEqual(await handleCheckInstantPayment(as(LAN.uid, { requestId }), deps), { paid: false, status: 'pending_payment' });
    await refused(handleCheckInstantPayment(as('p1', { requestId }), deps), 'permission-denied', 'permission_denied');
    await refused(handleCheckInstantPayment(as(LAN.uid, { requestId: 'ir_missing' }), deps), 'not-found', 'not_found');
    if (res.kind === 'payment') await w.pay(res.instructions.paymentId);
    assert.deepEqual(await handleCheckInstantPayment(as(LAN.uid, { requestId }), deps), { paid: true, status: 'searching' });
  });

  it('liveInstantDeps wires the gateway, the payment lookup and the cipher (#202)', () => {
    const deps = liveInstantDeps();
    assert.equal(deps.gateway.provider, 'fake');
    assert.ok(deps.payments);
    assert.equal(typeof deps.cipher.encrypt, 'function');
  });

  it('liveInstantDeps logs failed refund sends as a count only (#202)', async (t) => {
    assert.equal(liveInstantDeps().log, instantCloudLog);
    const lines = await captureLogs(t, async () => instantCloudLog.refundSendsFailed(2));
    const line = lines.find((l) => l.includes('instant refund sends failed'));
    assert.ok(line, lines.join(''));
    assert.match(line, /"count":2/);
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
