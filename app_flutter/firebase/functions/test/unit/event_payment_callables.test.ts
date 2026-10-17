import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  FakeBlockGate,
  FakePaymentGateway,
  MemoryBookingStore,
  MemoryEventStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type BookingDeps,
  type EventPaymentDeps,
} from '@photobooking/domain';
import {
  handleCancelEvent,
  handleCancelRegistration,
  handleCheckTicketPayment,
  handlePublishEvent,
  handleRegisterEvent,
  handleSaveEventDraft,
} from '../../src/callables/event.js';
import { handleConfirmFakePayment } from '../../src/callables/payment.js';
import * as allExports from '../../src/index.js';
import { CALLABLE_OPTIONS, DEV_PROJECT_ID, PAYMENT_CALLABLE_OPTIONS, currentProjectId } from '../../src/config.js';
import { assertFakePaymentsAllowed, fakePaymentsAllowed } from '../../src/infra/fake_payments.js';
import { handleEventClock, handleReleaseEventHolds } from '../../src/scheduled/event_clock.js';
import { MemoryPaymentLookup } from '../../../../../packages/domain/src/memory_payment_lookup.js';
import { TicketPaymentSettler } from '../../../../../packages/domain/src/event_payments.js';
import type { SettlementDeps } from '../../../../../packages/domain/src/payment_settlement.js';
import { TEST_CIPHER } from './support/payment_world.js';

