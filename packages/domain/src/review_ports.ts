import type { Booking, BookingEventRecord } from './booking.js';
import type { Clock, IdGenerator } from './ports.js';
import type { RealShootPost, Review } from './review.js';

export interface ReviewTx {
  getBooking(id: string): Promise<Booking | null>;
  getReview(reviewId: string): Promise<Review | null>;
  /** Display name for the review snapshots; null when the account has none. */
  getUserName(uid: string): Promise<string | null>;
  setBooking(b: Booking): void;
  addBookingEvent(e: BookingEventRecord): void;
  setReview(r: Review): void;
  createPost(p: RealShootPost): void;
}

export interface ReviewStore {
  runTransaction<T>(fn: (tx: ReviewTx) => Promise<T>): Promise<T>;
}

export interface ReviewDeps {
  readonly reviews: ReviewStore;
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly storageUrlPrefixes: readonly string[];
}
