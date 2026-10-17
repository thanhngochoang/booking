import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { Booking } from '../src/booking.js';
import { DomainError } from '../src/errors.js';
import { MemoryReviewStore } from '../src/memory_review_store.js';
import type { ReviewDeps } from '../src/review_ports.js';
import { submitReview } from '../src/submit_review.js';

const prefixes = [
  'https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/',
];

function makeCompletedBooking(overrides: Partial<Booking> = {}): Booking {
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
    ...overrides,
  };
}

const tomatoInput = (over: Record<string, unknown> = {}) => ({
  bookingId: 'book1',
  verdict: 'tomato',
  hits: 7,
  text: 'Trải nghiệm chụp ảnh tuyệt vời!',
  ...over,
});

describe('submitReview', () => {
  let store: MemoryReviewStore;
  let idCounter: number;
  let now: Date;
  let deps: ReviewDeps;

  beforeEach(() => {
    store = new MemoryReviewStore();
    idCounter = 0;
    now = new Date('2026-10-10T12:00:00.000Z');
    deps = {
      reviews: store,
      clock: { now: () => now },
      ids: { newId: () => `id_${++idCounter}` },
      storageUrlPrefixes: prefixes,
    };
  });

  it('stores verdict, hits, server intensity, reasons, subject, serviceName and bookingDay', async () => {
    store.seedBooking(makeCompletedBooking());

    const res = await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      verdict: 'brick',
      hits: 3,
      reasons: ['late', 'slow_delivery'],
      intensity: 1,
      text: 'Đến trễ và giao ảnh chậm quá',
    });

    assert.equal(res.postId, null);
    const stored = store.reviews.get('book1');
    assert.ok(stored);
    assert.deepEqual(res.review, stored);
    assert.equal(stored.id, 'book1');
    assert.equal(stored.bookingId, 'book1');
    assert.equal(stored.customerId, 'cust1');
    assert.equal(stored.subjectType, 'photographer');
    assert.equal(stored.subjectId, 'photo1');
    assert.equal(stored.photographerId, 'photo1');
    assert.equal(stored.serviceId, 'pkg1');
    assert.equal(stored.serviceName, 'Chụp chân dung');
    assert.equal(stored.bookingDay, '2026-10-10');
    assert.equal(stored.verdict, 'brick');
    assert.equal(stored.hits, 3);
    assert.equal(stored.intensity, 0.69);
    assert.deepEqual(stored.reasons, ['late', 'slow_delivery']);
    assert.equal(stored.text, 'Đến trễ và giao ảnh chậm quá');
    assert.equal(stored.photoPostId, null);
    assert.equal(stored.countedAt, null);
    assert.equal(stored.createdAt.toISOString(), now.toISOString());
    assert.equal('rating' in stored, false);
  });

  it('sets booking.reviewedAt and keeps booking.status completed', async () => {
    store.seedBooking(makeCompletedBooking());
    await submitReview(deps, 'cust1', tomatoInput());

    const storedBooking = store.bookings.get('book1');
    assert.ok(storedBooking);
    assert.equal(storedBooking.status, 'completed');
    assert.equal(storedBooking.reviewedAt, now.toISOString());
    assert.equal(storedBooking.version, 2);
    assert.equal(storedBooking.updatedAt, now.toISOString());
  });

  it('adds a booking event with status reviewed', async () => {
    store.seedBooking(makeCompletedBooking());
    await submitReview(deps, 'cust1', tomatoInput());

    assert.equal(store.events.length, 1);
    assert.equal(store.events[0]?.bookingId, 'book1');
    assert.equal(store.events[0]?.status, 'reviewed');
    assert.equal(store.events[0]?.actorId, 'cust1');
  });

  it('refuses with conflict when a review doc already exists', async () => {
    store.seedBooking(makeCompletedBooking());
    store.seedReview({
      id: 'book1',
      bookingId: 'book1',
      subjectType: 'photographer',
      subjectId: 'photo1',
      photographerId: 'photo1',
      customerId: 'cust1',
      serviceId: 'pkg1',
      serviceName: 'Chụp chân dung',
      bookingDay: '2026-10-10',
      verdict: 'tomato',
      hits: 1,
      intensity: 0.4,
      reasons: [],
      text: 'Đã có đánh giá từ trước',
      photoPostId: null,
      createdAt: now,
      countedAt: null,
    });
    await assert.rejects(
      () => submitReview(deps, 'cust1', tomatoInput()),
      (err: unknown) => err instanceof DomainError && err.code === 'conflict'
    );
  });

  it('refuses when reviewedAt is set with conflict', async () => {
    store.seedBooking(makeCompletedBooking({ reviewedAt: '2026-10-10T11:30:00.000Z' }));
    await assert.rejects(
      () => submitReview(deps, 'cust1', tomatoInput()),
      (err: unknown) => err instanceof DomainError && err.code === 'conflict'
    );
    assert.equal(store.reviews.size, 0);
  });

  it('refuses a legacy reviewed booking with conflict', async () => {
    store.seedBooking(makeCompletedBooking({ status: 'reviewed' }));
    await assert.rejects(
      () => submitReview(deps, 'cust1', tomatoInput()),
      (err: unknown) => err instanceof DomainError && err.code === 'conflict'
    );
  });

  it("with photos also creates the real-shoot post with the booking's service, place and the text as caption", async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    const postId = 'post_real_1';
    const storagePath = `posts/cust1/${postId}/0.jpg`;
    const photoUrl = `${prefixes[0]}${encodeURIComponent(storagePath)}?alt=media`;

    const res = await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      verdict: 'tomato',
      hits: 3,
      text: 'Ảnh chụp siêu nét, cảm ơn bạn!',
      postId,
      photos: [
        {
          url: photoUrl,
          storagePath,
          blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          w: 1200,
          h: 800,
        },
      ],
    });

    assert.equal(res.postId, postId);
    assert.equal(res.review.photoPostId, postId);

    // Post exists
    const post = store.posts.get(postId);
    assert.ok(post);
    assert.equal(post.id, postId);
    assert.equal(post.authorId, 'cust1');
    assert.equal(post.photographerId, 'photo1');
    assert.equal(post.serviceId, 'pkg1');
    assert.equal(post.bookingId, 'book1');
    assert.deepEqual(post.imageUrls, [photoUrl]);
    assert.equal(post.caption, 'Ảnh chụp siêu nét, cảm ơn bạn!');
    assert.equal(post.locationName, 'Thảo Cầm Viên, TP.HCM');
    assert.equal(post.createdAt.toISOString(), now.toISOString());
    assert.equal(post.imageMeta[0]?.blurHash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
  });

  it('a hidden package still gets the post', async () => {
    const booking = makeCompletedBooking({ serviceId: 'hiddenPkg' });
    store.seedBooking(booking);

    const postId = 'post_hidden_1';
    const storagePath = `posts/cust1/${postId}/0.jpg`;
    const photoUrl = `${prefixes[0]}${encodeURIComponent(storagePath)}`;

    const res = await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      verdict: 'tomato',
      hits: 3,
      text: 'Dù gói chụp đã ẩn nhưng buổi chụp rất vui.',
      postId,
      photos: [{ url: photoUrl, storagePath }],
    });

    assert.equal(res.postId, postId);
    const post = store.posts.get(postId);
    assert.ok(post);
    assert.equal(post.serviceId, 'hiddenPkg');
  });

  it('refuses a second review with conflict', async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      verdict: 'tomato',
      hits: 3,
      text: 'Lần đầu tiên đánh giá thành công',
    });

    await assert.rejects(
      () =>
        submitReview(deps, 'cust1', {
          bookingId: 'book1',
          verdict: 'tomato',
      hits: 3,
          text: 'Lần thứ hai cố đánh giá lại',
        }),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'conflict'
    );
  });

  it("someone else's booking is permission_denied", async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    await assert.rejects(
      () =>
        submitReview(deps, 'otherUser', {
          bookingId: 'book1',
          verdict: 'tomato',
      hits: 3,
          text: 'Đánh giá giùm bạn nè',
        }),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'permission_denied'
    );
  });

  it('a booking that is not completed is not_eligible', async () => {
    const booking = makeCompletedBooking({ status: 'upcoming' });
    store.seedBooking(booking);

    await assert.rejects(
      () =>
        submitReview(deps, 'cust1', {
          bookingId: 'book1',
          verdict: 'tomato',
      hits: 3,
          text: 'Chưa chụp đã đánh giá',
        }),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'not_eligible'
    );
  });

  it('an unknown booking is not_found', async () => {
    await assert.rejects(
      () =>
        submitReview(deps, 'cust1', {
          bookingId: 'unknownBooking',
          verdict: 'tomato',
      hits: 3,
          text: 'Booking không tồn tại',
        }),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'not_found'
    );
  });

  it('submitReview on an approved booking succeeds and status stays approved', async () => {
    const booking = makeCompletedBooking({ status: 'approved' });
    store.seedBooking(booking);

    const res = await submitReview(deps, 'cust1', tomatoInput());
    assert.ok(res.review);

    const storedBooking = store.bookings.get('book1');
    assert.ok(storedBooking);
    assert.equal(storedBooking.status, 'approved');
    assert.equal(storedBooking.reviewedAt, now.toISOString());
  });
});
