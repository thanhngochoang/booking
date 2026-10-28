import type { Booking } from './booking.js';
import type { BookingDeps } from './booking_ports.js';
import {
  AUTO_APPROVE_HOURS,
  canDeliver,
  DELIVERY_CHECK_HOURS,
  type DeliverySample,
  type DeliverySampleRef,
  revisionAllowance,
  validateRevisionRequest,
  validateSubmitDelivery,
} from './delivery.js';
import { deliveryDueAt, isDeliveryLate } from './delivery_deadline.js';
import { DomainError } from './errors.js';
import { isSettledPayment, type Payment, type Refund } from './escrow.js';
import { isId } from './ids.js';
import { refundMilestone } from './milestones.js';
import { dispatchRefund } from './refunds.js';

export async function submitDelivery(
  deps: BookingDeps,
  callerId: string,
  raw: unknown,
): Promise<{ round: number }> {
  const input = validateSubmitDelivery(raw);
  const now = deps.clock.now();
  const at = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(input.bookingId);
    if (!b) throw new DomainError('not_found');
    if (!canDeliver(b, callerId)) throw new DomainError('permission_denied');
    if (b.status !== 'shot' && b.status !== 'revision_requested') throw new DomainError('not_eligible');

    const rawSamples = await tx.getDeliverySamples(b.id, input.sampleIds);
    if (rawSamples.some((s) => s !== null && s.uploaderId !== callerId)) {
      throw new DomainError('permission_denied');
    }
    if (rawSamples.some((s) => s === null || s.status !== 'ready')) {
      throw new DomainError('not_ready');
    }

    const readySamples = rawSamples.filter((s): s is DeliverySample => s !== null);
    const round = (b.deliveryRound ?? 0) + 1;
    const sampleRefs: DeliverySampleRef[] = readySamples.map((s) => ({
      fileId: s.fileId,
      path: s.path,
      thumbPath: s.thumbPath,
      width: s.width,
      height: s.height,
    }));

    await tx.setDelivery({
      bookingId: b.id,
      round,
      samples: sampleRefs,
      photoCount: input.photoCount,
      linkHost: input.linkHost,
      note: input.note,
      submittedAt: at,
      submittedBy: callerId,
      decision: null,
    });

    await tx.setPrivateDelivery(b.id, {
      link: input.link,
      round,
      unlockedAt: null,
      updatedAt: at,
    });

    await tx.deleteDeliverySamples(b.id, input.sampleIds);

    const autoApproveAt = new Date(now.getTime() + AUTO_APPROVE_HOURS * 3_600_000).toISOString();

    const updatedBooking: Booking = {
      ...b,
      status: 'delivered',
      deliveryRound: round,
      deliveredAt: at,
      autoApproveAt,
      autoApproveNoticeAt: null,
      version: b.version + 1,
      updatedAt: at,
    };

    await tx.setBooking(updatedBooking);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: b.id,
      status: 'delivered',
      at,
      actorId: callerId,
    });

    return { round };
  });
}

export async function approveDelivery(
  deps: BookingDeps,
  input: { bookingId: string; actorId?: string },
): Promise<Booking> {
  const now = deps.clock.now();
  const at = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(input.bookingId);
    if (!b) throw new DomainError('not_found');

    const isSystem = input.actorId === undefined;
    if (!isSystem && input.actorId !== b.customerId) {
      throw new DomainError('permission_denied');
    }

    if (b.status !== 'delivered') throw new DomainError('not_eligible');

    const currentRound = b.deliveryRound ?? 1;
    const delivery = await tx.getDelivery(b.id, currentRound);
    const privateDelivery = await tx.getPrivateDelivery(b.id);

    if (delivery) {
      await tx.setDelivery({
        ...delivery,
        decision: {
          kind: 'approve',
          note: null,
          photoNotes: [],
          at,
          auto: isSystem,
          extra: false,
        },
      });
    }

    if (privateDelivery) {
      await tx.setPrivateDelivery(b.id, {
        ...privateDelivery,
        unlockedAt: at,
        updatedAt: at,
      });
    }

    const checkUntil = new Date(now.getTime() + DELIVERY_CHECK_HOURS * 3_600_000).toISOString();

    const updatedBooking: Booking = {
      ...b,
      status: 'approved',
      approvedAt: at,
      checkUntil,
      autoApproveAt: undefined,
      extraRound: null, // clear pending extraRound if any
      version: b.version + 1,
      updatedAt: at,
    };

    await tx.setBooking(updatedBooking);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: b.id,
      status: 'approved',
      at,
      actorId: input.actorId,
    });

    return updatedBooking;
  });
}

