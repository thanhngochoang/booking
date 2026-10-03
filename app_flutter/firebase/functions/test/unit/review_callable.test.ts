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
            data: { bookingId: 'b1', rating: 5, text: 'Rất tuyệt vời nha!' },
          },
          makeDeps()
        ),
      (err: unknown) =>
        err instanceof HttpsError &&
        err.code === 'unauthenticated' &&
        (err.details as Record<string, unknown> | undefined)?.code === 'permission_denied'
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
          rating: 5,
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
              rating: 5,
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
