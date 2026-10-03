import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  type Booking,
  type BookingDeps,
  MemoryBookingStore,
  FakePaymentGateway,
  type ServiceRecord,
  type CustomerContactRecord,
} from '@photobooking/domain';
import {
  handleCreateBooking,
  handleCreateDeposit,
  handleConfirmFakePayment,
  handleCheckDeposit,
  handleTransitionBooking,
  handleOpenDispute,
} from '../../src/callables/booking.js';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';

function createTestDeps(): { deps: BookingDeps; store: MemoryBookingStore; gateway: FakePaymentGateway } {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
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
      getService: async (_photographerId, id) => servicesMap.get(id) ?? null,
    },
    contacts: {
      get: async (uid) => contactsMap.get(uid) ?? null,
    },
    gateway,
    clock: { now: () => new Date('2026-10-01T10:00:00.000Z') },
    ids: { newId: () => `id_${idCounter++}` },
  };

  return { deps, store, gateway };
}

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

describe('Booking callables', () => {
  test('all booking callables reject unauthenticated requests with permission_denied', async () => {
    const { deps } = createTestDeps();
    const unauthed = { data: {} };

    await assert.rejects(handleCreateBooking(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleCreateDeposit(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleConfirmFakePayment(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleCheckDeposit(unauthed, deps), httpsError('unauthenticated', 'permission_denied'));
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
    assert.equal(result.deposit, 300_000);
    assert.equal(result.remaining, 700_000);
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

  test('handleCreateDeposit initiates payment intent for draft', async () => {
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

    const deposit = await handleCreateDeposit(
      {
        auth: { uid: 'c1' },
        data: {
          bookingId: draft.id,
          provider: 'fake',
        },
      },
      deps,
    );

    assert.ok(deposit.paymentId);
    assert.ok(deposit.payUrl);
    assert.equal(deposit.provider, 'fake');
  });

  test('handleConfirmFakePayment transitions draft to requested', async () => {
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

    const deposit = await handleCreateDeposit(
      {
        auth: { uid: 'c1' },
        data: {
          bookingId: draft.id,
          provider: 'fake',
        },
      },
      deps,
    );

    const paymentResult = await handleConfirmFakePayment(
      {
        auth: { uid: 'c1' },
        data: { paymentId: deposit.paymentId },
      },
      deps,
    );

    assert.equal(paymentResult.payment.status, 'paid');
    assert.equal(paymentResult.booking?.status, 'requested');
  });

  test('handleCheckDeposit returns paid status', async () => {
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

    const check1 = await handleCheckDeposit(
      {
        auth: { uid: 'c1' },
        data: { bookingId: draft.id },
      },
      deps,
    );
    assert.equal(check1.paid, false);
  });

  test('handleTransitionBooking allows photographer to accept requested booking', async () => {
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
    const deposit = await handleCreateDeposit(
      { auth: { uid: 'c1' }, data: { bookingId: draft.id, provider: 'fake' } },
      deps,
    );
    await handleConfirmFakePayment(
      { auth: { uid: 'c1' }, data: { paymentId: deposit.paymentId } },
      deps,
    );

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
      deposit: 300_000,
      remaining: 700_000,
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
      amount: 300_000,
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
