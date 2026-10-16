import type { PaymentMethod, PaymentSubject } from './escrow.js';
import type { Refund } from './escrow.js';
import type { Payment } from './escrow.js';
import type { TransferNotification, TransferOutcome } from './booking_ports.js';

/**
 * How to pay one payment, for any subject; what S04.04 shows.
 * Flat like #129's BookingCheckout.
 */
export interface PaymentInstructions {
  readonly paymentId: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly method: PaymentMethod;
  readonly amount: number;
  readonly expiresAt: string; // ISO-8601 UTC
  readonly transferCode: string; // 'PB XXXXXX'
  readonly qrPayload?: string;
  readonly bankName?: string;
  readonly accountMasked?: string;
  readonly payUrl?: string;
  readonly bankAppsUrl?: string;
}

/**
 * One payment subject's money rules, over the subject's own store (Decision 1).
 */
export interface SubjectSettler {
  /**
   * Applies one matched transfer in ONE transaction of the subject's store: if the record
   * `transferRecordId(transfer)` exists → 'duplicate'; else read the payment and the subject, `applyTransfer`,
   * write the subject's changes, any refund (`transferRefund` / `applyRefundToPayment`) and the transfer record
   * (`transferRecordOf(transfer, outcome, paymentId)`). After commit it sends each new refund with `this.dispatchRefund`.
   */
  settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>>;

  /** A `created` payment past expiresAt: `expireUnpaid` in the subject's transaction, then dispatch its refund. */
  expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'>;

  /**
   * Sends one refund and stores the outcome in the subject's store.
   * V1: #129's refund dispatch (booking `dispatchRefunds`, tickets `dispatchTicketRefund`; Decision 8).
   * After #201: `sendRefundOnce` + a transaction applying `mergeRefundOutcome`.
   * Re-sends of pending refunds do NOT go through this registry: they use V2's `RefundSubjects` (`liveRefundSubjects()`).
   */
  dispatchRefund(refund: Refund, payment: Payment): Promise<Refund>;

  /** The subject's own status code after a payment ('requested', 'paid', 'gone', …). */
  statusOf(payment: Payment): Promise<string>;
}
