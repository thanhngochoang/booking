/**
 * Domain entity types for Booking and related concepts.
 * Follows data-model/domain-model.md §2.4, §4, §5.
 */

import type { PaymentMethod } from './escrow.js';

export const BOOKING_STATUSES = [
  'draft',
  'requested',
  'accepted',
  'declined',
  'expired',
  'cancelled',
  'upcoming',
  'completed',
  'reviewed',
] as const;

export type BookingStatus = (typeof BOOKING_STATUSES)[number];

export const ESCROW_STATUSES = [
  'held',
  'released',
  'paid_out',
  'partially_refunded',
  'refunded',
  'disputed',
] as const;

export type EscrowStatus = (typeof ESCROW_STATUSES)[number];

export const PAYMENT_PROVIDERS = ['momo', 'vnpay', 'fake'] as const;
export type PaymentProvider = (typeof PAYMENT_PROVIDERS)[number];

export interface BookingServiceSnapshot {
  readonly name: string;
  readonly price: number;
  readonly durationMinutes: number;
}

export interface BookingContactSnapshot {
  readonly name: string;
  readonly phone: string;
  readonly allowZalo: boolean;
  readonly allowWhatsApp: boolean;
  readonly redactedAt?: string | null;
}

export interface BookingCancel {
  readonly by: 'customer' | 'photographer' | 'system';
  readonly reason?: string;
  readonly at: string;
  readonly refundPercent: number;
}

export interface BookingEventRecord {
  readonly id: string;
  readonly bookingId: string;
  readonly status: BookingStatus;
  readonly at: string;
  readonly actorId?: string;
}

/**
 * What the customer needs to pay the current payment (S04.04), mirrored on the booking by
 * `createPayment` so the app can draw the QR or open the wallet without reading `payments`.
 */
export interface BookingCheckout {
  readonly paymentId: string;
  readonly method: PaymentMethod;
  /** VND, the full price. */
  readonly amount: number;
  /** ISO-8601 UTC; the QR is refused from this instant on. */
  readonly expiresAt: string;
  /** `PB XXXXXX`, the memo to type. */
  readonly transferCode: string;
  /** 1-based count of payments made for this booking (at most MAX_PAYMENT_ATTEMPTS). */
  readonly attempt: number;
  readonly qrPayload?: string;
  readonly bankName?: string;
  readonly accountMasked?: string;
  readonly payUrl?: string;
  readonly bankAppsUrl?: string;
}

export interface Booking {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly serviceSnapshot: BookingServiceSnapshot;
  readonly day: string; // yyyy-MM-dd
  readonly start: string; // HH:mm
  readonly end: string; // HH:mm
  readonly place: { readonly name: string; readonly point?: { readonly lat: number; readonly lng: number } };
  readonly note?: string;
  readonly status: BookingStatus;
  readonly deposit: number;
  readonly remaining: number;
  readonly escrowStatus?: EscrowStatus;
  readonly depositRefunded?: number;
  readonly depositProvider?: PaymentProvider;
  readonly depositPaidAt?: string;
  readonly depositRefundedAt?: string;
  readonly acceptDeadline?: string;
  readonly cancel?: BookingCancel;
  readonly completedAt?: string;
  readonly reviewedAt?: string;
  readonly chatId?: string;
  /** Draft only: the payment the customer is paying now. */
  readonly checkout?: BookingCheckout;
  /**
   * Draft only, ISO-8601 UTC: the draft sweep deletes the draft from this instant on.
   * `createdAt + DRAFT_EXPIRY_MINUTES`, pushed to `expiresAt + DRAFT_PAYMENT_GRACE_MINUTES` by each new payment.
   */
  readonly payableUntil?: string;
  readonly version: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}