export async function requestRevision(
  deps: BookingDeps,
  callerId: string,
  raw: unknown,
): Promise<Booking> {
  const input = validateRevisionRequest(raw);
  const now = deps.clock.now();
  const at = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(input.bookingId);
    if (!b) throw new DomainError('not_found');
    if (callerId !== b.customerId) throw new DomainError('permission_denied');
    if (b.status !== 'delivered') throw new DomainError('not_eligible');

    const allowance = revisionAllowance(b);

    if (input.extra) {
      // Customer asks for extra round: only eligible if NO rounds left
      if (allowance.left > 0) {
        throw new DomainError('not_eligible');
      }
      if (b.extraRound?.status === 'pending') {
        throw new DomainError('conflict');
      }

      const updatedBooking: Booking = {
        ...b,
        extraRound: {
          status: 'pending',
          at,
          note: input.note,
          photoNotes: input.photoNotes,
        },
        version: b.version + 1,
        updatedAt: at,
      };

      await tx.setBooking(updatedBooking);
      return updatedBooking;
    }

    // Standard revision request
    if (allowance.left <= 0) {
      throw new DomainError('not_eligible');
    }

    const currentRound = b.deliveryRound ?? 1;
    const delivery = await tx.getDelivery(b.id, currentRound);
    if (delivery) {
      await tx.setDelivery({
        ...delivery,
        decision: {
          kind: 'request_revision',
          note: input.note,
          photoNotes: input.photoNotes,
          at,
          auto: false,
          extra: false,
        },
      });
    }

    const updatedBooking: Booking = {
      ...b,
      status: 'revision_requested',
      revisionsUsed: (b.revisionsUsed ?? 0) + 1,
      autoApproveAt: undefined,
      version: b.version + 1,
      updatedAt: at,
    };

    await tx.setBooking(updatedBooking);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: b.id,
      status: 'revision_requested',
      at,
      actorId: callerId,
    });

    return updatedBooking;
  });
}

export async function answerExtraRound(
  deps: BookingDeps,
  callerId: string,
  raw: { bookingId: string; grant: boolean },
): Promise<Booking> {
  const now = deps.clock.now();
  const at = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(raw.bookingId);
    if (!b) throw new DomainError('not_found');
    if (!canDeliver(b, callerId)) throw new DomainError('permission_denied');
    if (!b.extraRound || b.extraRound.status !== 'pending') {
      throw new DomainError('not_eligible');
    }

    if (raw.grant) {
      const currentRound = b.deliveryRound ?? 1;
      const delivery = await tx.getDelivery(b.id, currentRound);
      if (delivery) {
        await tx.setDelivery({
          ...delivery,
          decision: {
            kind: 'request_revision',
            note: b.extraRound.note,
            photoNotes: b.extraRound.photoNotes,
            at,
            auto: false,
            extra: true,
          },
        });
      }

      const updatedBooking: Booking = {
        ...b,
        status: 'revision_requested',
        revisionsGranted: (b.revisionsGranted ?? 0) + 1,
        revisionsUsed: (b.revisionsUsed ?? 0) + 1,
        autoApproveAt: undefined,
        extraRound: {
          ...b.extraRound,
          status: 'granted',
          at,
        },
        version: b.version + 1,
        updatedAt: at,
      };

      await tx.setBooking(updatedBooking);
      await tx.addBookingEvent({
        id: deps.ids.newId(),
        bookingId: b.id,
        status: 'revision_requested',
        at,
        actorId: callerId,
      });

      return updatedBooking;
    } else {
      const updatedBooking: Booking = {
        ...b,
        extraRound: {
          ...b.extraRound,
          status: 'declined',
          at,
        },
        version: b.version + 1,
        updatedAt: at,
      };

      await tx.setBooking(updatedBooking);
      return updatedBooking;
    }
  });
}

export interface CancelLateDeliveryInput {
  readonly bookingId: string;
  readonly customerId: string;
}

export async function cancelLateDelivery(
  deps: BookingDeps,
  input: CancelLateDeliveryInput,
): Promise<Booking> {
  if (!isId(input.bookingId) || !isId(input.customerId)) throw new DomainError('invalid_argument');
  const now = deps.clock.now();
  const at = now.toISOString();
  let pending: { refund: Refund; provider: Payment['provider'] } | undefined;
  const updated = await deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(input.bookingId);
    if (!b) throw new DomainError('not_found');
    if (b.customerId !== input.customerId) throw new DomainError('permission_denied');
    if (['delivered', 'revision_requested', 'approved'].includes(b.status)) {
      throw new DomainError('not_eligible', 'delivered');
    }
    if (b.status !== 'shot') throw new DomainError('not_eligible', 'status');
    if (b.escrowStatus === 'disputed') throw new DomainError('conflict');
    const due = deliveryDueAt(b);
    if (!isDeliveryLate(b, now) || !due) throw new DomainError('not_eligible', 'not_late');
    const found = (await deps.store.getPaymentsForBooking(b.id)).find(
      (p) => isSettledPayment(p) && p.milestones,
    );
    const payment = found ? await tx.getPayment(found.id) : null;
    if (!payment || !payment.milestones) throw new DomainError('not_eligible', 'status');
    const r = refundMilestone(
      payment,
      'delivery',
      deps.ids.newId(),
      deps.ids.newId(),
      now,
      'late_delivery',
    );
    await tx.setPayment(r.payment);
    await tx.addRefund(r.refund);
    await tx.addLedgerEntry(r.ledgerEntry);
    const dueAt = due.toISOString();
    const next: Booking = {
      ...b,
      status: 'completed',
      completedAt: at,
      escrowStatus: r.payment.escrowStatus,
      depositRefunded: (b.depositRefunded ?? 0) + r.refund.amount,
      deliveryCancel: { at, dueAt, refundedAmount: r.refund.amount },
      version: b.version + 1,
      updatedAt: at,
    };
    await tx.setBooking(next);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: b.id,
      status: 'completed',
      at,
      actorId: input.customerId,
    });
    pending = { refund: r.refund, provider: payment.provider };
    return next;
  });
  if (pending && pending.refund.status === 'pending') {
    await dispatchRefund(deps, pending.refund, pending.provider);
  }
  return updated;
}

