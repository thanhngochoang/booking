/**
 * Ports and dependencies for Booking domain use cases.
 */

import type { Booking, BookingContactSnapshot, BookingEventRecord, PaymentProvider } from './booking.js';
import type { Payment, Refund, LedgerEntry } from './escrow.js';
import type { Clock, IdGenerator, UserContactRecord } from './ports.js';

export interface ServiceRecord {
  readonly id: string;
  readonly photographerId: string;
  readonly name: string;
  readonly price: number;
  readonly durationMinutes: number;
  readonly active: boolean;
}

export interface ServiceCatalog {
  getService(photographerId: string, serviceId: string): Promise<ServiceRecord | null>;
}

export interface CustomerContactRecord extends UserContactRecord {
  readonly phone: string;
  readonly allowZalo?: boolean;
  readonly allowWhatsApp?: boolean;
  readonly name?: string;
}

export interface CustomerContactReader {
  get(uid: string): Promise<CustomerContactRecord | null>;
}

export interface AvailabilityDayRecord {
  readonly state: 'off' | 'booked' | 'pending';
  readonly bookingId?: string;
}

export interface BookingTx {
  getBooking(id: string): Promise<Booking | null>;
  getAvailabilityDay(photographerId: string, day: string): Promise<AvailabilityDayRecord | null>;
  getCustomerDraftForDay(customerId: string, photographerId: string, day: string): Promise<Booking | null>;
  setBooking(booking: Booking): Promise<void>;
  deleteBooking(id: string): Promise<void>;
  setAvailabilityDay(
    photographerId: string,
    day: string,
    record: { state: 'booked' | 'pending'; bookingId: string },
  ): Promise<void>;
  deleteAvailabilityDay(photographerId: string, day: string): Promise<void>;
  setContactSnapshot(bookingId: string, contact: BookingContactSnapshot): Promise<void>;
  getContactSnapshot(bookingId: string): Promise<BookingContactSnapshot | null>;
  deleteContactSnapshot(bookingId: string): Promise<void>;
  getPayment(id: string): Promise<Payment | null>;
  getPaymentByIdempotencyKey(key: string): Promise<Payment | null>;
  setPayment(payment: Payment): Promise<void>;
  addRefund(refund: Refund): Promise<void>;
  addLedgerEntry(entry: LedgerEntry): Promise<void>;
  addBookingEvent(event: BookingEventRecord): Promise<void>;
}

export interface BookingStore {
  runTransaction<T>(fn: (tx: BookingTx) => Promise<T>): Promise<T>;
  getBooking(id: string): Promise<Booking | null>;
  getAvailabilityDay(photographerId: string, day: string): Promise<AvailabilityDayRecord | null>;
  getCustomerDraftForDay(customerId: string, photographerId: string, day: string): Promise<Booking | null>;
  getPayment(id: string): Promise<Payment | null>;
  getPaymentByIdempotencyKey(key: string): Promise<Payment | null>;
  getPaymentsForBooking(bookingId: string): Promise<readonly Payment[]>;
  getRefundsForPayment(paymentId: string): Promise<readonly Refund[]>;
  getLedgerEntriesForPayment(paymentId: string): Promise<readonly LedgerEntry[]>;
  getContactSnapshot(bookingId: string): Promise<BookingContactSnapshot | null>;
  // Sweep queries
  findUnpaidDraftsOlderThan(cutoff: Date, limit?: number): Promise<readonly Booking[]>;
  findExpiredRequests(now: Date, limit?: number): Promise<readonly Booking[]>;
  findUpcomingTransitions(now: Date, limit?: number): Promise<readonly Booking[]>;
  findAutoCompletions(cutoff: Date, limit?: number): Promise<readonly Booking[]>;
  findReleasableEscrows(cutoff: Date, limit?: number): Promise<readonly Payment[]>;
}

export interface PaymentGateway {
  createDepositIntent(params: {
    readonly paymentId: string;
    readonly bookingId: string;
    readonly amount: number;
    readonly provider: PaymentProvider;
    readonly returnUrl?: string;
  }): Promise<{ readonly payUrl: string; readonly providerRef?: string }>;

  issueRefund(params: {
    readonly paymentId: string;
    readonly refundId: string;
    readonly amount: number;
    readonly provider: PaymentProvider;
    readonly providerRef?: string;
  }): Promise<{ readonly success: boolean; readonly providerRef?: string; readonly error?: string }>;

  checkPaymentStatus(params: {
    readonly paymentId: string;
    readonly provider: PaymentProvider;
    readonly providerRef?: string;
  }): Promise<{ readonly paid: boolean; readonly providerRef?: string }>;
}

export interface BookingDeps {
  readonly store: BookingStore;
  readonly services: ServiceCatalog;
  readonly contacts: CustomerContactReader;
  readonly gateway: PaymentGateway;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
