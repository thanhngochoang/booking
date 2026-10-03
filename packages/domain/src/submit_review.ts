import type { Booking, BookingEventRecord } from './booking.js';
import { DomainError } from './errors.js';
import { type RealShootPost, type Review, validateReviewInput } from './review.js';
import type { ReviewDeps } from './review_ports.js';

export async function submitReview(
  deps: ReviewDeps,
  callerId: string,
  raw: unknown
): Promise<{ review: Review; postId: string | null }> {
  const input = validateReviewInput(raw, callerId, deps.storageUrlPrefixes);

  return deps.reviews.runTransaction(async (tx) => {
    const booking = await tx.getBooking(input.bookingId);
    const existing = await tx.getReview(input.bookingId);

    if (booking === null) {
      throw new DomainError('not_found');
    }

    if (booking.customerId !== callerId) {
      throw new DomainError('permission_denied');
    }

    if (existing !== null || booking.status === 'reviewed') {
      throw new DomainError('conflict');
    }

    if (booking.status !== 'completed') {
      throw new DomainError('not_eligible');
    }

    const now = deps.clock.now();
    const nowIso = now.toISOString();
    const postId = input.photos.length > 0 ? input.postId : null;

    const review: Review = {
      bookingId: input.bookingId,
      customerId: callerId,
      photographerId: booking.photographerId,
      serviceId: booking.serviceId,
      rating: input.rating,
      text: input.text,
      photoPostId: postId,
      createdAt: now,
      countedAt: null,
    };
    tx.setReview(review);

    if (postId !== null) {
      const post: RealShootPost = {
        id: postId,
        authorId: callerId,
        photographerId: booking.photographerId,
        serviceId: booking.serviceId,
        bookingId: input.bookingId,
        imageUrls: input.photos.map((p) => p.url),
        imageMeta: input.photos.map((p) => ({
          blurHash: p.blurHash,
          w: p.w,
          h: p.h,
        })),
        caption: input.text,
        locationName: booking.place.name,
        createdAt: now,
      };
      tx.createPost(post);
    }

    const updatedBooking: Booking = {
      ...booking,
      status: 'reviewed',
      reviewedAt: nowIso,
      version: booking.version + 1,
      updatedAt: nowIso,
    };
    tx.setBooking(updatedBooking);

    const event: BookingEventRecord = {
      id: deps.ids.newId(),
      bookingId: input.bookingId,
      status: 'reviewed',
      at: nowIso,
      actorId: callerId,
    };
    tx.addBookingEvent(event);

    return { review, postId };
  });
}
