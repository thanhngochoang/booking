import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  type Booking,
  type BookingDeps,
  MemoryBookingStore,
  FakePaymentGateway,
  FakeBlockGate,
  type ServiceRecord,
  type CustomerContactRecord,
  computeDeposit,
} from '@photobooking/domain';
import {
  handleCreateBooking,
  handleTransitionBooking,
  handleOpenDispute,
} from '../../src/callables/booking.js';
import { handleConfirmFakePayment, handleCreatePayment } from '../../src/callables/payment.js';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { TEST_CIPHER } from './support/payment_world.js';

function createTestDeps(): { deps: BookingDeps; store: MemoryBookingStore; gateway: FakePaymentGateway; blocks: FakeBlockGate } {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
  const blocks = new FakeBlockGate();
  let idCounter = 1;

  const servicesMap = new Map<string, ServiceRecord>([
    ['svc1', { id: 'svc1', photographerId: 'p1', name: 'Gói chụp chân dung', price: 1_000_000, durationMinutes: 120, active: true }],
  ]);

  const contactsMap = new Map<string, CustomerContactRecord>([
    ['c1', { name: 'Nguyễn Văn A', phone: '+84903123456', allowZalo: true, allowWhatsApp: false }],
  ]);

  const deps: BookingDeps = {
    store,
    services: {
      getService: async (photographerId, id) => {
        const svc = servicesMap.get(id);
        return svc === undefined ? null : { ...svc, photographerId };
      },
    },
    contacts: {
      get: async (uid) => contactsMap.get(uid) ?? null,
    },
    providers: { acceptsOrders: async (id) => id !== 'closed1' },
    blocks,
    gateway,
    cipher: TEST_CIPHER,
    clock: { now: () => new Date('2026-10-01T10:00:00.000Z') },
    ids: { newId: () => `id_${idCounter++}` },
  };

  return { deps, store, gateway, blocks };
}

/** Fake payments run on the emulator (or the dev project) only; the fake webhook needs its (test) secret. */
const EMULATOR_ENV = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag', FAKE_PAYMENT_WEBHOOK_SECRET: 'unit-test-webhook-secret' };

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

