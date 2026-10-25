/**
 * Domain entity types for Booking and related concepts.
 * Follows data-model/domain-model.md §2.4, §4, §5.
 */

import type { AddonKind, AddonUnit } from './addon.js';
import type { PaymentMethod } from './escrow.js';
import type { ExtraRound } from './delivery.js';
import type { AssigneeKind } from './studio_ports.js';

export const BOOKING_STATUSES = [
  'draft',
  'requested',
  'accepted',
  'declined',
  'expired',
  'cancelled',
  'upcoming',
  'shot',
  'delivered',
  'revision_requested',
  'approved',
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
  /**
   * `studio_fault`: the customer's 100% cancel after a studio fault (#136 Decision 12), `reason` holding the fault
   * kind; or the clock's cancel of a studio booking still unassigned at its start (`at` ≥ start, reason `assign_overdue`).
   */
  readonly by: 'customer' | 'photographer' | 'system' | 'studio_fault';
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

/** One priced add-on line, a snapshot taken when the draft is created (amount = unitPrice × qty). */
export interface AddonLine {
  readonly addonId: string;
  readonly kind: AddonKind;
  readonly name: string;
  readonly unit: AddonUnit;
  readonly unitPrice: number;
  readonly qty: number;
  readonly amount: number;
}

/** Where the photographer picks the customer up (transport add-on); same shape as `place`. */
export interface BookingPickup {
  readonly name: string;
  readonly point?: { readonly lat: number; readonly lng: number };
}

/** Why the customer of a studio booking may cancel with a 100% refund (#136 Decision 12). */
export type StudioFaultKind = 'assign_overdue' | 'change_declined' | 'change_expired' | 'late_reassign';

/** One line of a studio booking's assignment log (S27 adds the offer fields, collaborators only). */
export interface StudioAssignment {
  readonly assigneeId: string;
  readonly assigneeKind: AssigneeKind;
  readonly at: string;
  /** Who assigned (the studio owner). */
  readonly by: string;
  readonly reason: string | null;
  /** Reassigned after assignDeadline. */
  readonly late: boolean;
  /** S27 collaborator offer: when it lapses unanswered (ISO). The agreed fee is never here (#151 Decision 3). */
  readonly offerExpiresAt?: string;
  readonly acceptedAt?: string;
  readonly declinedAt?: string;
}

/** The customer's one request to change the assignee (S26.05). */
export interface StudioChangeRequest {
  readonly at: string;
  readonly note: string | null;
  /** min(at + 6 h, startAt). */
  readonly respondBy: string;
  readonly status: 'pending' | 'reassigned' | 'declined' | 'expired';
  readonly declineReason: string | null;
  readonly answeredAt: string | null;
}

export interface StudioFault {
  readonly kind: StudioFaultKind;
  readonly at: string;
}

export type AssignReminder = 'h48' | 'h26';
export type BookingSource = 'package' | 'quote' | 'instant' | 'spot' | 'spot_slot';

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
  /** Add-on lines; written only when there is at least one (readers default to []). */
  readonly addons?: readonly AddonLine[];
  /** Written only with a transport add-on; never copied to a public document or a message. */
  readonly pickup?: BookingPickup;
  readonly status: BookingStatus;
  readonly deposit: number;
  readonly remaining: number;
  readonly escrowStatus?: EscrowStatus;
  readonly depositRefunded?: number;
  readonly depositProvider?: PaymentProvider;
  readonly depositPaidAt?: string;
  readonly depositRefundedAt?: string;
  /**
   * Server-written (#141 Decision 6): the booking's cancel/decline/expiry refund waits in
   * `awaiting_account` for the customer to confirm an account (S05.02 row, S22.04); false once chosen.
   */
  readonly refundAccountNeeded?: boolean;
  readonly acceptDeadline?: string;
  readonly cancel?: BookingCancel;
  readonly completedAt?: string;
  readonly reviewedAt?: string;
  /** The booking's latest dispute (S18), open or resolved; written only by the dispute transaction (server). */
  readonly disputeId?: string | null;
  readonly chatId?: string;
  readonly source?: BookingSource;
  readonly spotId?: string;
  readonly spotScheduleId?: string;
  readonly slotOfferId?: string;
  /** Draft only: the payment the customer is paying now. */
  readonly checkout?: BookingCheckout;
  /**
   * Draft only, ISO-8601 UTC: the draft sweep deletes the draft from this instant on.
   * `createdAt + DRAFT_EXPIRY_MINUTES`, pushed to `expiresAt + DRAFT_PAYMENT_GRACE_MINUTES` by each new payment.
   */
  readonly payableUntil?: string;
  /** Number of free revision rounds included in this booking. */
  readonly revisionsIncluded?: number;
  readonly revisionsUsed?: number;
  readonly revisionsGranted?: number;
  readonly deliveryRound?: number;
  readonly shotAt?: string;
  readonly deliveredAt?: string;
  readonly approvedAt?: string;
  readonly checkUntil?: string;
  readonly autoApproveAt?: string;
  readonly autoApproveNoticeAt?: string | null;
  readonly extraRound?: ExtraRound | null;
  readonly samplesPurgeAfter?: string | null;
  readonly samplesPurged?: boolean;
  // ── Studio bookings only (#136; absent on individual bookings) ──
  readonly isStudio?: boolean;
  /** Who shoots for the studio; kept after "Trả việc" until the studio reassigns. */
  readonly assigneeId?: string | null;
  readonly assigneeKind?: AssigneeKind | null;
  /**
   * S27: false while a collaborator's offer waits for an answer (the booking stays unassigned, the collaborator
   * has no calendar block, chat membership or contact); true once accepted, and for a member.
   */
  readonly assigneeAccepted?: boolean;
  /** `assigned` once the assignee is confirmed (a member, or a collaborator who accepted). */
  readonly assignStatus?: 'unassigned' | 'assigned';
  /** ISO; max(startAt − 24 h, createdAt + 2 h), never after startAt. */
  readonly assignDeadline?: string;
  /** Set once by the sweep when the deadline passed unassigned; stays as history after a late assignment. */
  readonly assignOverdue?: boolean;
  readonly assignedAt?: string | null;
  readonly assignments?: readonly StudioAssignment[];
  readonly assignRemindersSent?: readonly AssignReminder[];
  readonly changeRequest?: StudioChangeRequest | null;
  readonly studioFault?: StudioFault | null;
  readonly assignmentReturned?: { readonly at: string; readonly reason: string | null } | null;
  readonly version: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

