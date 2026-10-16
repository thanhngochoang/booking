import {
  BookingPaymentSettler,
  TicketPaymentSettler,
  type SettlementDeps,
} from '@photobooking/domain';
import { db } from './admin.js';
import { getSharedFakeGateway, liveBookingDeps } from './live_booking.js';
import { liveEventPaymentDeps } from './live_event.js';
import { FirestorePaymentLookup } from './payment_firestore.js';

export function liveSettlementDeps(): SettlementDeps {
  const firestore = db();
  return {
    payments: new FirestorePaymentLookup(firestore),
    gateway: getSharedFakeGateway(),
    clock: { now: () => new Date() },
    subjects: {
      booking: new BookingPaymentSettler(liveBookingDeps()),
      event_registration: new TicketPaymentSettler(liveEventPaymentDeps()),
    },
  };
}
