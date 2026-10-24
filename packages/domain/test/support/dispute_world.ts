import type { Booking } from '../../src/booking.js';
import type { DisputeDeps, DisputeSubjectView } from '../../src/dispute_ports.js';
import { disputeEscrowPayment, isSettledPayment, type LedgerEntry, type Payment, type Refund } from '../../src/escrow.js';
import { FakePaymentGateway } from '../../src/fake_payment_gateway.js';
import type { MemoryBookingStore } from '../../src/memory_booking_store.js';
import { MemoryDisputeStore } from '../../src/memory_dispute_store.js';
import { disputeMilestone, releaseMilestone, splitMilestones, withMilestones, type MilestoneKind } from '../../src/milestones.js';
import type { DisplayNames, SupportDeps } from '../../src/support_use_cases.js';
import { ControllableClock, SequentialIdGen } from './booking_world.js';
import { TEST_CIPHER } from './test_cipher.js';

/** 2026-10-20 10:00 UTC. */
export const NOW = new Date('2026-10-20T10:00:00.000Z');
const HOUR_MS = 3_600_000;
export const hoursFrom = (h: number, from: Date = NOW): Date => new Date(from.getTime() + h * HOUR_MS);

export const NAMES: Readonly<Record<string, string>> = { c1: 'An', c2: 'Bình', p1: 'Minh Trí', h1: 'Hà Host', staff1: 'Nhân Viên' };

export interface DisputeWorld {
  readonly store: MemoryDisputeStore;
  readonly gateway: FakePaymentGateway;
  readonly clock: ControllableClock;
  readonly ids: SequentialIdGen;
  readonly names: DisplayNames;
  readonly deps: DisputeDeps;
  /** The same store as a SupportStore (dispute threads go through `sendSupportMessage`). */
  readonly supportDeps: SupportDeps;
}

export function createDisputeWorld(now: Date = NOW): DisputeWorld {
  const store = new MemoryDisputeStore();
  const gateway = new FakePaymentGateway();
  const clock = new ControllableClock(now);
  const ids = new SequentialIdGen('id');
  const names: DisplayNames = { displayName: async (uid) => NAMES[uid] ?? '' };
  return {
    store,
    gateway,
    clock,
    ids,
    names,
    deps: { store, gateway, cipher: TEST_CIPHER, names, clock, ids },
    supportDeps: { store, names, clock, ids },
  };
}

export function bookingView(over: Partial<DisputeSubjectView> = {}): DisputeSubjectView {
  return {
    type: 'booking',
    id: 'b1',
    eventId: null,
    customerId: 'c1',
    providerId: 'p1',
    state: 'completed',
    windowStart: null,
    shotAt: null,
    checkUntil: null,
    amount: 1_000_000,
    paymentId: null,
    disputeId: null,
    snapshot: { title: 'Minh Trí · Chân dung', subtitle: 'T2 19/10 · 15:30–17:30', providerName: 'Minh Trí', thumbUrl: null },
    ...over,
  };
}

export function ticketView(over: Partial<DisputeSubjectView> = {}): DisputeSubjectView {
  return {
    type: 'ticket',
    id: 'r1',
    eventId: 'e1',
    customerId: 'c1',
    providerId: 'h1',
    state: 'paid',
    windowStart: hoursFrom(-3),
    shotAt: null,
    checkUntil: null,
    amount: 300_000,
    paymentId: 'pay_r1',
    disputeId: null,
    snapshot: { title: 'Chụp phố đêm', subtitle: 'T2 20/10 · 06:00–07:00', providerName: 'Hà Host', thumbUrl: null },
    ...over,
  };
}

export function paidPayment(over: Partial<Payment> = {}): Payment {
  const at = hoursFrom(-24 * 10).toISOString();
  return {
    id: 'pay_b1',
    subjectType: 'booking',
    subjectId: 'b1',
    payerId: 'c1',
    payeeId: 'p1',
    provider: 'fake',
    amount: 1_000_000,
    status: 'paid',
    escrowStatus: 'held',
    idempotencyKey: 'key_b1',
    method: 'momo',
    paidAt: at,
    createdAt: at,
    updatedAt: at,
    ...over,
  };
}

function receivedEntry(p: Payment, amount = p.amount): LedgerEntry {
  return {
    id: `le_recv_${p.id}`,
    type: 'payment_received',
    paymentId: p.id,
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    accountOwnerId: 'platform_escrow',
    amount,
    at: p.createdAt,
  };
}

function seed(w: DisputeWorld, view: DisputeSubjectView, payment: Payment, received = payment.amount): void {
  w.store.putSubject(view);
  w.store.payments.set(payment.id, payment);
  w.store.ledger.push(receivedEntry(payment, received));
}

/** b1 marked shot 2 hours ago: both milestones held (500 000 each). */
export function seedShotBooking(w: DisputeWorld): void {
  const shotAt = hoursFrom(-2);
  const p = withMilestones(paidPayment(), splitMilestones(1_000_000, shotAt), shotAt.toISOString());
  seed(w, bookingView({ state: 'shot', shotAt }), p);
}

