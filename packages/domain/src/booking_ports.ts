/**
 * Ports and dependencies for Booking domain use cases.
 */

import type { AddonCatalog } from './addon_ports.js';
import type { BlockGate } from './block_ports.js';
import type { Booking, BookingContactSnapshot, BookingEventRecord, PaymentProvider } from './booking.js';
import type { Payment, PaymentMethod, PaymentSubject, Refund, LedgerEntry } from './escrow.js';
import type { Clock, IdGenerator, UserContactRecord } from './ports.js';

export interface ServiceRecord {
  readonly id: string;
  readonly photographerId: string;
  readonly name: string;
  readonly price: number;
  readonly durationMinutes: number;
  readonly active: boolean;
  /** Free revision rounds of a package (from deliverables.revisions; a quote passes terms.revisions). */
  readonly revisions?: number;
}

export interface ServiceCatalog {
  getService(photographerId: string, serviceId: string): Promise<ServiceRecord | null>;
}

/** Whether a provider currently takes orders (verified and profile complete). */
export interface ProviderOrderGate {
  acceptsOrders(photographerId: string): Promise<boolean>;
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

/**
 * One incoming transfer as the payment provider reports it (webhook or reconciliation query),
 * already authenticated by the adapter. `txnId` is the provider's transaction id.
 */
export interface TransferNotification {
  readonly provider: PaymentProvider;
  readonly txnId: string;
  /** VND, positive integer. */
  readonly amount: number;
  /** The memo the sender typed; matched with `transferCodesIn`. */
  readonly content: string;
  /** ISO-8601 UTC, when the provider received the money (decides late transfers). */
  readonly receivedAt: string;
  /** The provider's body as received, kept on the transfer record only. */
  readonly raw?: string;
  readonly payer?: { readonly bankCode?: string; readonly accountMasked?: string; readonly name?: string };
}

/** The gateway's answer to createPayment. Renamed from #129's `PaymentInstructions` (Decision 4). */
export interface GatewayInstructions {
  readonly providerRef?: string;
  readonly qrPayload?: string;
  readonly bankName?: string;
  readonly accountMasked?: string;
  readonly payUrl?: string;
  readonly bankAppsUrl?: string;
}

/**
 * The result of handling one transfer: `paid` (the payment reached its amount), `paid_with_refund`
 * (and the part above it went back), `partial` (still short), `refunded` (the whole transfer went
 * back: late, extra, or the draft is gone), `needs_review` (no payment matched; staff decide),
 * `duplicate` (this transaction was handled before; nothing changed).
 */
export type TransferOutcome = 'paid' | 'paid_with_refund' | 'partial' | 'refunded' | 'needs_review' | 'duplicate';

/** One handled transfer, id `${provider}_${txnId}` (the idempotency key of the notification). */
export interface TransferRecord {
  readonly id: string;
  readonly provider: PaymentProvider;
  readonly txnId: string;
  readonly raw?: string;
  readonly receivedAt: string;
  readonly outcome: Exclude<TransferOutcome, 'duplicate'>;
  readonly paymentId?: string;
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
  getTransferRecord(id: string): Promise<TransferRecord | null>;
  /** Written in the same transaction as the payment and ledger changes, so a repeat is a no-op. */
  saveTransferRecord(record: TransferRecord): Promise<void>;
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
  /**
   * Every payment whose `transferCode` is `code`, any status. Codes are unique among open
   * (`created`) payments only, so closed ones can share a code.
   */
  findPaymentsByTransferCode(code: string): Promise<readonly Payment[]>;
  getTransferRecord(id: string): Promise<TransferRecord | null>;
  // Sweep queries
  /** Booking payments in `created` with `createdAt <= createdBefore`. */
  findPaymentsToReconcile(createdBefore: Date, limit?: number): Promise<readonly Payment[]>;
  /** Payments in `created` with `expiresAt <= now`. */
  findOverduePayments(now: Date, limit?: number): Promise<readonly Payment[]>;
  /** Drafts with `payableUntil <= now`; drafts without the field are never returned. */
  findExpiredDrafts(now: Date, limit?: number): Promise<readonly Booking[]>;
  findExpiredRequests(now: Date, limit?: number): Promise<readonly Booking[]>;
  findUpcomingTransitions(now: Date, limit?: number): Promise<readonly Booking[]>;
  findAutoCompletions(cutoff: Date, limit?: number): Promise<readonly Booking[]>;
  findReleasableEscrows(cutoff: Date, limit?: number): Promise<readonly Payment[]>;
}

export interface PaymentGateway {
  /** The provider this gateway talks to; stored on the payments it creates. */
  readonly provider: PaymentProvider;

  /**
   * Opens a payment with the provider and returns how the customer pays it. The adapter MUST send
   * `idempotencyKey` so a retried call never opens a second payment.
   */
  createPayment(params: {
    readonly paymentId: string;
    readonly subjectType?: PaymentSubject;
    readonly subjectId?: string;
    readonly bookingId?: string;
    readonly amount: number;
    readonly method: PaymentMethod;
    readonly transferCode: string;
    readonly expiresAt: string;
    readonly idempotencyKey: string;
  }): Promise<GatewayInstructions>;

  /** Transfers the provider has received for this payment (reconciliation, "Kiểm tra lại"). */
  queryTransfers(params: {
    readonly paymentId: string;
    readonly transferCode: string;
    readonly providerRef?: string;
  }): Promise<readonly TransferNotification[]>;

  /**
   * `refundId` is an idempotency key: the real adapter MUST send it to the provider so that a
   * repeated call (the event clock re-sends a ticket refund left `pending`) never pays twice.
   */
  issueRefund(params: {
    readonly paymentId: string;
    readonly refundId: string;
    readonly amount: number;
    readonly provider: PaymentProvider;
    readonly providerRef?: string;
  }): Promise<{ readonly success: boolean; readonly providerRef?: string; readonly error?: string }>;
}

export interface BookingDeps {
  readonly store: BookingStore;
  readonly services: ServiceCatalog;
  /** Read side of the provider's add-ons (priced by createBookingDraft). */
  readonly addons: AddonCatalog;
  readonly providers: ProviderOrderGate;
  /** Checked with `providers` before a new order (see order_gate.ts). */
  readonly blocks: BlockGate;
  readonly contacts: CustomerContactReader;
  readonly gateway: PaymentGateway;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
