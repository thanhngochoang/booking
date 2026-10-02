/**
 * Domain entity types for Booking and related concepts.
 * Follows data-model/domain-model.md §2.4, §4, §5.
 */

export type BookingStatus =
  | 'draft'
  | 'requested'
  | 'accepted'
  | 'declined'
  | 'expired'
  | 'cancelled'
  | 'upcoming'
  | 'completed'
  | 'reviewed';

export type EscrowStatus =
  | 'held'
  | 'released'
  | 'paid_out'
  | 'partially_refunded'
  | 'refunded'
  | 'disputed';

export type PaymentProvider = 'momo' | 'vnpay' | 'fake';

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
  readonly version: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}
