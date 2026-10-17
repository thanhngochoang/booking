import { ticketRefundHandler, type RefundSubjects } from '@photobooking/domain';
import { liveEventPaymentDeps } from './live_event.js';

export function liveRefundSubjects(): RefundSubjects {
  return {
    event_registration: ticketRefundHandler(liveEventPaymentDeps()),
  };
}
