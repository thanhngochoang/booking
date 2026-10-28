import type { EscrowStatus } from './booking.js';
import type { PaymentGateway } from './booking_ports.js';
import type { Dispute, DisputeSnapshot, DisputeStatus, DisputeSubjectType } from './dispute.js';
import { isSettledPayment, type LedgerEntry, type Payment, type Refund } from './escrow.js';
import type { AccountCipher } from './payout_ports.js';
import type { Clock, IdGenerator } from './ports.js';
import type { DisplayNames } from './support_use_cases.js';
import type { SupportMessage, SupportThread } from './support_thread.js';

/** What a dispute needs to know about its booking or ticket (registration), as the adapter reads it. */
export interface DisputeSubjectView {
  readonly type: DisputeSubjectType;
  /** bookingId | registrationId. */
  readonly id: string;
  readonly eventId: string | null;
  readonly customerId: string;
  /** Photographer uid, event host, or `'platform'` for platform-hosted events. */
  readonly providerId: string;
  /** Booking status | registration status. */
  readonly state: string;
  /** Booking: `completedAt` (used only for payments without milestones); ticket: the event's `endAt`. */
  readonly windowStart: Date | null;
  /** #152 booking fields. */
  readonly shotAt: Date | null;
  readonly checkUntil: Date | null;
  /** S30 (Decision 10): the customer answered "Không diễn ra" to the shoot question (booking only). */
  readonly shootDeniedAt?: Date | null;
  /** 0 for a free ticket. */
  readonly amount: number;
  /** Registration's paymentId; null for bookings (looked up by `findSubjectPayment`). */
  readonly paymentId: string | null;
  /** The subject's latest dispute (open or resolved). */
  readonly disputeId: string | null;
  readonly snapshot: DisputeSnapshot;
}

/**
 * The payment a booking dispute freezes, out of the booking's payments: a settled one (a stray
 * `created` or expired payment never counts), the one still holding money first. Every store's
 * `findSubjectPayment` uses it, so the memory and Firestore stores pick the same payment.
 */
export function pickSubjectPayment(payments: readonly Payment[]): Payment | null {
  const settled = payments.filter(isSettledPayment);
  const holding = (p: Payment) => p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded' || p.escrowStatus === 'disputed';
  return settled.find(holding) ?? settled[0] ?? null;
}

/** One transaction: every read before the first write (memory stores refuse a read after a write). */
export interface DisputeTx {
  getSubject(type: DisputeSubjectType, id: string, eventId: string | null): Promise<DisputeSubjectView | null>;
  getDispute(id: string): Promise<Dispute | null>;
  getPayment(id: string): Promise<Payment | null>;
  getRefund(id: string): Promise<Refund | null>;
  getThread(id: string): Promise<SupportThread | null>;
  /**
   * Booking: `pickSubjectPayment` of the payments whose subjectId is the booking id (a `created` QR
   * payment never counts, a holding one first); ticket: the registration's `paymentId`. The use case checks what it holds.
   */
  findSubjectPayment(subject: DisputeSubjectView): Promise<Payment | null>;
  setDispute(d: Dispute): void;
  setPayment(p: Payment): void;
  /** Booking: `disputeId` + the `escrowStatus` mirror; registration: `disputeId` only. */
  linkSubject(subject: DisputeSubjectView, patch: { readonly disputeId: string; readonly escrowStatus: EscrowStatus }): void;
  /** Creates or replaces a refund. */
  addRefund(r: Refund): void;
  addLedgerEntry(e: LedgerEntry): void;
  putThread(t: SupportThread): void;
  addMessage(m: SupportMessage): void;
}

export interface DisputeStore {
  runTransaction<T>(fn: (tx: DisputeTx) => Promise<T>): Promise<T>;
  getRefundsForPayment(paymentId: string): Promise<readonly Refund[]>;
  /** Oldest first (staff CLI). */
  listByStatus(status: DisputeStatus, limit: number): Promise<readonly Dispute[]>;
}

export interface DisputeDeps {
  readonly store: DisputeStore;
  /** #129's port; refunds go out with V2's `sendRefundOnce`. */
  readonly gateway: PaymentGateway;
  /** Reveals a bank-transfer refund's destination for the gateway (V2). */
  readonly cipher: AccountCipher;
  readonly names: DisplayNames;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
