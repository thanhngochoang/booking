import {
  BookingPaymentSettler,
  InstantPaymentSettler,
  TicketPaymentSettler,
  VerificationFeeSettler,
  groupSettler,
  type BookingDeps,
  type EventPaymentDeps,
  type InstantDeps,
  type PayerHistoryDeps,
  type SettlementDeps,
  type VerificationDeps,
} from '@photobooking/domain';
import { db } from './admin.js';
import { getSharedFakeGateway, liveBookingDeps } from './live_booking.js';
import { liveEventPaymentDeps } from './live_event.js';
import { liveInstantDeps } from './live_instant.js';
import { liveVerificationDeps } from './live_verification.js';
import { FirestorePayerHistoryStore } from './payer_history_firestore.js';
import { FirestorePaymentLookup } from './payment_firestore.js';

/** The deps of each payment subject; a subject left out gets no settler. */
export interface SettlementSubjectDeps {
  readonly booking?: BookingDeps;
  readonly event?: EventPaymentDeps;
  readonly verification?: VerificationDeps;
  readonly instant?: InstantDeps;
}

/**
 * V1's subject registry: the webhook, the payment clock (reconciliation, expiry), the fake
 * confirmation and `checkVerificationFee` reach a payment only through its subject's settler here.
 */
export function settlementSubjectsOf(d: SettlementSubjectDeps): SettlementDeps['subjects'] {
  return {
    ...(d.booking !== undefined ? { booking: new BookingPaymentSettler(d.booking) } : {}),
    // S30 (#223 Decision 6): a booking with tickets is paid through its group payment, over the booking store's
    // transaction (which reaches events, registrations and entry_days). Task 6 adds the Firestore group tests.
    ...(d.booking !== undefined ? { payment_group: groupSettler(d.booking) } : {}),
    ...(d.event !== undefined ? { event_registration: new TicketPaymentSettler(d.event) } : {}),
    ...(d.verification !== undefined ? { verification_fee: new VerificationFeeSettler(d.verification) } : {}),
    ...(d.instant !== undefined ? { instant_request: new InstantPaymentSettler(d.instant) } : {}),
  };
}

export function liveSettlementDeps(): SettlementDeps {
  const firestore = db();
  return {
    payments: new FirestorePaymentLookup(firestore),
    gateway: getSharedFakeGateway(),
    clock: { now: () => new Date() },
    subjects: settlementSubjectsOf({
      booking: liveBookingDeps(),
      event: liveEventPaymentDeps(),
      verification: liveVerificationDeps(),
      instant: liveInstantDeps(),
    }),
  };
}

/** S22.01 payer rows and totals (#141): refreshed by the payment and refund triggers. */
export function livePayerHistoryDeps(): PayerHistoryDeps {
  return { store: new FirestorePayerHistoryStore(db()), clock: { now: () => new Date() } };
}
