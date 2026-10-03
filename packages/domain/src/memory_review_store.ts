import type { Booking, BookingEventRecord } from './booking.js';
import type { RealShootPost, Review } from './review.js';
import type { ReviewStore, ReviewTx } from './review_ports.js';

export class MemoryReviewStore implements ReviewStore {
  readonly bookings = new Map<string, Booking>();
  readonly reviews = new Map<string, Review>();
  readonly posts = new Map<string, RealShootPost>();
  readonly events: BookingEventRecord[] = [];

  seedBooking(booking: Booking): void {
    this.bookings.set(booking.id, booking);
  }

  seedReview(review: Review): void {
    this.reviews.set(review.bookingId, review);
  }

  async runTransaction<T>(fn: (tx: ReviewTx) => Promise<T>): Promise<T> {
    const stagedBookings = new Map<string, Booking>();
    const stagedReviews = new Map<string, Review>();
    const stagedPosts = new Map<string, RealShootPost>();
    const stagedEvents: BookingEventRecord[] = [];

    let hasWritten = false;

    const tx: ReviewTx = {
      getBooking: async (id: string): Promise<Booking | null> => {
        if (hasWritten) {
          throw new Error(
            'Transaction read after write: getBooking called after a write operation'
          );
        }
        return this.bookings.get(id) ?? null;
      },

      getReview: async (bookingId: string): Promise<Review | null> => {
        if (hasWritten) {
          throw new Error(
            'Transaction read after write: getReview called after a write operation'
          );
        }
        return this.reviews.get(bookingId) ?? null;
      },

      setBooking: (b: Booking): void => {
        hasWritten = true;
        stagedBookings.set(b.id, b);
      },

      addBookingEvent: (e: BookingEventRecord): void => {
        hasWritten = true;
        stagedEvents.push(e);
      },

      setReview: (r: Review): void => {
        hasWritten = true;
        stagedReviews.set(r.bookingId, r);
      },

      createPost: (p: RealShootPost): void => {
        hasWritten = true;
        stagedPosts.set(p.id, p);
      },
    };

    const result = await fn(tx);

    for (const [id, b] of stagedBookings) {
      this.bookings.set(id, b);
    }
    for (const [id, r] of stagedReviews) {
      this.reviews.set(id, r);
    }
    for (const [id, p] of stagedPosts) {
      this.posts.set(id, p);
    }
    for (const e of stagedEvents) {
      this.events.push(e);
    }

    return result;
  }
}
