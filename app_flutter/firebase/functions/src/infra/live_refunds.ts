import {
  ticketRefundHandler,
  verificationFeeRefundHandler,
  type EventPaymentDeps,
  type RefundSubjects,
  type VerificationDeps,
} from '@photobooking/domain';
import { liveEventPaymentDeps } from './live_event.js';
import { liveVerificationDeps } from './live_verification.js';

/** The deps of each non-booking subject whose refunds V2 re-sends and records (bookings are built in). */
export interface RefundSubjectDeps {
  readonly event?: EventPaymentDeps;
  readonly verification?: VerificationDeps;
}

/** V2's refund handlers by subject: the payment clock's re-send and the webhook's refund events. */
export function refundSubjectsOf(d: RefundSubjectDeps): RefundSubjects {
  return {
    ...(d.event !== undefined ? { event_registration: ticketRefundHandler(d.event) } : {}),
    ...(d.verification !== undefined ? { verification_fee: verificationFeeRefundHandler(d.verification) } : {}),
  };
}

export function liveRefundSubjects(): RefundSubjects {
  return refundSubjectsOf({ event: liveEventPaymentDeps(), verification: liveVerificationDeps() });
}
