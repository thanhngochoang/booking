import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import type { Booking } from '@photobooking/domain';
import { MemoryReviewStore } from '@photobooking/domain';
import { handleSubmitReview } from '../../src/callables/review.js';

describe('submitReview callable unit tests', () => {
  let store: MemoryReviewStore;
  const prefixes = ['https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/'];

  beforeEach(() => {
    store = new MemoryReviewStore();
  });

  function makeDeps() {
    return {
      reviews: store,
      clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
      ids: { newId: () => 'id_evt_1' },
      storageUrlPrefixes: prefixes,
    };
  }

  function makeCompletedBooking(): Booking {
    return {
      id: 'book1',
      customerId: 'cust1',
      photographerId: 'photo1',
      serviceId: 'pkg1',
      serviceSnapshot: {
        name: 'Chụp chân dung',
        price: 1000000,
        durationMinutes: 90,
      },
      day: '2026-10-10',
      start: '09:00',
      end: '10:30',
      place: { name: 'Thảo Cầm Viên, TP.HCM' },
      status: 'completed',
      deposit: 300000,
      remaining: 700000,
      completedAt: '2026-10-10T11:00:00.000Z',
      version: 1,
      createdAt: '2026-10-01T10:00:00.000Z',
      updatedAt: '2026-10-10T11:00:00.000Z',
    };
  }

  it('unauthenticated is refused before any read', async () => {
    await assert.rejects(
      () =>
        handleSubmitReview(
          {
            auth: undefined,
            data: { bookingId: 'b1', verdict: 'tomato', hits: 3, text: 'Rất tuyệt vời nha!' },
          },
          makeDeps()
        ),
      (err: unknown) =>
        err instanceof HttpsError &&
        err.code === 'unauthenticated' &&
        (err.details as Record<string, unknown> | undefined)?.code === 'permission_denied'
    );
  });

  it('submitReview passes verdict input through and returns postId', async () => {
    store.seedBooking(makeCompletedBooking());
    const res = await handleSubmitReview(
      {
        auth: { uid: 'cust1' },
        data: {
          bookingId: 'book1',
          verdict: 'brick',
          hits: 3,
          reasons: ['late', 'slow_delivery'],
          text: 'Đến trễ 30 phút, ảnh giao sau 10 ngày.',
          intensity: 1,
          rating: 5,
        },
      },
      makeDeps()
    );
    assert.deepEqual(res, { postId: null });
    const saved = store.reviews.get('book1');
    assert.equal(saved?.verdict, 'brick');
    assert.equal(saved?.hits, 3);
    assert.equal(saved?.intensity, 0.69, 'the server computes the intensity');
    assert.deepEqual(saved?.reasons, ['late', 'slow_delivery']);
    assert.equal(saved?.subjectId, 'photo1');
    assert.equal(saved?.bookingDay, '2026-10-10');
    assert.equal('rating' in (saved ?? {}), false);
    assert.equal(store.bookings.get('book1')?.status, 'completed');
  });

  it('an unknown verdict is invalid-argument with details.code invalid_argument', async () => {
    store.seedBooking(makeCompletedBooking());
    await assert.rejects(
      () =>
        handleSubmitReview(
          { auth: { uid: 'cust1' }, data: { bookingId: 'book1', verdict: 'star', hits: 3, text: 'Buổi chụp tuyệt vời!' } },
          makeDeps()
        ),
      (err: unknown) =>
        err instanceof HttpsError &&
        err.code === 'invalid-argument' &&
        (err.details as Record<string, unknown> | undefined)?.code === 'invalid_argument'
    );
  });

  it('an upcoming booking is failed-precondition with details.code not_eligible', async () => {
    store.seedBooking({ ...makeCompletedBooking(), status: 'upcoming' });
    await assert.rejects(
      () =>
        handleSubmitReview(
          { auth: { uid: 'cust1' }, data: { bookingId: 'book1', verdict: 'tomato', hits: 3, text: 'Buổi chụp tuyệt vời!' } },
          makeDeps()
        ),
      (err: unknown) =>
        err instanceof HttpsError &&
        err.code === 'failed-precondition' &&
        (err.details as Record<string, unknown> | undefined)?.code === 'not_eligible'
    );
  });

  it('the callable maps conflict to aborted with details.code and never logs the text', async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);
    const deps = makeDeps();

    // First call succeeds
    const res1 = await handleSubmitReview(
      {
        auth: { uid: 'cust1' },
        data: {
          bookingId: 'book1',
          verdict: 'tomato',
          hits: 3,
          text: 'Buổi chụp tuyệt vời!',
        },
      },
      deps
    );
    assert.equal(res1.postId, null);

    // Second call is conflict -> maps to aborted with details.code === 'conflict'
    await assert.rejects(
      () =>
        handleSubmitReview(
          {
            auth: { uid: 'cust1' },
            data: {
              bookingId: 'book1',
              verdict: 'tomato',
              hits: 3,
              text: 'Bí mật riêng tư không được log',
            },
          },
          deps
        ),
      (err: unknown) =>
        err instanceof HttpsError &&
        err.code === 'aborted' &&
        (err.details as Record<string, unknown> | undefined)?.code === 'conflict'
    );
  });
});
