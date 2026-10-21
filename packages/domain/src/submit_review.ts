import type { Booking, BookingEventRecord } from './booking.js';
import { DomainError } from './errors.js';
import {
  intensityOf,
  isReviewable,
  type RealShootPost,
  type Review,
  reviewDocId,
  validateReviewInput,
} from './review.js';
import type { ReviewDeps } from './review_ports.js';

export async function submitReview(
  deps: ReviewDeps,
  callerId: string,
  raw: unknown
): Promise<{ review: Review; postId: string | null }> {
  // The studio block is validated when sent; the booking decides in the transaction whether it was due.
  const sentStudio =
    typeof raw === 'object' && raw !== null && (raw as { studio?: unknown }).studio != null;
  const input = validateReviewInput(raw, callerId, deps.storageUrlPrefixes, {
    studio: sentStudio,
  });

  return deps.reviews.runTransaction(async (tx) => {
    const booking = await tx.getBooking(input.bookingId);
    const reviewId = reviewDocId(input.bookingId, 'photographer');
    const studioReviewId = reviewDocId(input.bookingId, 'studio');
    const existing = await tx.getReview(reviewId);
    const existingStudio = await tx.getReview(studioReviewId);

    if (booking === null) {
      throw new DomainError('not_found');
    }

    if (booking.customerId !== callerId) {
      throw new DomainError('permission_denied');
    }

    const isStudio = booking.isStudio === true;
    if (isStudio !== (input.studio !== null)) {
      throw new DomainError('invalid_argument');
    }

    if (
      existing !== null ||
      existingStudio !== null ||
      booking.reviewedAt !== undefined ||
      booking.status === 'reviewed'
    ) {
      throw new DomainError('conflict');
    }

    if (!isReviewable(booking.status)) {
      throw new DomainError('not_eligible');
    }

    const assigneeId = isStudio ? (booking.assigneeId ?? null) : null;
    if (isStudio && assigneeId === null) {
      throw new DomainError('not_eligible');
    }

    // Name snapshots are reads: they come before the first write.
    const studioName = isStudio ? ((await tx.getUserName(booking.photographerId)) ?? '') : '';
    const assigneeName =
      assigneeId !== null ? ((await tx.getUserName(assigneeId)) ?? '') : '';

    const now = deps.clock.now();
    const nowIso = now.toISOString();
    const postId = input.photos.length > 0 ? input.postId : null;

    // A studio booking: the member review counts for the last assignee, the studio review for the studio.
    const memberId = assigneeId ?? booking.photographerId;
    const review: Review = {
      id: reviewId,
      bookingId: input.bookingId,
      subjectType: 'photographer',
      subjectId: memberId,
      photographerId: memberId,
      customerId: callerId,
      serviceId: booking.serviceId,
      serviceName: booking.serviceSnapshot.name,
      bookingDay: booking.day,
      verdict: input.verdict,
      hits: input.hits,
      intensity: intensityOf(input.hits),
      reasons: input.reasons,
      text: input.text,
      photoPostId: postId,
      createdAt: now,
      countedAt: null,
      ...(isStudio ? { viaStudioId: booking.photographerId, viaStudioName: studioName } : {}),
    };
    tx.setReview(review);

    if (input.studio !== null && assigneeId !== null) {
      const studioReview: Review = {
        id: studioReviewId,
        bookingId: input.bookingId,
        subjectType: 'studio',
        subjectId: booking.photographerId,
        photographerId: booking.photographerId,
        customerId: callerId,
        serviceId: booking.serviceId,
        serviceName: booking.serviceSnapshot.name,
        bookingDay: booking.day,
        verdict: input.studio.verdict,
        hits: input.studio.hits,
        intensity: intensityOf(input.studio.hits),
        reasons: input.studio.reasons,
        text: input.studio.text,
        photoPostId: null,
        createdAt: now,
        countedAt: null,
        assigneeId,
        assigneeName,
      };
      tx.setReview(studioReview);
    }

    if (postId !== null) {
      const post: RealShootPost = {
        id: postId,
        authorId: callerId,
        photographerId: booking.photographerId,
        serviceId: booking.serviceId,
        bookingId: input.bookingId,
        ...(assigneeId !== null ? { assigneeId } : {}),
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