const ID = (n: number): string => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n).padStart(2, '0')}`;
const EVENT_ID = ID(1);
const EMULATOR = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' };
const DEV = { GCLOUD_PROJECT: DEV_PROJECT_ID };
const PROD = { GCLOUD_PROJECT: 'booking-prod-1' };

const disabled = (e: unknown) =>
  e instanceof HttpsError && e.code === 'failed-precondition'
  && (e.details as { code?: string }).code === 'fake_payments_disabled';

describe('fake payment gate', () => {
  it('is allowed on the emulator with a demo-* or the dev project', () => {
    assert.equal(fakePaymentsAllowed(EMULATOR), true);
    assert.equal(fakePaymentsAllowed({ ...EMULATOR, GCLOUD_PROJECT: DEV_PROJECT_ID }), true);
  });

  it('FUNCTIONS_EMULATOR=true on another project id (or none) is refused', () => {
    assert.equal(fakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'booking-prod-1' }), false);
    assert.equal(fakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'true', FIREBASE_CONFIG: JSON.stringify({ projectId: 'booking-prod-1' }) }), false);
    assert.equal(fakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'true' }), false);
    assert.equal(fakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'nodemo-x' }), false);
    assert.throws(() => assertFakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'booking-prod-1' }), disabled);
  });

  it('is allowed on the dev project (GCLOUD_PROJECT or FIREBASE_CONFIG)', () => {
    assert.equal(fakePaymentsAllowed(DEV), true);
    assert.equal(fakePaymentsAllowed({ FIREBASE_CONFIG: JSON.stringify({ projectId: DEV_PROJECT_ID }) }), true);
    assert.equal(currentProjectId({ FIREBASE_CONFIG: 'not json' }), undefined);
  });

  it('is refused on any other project, and with no project at all', () => {
    assert.equal(fakePaymentsAllowed(PROD), false);
    assert.equal(fakePaymentsAllowed({}), false);
    assert.equal(fakePaymentsAllowed({ GCLOUD_PROJECT: 'demo-nag' }), false);
    assert.equal(fakePaymentsAllowed({ FUNCTIONS_EMULATOR: 'false', GCLOUD_PROJECT: 'booking-c1922-copy' }), false);
    assert.throws(() => assertFakePaymentsAllowed(PROD), disabled);
  });

  it('booking confirmFakePayment is refused on another project before any read', async () => {
    const store = new MemoryBookingStore();
    let reads = 0;
    const counting = new Proxy(store, {
      get(target, prop, receiver) {
        const v = Reflect.get(target, prop, receiver) as unknown;
        if (typeof v !== 'function') return v;
        return (...args: unknown[]) => {
          reads += 1;
          return (v as (...a: unknown[]) => unknown).apply(target, args);
        };
      },
    });
    const deps: BookingDeps = {
      store: counting,
      services: { getService: async () => null },
      addons: { listAddons: async () => [] },
      contacts: { get: async () => null },
      providers: { acceptsOrders: async () => true },
      blocks: new FakeBlockGate(),
      gateway: new FakePaymentGateway(),
      cipher: TEST_CIPHER,
      clock: { now: () => new Date('2026-10-01T10:00:00.000Z') },
      ids: { newId: () => 'id_1' },
    };
    await assert.rejects(handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: 'p1' } }, deps, PROD), disabled);
    assert.equal(reads, 0);
    // On the emulator the request reaches the domain (and is refused there: no such payment).
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: 'p1' } }, deps, EMULATOR),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });
});

describe('ticket payment callables', () => {
  let store: MemoryEventStore;
  let gateway: FakePaymentGateway;
  let next: number;
  let now: Date;

  const deps = (): EventPaymentDeps => {
    const d: EventPaymentDeps = {
      events: store,
      people: {
        photographer: async (uid) =>
          uid === 'ph1' ? { onboardingComplete: true, name: 'Lan', avatarUrl: null, verified: true } : null,
        user: async (uid) => ({ name: uid, avatarUrl: null }),
      },
      contacts: { get: async (uid) => (uid === 'cu1' || uid === 'cu2' ? { phone: '+84912000001' } : null) },
      media: { isOwnUpload: (url, path, uid, eventId) => path.startsWith(`eventCovers/${uid}/${eventId}/`) && url.endsWith(path) },
      clock: { now: () => now },
      ids: { newId: () => ID(next++) },
      random: (n) => Uint8Array.from({ length: n }, (_, i) => (i * 37 + 11 + next) % 256),
      gateway,
      payments: new MemoryPaymentLookup([store]),
      cipher: TEST_CIPHER,
    };
    return d;
  };

  const settlementDeps = (): SettlementDeps => {
    const d = deps();
    return {
      payments: d.payments,
      gateway: d.gateway,
      clock: d.clock,
      subjects: { event_registration: new TicketPaymentSettler(d) },
    };
  };

  const publishPaid = async (): Promise<void> => {
    const path = `eventCovers/ph1/${EVENT_ID}/c.jpg`;
    await handleSaveEventDraft({ auth: { uid: 'ph1' }, data: {
      eventId: EVENT_ID, title: 'Photo walk', type: 'photo_walk', coverUrl: `https://s.test/${path}`, coverPath: path,
      startAt: '2026-10-12T02:00:00.000Z', endAt: '2026-10-12T05:00:00.000Z',
      location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 }, capacity: 5, price: 200_000,
    } }, deps());
    await handlePublishEvent({ auth: { uid: 'ph1' }, data: { eventId: EVENT_ID } }, deps());
  };

  const register = (uid: string, method: unknown = 'bank_qr') =>
    handleRegisterEvent({ auth: { uid }, data: { eventId: EVENT_ID, quantity: 2, name: 'An', method } }, deps());

  beforeEach(() => {
    store = new MemoryEventStore();
    gateway = new FakePaymentGateway();
    next = 10;
    now = new Date('2026-10-06T03:00:00.000Z');
  });

  it('there is no confirmFakeTicketPayment export', () => {
    assert.equal('confirmFakeTicketPayment' in allExports, false);
  });

  it('registerEvent and the ticket payment callables get 30 s (contention)', () => {
    assert.equal(PAYMENT_CALLABLE_OPTIONS.timeoutSeconds, 30);
    assert.equal(PAYMENT_CALLABLE_OPTIONS.region, CALLABLE_OPTIONS.region);
    assert.equal(CALLABLE_OPTIONS.timeoutSeconds, 10);
  });

  it('registerEvent takes method and returns instructions', async () => {
    await publishPaid();
    const r = await register('cu1', 'bank_qr');
    assert.equal(r.status, 'held');
    assert.ok(r.paymentId);
    assert.ok(r.instructions);
    assert.equal(r.instructions.method, 'bank_qr');
    assert.equal(r.instructions.amount, 400_000);
    assert.match(r.instructions.transferCode, /^PB /);
    assert.equal(r.holdExpiresAt, new Date(now.getTime() + 10 * 60_000).toISOString());
  });

  it('registerEvent refuses provider-only input (invalid_argument)', async () => {
    await publishPaid();
    await assert.rejects(
      handleRegisterEvent({ auth: { uid: 'cu1' }, data: { eventId: EVENT_ID, quantity: 2, name: 'An', provider: 'momo' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
  });

  it('checkTicketPayment applies a transfer the gateway reports', async () => {
    await publishPaid();
    const r = await register('cu1');
    const ask = { auth: { uid: 'cu1' }, data: { eventId: EVENT_ID, registrationId: r.registrationId } };
    assert.deepEqual(await handleCheckTicketPayment(ask, { ...deps(), settlement: settlementDeps() }), { paid: false, status: 'held' });
    const p = store.payments.get(r.paymentId as string);
    assert.ok(p);
    assert.ok(p.transferCode);
    gateway.pushTransfer(p.id, {
      provider: 'fake',
      txnId: 'tx_gw_1',
      amount: p.amount,
      content: p.transferCode,
      receivedAt: now.toISOString(),
    });
    assert.deepEqual(await handleCheckTicketPayment(ask, { ...deps(), settlement: settlementDeps() }), { paid: true, status: 'paid' });
  });

  it('cancelRegistration ≥ 48 h before refunds 100%', async () => {
    await publishPaid();
    const r = await register('cu1');
    await handleConfirmFakePayment(
      { auth: { uid: 'cu1' }, data: { paymentId: r.paymentId, kind: 'exact' } },
      settlementDeps(),
      { ...EMULATOR, FAKE_PAYMENT_WEBHOOK_SECRET: 'test-secret' },
    );
    const out = await handleCancelRegistration(
      { auth: { uid: 'cu1' }, data: { eventId: EVENT_ID, registrationId: r.registrationId } }, deps(),
    );
    assert.deepEqual(out, { status: 'refunded', refundPercent: 100 });
    assert.equal(store.payments.get(r.paymentId as string)?.escrowStatus, 'refunded');
  });

  it('cancelEvent refunds every paid ticket', async () => {
    await publishPaid();
    const r = await register('cu1');
    await handleConfirmFakePayment(
      { auth: { uid: 'cu1' }, data: { paymentId: r.paymentId, kind: 'exact' } },
      settlementDeps(),
      { ...EMULATOR, FAKE_PAYMENT_WEBHOOK_SECRET: 'test-secret' },
    );
    const out = await handleCancelEvent({ auth: { uid: 'ph1' }, data: { eventId: EVENT_ID } }, deps());
    assert.deepEqual(out, { paidRegistrationIds: [r.registrationId], refunded: 1, failed: 0 });
    assert.equal(store.registrations.get(`${EVENT_ID}/${r.registrationId}`)?.status, 'refunded');
    // Explicit memory notify deps: the default would be liveNotifyDeps() (Firestore).
    const notify = { store: new MemoryNotificationStore(), push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => now } };
    assert.equal((await handleEventClock(deps(), { notify })).refunded, 0);
  });

  it('releaseEventHolds frees an expired hold', async () => {
    await publishPaid();
    await register('cu1');
    assert.equal(await handleReleaseEventHolds(deps()), 0);
    now = new Date(now.getTime() + 10 * 60_000);
    assert.equal(await handleReleaseEventHolds(deps()), 1);
    assert.equal(store.events.get(EVENT_ID)?.heldCount, 0);
  });
});
