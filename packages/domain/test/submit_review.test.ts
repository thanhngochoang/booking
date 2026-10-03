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

  it('writes the review, moves the booking to reviewed with an event', async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    const res = await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      rating: 5,
      text: 'Trải nghiệm chụp ảnh tuyệt vời!',
    });

    assert.equal(res.postId, null);
    assert.equal(res.review.bookingId, 'book1');
    assert.equal(res.review.customerId, 'cust1');
    assert.equal(res.review.photographerId, 'photo1');
    assert.equal(res.review.serviceId, 'pkg1');
    assert.equal(res.review.rating, 5);
    assert.equal(res.review.text, 'Trải nghiệm chụp ảnh tuyệt vời!');
    assert.equal(res.review.photoPostId, null);
    assert.equal(res.review.countedAt, null);

    // Stored review
    const storedReview = store.reviews.get('book1');
    assert.ok(storedReview);
    assert.equal(storedReview.rating, 5);

    // Stored booking
    const storedBooking = store.bookings.get('book1');
    assert.ok(storedBooking);
    assert.equal(storedBooking.status, 'reviewed');
    assert.equal(storedBooking.reviewedAt, now.toISOString());
    assert.equal(storedBooking.version, 2);

    // Stored event
    assert.equal(store.events.length, 1);
    assert.equal(store.events[0]?.bookingId, 'book1');
    assert.equal(store.events[0]?.status, 'reviewed');
    assert.equal(store.events[0]?.actorId, 'cust1');
  });

  it("with photos also creates the real-shoot post with the booking's service, place and the text as caption", async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    const postId = 'post_real_1';
    const storagePath = `posts/cust1/${postId}/0.jpg`;
    const photoUrl = `${prefixes[0]}${encodeURIComponent(storagePath)}?alt=media`;

    const res = await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      rating: 4,
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
      rating: 5,
      text: 'Dù gói chụp đã ẩn nhưng buổi chụp rất vui.',
      postId,
      photos: [{ url: photoUrl, storagePath }],
    });

    assert.equal(res.postId, postId);
    const post = store.posts.get(postId);
    assert.ok(post);
    assert.equal(post.serviceId, 'hiddenPkg');
  });

  it('a second submit is a conflict and writes nothing', async () => {
    const booking = makeCompletedBooking();
    store.seedBooking(booking);

    await submitReview(deps, 'cust1', {
      bookingId: 'book1',
      rating: 5,
      text: 'Lần đầu tiên đánh giá thành công',
    });

    await assert.rejects(
      () =>
        submitReview(deps, 'cust1', {
          bookingId: 'book1',
          rating: 4,
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
          rating: 5,
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
          rating: 5,
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
          rating: 5,
          text: 'Booking không tồn tại',
        }),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'not_found'
    );
  });
});
