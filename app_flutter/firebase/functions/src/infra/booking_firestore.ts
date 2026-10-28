/**
 * Firestore mapping and BookingStore implementation for Firebase Cloud Functions.
 */

import {
  FieldValue,
  Timestamp,
  GeoPoint,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  MAX_MEMBERS_VERIFIED,
  PAYMENT_METHODS,
  acceptsOrders,
  collabJobId,
  collaborationId,
  escrowRefundedTotal,
  formatVnDate,
  isAddonKind,
  isAddonUnit,
  isPaymentMethod,
  isPaymentSubject,
  parseVnDateTime,
  waitsForAssignee,
  type AddonLine,
  type AssigneeKind,
  type Booking,
  type BookingPickup,
  type BookingCheckout,
  type BookingContactSnapshot,
  type BookingSource,
  type BookingStatus,
  type BookingTerms,
  type EscrowStatus,
  type PaymentProvider,
  type AvailabilityDayRecord,
  type StudioBookingStore,
  type StudioAssignment,
  type StudioBookingTx,
  type StudioDayLoad,
  type Payment,
  type PaymentDispute,
  type PaymentStatus,
  type Refund,
  type RefundStatus,
  type StoredBankAccount,
  type LedgerEntry,
  type LedgerEntryType,
  type TransferOutcome,
  type TransferRecord,
  type DeliverySample,
  type SlotOffer,
  type SpotDay,
} from '@photobooking/domain';
import {
  deliveryRoundToFirestore,
  deliveryRoundFromFirestore,
  deliverySampleFromFirestore,
  privateDeliveryToFirestore,
  privateDeliveryFromFirestore,
} from './delivery_firestore.js';
import {
  SPOTS_COLLECTION,
  SPOT_SCHEDULES_COLLECTION,
  SPOT_SLOT_OFFERS_COLLECTION,
  SPOT_DAYS_COLLECTION,
  spotFromFirestore,
  scheduleFromFirestore,
  offerFromFirestore,
  spotDayFromFirestore,
  spotDayToFirestore,
} from './spot_firestore.js';
import {
  COLLAB_JOBS_COLLECTION,
  RECRUIT_COUNTERS_DOC,
  STUDIO_COLLABORATIONS_COLLECTION,
  collabJobFromDoc,
  collabJobToDoc,
  collaborationFromDoc,
  countersFromDoc,
} from './recruit_mapping.js';

export const BOOKINGS_COLLECTION = 'bookings';
export const AVAILABILITY_COLLECTION = 'availability';
export const PAYMENTS_COLLECTION = 'payments';
export const REFUNDS_COLLECTION = 'refunds';
export const LEDGER_COLLECTION = 'ledger_entries';
/** One handled provider notification per doc, id `${provider}_${txnId}` (server only). */
export const PAYMENT_NOTIFICATIONS_COLLECTION = 'payment_notifications';
/** `${studioId}_${day}`, server only (#136 Decision 26). */
export const STUDIO_DAY_LOAD_COLLECTION = 'studio_day_load';

function toIsoString(v: unknown): string | undefined {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return undefined;
}