describe('Booking callables', () => {
  test('all booking callables reject unauthenticated requests with permission_denied', async () => {
    const { deps } = createTestDeps();
    const unauthed = { data: {} };

    await assert.rejects(handleCreateBooking(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleTransitionBooking(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleOpenDispute(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
  });

  test('handleCreateBooking creates a draft booking for signed-in customer', async () => {
    const { deps } = createTestDeps();
    const result = await handleCreateBooking(
      {
        auth: { uid: 'c1' },
        data: {
          photographerId: 'p1',
          serviceId: 'svc1',
          day: '2026-10-15',
          start: '09:00',
          place: { name: 'Thảo Cầm Viên, Quận 1' },
          note: 'Chụp ngoại cảnh',
        },
      },
      deps,
    );

    assert.equal(result.customerId, 'c1');
    assert.equal(result.photographerId, 'p1');
    assert.equal(result.status, 'draft');
    assert.equal(result.deposit, computeDeposit(1_000_000).deposit);
    assert.equal(result.remaining, 0);
  });

  test('createBooking refuses a closed provider with failed-precondition and details.code not_accepting_orders', async () => {
    const { deps } = createTestDeps();
    await assert.rejects(
      handleCreateBooking(
        {
          auth: { uid: 'c1' },
          data: {
            photographerId: 'closed1',
            serviceId: 'svc1',
            day: '2026-10-15',
            start: '09:00',
            place: { name: 'Thảo Cầm Viên, Quận 1' },
          },
        },
        deps,
      ),
      httpsError('failed-precondition', 'not_accepting_orders'),
    );
  });

  test('createBooking refuses a blocked pair with failed-precondition and details.code blocked', async () => {
    const { deps, blocks } = createTestDeps();
    blocks.block('p1', 'c1');
    await assert.rejects(
      handleCreateBooking(
        {
          auth: { uid: 'c1' },
          data: {
            photographerId: 'p1',
            serviceId: 'svc1',
            day: '2026-10-15',
            start: '09:00',
            place: { name: 'Thảo Cầm Viên, Quận 1' },
          },
        },
        deps,
      ),
      httpsError('failed-precondition', 'blocked'),
    );
  });

  test('createPayment refuses a blocked pair with failed-precondition and details.code blocked', async () => {
    const { deps, blocks } = createTestDeps();
    const draft = await handleCreateBooking(
      {
        auth: { uid: 'c1' },
        data: {
          photographerId: 'p1',
          serviceId: 'svc1',
          day: '2026-10-15',
          start: '09:00',
          place: { name: 'Thảo Cầm Viên' },
        },
      },
      deps,
    );
    blocks.block('c1', 'p1');
    await assert.rejects(
      handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } }, deps, EMULATOR_ENV),
      httpsError('failed-precondition', 'blocked'),
    );
  });

  test('handleCreateBooking rejects invalid input with invalid_argument', async () => {
    const { deps } = createTestDeps();
    await assert.rejects(
      handleCreateBooking(
        {
          auth: { uid: 'c1' },
          data: {
            photographerId: 'p1',
            serviceId: 'svc1',
            day: 'bad-day',
            start: '09:00',
            place: { name: 'Thảo Cầm Viên' },
          },
        },
        deps,
      ),
      httpsError('invalid-argument', 'invalid_argument'),
    );
  });

  test('handleCreateBooking passes expectedPrice and rejects price_changed', async () => {
    const { deps } = createTestDeps();
    // svc1 price is 1_000_000
    await assert.rejects(
      handleCreateBooking(
        {
          auth: { uid: 'c1' },
          data: {
            photographerId: 'p1',
            serviceId: 'svc1',
            day: '2026-10-15',
            start: '09:00',
            place: { name: 'Thảo Cầm Viên' },
            expectedPrice: 900_000,
          },
        },
        deps,
      ),
      httpsError('failed-precondition', 'price_changed'),
    );

    const ok = await handleCreateBooking(
      {
        auth: { uid: 'c1' },
        data: {
          photographerId: 'p1',
          serviceId: 'svc1',
          day: '2026-10-15',
          start: '09:00',
          place: { name: 'Thảo Cầm Viên' },
          expectedPrice: 1_000_000,
        },
      },
      deps,
    );
    assert.equal(ok.status, 'draft');
  });

  test('a booking paid through createPayment and the fake transfer is accepted by the photographer', async () => {
    const { deps } = createTestDeps();
    const draft = await handleCreateBooking(
      {
        auth: { uid: 'c1' },
        data: {
          photographerId: 'p1',
          serviceId: 'svc1',
          day: '2026-10-15',
          start: '09:00',
          place: { name: 'Thảo Cầm Viên' },
        },
      },
      deps,
    );
    const payment = await handleCreatePayment(
      { auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } },
      deps,
      EMULATOR_ENV,
    );
    const paid = await handleConfirmFakePayment(
      { auth: { uid: 'c1' }, data: { paymentId: payment.paymentId, kind: 'exact' } },
      deps,
      EMULATOR_ENV,
    );
    assert.deepEqual(paid, { outcome: 'paid' });

    const accepted = await handleTransitionBooking(
      {
        auth: { uid: 'p1' },
        data: {
          bookingId: draft.id,
          action: 'accept',
        },
      },
      deps,
    );

    assert.equal(accepted.status, 'accepted');
  });

  test('transitionBooking refuses the retired review action with invalid_argument and leaves the booking', async () => {
    const { deps, store } = createTestDeps();
    const booking: Booking = {
      id: 'b_review',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'svc1',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '09:00',
      end: '11:00',
      place: { name: 'Thảo Cầm Viên' },
      status: 'completed',
      deposit: 1_000_000,
      remaining: 0,
      escrowStatus: 'held',
      completedAt: '2026-10-01T09:00:00.000Z',
      version: 1,
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T09:00:00.000Z',
    };
    store.bookings.set(booking.id, booking);

    await assert.rejects(
      handleTransitionBooking({ auth: { uid: 'c1' }, data: { bookingId: 'b_review', action: 'review' } }, deps),
      httpsError('invalid-argument', 'invalid_argument'),
    );
    const after = store.bookings.get('b_review');
    assert.equal(after?.status, 'completed');
    assert.equal(after?.reviewedAt, undefined);
  });

  test('handleOpenDispute allows customer to dispute a completed booking', async () => {
    const { deps, store } = createTestDeps();
    const booking: Booking = {
      id: 'b_completed',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'svc1',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '09:00',
      end: '11:00',
      place: { name: 'Thảo Cầm Viên' },
      status: 'completed',
      deposit: 1_000_000,
      remaining: 0,
      escrowStatus: 'held',
      completedAt: '2026-10-01T09:00:00.000Z',
      version: 1,
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T09:00:00.000Z',
    };
    store.bookings.set(booking.id, booking);
    store.payments.set('pay_1', {
      id: 'pay_1',
      subjectType: 'booking',
      subjectId: 'b_completed',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 1_000_000,
      status: 'paid',
      escrowStatus: 'held',
      idempotencyKey: 'dep_b_completed_fake',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
    });

    const disputed = await handleOpenDispute(
      {
        auth: { uid: 'c1' },
        data: {
          bookingId: 'b_completed',
          reason: 'Thợ ảnh đến muộn 2 tiếng và không chụp đủ số ảnh cam kết',
        },
      },
      deps,
    );

    assert.equal(disputed.escrowStatus, 'disputed');
  });

  test('handleBookingClock runs sweeps without throwing', async () => {
    const { deps } = createTestDeps();
    const sweepResult = await handleBookingClock(deps);
    assert.deepEqual(sweepResult, {
      cleanedDrafts: 0,
      expiredRequests: 0,
      upcomingTransitions: 0,
      autoCompletions: 0,
      releasedEscrows: 0,
    });
  });
});