/** b1 approved, delivery check open 24 more hours; the shoot milestone (500 000) was released days ago. */
export function seedApprovedBooking(w: DisputeWorld): void {
  const shotAt = hoursFrom(-24 * 3);
  const split = withMilestones(paidPayment(), splitMilestones(1_000_000, shotAt), shotAt.toISOString());
  const rel = releaseMilestone(split, 'shoot', 'le_rel_shoot', hoursFrom(-48));
  seed(w, bookingView({ state: 'approved', shotAt, checkUntil: hoursFrom(24) }), rel.payment);
  w.store.ledger.push(rel.ledgerEntry);
}

/**
 * b1 completed 2 hours ago, payment from before milestones. `escrowRefund`: an earlier refund out of
 * escrow (fromEscrow true); `overpaid`: an over-transfer whose excess went straight back (fromEscrow false).
 */
export function seedLegacyBooking(
  w: DisputeWorld,
  opts: { readonly escrowRefund?: number; readonly overpaid?: number; readonly escrowStatus?: Payment['escrowStatus'] } = {},
): void {
  const escrowRefund = opts.escrowRefund ?? 0;
  const overpaid = opts.overpaid ?? 0;
  const partly = escrowRefund > 0;
  const p = paidPayment({
    status: partly ? 'partially_refunded' : 'paid',
    escrowStatus: opts.escrowStatus ?? (partly ? 'partially_refunded' : 'held'),
    refundedAmount: escrowRefund + overpaid || undefined,
  });
  seed(w, bookingView({ state: 'completed', windowStart: hoursFrom(-2) }), p, p.amount + overpaid);
  const refund = (id: string, amount: number, fromEscrow: boolean): void => {
    const r: Refund = {
      id, paymentId: p.id, subjectType: 'booking', amount, percent: 100, status: 'done', manual: false, fromEscrow,
      method: 'gateway', attempts: 1, reason: fromEscrow ? 'cancel' : 'overpaid_excess', createdAt: p.createdAt, updatedAt: p.createdAt,
    };
    w.store.refunds.set(id, r);
    w.store.ledger.push({
      id: `le_${id}`, type: 'refund_issued', paymentId: p.id, refundId: id, subjectType: 'booking', subjectId: p.subjectId,
      accountOwnerId: p.payerId, amount: -amount, at: p.createdAt,
    });
  };
  if (escrowRefund > 0) refund('rf_escrow', escrowRefund, true);
  if (overpaid > 0) refund('rf_excess', overpaid, false);
}

/** r1 of event e1 (ended 3 hours ago), 300 000 held for host h1 or for the platform. */
export function seedTicket(w: DisputeWorld, opts: { readonly platform?: boolean; readonly amount?: number } = {}): void {
  const amount = opts.amount ?? 300_000;
  const payeeId = opts.platform ? 'platform' : 'h1';
  const view = ticketView({ providerId: payeeId, amount, paymentId: amount > 0 ? 'pay_r1' : null });
  const p = paidPayment({
    id: 'pay_r1', subjectType: 'event_registration', subjectId: 'r1', eventId: 'e1', payeeId, amount,
    idempotencyKey: 'key_r1', releaseAfter: hoursFrom(21).toISOString(),
  });
  seed(w, view, p);
}

export function openInput(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    disputeId: 'd1',
    subjectType: 'booking',
    subjectId: 'b1',
    eventId: null,
    reason: 'not_as_agreed',
    description: '  Thợ đến muộn hai tiếng và thiếu ảnh  ',
    evidencePaths: ['disputeEvidence/c1/d1/f1.jpg'],
    ...over,
  };
}

/**
 * Booking world (MemoryBookingStore): freezes the booking's paid payment the way openDispute does,
 * for tests of sweeps, payouts and earnings that only need a disputed payment.
 */
export function freezeBookingPayment(
  store: MemoryBookingStore,
  bookingId: string,
  now: Date,
  kind: MilestoneKind = 'shoot',
): Payment {
  const p = [...store.payments.values()].find((x) => x.subjectId === bookingId && isSettledPayment(x));
  if (!p) throw new Error(`no paid payment for ${bookingId}`);
  const frozen: Payment = p.milestones
    ? { ...disputeMilestone(p, kind, now), dispute: { reason: 'other', openedAt: now.toISOString(), disputeId: 'd_test', milestone: kind } }
    : {
        ...disputeEscrowPayment(p, now),
        dispute: {
          reason: 'other', openedAt: now.toISOString(), disputeId: 'd_test', milestone: null,
          prevEscrowStatus: p.escrowStatus === 'partially_refunded' ? 'partially_refunded' : 'held',
        },
      };
  store.payments.set(frozen.id, frozen);
  const b = store.bookings.get(bookingId);
  if (b) {
    const next: Booking = { ...b, escrowStatus: frozen.escrowStatus, disputeId: 'd_test' };
    store.bookings.set(bookingId, next);
  }
  return frozen;
}