function toTimestamp(iso: string | null | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

/** The client mirror of the open payment (#129 Decision 14); absent optional fields are not written. */
function checkoutToFirestore(c: BookingCheckout | undefined): DocumentData | null {
  if (!c) return null;
  const optional = {
    qrPayload: c.qrPayload,
    bankName: c.bankName,
    accountMasked: c.accountMasked,
    payUrl: c.payUrl,
    bankAppsUrl: c.bankAppsUrl,
  };
  return {
    paymentId: c.paymentId,
    method: c.method,
    amount: c.amount,
    expiresAt: toTimestamp(c.expiresAt),
    transferCode: c.transferCode,
    attempt: c.attempt,
    ...Object.fromEntries(Object.entries(optional).filter(([, v]) => v !== undefined)),
  };
}

function checkoutFromFirestore(d: unknown): BookingCheckout | undefined {
  if (!d || typeof d !== 'object') return undefined;
  const c = d as Record<string, unknown>;
  const expiresAt = toIsoString(c.expiresAt);
  if (
    typeof c.paymentId !== 'string' ||
    !isPaymentMethod(c.method) ||
    typeof c.amount !== 'number' ||
    expiresAt === undefined ||
    typeof c.transferCode !== 'string' ||
    typeof c.attempt !== 'number'
  ) {
    return undefined;
  }
  const str = (k: string): string | undefined => (typeof c[k] === 'string' ? (c[k] as string) : undefined);
  const optional = {
    qrPayload: str('qrPayload'),
    bankName: str('bankName'),
    accountMasked: str('accountMasked'),
    payUrl: str('payUrl'),
    bankAppsUrl: str('bankAppsUrl'),
  };
  return {
    paymentId: c.paymentId,
    method: c.method,
    amount: c.amount,
    expiresAt,
    transferCode: c.transferCode,
    attempt: c.attempt,
    ...(Object.fromEntries(Object.entries(optional).filter(([, v]) => v !== undefined)) as Partial<BookingCheckout>),
  };
}

/** The studio fields (#136); written only on studio bookings. */
function studioFieldsToFirestore(b: Booking): DocumentData {
  if (b.isStudio !== true) return {};
  const cr = b.changeRequest ?? null;
  return {
    isStudio: true,
    assigneeId: b.assigneeId ?? null,
    assigneeKind: b.assigneeKind ?? null,
    // S27: false while a collaborator's offer waits (rules keep the customer contact closed until true).
    ...(b.assigneeAccepted !== undefined ? { assigneeAccepted: b.assigneeAccepted } : {}),
    assignStatus: b.assignStatus ?? 'unassigned',
    assignDeadline: toTimestamp(b.assignDeadline),
    assignOverdue: b.assignOverdue ?? false,
    assignedAt: toTimestamp(b.assignedAt),
    assignments: (b.assignments ?? []).map((a) => ({
      assigneeId: a.assigneeId,
      assigneeKind: a.assigneeKind,
      at: toTimestamp(a.at),
      by: a.by,
      reason: a.reason,
      late: a.late,
      // S27 collaborator offers only; the agreed fee is never on the booking (#151 Decision 3).
      ...(a.offerExpiresAt !== undefined ? { offerExpiresAt: toTimestamp(a.offerExpiresAt) } : {}),
      ...(a.acceptedAt !== undefined ? { acceptedAt: toTimestamp(a.acceptedAt) } : {}),
      ...(a.declinedAt !== undefined ? { declinedAt: toTimestamp(a.declinedAt) } : {}),
    })),
    assignRemindersSent: [...(b.assignRemindersSent ?? [])],
    changeRequest: cr
      ? {
          at: toTimestamp(cr.at),
          note: cr.note,
          respondBy: toTimestamp(cr.respondBy),
          status: cr.status,
          declineReason: cr.declineReason,
          answeredAt: toTimestamp(cr.answeredAt),
        }
      : null,
    studioFault: b.studioFault ? { kind: b.studioFault.kind, at: toTimestamp(b.studioFault.at) } : null,
    assignmentReturned: b.assignmentReturned
      ? { at: toTimestamp(b.assignmentReturned.at), reason: b.assignmentReturned.reason }
      : null,
  };
}

/** A stored assignee kind; anything else is null (an entry without one predates S27 and is a member). */
function assigneeKindOf(v: unknown): AssigneeKind | null {
  return v === 'member' || v === 'collaborator' ? v : null;
}

function studioFieldsFromFirestore(d: DocumentData): Partial<Booking> {
  if (d.isStudio !== true) return {};
  const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
  const cr = d.changeRequest && typeof d.changeRequest === 'object' ? (d.changeRequest as Record<string, unknown>) : null;
  const fault = d.studioFault && typeof d.studioFault === 'object' ? (d.studioFault as Record<string, unknown>) : null;
  const returned =
    d.assignmentReturned && typeof d.assignmentReturned === 'object'
      ? (d.assignmentReturned as Record<string, unknown>)
      : null;
  return {
    isStudio: true,
    assigneeId: str(d.assigneeId),
    assigneeKind: assigneeKindOf(d.assigneeKind),
    ...(typeof d.assigneeAccepted === 'boolean' ? { assigneeAccepted: d.assigneeAccepted } : {}),
    assignStatus: d.assignStatus === 'assigned' ? 'assigned' : 'unassigned',
    ...(toIsoString(d.assignDeadline) !== undefined ? { assignDeadline: toIsoString(d.assignDeadline) } : {}),
    assignOverdue: d.assignOverdue === true,
    assignedAt: toIsoString(d.assignedAt) ?? null,
    assignments: Array.isArray(d.assignments)
      ? d.assignments.map((raw: Record<string, unknown>): StudioAssignment => {
          const offerExpiresAt = toIsoString(raw?.offerExpiresAt);
          const acceptedAt = toIsoString(raw?.acceptedAt);
          const declinedAt = toIsoString(raw?.declinedAt);
          return {
            assigneeId: String(raw?.assigneeId ?? ''),
            assigneeKind: assigneeKindOf(raw?.assigneeKind) ?? 'member',
            at: toIsoString(raw?.at) ?? '',
            by: String(raw?.by ?? ''),
            reason: str(raw?.reason),
            late: raw?.late === true,
            ...(offerExpiresAt !== undefined ? { offerExpiresAt } : {}),
            ...(acceptedAt !== undefined ? { acceptedAt } : {}),
            ...(declinedAt !== undefined ? { declinedAt } : {}),
          };
        })
      : [],
    assignRemindersSent: Array.isArray(d.assignRemindersSent)
      ? d.assignRemindersSent.filter((r: unknown): r is 'h48' | 'h26' => r === 'h48' || r === 'h26')
      : [],
    changeRequest: cr
      ? {
          at: toIsoString(cr.at) ?? '',
          note: str(cr.note),
          respondBy: toIsoString(cr.respondBy) ?? '',
          status: (['pending', 'reassigned', 'declined', 'expired'] as const).find((s) => s === cr.status) ?? 'pending',
          declineReason: str(cr.declineReason),
          answeredAt: toIsoString(cr.answeredAt) ?? null,
        }
      : null,
    studioFault:
      fault &&
      (fault.kind === 'assign_overdue' ||
        fault.kind === 'change_declined' ||
        fault.kind === 'change_expired' ||
        fault.kind === 'late_reassign')
        ? { kind: fault.kind, at: toIsoString(fault.at) ?? '' }
        : null,
    assignmentReturned: returned ? { at: toIsoString(returned.at) ?? '', reason: str(returned.reason) } : null,
  };
}

function studioDayLoadFromFirestore(studioId: string, day: string, d: DocumentData | undefined): StudioDayLoad | null {
  if (!d) return null;
  const ids = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
  return {
    studioId,
    day,
    unassignedIds: ids(d.unassignedIds),
    assignedIds: ids(d.assignedIds),
    updatedAt: toIsoString(d.updatedAt) ?? '',
  };
}

export function termsToFirestore(t: BookingTerms): DocumentData {
  return {
    price: t.price,
    durationMinutes: t.durationMinutes,
    photoCount: t.photoCount ?? null,
    editedCount: t.editedCount,
    deliveryDays: t.deliveryDays,
    revisions: t.revisions,
    milestones: t.milestones.map((m) => ({ kind: m.kind, percent: m.percent })),
  };
}

export function termsFromFirestore(v: unknown): BookingTerms | undefined {
  if (!v || typeof v !== 'object') return undefined;
  const d = v as Record<string, unknown>;
  if (
    typeof d.price !== 'number' ||
    typeof d.durationMinutes !== 'number' ||
    typeof d.editedCount !== 'number' ||
    typeof d.deliveryDays !== 'number' ||
    typeof d.revisions !== 'number' ||
    !Array.isArray(d.milestones)
  ) {
    return undefined;
  }
  const milestones: { kind: 'shoot' | 'delivery'; percent: number }[] = [];
  for (const m of d.milestones) {
    if (m && typeof m === 'object' && (m.kind === 'shoot' || m.kind === 'delivery') && typeof m.percent === 'number') {
      milestones.push({ kind: m.kind, percent: m.percent });
    }
  }
  return {
    price: d.price,
    durationMinutes: d.durationMinutes,
    photoCount: typeof d.photoCount === 'number' ? d.photoCount : null,
    editedCount: d.editedCount,
    deliveryDays: d.deliveryDays,
    revisions: d.revisions,
    milestones,
  };
}

export function bookingToFirestore(b: Booking): DocumentData {
  return {
    customerId: b.customerId,
    photographerId: b.photographerId,
    serviceId: b.serviceId,
    serviceSnapshot: {
      name: b.serviceSnapshot.name,
      price: b.serviceSnapshot.price,
      durationMinutes: b.serviceSnapshot.durationMinutes,
    },
    day: b.day,
    start: b.start,
    end: b.end,
    place: {
      name: b.place.name,
      point: b.place.point ? new GeoPoint(b.place.point.lat, b.place.point.lng) : null,
    },
    note: b.note ?? null,
    ...(b.addons && b.addons.length > 0
      ? {
          addons: b.addons.map((l) => ({
            addonId: l.addonId,
            kind: l.kind,
            name: l.name,
            unit: l.unit,
            unitPrice: l.unitPrice,
            qty: l.qty,
            amount: l.amount,
          })),
        }
      : {}),
    ...(b.pickup
      ? {
          pickup: {
            name: b.pickup.name,
            point: b.pickup.point ? new GeoPoint(b.pickup.point.lat, b.pickup.point.lng) : null,
          },
        }
      : {}),
    status: b.status,
    deposit: b.deposit,
    remaining: b.remaining,
    escrowStatus: b.escrowStatus ?? null,
    depositRefunded: b.depositRefunded ?? 0,
    depositProvider: b.depositProvider ?? null,
    depositPaidAt: toTimestamp(b.depositPaidAt),
    depositRefundedAt: toTimestamp(b.depositRefundedAt),
    ...(b.refundAccountNeeded !== undefined ? { refundAccountNeeded: b.refundAccountNeeded } : {}),
    acceptDeadline: toTimestamp(b.acceptDeadline),
    cancel: b.cancel
      ? {
          by: b.cancel.by,
          reason: b.cancel.reason ?? null,
          at: toTimestamp(b.cancel.at),
          refundPercent: b.cancel.refundPercent,
        }
      : null,
    completedAt: toTimestamp(b.completedAt),
    reviewedAt: toTimestamp(b.reviewedAt),
    // S18: the dispute mirror (written by the dispute transaction) survives every booking write.
    disputeId: b.disputeId ?? null,
    chatId: b.chatId ?? null,
    revisionsIncluded: b.revisionsIncluded ?? null,
    revisionsUsed: b.revisionsUsed ?? null,
    revisionsGranted: b.revisionsGranted ?? null,
    deliveryRound: b.deliveryRound ?? null,
    shotAt: toTimestamp(b.shotAt),
    deliveredAt: toTimestamp(b.deliveredAt),
    approvedAt: toTimestamp(b.approvedAt),
    checkUntil: toTimestamp(b.checkUntil),
    autoApproveAt: toTimestamp(b.autoApproveAt),
    autoApproveNoticeAt: toTimestamp(b.autoApproveNoticeAt),
    extraRound: b.extraRound
      ? {
          status: b.extraRound.status,
          at: toTimestamp(b.extraRound.at),
          note: b.extraRound.note ?? null,
          photoNotes: b.extraRound.photoNotes.map((pn) => ({
            sampleIndex: pn.sampleIndex,
            note: pn.note,
          })),
        }
      : null,
    samplesPurgeAfter: toTimestamp(b.samplesPurgeAfter),
    samplesPurged: b.samplesPurged ?? false,
    source: b.source ?? null,
    jobId: b.jobId ?? null,
    quoteId: b.quoteId ?? null,
    terms: b.terms ? termsToFirestore(b.terms) : null,
    spotId: b.spotId ?? null,
    spotScheduleId: b.spotScheduleId ?? null,
    slotOfferId: b.slotOfferId ?? null,
    checkout: checkoutToFirestore(b.checkout),
    payableUntil: toTimestamp(b.payableUntil),
    ...studioFieldsToFirestore(b),
    version: b.version,
    createdAt: toTimestamp(b.createdAt),
    updatedAt: toTimestamp(b.updatedAt),
  };
}

function addonLinesFromFirestore(v: unknown): AddonLine[] {
  if (!Array.isArray(v)) return [];
  const lines: AddonLine[] = [];
  for (const raw of v) {
    const l = (raw ?? {}) as Record<string, unknown>;
    if (
      typeof l.addonId === 'string' &&
      isAddonKind(l.kind) &&
      typeof l.name === 'string' &&
      isAddonUnit(l.unit) &&
      typeof l.unitPrice === 'number' &&
      typeof l.qty === 'number' &&
      typeof l.amount === 'number'
    ) {
      lines.push({
        addonId: l.addonId,
        kind: l.kind,
        name: l.name,
        unit: l.unit,
        unitPrice: l.unitPrice,
        qty: l.qty,
        amount: l.amount,
      });
    }
  }
  return lines;
}

function pickupFromFirestore(v: unknown): BookingPickup | undefined {
  if (typeof v !== 'object' || v === null) return undefined;
  const p = v as { name?: unknown; point?: unknown };
  if (typeof p.name !== 'string') return undefined;
  return {
    name: p.name,
    ...(p.point instanceof GeoPoint ? { point: { lat: p.point.latitude, lng: p.point.longitude } } : {}),
  };
}

export function bookingFromFirestore(id: string, d: DocumentData | undefined): Booking | null {
  if (!d) return null;
  const { customerId, photographerId, serviceId, serviceSnapshot, day, start, end, place, status } = d;
  if (
    typeof customerId !== 'string' ||
    typeof photographerId !== 'string' ||
    typeof serviceId !== 'string' ||
    !serviceSnapshot ||
    typeof day !== 'string' ||
    typeof start !== 'string' ||
    typeof end !== 'string' ||
    !place ||
    typeof status !== 'string'
  ) {
    return null;
  }

  const checkout = checkoutFromFirestore(d.checkout);
  const payableUntil = toIsoString(d.payableUntil);
  const pointGeo = place.point instanceof GeoPoint ? { lat: place.point.latitude, lng: place.point.longitude } : undefined;

  const addons = addonLinesFromFirestore(d.addons);
  const pickup = pickupFromFirestore(d.pickup);

  let cancelObj: Booking['cancel'] | undefined;
  if (d.cancel && typeof d.cancel === 'object') {
    cancelObj = {
      by: d.cancel.by,
      reason: d.cancel.reason ?? undefined,
      at: toIsoString(d.cancel.at) ?? new Date().toISOString(),
      refundPercent: d.cancel.refundPercent ?? 0,
    };
  }

  return {
    id,
    customerId,
    photographerId,
    serviceId,
    serviceSnapshot: {
      name: serviceSnapshot.name,
      price: serviceSnapshot.price,
      durationMinutes: serviceSnapshot.durationMinutes,
    },
    day,
    start,
    end,
    place: {
      name: place.name,
      point: pointGeo,
    },
    note: d.note ?? undefined,
    ...(addons.length > 0 ? { addons } : {}),
    ...(pickup !== undefined ? { pickup } : {}),
    status: status as BookingStatus,
    deposit: typeof d.deposit === 'number' ? d.deposit : typeof (d.deposit as { amount?: unknown })?.amount === 'number' ? (d.deposit as { amount: number }).amount : 0,
    remaining: d.remaining,
    escrowStatus: (d.escrowStatus as EscrowStatus) ?? undefined,
    depositRefunded: d.depositRefunded ?? undefined,
    depositProvider: (d.depositProvider as PaymentProvider) ?? undefined,
    depositPaidAt: toIsoString(d.depositPaidAt),
    depositRefundedAt: toIsoString(d.depositRefundedAt),
    ...(typeof d.refundAccountNeeded === 'boolean' ? { refundAccountNeeded: d.refundAccountNeeded } : {}),
    acceptDeadline: toIsoString(d.acceptDeadline),
    cancel: cancelObj,
    completedAt: toIsoString(d.completedAt),
    reviewedAt: toIsoString(d.reviewedAt),
    ...(typeof d.disputeId === 'string' && d.disputeId !== '' ? { disputeId: d.disputeId } : {}),
    chatId: d.chatId ?? undefined,
    source: typeof d.source === 'string' ? (d.source as BookingSource) : 'package',
    ...(typeof d.jobId === 'string' ? { jobId: d.jobId } : {}),
    ...(typeof d.quoteId === 'string' ? { quoteId: d.quoteId } : {}),
    ...(d.terms ? { terms: termsFromFirestore(d.terms) } : {}),
    ...(typeof d.spotId === 'string' ? { spotId: d.spotId } : {}),
    ...(typeof d.spotScheduleId === 'string' ? { spotScheduleId: d.spotScheduleId } : {}),
    ...(typeof d.slotOfferId === 'string' ? { slotOfferId: d.slotOfferId } : {}),
    ...(typeof d.revisionsIncluded === 'number' ? { revisionsIncluded: d.revisionsIncluded } : {}),
    ...(typeof d.revisionsUsed === 'number' ? { revisionsUsed: d.revisionsUsed } : {}),
    ...(typeof d.revisionsGranted === 'number' ? { revisionsGranted: d.revisionsGranted } : {}),
    ...(typeof d.deliveryRound === 'number' ? { deliveryRound: d.deliveryRound } : {}),
    shotAt: toIsoString(d.shotAt),
    deliveredAt: toIsoString(d.deliveredAt),
    approvedAt: toIsoString(d.approvedAt),
    checkUntil: toIsoString(d.checkUntil),
    autoApproveAt: toIsoString(d.autoApproveAt),
    autoApproveNoticeAt: d.autoApproveNoticeAt !== undefined ? toIsoString(d.autoApproveNoticeAt) : undefined,
    extraRound: d.extraRound && typeof d.extraRound === 'object'
      ? {
          status: d.extraRound.status,
          at: toIsoString(d.extraRound.at) ?? new Date(0).toISOString(),
          note: typeof d.extraRound.note === 'string' ? d.extraRound.note : null,
          photoNotes: Array.isArray(d.extraRound.photoNotes)
            ? d.extraRound.photoNotes.map((pn: { sampleIndex?: unknown; note?: unknown }) => ({
                sampleIndex: Number(pn?.sampleIndex ?? 0),
                note: String(pn?.note ?? ''),
              }))
            : [],
        }
      : null,
    samplesPurgeAfter: d.samplesPurgeAfter !== undefined ? toIsoString(d.samplesPurgeAfter) : undefined,
    samplesPurged: Boolean(d.samplesPurged),
    ...(checkout !== undefined ? { checkout } : {}),
    ...(payableUntil !== undefined ? { payableUntil } : {}),
    ...studioFieldsFromFirestore(d),
    version: d.version ?? 1,
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

/**
 * `payments/{id}.dispute` (S18): `{reason, openedAt, disputeId?, milestone?, prevEscrowStatus?}`. Only the
 * fields present are written, so a row from before S18 (`reason` + `openedAt`) reads back unchanged.
 */
function paymentDisputeToFirestore(x: PaymentDispute): DocumentData {
  return {
    reason: x.reason,
    openedAt: toTimestamp(x.openedAt),
    ...(x.disputeId !== undefined ? { disputeId: x.disputeId } : {}),
    ...(x.milestone !== undefined ? { milestone: x.milestone } : {}),
    ...(x.prevEscrowStatus !== undefined ? { prevEscrowStatus: x.prevEscrowStatus } : {}),
  };
}

function paymentDisputeFromFirestore(v: unknown): PaymentDispute | null {
  if (typeof v !== 'object' || v === null) return null;
  const d = v as Record<string, unknown>;
  if (typeof d.reason !== 'string') return null;
  const m = d.milestone;
  const prev = d.prevEscrowStatus;
  return {
    reason: d.reason,
    openedAt: toIsoString(d.openedAt) ?? new Date(0).toISOString(),
    ...(typeof d.disputeId === 'string' && d.disputeId !== '' ? { disputeId: d.disputeId } : {}),
    ...(m === null || m === 'shoot' || m === 'delivery' ? { milestone: m } : {}),
    ...(prev === 'held' || prev === 'partially_refunded' ? { prevEscrowStatus: prev } : {}),
  };
}

export function paymentToFirestore(p: Payment): DocumentData {
  return {
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    // Ticket payments carry their event (the event's escrow sweeps query it); bookings write null.
    eventId: p.eventId ?? null,
    payerId: p.payerId,
    payeeId: p.payeeId,
    provider: p.provider,
    amount: p.amount,
    status: p.status,
    escrowStatus: p.escrowStatus,
    idempotencyKey: p.idempotencyKey,
    providerRef: p.providerRef ?? null,
    // Checkout payments (createPayment); null on ticket and older deposit payments.
    method: p.method ?? null,
    transferCode: p.transferCode ?? null,
    expiresAt: toTimestamp(p.expiresAt),
    receivedAmount: p.receivedAmount ?? null,
    instructions: p.instructions ?? null,
    payer: p.payer ? {
      bankCode: p.payer.bankCode,
      bankName: p.payer.bankName,
      accountNumberEnc: p.payer.accountNumberEnc,
      accountLast4: p.payer.accountLast4,
      holderName: p.payer.holderName,
    } : null,
    refundedAmount: p.refundedAmount ?? null,
    paidAt: toTimestamp(p.paidAt),
    releasedAt: toTimestamp(p.releasedAt),
    releaseAfter: toTimestamp(p.releaseAfter),
    dispute: p.dispute ? paymentDisputeToFirestore(p.dispute) : null,
    payoutId: p.payoutId ?? null,
    payableAmount: p.payableAmount ?? null,
    // An instant payment's platform fee snapshot (Decision 6); absent → the payout policy's rate.
    ...(p.feeBp !== undefined ? { feeBp: p.feeBp } : {}),
    milestones: p.milestones
      ? p.milestones.map((m) => ({
          kind: m.kind,
          amount: m.amount,
          status: m.status,
          releaseAfter: toTimestamp(m.releaseAfter),
          releasedAt: toTimestamp(m.releasedAt),
          payoutId: m.payoutId ?? null,
        }))
      : null,
    createdAt: toTimestamp(p.createdAt),
    updatedAt: toTimestamp(p.updatedAt),
  };
}

export function paymentFromFirestore(id: string, d: DocumentData | undefined): Payment | null {
  if (!d) return null;
  const payer = d.payer && typeof d.payer === 'object' && typeof d.payer.bankCode === 'string'
    ? {
        bankCode: d.payer.bankCode,
        bankName: d.payer.bankName ?? d.payer.bankCode,
        accountNumberEnc: d.payer.accountNumberEnc,
        accountLast4: d.payer.accountLast4,
        holderName: d.payer.holderName,
      }
    : d.payer === null ? null : undefined;

  return {
    id,
    subjectType: d.subjectType,
    subjectId: d.subjectId,
    ...(typeof d.eventId === 'string' && d.eventId !== '' ? { eventId: d.eventId } : {}),
    payerId: d.payerId,
    payeeId: d.payeeId,
    provider: d.provider as PaymentProvider,
    amount: d.amount,
    status: d.status as PaymentStatus,
    escrowStatus: d.escrowStatus as EscrowStatus,
    idempotencyKey: d.idempotencyKey,
    providerRef: d.providerRef ?? undefined,
    ...(isPaymentMethod(d.method) ? { method: d.method } : {}),
    ...(typeof d.transferCode === 'string' && d.transferCode !== '' ? { transferCode: d.transferCode } : {}),
    ...(toIsoString(d.expiresAt) !== undefined ? { expiresAt: toIsoString(d.expiresAt) } : {}),
    ...(typeof d.receivedAmount === 'number' ? { receivedAmount: d.receivedAmount } : {}),
    ...(d.instructions && typeof d.instructions === 'object' ? { instructions: d.instructions } : {}),
    ...(payer !== undefined ? { payer } : {}),
    ...(typeof d.refundedAmount === 'number' ? { refundedAmount: d.refundedAmount } : {}),
    paidAt: toIsoString(d.paidAt),
    releasedAt: toIsoString(d.releasedAt),
    releaseAfter: toIsoString(d.releaseAfter),
    dispute: paymentDisputeFromFirestore(d.dispute),
    payoutId: typeof d.payoutId === 'string' && d.payoutId !== '' ? d.payoutId : null,
    ...(typeof d.payableAmount === 'number' ? { payableAmount: d.payableAmount } : {}),
    ...(typeof d.feeBp === 'number' && Number.isInteger(d.feeBp) && d.feeBp >= 0 && d.feeBp <= 10_000 ? { feeBp: d.feeBp } : {}),
    ...(Array.isArray(d.milestones)
      ? {
          milestones: d.milestones.map((m: { kind?: unknown; amount?: unknown; status?: unknown; releaseAfter?: unknown; releasedAt?: unknown; payoutId?: unknown }) => ({
            kind: m.kind as 'shoot' | 'delivery',
            amount: Number(m.amount ?? 0),
            status: m.status as 'held' | 'released' | 'paid_out' | 'disputed' | 'refunded',
            releaseAfter: toIsoString(m.releaseAfter) ?? null,
            releasedAt: toIsoString(m.releasedAt) ?? null,
            payoutId: typeof m.payoutId === 'string' && m.payoutId !== '' ? m.payoutId : null,
          })),
        }
      : {}),
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

export function refundToFirestore(r: Refund): DocumentData {
  return {
    paymentId: r.paymentId,
    subjectType: r.subjectType ?? null,
    amount: r.amount,
    percent: r.percent,
    status: r.status,
    method: r.method,
    destination: r.destination ? {
      bankCode: r.destination.bankCode,
      bankName: r.destination.bankName,
      accountNumberEnc: r.destination.accountNumberEnc,
      accountLast4: r.destination.accountLast4,
      holderName: r.destination.holderName,
      source: r.destination.source,
    } : null,
    confirmBy: toTimestamp(r.confirmBy),
    // S22.04 (#141): the account the customer looked up, number encrypted; cleared once chosen.
    candidate: r.candidate ? storedBankAccountToFirestore(r.candidate) : null,
    // S22.04 holder-name lookups charged to this refund's Vietnam day (the cap).
    accountLookups: r.accountLookups ? { day: r.accountLookups.day, count: r.accountLookups.count } : null,
    attempts: r.attempts,
    lastAttemptAt: toTimestamp(r.lastAttemptAt),
    failureReason: r.failureReason ?? null,
    manual: r.manual,
    fromEscrow: r.fromEscrow,
    reason: r.reason ?? null,
    providerRef: r.providerRef ?? null,
    createdAt: toTimestamp(r.createdAt),
    updatedAt: toTimestamp(r.updatedAt),
  };
}

/** A stored bank account (refund `candidate`): number encrypted, never a plain field. */
function storedBankAccountToFirestore(a: StoredBankAccount): DocumentData {
  return {
    bankCode: a.bankCode,
    bankName: a.bankName,
    accountNumberEnc: a.accountNumberEnc,
    accountLast4: a.accountLast4,
    holderName: a.holderName,
  };
}

function storedBankAccountFromFirestore(v: unknown): StoredBankAccount | undefined {
  if (typeof v !== 'object' || v === null) return undefined;
  const a = v as Record<string, unknown>;
  if (typeof a.bankCode !== 'string' || typeof a.accountNumberEnc !== 'string') return undefined;
  return {
    bankCode: a.bankCode,
    bankName: typeof a.bankName === 'string' ? a.bankName : a.bankCode,
    accountNumberEnc: a.accountNumberEnc,
    accountLast4: typeof a.accountLast4 === 'string' ? a.accountLast4 : '',
    holderName: typeof a.holderName === 'string' ? a.holderName : '',
  };
}

export function refundFromFirestore(id: string, d: DocumentData | undefined): Refund | null {
  if (!d) return null;
  const candidate = storedBankAccountFromFirestore(d.candidate);
  const destination = d.destination && typeof d.destination === 'object' && typeof d.destination.bankCode === 'string'
    ? {
        bankCode: d.destination.bankCode,
        bankName: d.destination.bankName ?? d.destination.bankCode,
        accountNumberEnc: d.destination.accountNumberEnc,
        accountLast4: d.destination.accountLast4,
        holderName: d.destination.holderName,
        source: d.destination.source as 'payer' | 'customer',
      }
    : undefined;

  return {
    id,
    paymentId: d.paymentId,
    ...(isPaymentSubject(d.subjectType) ? { subjectType: d.subjectType } : {}),
    amount: d.amount,
    percent: d.percent,
    status: d.status as RefundStatus,
    method: (d.method as Refund['method']) ?? 'gateway',
    ...(destination ? { destination } : {}),
    ...(toIsoString(d.confirmBy) !== undefined ? { confirmBy: toIsoString(d.confirmBy) } : {}),
    ...(candidate ? { candidate } : {}),
    ...(typeof d.accountLookups?.day === 'string' && typeof d.accountLookups?.count === 'number'
      ? { accountLookups: { day: d.accountLookups.day, count: d.accountLookups.count } }
      : {}),
    attempts: typeof d.attempts === 'number' ? d.attempts : 0,
    ...(toIsoString(d.lastAttemptAt) !== undefined ? { lastAttemptAt: toIsoString(d.lastAttemptAt) } : {}),
    ...(typeof d.failureReason === 'string' ? { failureReason: d.failureReason } : {}),
    manual: d.manual ?? false,
    // Stored before the marker existed: a cancellation/decline/dispute refund, out of escrow.
    fromEscrow: d.fromEscrow !== false,
    ...(d.reason ? { reason: d.reason } : {}),
    ...(d.providerRef ? { providerRef: d.providerRef } : {}),
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

/**
 * What escrow gave back for one payment, from its `refunds` documents: release, payouts and
 * earnings subtract this. Money sent straight back on arrival (`fromEscrow: false`) is left out;
 * a document without the marker counts. The free-text `reason` is never read.
 */
export function escrowRefundedOfDocs(docs: readonly DocumentData[]): number {
  return escrowRefundedTotal(
    docs
      .filter((d) => typeof d.amount === 'number')
      .map((d) => ({ amount: d.amount as number, fromEscrow: d.fromEscrow !== false })),
  );
}

export function ledgerEntryToFirestore(e: LedgerEntry): DocumentData {
  return {
    type: e.type,
    paymentId: e.paymentId ?? null,
    refundId: e.refundId ?? null,
    payoutId: e.payoutId ?? null,
    subjectType: e.subjectType ?? null,
    subjectId: e.subjectId ?? null,
    accountOwnerId: e.accountOwnerId,
    amount: e.amount,
    note: e.note ?? null,
    at: toTimestamp(e.at),
  };
}

export function ledgerEntryFromFirestore(id: string, d: DocumentData | undefined): LedgerEntry | null {
  if (!d) return null;
  return {
    id,
    type: d.type as LedgerEntryType,
    ...(d.paymentId ? { paymentId: d.paymentId } : {}),
    ...(d.refundId ? { refundId: d.refundId } : {}),
    ...(d.payoutId ? { payoutId: d.payoutId } : {}),
    ...(d.subjectType ? { subjectType: d.subjectType } : {}),
    ...(d.subjectId ? { subjectId: d.subjectId } : {}),
    accountOwnerId: d.accountOwnerId,
    amount: d.amount,
    ...(d.note ? { note: d.note } : {}),
    at: toIsoString(d.at) ?? new Date().toISOString(),
  };
}

const TRANSFER_OUTCOMES: readonly string[] = ['paid', 'paid_with_refund', 'partial', 'refunded', 'needs_review'] satisfies readonly Exclude<TransferOutcome, 'duplicate'>[];

/** `payment_notifications/{id}`: `{provider, txnId, raw, receivedAt, outcome, paymentId}` (#129 Decision 4). */
export function transferRecordToFirestore(r: TransferRecord): DocumentData {
  return {
    provider: r.provider,
    txnId: r.txnId,
    raw: r.raw ?? null,
    receivedAt: toTimestamp(r.receivedAt),
    outcome: r.outcome,
    paymentId: r.paymentId ?? null,
  };
}

export function transferRecordFromFirestore(id: string, d: DocumentData | undefined): TransferRecord | null {
  if (!d) return null;
  const outcome = TRANSFER_OUTCOMES.includes(d.outcome) ? (d.outcome as TransferRecord['outcome']) : 'needs_review';
  return {
    id,
    provider: d.provider as PaymentProvider,
    txnId: d.txnId,
    ...(typeof d.raw === 'string' ? { raw: d.raw } : {}),
    receivedAt: toIsoString(d.receivedAt) ?? new Date(0).toISOString(),
    outcome,
    ...(typeof d.paymentId === 'string' && d.paymentId !== '' ? { paymentId: d.paymentId } : {}),
  };
}

function paymentsOf(docs: readonly { id: string; data(): DocumentData }[]): Payment[] {
  const res: Payment[] = [];
  for (const doc of docs) {
    const p = paymentFromFirestore(doc.id, doc.data());
    if (p) res.push(p);
  }
  return res;
}

/** A member the studio can assign and count as capacity: verified and onboarded, not being deleted (Decision 26). */
export function isAssignableMember(p: DocumentData | undefined): boolean {
  return p !== undefined && p.deletionPending !== true && acceptsOrders(p);
}

/**
 * Every active member of the studio (`photographers.studioId`, Decision 2) with whether they can be assigned and
 * whether their own day is empty, read in `tx`. The one reader behind createBooking's capacity check and the
 * derived `full` day, so both always agree.
 */
export async function readStudioMemberDays(
  firestore: Firestore,
  tx: Transaction,
  studioId: string,
  day: string,
): Promise<{ uid: string; verified: boolean; free: boolean }[]> {
  const members = await tx.get(
    firestore.collection('photographers').where('studioId', '==', studioId).limit(MAX_MEMBERS_VERIFIED),
  );
  if (members.empty) return [];
  const days = await tx.getAll(
    ...members.docs.map((m) => firestore.collection(AVAILABILITY_COLLECTION).doc(m.id).collection('days').doc(day)),
  );
  return members.docs.map((m, i) => ({
    uid: m.id,
    verified: isAssignableMember(m.data()),
    free: days[i]?.exists !== true,
  }));
}

function bookingsOf(docs: readonly { id: string; data(): DocumentData }[]): Booking[] {
  const res: Booking[] = [];
  for (const doc of docs) {
    const b = bookingFromFirestore(doc.id, doc.data());
    if (b) res.push(b);
  }
  return res;
}

export class FirestoreBookingStore implements StudioBookingStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const tx: StudioBookingTx = {
        incrementStudioCounter: (studioId, field) => {
          fTx.set(this.firestore.collection('photographers').doc(studioId), { [field]: FieldValue.increment(1) }, { merge: true });
        },
        getStudioDayLoad: async (studioId, day) => {
          const snap = await fTx.get(this.firestore.collection(STUDIO_DAY_LOAD_COLLECTION).doc(`${studioId}_${day}`));
          return snap.exists ? studioDayLoadFromFirestore(studioId, day, snap.data()) : null;
        },
        setStudioDayLoad: async (load) => {
          fTx.set(this.firestore.collection(STUDIO_DAY_LOAD_COLLECTION).doc(`${load.studioId}_${load.day}`), {
            studioId: load.studioId,
            day: load.day,
            unassignedIds: [...load.unassignedIds],
            assignedIds: [...load.assignedIds],
            updatedAt: toTimestamp(load.updatedAt),
          });
        },
        getMemberStudio: async (uid) => {
          const snap = await fTx.get(this.firestore.collection('photographers').doc(uid));
          const studioId = snap.data()?.studioId;
          return typeof studioId === 'string' && studioId !== '' ? studioId : null;
        },
        getMemberDays: (studioId, day) => readStudioMemberDays(this.firestore, fTx, studioId, day),
        // S27 (#151) collaborator offers run in this transaction: the collaboration, the collab job (fee and
        // offer, never on the booking) and the studio's recruit counters (recruitBlockedUntil).
        getCollaboration: async (studioId, uid) => {
          const snap = await fTx.get(this.firestore.collection(STUDIO_COLLABORATIONS_COLLECTION).doc(collaborationId(studioId, uid)));
          return snap.exists ? collaborationFromDoc(snap.id, snap.data()) : null;
        },
        getCollabJob: async (bookingId, uid) => {
          const snap = await fTx.get(this.firestore.collection(COLLAB_JOBS_COLLECTION).doc(collabJobId(bookingId, uid)));
          return snap.exists ? collabJobFromDoc(snap.id, snap.data()) : null;
        },
        getRecruitCounters: async (uid) => {
          const snap = await fTx.get(
            this.firestore.collection('photographers').doc(uid).collection('private').doc(RECRUIT_COUNTERS_DOC),
          );
          return countersFromDoc(snap.exists ? snap.data() : undefined);
        },
        putCollabJob: (j) => {
          fTx.set(this.firestore.collection(COLLAB_JOBS_COLLECTION).doc(j.id), collabJobToDoc(j));
        },
        getBooking: async (id) => {
          const snap = await fTx.get(this.firestore.collection(BOOKINGS_COLLECTION).doc(id));
          return bookingFromFirestore(snap.id, snap.data());
        },
        getAvailabilityDay: async (photographerId, day) => {
          const snap = await fTx.get(
            this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day),
          );
          if (!snap.exists) return null;
          const d = snap.data();
          if (!d) return null;
          return {
            state: d.state,
            bookingId: typeof d.bookingId === 'string' ? d.bookingId : undefined,
            scheduleId: typeof d.scheduleId === 'string' ? d.scheduleId : undefined,
            spotId: typeof d.spotId === 'string' ? d.spotId : undefined,
          };
        },
        getCustomerDraftForDay: async (customerId, photographerId, day) => {
          const q = this.firestore
            .collection(BOOKINGS_COLLECTION)
            .where('customerId', '==', customerId)
            .where('photographerId', '==', photographerId)
            .where('day', '==', day)
            .where('status', '==', 'draft')
            .limit(1);
          const snap = await fTx.get(q);
          if (snap.empty || !snap.docs[0]) return null;
          return bookingFromFirestore(snap.docs[0].id, snap.docs[0].data());
        },
        setBooking: async (b) => {
          fTx.set(this.firestore.collection(BOOKINGS_COLLECTION).doc(b.id), bookingToFirestore(b));
        },
        deleteBooking: async (id) => {
          fTx.delete(this.firestore.collection(BOOKINGS_COLLECTION).doc(id));
        },
        setAvailabilityDay: async (photographerId, day, record) => {
          const ref = this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day);
          fTx.set(ref, record);
        },
        deleteAvailabilityDay: async (photographerId, day) => {
          const ref = this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day);
          fTx.delete(ref);
        },
        setContactSnapshot: async (bookingId, contact) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          fTx.set(ref, {
            name: contact.name,
            phone: contact.phone,
            allowZalo: contact.allowZalo,
            allowWhatsApp: contact.allowWhatsApp,
            redactedAt: toTimestamp(contact.redactedAt ?? undefined),
          });
        },
        getContactSnapshot: async (bookingId) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          const snap = await fTx.get(ref);
          if (!snap.exists) return null;
          const d = snap.data();
          if (!d) return null;
          return {
            name: d.name ?? '',
            phone: d.phone,
            allowZalo: d.allowZalo ?? false,
            allowWhatsApp: d.allowWhatsApp ?? false,
            redactedAt: toIsoString(d.redactedAt),
          };
        },
        deleteContactSnapshot: async (bookingId) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          fTx.delete(ref);
        },
        getPayment: async (id) => {
          const snap = await fTx.get(this.firestore.collection(PAYMENTS_COLLECTION).doc(id));
          return paymentFromFirestore(snap.id, snap.data());
        },
        getPaymentByIdempotencyKey: async (key) => {
          const q = this.firestore.collection(PAYMENTS_COLLECTION).where('idempotencyKey', '==', key).limit(1);
          const snap = await fTx.get(q);
          if (snap.empty || !snap.docs[0]) return null;
          return paymentFromFirestore(snap.docs[0].id, snap.docs[0].data());
        },
        setPayment: async (payment) => {
          fTx.set(this.firestore.collection(PAYMENTS_COLLECTION).doc(payment.id), paymentToFirestore(payment));
        },
        getRefund: async (id) => {
          const snap = await fTx.get(this.firestore.collection(REFUNDS_COLLECTION).doc(id));
          return refundFromFirestore(snap.id, snap.data());
        },
        addRefund: async (refund) => {
          fTx.set(this.firestore.collection(REFUNDS_COLLECTION).doc(refund.id), refundToFirestore(refund));
        },
        addLedgerEntry: async (entry) => {
          fTx.set(this.firestore.collection(LEDGER_COLLECTION).doc(entry.id), ledgerEntryToFirestore(entry));
        },
        getTransferRecord: async (id) => {
          const snap = await fTx.get(this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(id));
          return transferRecordFromFirestore(snap.id, snap.data());
        },
        saveTransferRecord: async (record) => {
          fTx.set(this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(record.id), transferRecordToFirestore(record));
        },
        addBookingEvent: async (event) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(event.bookingId).collection('events').doc(event.id);
          fTx.set(ref, {
            status: event.status,
            at: toTimestamp(event.at),
            actorId: event.actorId ?? null,
          });
        },
        getDelivery: async (bookingId, round) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('deliveries').doc(String(round));
          const snap = await fTx.get(ref);
          return deliveryRoundFromFirestore(round, snap.data());
        },
        setDelivery: async (d) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(d.bookingId).collection('deliveries').doc(String(d.round));
          fTx.set(ref, deliveryRoundToFirestore(d));
        },
        getDeliverySamples: async (bookingId, fileIds) => {
          const results: (DeliverySample | null)[] = [];
          for (const fid of fileIds) {
            const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('deliverySamples').doc(fid);
            const snap = await fTx.get(ref);
            results.push(deliverySampleFromFirestore(fid, snap.data()));
          }
          return results;
        },
        deleteDeliverySamples: async (bookingId, fileIds) => {
          for (const fid of fileIds) {
            const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('deliverySamples').doc(fid);
            fTx.delete(ref);
          }
        },
        setPrivateDelivery: async (bookingId, p) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('delivery');
          fTx.set(ref, privateDeliveryToFirestore(p));
        },
        getPrivateDelivery: async (bookingId) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('delivery');
          const snap = await fTx.get(ref);
          return privateDeliveryFromFirestore(snap.data());
        },
        getSpot: async (id) => {
          const snap = await fTx.get(this.firestore.collection(SPOTS_COLLECTION).doc(id));
          return spotFromFirestore(snap.id, snap.data());
        },
        getSpotSchedule: async (id) => {
          const snap = await fTx.get(this.firestore.collection(SPOT_SCHEDULES_COLLECTION).doc(id));
          return scheduleFromFirestore(snap.id, snap.data());
        },
        getSlotOffer: async (id) => {
          const snap = await fTx.get(this.firestore.collection(SPOT_SLOT_OFFERS_COLLECTION).doc(id));
          return offerFromFirestore(snap.id, snap.data());
        },
        getSpotDay: async (scheduleId, day) => {
          const snap = await fTx.get(this.firestore.collection(SPOT_DAYS_COLLECTION).doc(`${scheduleId}_${day}`));
          return spotDayFromFirestore(snap.data());
        },
        setSpotDay: async (spotDay) => {
          fTx.set(
            this.firestore.collection(SPOT_DAYS_COLLECTION).doc(`${spotDay.scheduleId}_${spotDay.day}`),
            spotDayToFirestore(spotDay),
          );
        },
      };

      return fn(tx);
    });
  }

  async getBooking(id: string): Promise<Booking | null> {
    const snap = await this.firestore.collection(BOOKINGS_COLLECTION).doc(id).get();
    return bookingFromFirestore(snap.id, snap.data());
  }

  async getAvailabilityDay(photographerId: string, day: string): Promise<AvailabilityDayRecord | null> {
    const snap = await this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day).get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;
    return {
      state: d.state,
      bookingId: typeof d.bookingId === 'string' ? d.bookingId : undefined,
      scheduleId: typeof d.scheduleId === 'string' ? d.scheduleId : undefined,
      spotId: typeof d.spotId === 'string' ? d.spotId : undefined,
    };
  }

  async getSlotOffer(id: string): Promise<SlotOffer | null> {
    const snap = await this.firestore.collection(SPOT_SLOT_OFFERS_COLLECTION).doc(id).get();
    return offerFromFirestore(snap.id, snap.data());
  }

  async getSpotDay(scheduleId: string, day: string): Promise<SpotDay | null> {
    const snap = await this.firestore.collection(SPOT_DAYS_COLLECTION).doc(`${scheduleId}_${day}`).get();
    return spotDayFromFirestore(snap.data());
  }

  async getCustomerDraftForDay(customerId: string, photographerId: string, day: string): Promise<Booking | null> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('customerId', '==', customerId)
      .where('photographerId', '==', photographerId)
      .where('day', '==', day)
      .where('status', '==', 'draft')
      .limit(1)
      .get();
    if (snap.empty || !snap.docs[0]) return null;
    return bookingFromFirestore(snap.docs[0].id, snap.docs[0].data());
  }

  async getPayment(id: string): Promise<Payment | null> {
    const snap = await this.firestore.collection(PAYMENTS_COLLECTION).doc(id).get();
    return paymentFromFirestore(snap.id, snap.data());
  }

  async getPaymentByIdempotencyKey(key: string): Promise<Payment | null> {
    const snap = await this.firestore.collection(PAYMENTS_COLLECTION).where('idempotencyKey', '==', key).limit(1).get();
    if (snap.empty || !snap.docs[0]) return null;
    return paymentFromFirestore(snap.docs[0].id, snap.docs[0].data());
  }

  async getPaymentsForBooking(bookingId: string): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('subjectType', '==', 'booking')
      .where('subjectId', '==', bookingId)
      .get();
    const res: Payment[] = [];
    for (const doc of snap.docs) {
      const p = paymentFromFirestore(doc.id, doc.data());
      if (p) res.push(p);
    }
    return res;
  }

  async getRefund(id: string): Promise<Refund | null> {
    const snap = await this.firestore.collection(REFUNDS_COLLECTION).doc(id).get();
    return refundFromFirestore(snap.id, snap.data());
  }

  async getRefundsForPayment(paymentId: string): Promise<readonly Refund[]> {
    const snap = await this.firestore.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId).get();
    const res: Refund[] = [];
    for (const doc of snap.docs) {
      const r = refundFromFirestore(doc.id, doc.data());
      if (r) res.push(r);
    }
    return res;
  }

  /** status pending, lastAttemptAt <= before, any subject, oldest first. */
  async findPendingRefunds(before: Date, limit = 100): Promise<readonly Refund[]> {
    const snap = await this.firestore
      .collection(REFUNDS_COLLECTION)
      .where('status', '==', 'pending')
      .where('lastAttemptAt', '<=', Timestamp.fromDate(before))
      .orderBy('lastAttemptAt')
      .limit(limit)
      .get();
    const res: Refund[] = [];
    for (const doc of snap.docs) {
      const r = refundFromFirestore(doc.id, doc.data());
      if (r) res.push(r);
    }
    return res;
  }

  /** status awaiting_account, confirmBy <= now (rows without confirmBy never), oldest first. */
  async awaitingRefundsDue(now: Date, limit = 100): Promise<readonly Refund[]> {
    const snap = await this.firestore
      .collection(REFUNDS_COLLECTION)
      .where('status', '==', 'awaiting_account')
      .where('confirmBy', '<=', Timestamp.fromDate(now))
      .orderBy('confirmBy')
      .limit(limit)
      .get();
    const res: Refund[] = [];
    for (const doc of snap.docs) {
      const r = refundFromFirestore(doc.id, doc.data());
      if (r) res.push(r);
    }
    return res;
  }

  async getLedgerEntriesForPayment(paymentId: string): Promise<readonly LedgerEntry[]> {
    const snap = await this.firestore.collection(LEDGER_COLLECTION).where('paymentId', '==', paymentId).get();
    const res: LedgerEntry[] = [];
    for (const doc of snap.docs) {
      const e = ledgerEntryFromFirestore(doc.id, doc.data());
      if (e) res.push(e);
    }
    return res;
  }

  async getContactSnapshot(bookingId: string): Promise<BookingContactSnapshot | null> {
    const snap = await this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact').get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;
    return {
      name: d.name ?? '',
      phone: d.phone,
      allowZalo: d.allowZalo ?? false,
      allowWhatsApp: d.allowWhatsApp ?? false,
      redactedAt: toIsoString(d.redactedAt),
    };
  }

  async findPaymentsByTransferCode(code: string): Promise<readonly Payment[]> {
    const snap = await this.firestore.collection(PAYMENTS_COLLECTION).where('transferCode', '==', code).get();
    return paymentsOf(snap.docs);
  }

  async getTransferRecord(id: string): Promise<TransferRecord | null> {
    const snap = await this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(id).get();
    return transferRecordFromFirestore(snap.id, snap.data());
  }

  /**
   * Open checkout payments of bookings: `method` is set only by createPayment, so ticket payments and
   * older deposit payments still `created` never fill the page
   * (index `status, subjectType, method, createdAt`).
   */
  async findPaymentsToReconcile(createdBefore: Date, limit = 100): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('status', '==', 'created')
      .where('subjectType', '==', 'booking')
      .where('method', 'in', [...PAYMENT_METHODS])
      .where('createdAt', '<=', Timestamp.fromDate(createdBefore))
      .limit(limit)
      .get();
    return paymentsOf(snap.docs);
  }

  /** The same set as findPaymentsToReconcile, past `expiresAt` (index `status, subjectType, method, expiresAt`). */
  async findOverduePayments(now: Date, limit = 100): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('status', '==', 'created')
      .where('subjectType', '==', 'booking')
      .where('method', 'in', [...PAYMENT_METHODS])
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    return paymentsOf(snap.docs);
  }

  /** Drafts with `payableUntil <= now` (index `status, payableUntil`); drafts without it never match. */
  async findExpiredDrafts(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'draft')
      .where('payableUntil', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findExpiredRequests(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'requested')
      .where('acceptDeadline', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findUpcomingTransitions(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'accepted')
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  /**
   * One page of `upcoming` bookings ordered by day, start and id (index `status, day, start, __name__`).
   * Pass the previous `next` as `after`; `next` is null on the last page.
   */
  async findUpcomingPage(limit: number, after: unknown = null): Promise<{ bookings: Booking[]; next: unknown }> {
    let q = this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'upcoming')
      .orderBy('day')
      .orderBy('start')
      .orderBy('__name__');
    if (after !== null) q = q.startAfter(after as never);
    const snap = await q.limit(limit).get();
    const bookings: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) bookings.push(b);
    }
    return { bookings, next: snap.size < limit ? null : (snap.docs[snap.size - 1] ?? null) };
  }

  async findAutoCompletions(cutoff: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', 'in', ['upcoming', 'accepted'])
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      // A studio booking without an assignee is never marked shot (#136); the studio sweep cancels it at its start.
      if (b && !waitsForAssignee(b)) res.push(b);
    }
    return res;
  }

  async findReleasableEscrows(cutoff: Date, limit = 100): Promise<readonly Payment[]> {
    // Held money, then disputed milestone payments (another milestone may be due; S18 Decision 1). Two
    // queries on the same (escrowStatus, releaseAfter) index, so frozen payments never starve the others.
    const query = (statuses: readonly string[]) =>
      this.firestore
        .collection(PAYMENTS_COLLECTION)
        .where('escrowStatus', 'in', statuses)
        .where('releaseAfter', '<=', Timestamp.fromDate(cutoff))
        .limit(limit)
        .get();
    const res: Payment[] = [];
    for (const doc of (await query(['held', 'partially_refunded'])).docs) {
      const p = paymentFromFirestore(doc.id, doc.data());
      if (p) res.push(p);
    }
    if (res.length >= limit) return res;
    for (const doc of (await query(['disputed'])).docs) {
      const p = paymentFromFirestore(doc.id, doc.data());
      if (p?.milestones && res.length < limit) res.push(p);
    }
    return res;
  }

  async findDueAutoApprovals(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'delivered')
      .where('autoApproveAt', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findDueChecks(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'approved')
      .where('checkUntil', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  /**
   * Studio bookings with assign work (#136 Decision 20a): unassigned, not yet overdue, requested | accepted, deadline
   * within 24 h, soonest first (index `assignStatus, assignOverdue, status, assignDeadline`). Filtering the status
   * here keeps cancelled and expired unassigned bookings from filling the page forever.
   */
  async findUnassignedStudioBookingsDue(now: Date, limit: number): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('assignStatus', '==', 'unassigned')
      .where('assignOverdue', '==', false)
      .where('status', 'in', ['requested', 'accepted'])
      .where('assignDeadline', '<=', Timestamp.fromDate(new Date(now.getTime() + 24 * 3600 * 1000)))
      .orderBy('assignDeadline')
      .limit(limit)
      .get();
    return bookingsOf(snap.docs);
  }

  /**
   * Unassigned studio bookings whose start has come (#136 ruling: the sweep cancels them), oldest day first
   * (index `assignStatus, status, day`). The query stops at today in Vietnam and today's bookings not started yet
   * are dropped here; they sort after every earlier day, and each run cancels what it returns.
   */
  async findUnassignedStudioBookingsStarted(now: Date, limit: number): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('assignStatus', '==', 'unassigned')
      .where('status', 'in', ['requested', 'accepted'])
      .where('day', '<=', formatVnDate(now))
      .orderBy('day')
      .limit(limit)
      .get();
    return bookingsOf(snap.docs).filter((b) => parseVnDateTime(b.day, b.start).getTime() <= now.getTime());
  }

  /** Pending change requests past `respondBy`, oldest first (index `changeRequest.status, changeRequest.respondBy`). */
  async findDueChangeRequests(now: Date, limit: number): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('changeRequest.status', '==', 'pending')
      .where('changeRequest.respondBy', '<=', Timestamp.fromDate(now))
      .orderBy('changeRequest.respondBy')
      .limit(limit)
      .get();
    return bookingsOf(snap.docs);
  }

  async findDueAutoApproveNotices(now: Date, limit = 100): Promise<readonly Booking[]> {
    const cutoff = new Date(now.getTime() + 24 * 3600 * 1000);
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'delivered')
      .where('autoApproveNoticeAt', '==', null)
      .where('autoApproveAt', '<=', Timestamp.fromDate(cutoff))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }
}
