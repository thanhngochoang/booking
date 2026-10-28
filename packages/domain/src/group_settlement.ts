/**
 * Group payments (S30, plan #223 Decision 6; spec §5.2 "một lần thanh toán, nhiều dòng"): the customer
 * pays ONE payment (`subjectType: payment_group`, its own transfer code) that fans out into one held
 * child payment per line (a booking, entry tickets, …). Children are `awaiting_group` (no transfer code,
 * never matched, reconciled or expired on their own) until the group is paid in full: then every child
 * becomes `paid` with its subject's paid effects and its own escrow, and the group's escrow is `released`
 * with nothing payable (its money is now the lines'). Under-paid, late or extra transfers stay on the
 * group (the existing rules); an expired group expires every child and releases the held registrations.
 * Milestones, payouts, refunds, ledger invariants and earnings then work per child as for any payment.
 */

import type { Booking, PaymentProvider } from './booking.js';
import type { BookingDeps, BookingTx, TransferNotification, TransferOutcome } from './booking_ports.js';
import { moveDraftToRequested } from './booking_payment_paths.js';
import { formatVnDate } from './booking_policy.js';
import { newSubjectPayment } from './create_payment.js';
import type { EntryDay } from './entry_tickets.js';
import type { EntryDayDelta } from './entry_days.js';
import { entryDaysAfter } from './entry_days.js';
import { DomainError } from './errors.js';
import {
  applyRefundToPayment,
  type LedgerEntry,
  type LineKind,
  type Payment,
  type PaymentMethod,
  type PaymentSubject,
  type Refund,
  type StoredBankAccount,
} from './escrow.js';
import type { EventRecord, RegistrationDoc } from './event.js';
import { payerAccountOf } from './payer_account.js';
import { applyTransfer, expireUnpaid, transferRecordId, transferRecordOf } from './payment_settlement.js';
import type { SubjectSettler } from './payment_ports.js';
import { dispatchRefunds, transferRefund } from './refunds.js';
import { ticketHoldReleased, ticketPaidUpdate } from './ticket_paid.js';
import { systemRandom } from './ids.js';
import { freshPassCode, newPass, writePass } from './pass.js';

/** A group exists only for two lines or more; a single line keeps today's direct payment. */
export const MIN_GROUP_LINES = 2;

/** One line of a group payment: its child payment and who receives it. */
export interface GroupLine {
  readonly paymentId: string;
  readonly kind: LineKind;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly payeeId: string;
  readonly amount: number;
}

export const PAYMENT_GROUP_STATUSES = ['created', 'paid', 'expired'] as const;
export type PaymentGroupStatus = (typeof PAYMENT_GROUP_STATUSES)[number];

/** `payment_groups/{id}` (id = the group payment's): what the payer sees; server-written, payer-readable. */
export interface PaymentGroupView {
  readonly id: string;
  readonly payerId: string;
  readonly lines: readonly GroupLine[];
  readonly total: number;
  /** Mirrors the group payment: `expired` also for a late transfer that was refunded. */
  readonly status: PaymentGroupStatus;
  readonly expiresAt: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/**
 * The one transaction the group settler runs: payments of any subject, bookings, registrations, entry
 * events and `entry_days`, transfer records and the group view. Every booking transaction provides it
 * (`BookingStore` satisfies `GroupSettlementStore`); the memory booking store once linked to the event
 * store (`MemoryGroupStore`). Every read comes before the first write.
 */
export type GroupSettlementTx = Pick<
  BookingTx,
  | 'getPayment'
  | 'setPayment'
  | 'childrenOf'
  | 'getBooking'
  | 'setBooking'
  | 'setAvailabilityDay'
  | 'addBookingEvent'
  | 'getRegistration'
  | 'putRegistration'
  | 'putRegistrationContact'
  | 'getEntryEvent'
  | 'putEntryEvent'
  | 'getEntryDay'
  | 'putEntryDay'
  | 'getTransferRecord'
  | 'saveTransferRecord'
  | 'putGroupView'
  | 'addRefund'
  | 'addLedgerEntry'
  | 'passTaken'
  | 'putPass'
  | 'putPrivatePass'
>;

export interface GroupSettlementStore {
  runTransaction<T>(fn: (tx: GroupSettlementTx) => Promise<T>): Promise<T>;
}

/** The payment the customer pays: `payment_group`, its own transfer code, `amount = Σ lines`, payee = payer. */
export function newGroupPayment(p: {
  readonly id: string;
  readonly payerId: string;
  readonly total: number;
  readonly method: PaymentMethod;
  readonly provider: PaymentProvider;
  readonly idempotencyKey: string;
  readonly now: Date;
  readonly expiresAt: Date;
}): Payment {
  return newSubjectPayment({
    id: p.id,
    subjectType: 'payment_group',
    subjectId: p.id,
    payerId: p.payerId,
    payeeId: p.payerId,
    amount: p.total,
    method: p.method,
    provider: p.provider,
    idempotencyKey: p.idempotencyKey,
    now: p.now,
    expiresAt: p.expiresAt,
  });
}

/**
 * A line's child payment: `awaiting_group`, no transfer code, escrow `held` (as a fresh payment), the
 * group's expiry. A ticket line carries its event (`eventId`), its release instant (entry tickets:
 * `entryReleaseAt(visitDay)`) and `payeeKind: organizer`.
 */
export function newChildPayment(p: {
  readonly id: string;
  readonly groupId: string;
  readonly line: Omit<GroupLine, 'paymentId'>;
  readonly payerId: string;
  readonly method: PaymentMethod;
  readonly provider: PaymentProvider;
  readonly payeeKind?: 'organizer';
  readonly eventId?: string;
  readonly releaseAfter?: Date;
  readonly now: Date;
  readonly expiresAt: Date;
}): Payment {
  const at = p.now.toISOString();
  return {
    ...(p.payeeKind !== undefined ? { payeeKind: p.payeeKind } : {}),
    ...(p.eventId !== undefined ? { eventId: p.eventId } : {}),
    ...(p.releaseAfter !== undefined ? { releaseAfter: p.releaseAfter.toISOString() } : {}),
    id: p.id,
    subjectType: p.line.subjectType,
    subjectId: p.line.subjectId,
    payerId: p.payerId,
    payeeId: p.line.payeeId,
    provider: p.provider,
    amount: p.line.amount,
    status: 'awaiting_group',
    escrowStatus: 'held',
    idempotencyKey: `grp_${p.groupId}_${p.line.kind}`,
    method: p.method,
    expiresAt: p.expiresAt.toISOString(),
    receivedAmount: 0,
    groupId: p.groupId,
    lineKind: p.line.kind,
    createdAt: at,
    updatedAt: at,
  };
}

/** `invalid_argument` unless there are ≥ 2 children of this group and payer, summing to its amount. */
export function assertLinesSum(group: Payment, children: readonly Payment[]): void {
  const ok = group.subjectType === 'payment_group'
    && children.length >= MIN_GROUP_LINES
    && children.every((c) => c.groupId === group.id && c.payerId === group.payerId && c.amount > 0)
    && children.reduce((s, c) => s + c.amount, 0) === group.amount;
  if (!ok) throw new DomainError('invalid_argument');
}

export const lineOf = (c: Payment): GroupLine => ({
  paymentId: c.id,
  kind: c.lineKind ?? (c.subjectType === 'booking' ? 'booking' : 'event_ticket'),
  subjectType: c.subjectType,
  subjectId: c.subjectId,
  payeeId: c.payeeId,
  amount: c.amount,
});

export function groupViewOf(group: Payment, lines: readonly GroupLine[], status: PaymentGroupStatus, now: Date): PaymentGroupView {
  return {
    id: group.id,
    payerId: group.payerId,
    lines,
    total: group.amount,
    status,
    expiresAt: group.expiresAt ?? group.createdAt,
    createdAt: group.createdAt,
    updatedAt: now.toISOString(),
  };
}

export type RefundCancelBy = 'provider' | 'customer' | 'venue_day_closed';

/**
 * Spec §5.3: who refunds what when a booking with tickets ends early.
 * - provider (decline, expiry, provider cancel): every line 100% (booking `bookingReason`, tickets
 *   `provider_cancelled`: the reason to go is gone), `keepTickets` ignored;
 * - customer: the booking line at `bookingPercent` (the booking table), the ticket lines at
 *   `entryPercent` (`entryRefundPercent`, 0 = cancelled and kept by the organizer) unless `keepTickets`;
 * - venue_day_closed: the ticket lines 100% (`day_closed`), the booking untouched.
 */
export function refundPlan(
  lines: readonly GroupLine[],
  cancelBy: RefundCancelBy,
  keepTickets: boolean,
  bookingPercent: number,
  entryPercent: number,
  bookingReason: string = cancelBy === 'customer' ? 'customer_cancel' : 'decline',
): { paymentId: string; percent: number; reason: string }[] {
  const out: { paymentId: string; percent: number; reason: string }[] = [];
  for (const l of lines) {
    const ticket = l.kind !== 'booking';
    if (cancelBy === 'venue_day_closed') {
      if (ticket) out.push({ paymentId: l.paymentId, percent: 100, reason: 'day_closed' });
    } else if (cancelBy === 'provider') {
      out.push({ paymentId: l.paymentId, percent: 100, reason: ticket ? 'provider_cancelled' : bookingReason });
    } else if (!ticket) {
      out.push({ paymentId: l.paymentId, percent: bookingPercent, reason: bookingReason });
    } else if (!keepTickets) {
      out.push({ paymentId: l.paymentId, percent: entryPercent, reason: 'customer_cancel' });
    }
  }
  return out;
}

// ── Reading and folding a group's lines inside one transaction ──

type LineState =
  | { readonly kind: 'booking'; readonly payment: Payment; readonly booking: Booking | null }
  | { readonly kind: 'ticket'; readonly payment: Payment; readonly reg: RegistrationDoc | null; readonly eventId: string | null };

/**
 * The entry events and `entry_days` rows a transaction touches, read once and written once: several
 * changes to the same event or day (a released old hold and a new one) fold into one write.
 */
export class EntryFold {
  private readonly events = new Map<string, EventRecord | null>();
  private readonly changed = new Set<string>();
  /** eventId → day → the row read (null: none yet). */
  private readonly days = new Map<string, Map<string, EntryDay | null>>();
  private readonly deltas = new Map<string, EntryDayDelta[]>();

  async readEvent(tx: Pick<GroupSettlementTx, 'getEntryEvent'>, id: string): Promise<EventRecord | null> {
    if (!this.events.has(id)) this.events.set(id, await tx.getEntryEvent(id));
    return this.events.get(id) ?? null;
  }

  async readDay(tx: Pick<GroupSettlementTx, 'getEntryDay'>, eventId: string, day: string): Promise<EntryDay | null> {
    const rows = this.days.get(eventId) ?? new Map<string, EntryDay | null>();
    this.days.set(eventId, rows);
    if (!rows.has(day)) rows.set(day, await tx.getEntryDay(eventId, day));
    return rows.get(day) ?? null;
  }

  /** The event as read, with this transaction's changes. */
  event(id: string): EventRecord | null {
    return this.events.get(id) ?? null;
  }

  /** The day's row as read (before this transaction's deltas). */
  day(eventId: string, day: string): EntryDay | null {
    return this.days.get(eventId)?.get(day) ?? null;
  }

  putEvent(e: EventRecord): void {
    this.events.set(e.id, e);
    this.changed.add(e.id);
  }

  addDelta(eventId: string, d: EntryDayDelta | null): void {
    if (d === null) return;
    this.deltas.set(eventId, [...(this.deltas.get(eventId) ?? []), d]);
  }

  /** Writes only: each changed event and day once. */
  async flush(tx: Pick<GroupSettlementTx, 'putEntryEvent' | 'putEntryDay'>, now: Date): Promise<void> {
    for (const id of this.changed) {
      const e = this.events.get(id);
      if (e) await tx.putEntryEvent(e);
    }
    for (const [eventId, deltas] of this.deltas) {
      for (const row of entryDaysAfter(eventId, this.days.get(eventId) ?? new Map(), deltas, now)) await tx.putEntryDay(row);
    }
  }
}

export interface GroupRead {
  readonly group: Payment;
  readonly children: readonly Payment[];
  readonly lines: readonly LineState[];
}

/** Reads only: the group's children and each child's subject (booking; registration, event and day). */
export async function readGroup(tx: GroupSettlementTx, group: Payment, fold: EntryFold): Promise<GroupRead> {
  const children = await tx.childrenOf(group.id);
  const lines: LineState[] = [];
  for (const c of children) {
    if (c.subjectType === 'booking') {
      lines.push({ kind: 'booking', payment: c, booking: await tx.getBooking(c.subjectId) });
      continue;
    }
    const eventId = c.eventId ?? null;
    const reg = eventId === null ? null : await tx.getRegistration(eventId, c.subjectId);
    if (eventId !== null) {
      await fold.readEvent(tx, eventId);
      if (reg !== null && typeof reg.visitDay === 'string') await fold.readDay(tx, eventId, reg.visitDay);
    }
    lines.push({ kind: 'ticket', payment: c, reg, eventId });
  }
  return { group, children, lines };
}

const isHeldFor = (reg: RegistrationDoc | null, child: Payment): reg is RegistrationDoc =>
  reg !== null && reg.status === 'held' && reg.paymentId === child.id;

/**
 * A `venue_fee` line (S30 Decision 16) rides on its registration's `event_ticket` line: the registration's
 * own payment is the ticket line, so the subject's effects (seats, paid, contact, hold release) come
 * from that line only; the venue line is paid and expires with the group like any other.
 */
const ridesOnTicket = (l: LineState): boolean => l.kind === 'ticket' && l.payment.lineKind === 'venue_fee';

/**
 * Writes only: the group (already `expired` or refunded by the caller) takes its children with it:
 * every `awaiting_group` child expires, every registration still held for it is released (seats and
 * `entry_days.held` back, through `fold`), the view says `expired`.
 */
export async function expireGroupLines(tx: GroupSettlementTx, read: GroupRead, fold: EntryFold, group: Payment, now: Date): Promise<void> {
  const at = now.toISOString();
  for (const c of read.children) {
    if (c.status === 'awaiting_group') await tx.setPayment({ ...c, status: 'expired', escrowStatus: 'refunded', updatedAt: at });
  }
  for (const l of read.lines) {
    if (l.kind !== 'ticket' || ridesOnTicket(l) || l.eventId === null || !isHeldFor(l.reg, l.payment)) continue;
    const ev = fold.event(l.eventId);
    if (ev === null) {
      await tx.putRegistration({ ...l.reg, status: 'cancelled', cancelledAt: now, updatedAt: now, version: l.reg.version + 1 });
      continue;
    }
    const released = ticketHoldReleased(ev, l.reg, now);
    await tx.putRegistration(released.registration);
    fold.putEvent(released.event);
    fold.addDelta(ev.id, released.day);
  }
  await tx.putGroupView(groupViewOf(group, read.children.map(lineOf), 'expired', now));
}

/** Why a fully paid group cannot become its lines (then the whole transfer goes back), or null. */
async function lateReason(deps: BookingDeps, read: GroupRead, fold: EntryFold, now: Date): Promise<string | null> {
  for (const l of read.lines) {
    if (l.kind === 'booking') {
      if (l.booking === null || l.booking.status !== 'draft') return 'late_payment_draft_expired';
      if (!(await deps.providers.acceptsOrders(l.payment.payeeId))) return 'provider_not_accepting';
      continue;
    }
    if (ridesOnTicket(l)) continue;
    const ev = l.eventId === null ? null : fold.event(l.eventId);
    const reg = l.reg;
    const closed = ev !== null && reg !== null && typeof reg.visitDay === 'string' && fold.day(ev.id, reg.visitDay)?.closed === true;
    if (!isHeldFor(reg, l.payment) || ev === null || ev.status === 'cancelled' || reg.holdExpiresAt === null
      || reg.holdExpiresAt.getTime() <= now.getTime() || closed) {
      return 'late_payment_hold_expired';
    }
  }
  return null;
}

/**
 * Decision 7: a group gets a pass when it holds a booking or an entry ticket. A normal event's ticket
 * (with its venue fee, Decision 16) keeps its public ticket code and gets none.
 */
function groupGetsPass(read: GroupRead, fold: EntryFold): boolean {
  return read.lines.some((l) => l.kind === 'booking'
    || (l.eventId !== null && fold.event(l.eventId)?.type === 'entry'));
}

/** The group's one pass (Decision 7): its booking (if any) and every ticket line's registration (once each), on the booking's or visit day. */
function groupPass(read: GroupRead, group: Payment, code8: string, now: Date) {
  const booking = read.lines.find((l): l is Extract<LineState, { kind: 'booking' }> => l.kind === 'booking')?.booking ?? null;
  const tickets = read.lines.filter((l): l is Extract<LineState, { kind: 'ticket' }> => l.kind === 'ticket');
  const regs = [...new Map(tickets.map((l) => l.reg).filter((r): r is RegistrationDoc => r !== null).map((r) => [r.id, r])).values()];
  const day = booking?.day ?? regs.map((r) => r.visitDay).find((d): d is string => typeof d === 'string') ?? formatVnDate(now);
  return newPass({
    code8, customerId: group.payerId, day, bookingId: booking?.id ?? null, eventId: regs[0]?.eventId ?? null,
    registrationIds: regs.map((r) => r.id), now,
  });
}

function receivedEntry(deps: BookingDeps, child: Payment, now: Date): LedgerEntry {
  return {
    id: deps.ids.newId(),
    type: child.subjectType === 'event_registration' ? 'ticket_received' : 'payment_received',
    paymentId: child.id,
    subjectType: child.subjectType,
    subjectId: child.subjectId,
    accountOwnerId: 'platform_escrow',
    amount: child.amount,
    note: `Line of payment group ${child.groupId ?? ''}`,
    at: now.toISOString(),
  };
}

/** The settler of `payment_group` payments, over the booking deps' store unless another `groups` is given. */
export function groupSettler(deps: BookingDeps, groups: GroupSettlementStore = deps.store): SubjectSettler {
  const dispatch = (refunds: readonly Refund[], provider: PaymentProvider) =>
    dispatchRefunds(deps, refunds.map((refund) => ({ refund, provider })));

  return {
    async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
      const recordId = transferRecordId(transfer);
      // Encrypted before the transaction; a cipher failure fails the notification (provider retries).
      const captured: StoredBankAccount | null = await payerAccountOf(deps.cipher, transfer.payer);
      const now = deps.clock.now();
      let pending: Refund[] = [];
      let provider: PaymentProvider = deps.gateway.provider;

      const outcome = await groups.runTransaction(async (tx): Promise<Exclude<TransferOutcome, 'needs_review'>> => {
        pending = [];
        // Reads
        if (await tx.getTransferRecord(recordId)) return 'duplicate';
        const group = await tx.getPayment(paymentId);
        if (!group || group.subjectType !== 'payment_group') throw new DomainError('not_found');
        provider = group.provider;
        const fold = new EntryFold();
        const read = await readGroup(tx, group, fold);
        const applied = applyTransfer({ payment: group, transfer, ledgerEntryId: deps.ids.newId(), now });
        const late = applied.decision.kind === 'paid' ? await lateReason(deps, read, fold, now) : null;
        // Decision 7: the paid group's lines share one pass; its code is drawn (a read) before any write.
        const passCode = applied.decision.kind === 'paid' && late === null && groupGetsPass(read, fold)
          ? await freshPassCode(deps.random ?? systemRandom, (c) => tx.passTaken(c))
          : null;
        const contact = applied.decision.kind === 'paid' && late === null && read.lines.some((l) => l.kind === 'ticket')
          ? await deps.contacts.get(group.payerId)
          : null;

        // Writes
        await tx.addLedgerEntry(applied.ledgerEntry);
        let current: Payment = { ...applied.payment, payer: group.payer ?? captured };
        const giveBack = async (amount: number, reason: Parameters<typeof transferRefund>[0]['reason']) => {
          const r = transferRefund({
            payment: current, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), amount, reason,
            destination: captured ?? current.payer, providerRef: transfer.txnId, now,
          });
          current = r.payment;
          await tx.addRefund(r.refund);
          await tx.addLedgerEntry(r.ledgerEntry);
          pending.push(r.refund);
        };

        if (applied.decision.kind === 'partial') {
          await tx.setPayment(current);
          await tx.saveTransferRecord(transferRecordOf(transfer, 'partial', group.id));
          return 'partial';
        }
        if (applied.decision.kind === 'refund') {
          current = group;
          await giveBack(transfer.amount, applied.decision.reason);
          await tx.setPayment({ ...current, updatedAt: now.toISOString() });
          await tx.saveTransferRecord(transferRecordOf(transfer, 'refunded', group.id));
          return 'refunded';
        }

        // Paid in full.
        if (applied.excess > 0) await giveBack(applied.excess, 'overpaid_excess');
        if (late !== null) {
          // A line can no longer be bought (the draft is gone, the hold ended, the day closed): the
          // whole group goes back, no line is paid.
          const r = applyRefundToPayment({
            payment: current, refundId: deps.ids.newId(), percent: 100, ledgerEntryId: deps.ids.newId(), reason: late, now,
          });
          const refund: Refund = { ...r.refund, providerRef: transfer.txnId };
          await tx.setPayment(r.payment);
          await tx.addRefund(refund);
          await tx.addLedgerEntry(r.ledgerEntry);
          pending.push(refund);
          await expireGroupLines(tx, read, fold, r.payment, now);
          await fold.flush(tx, now);
          await tx.saveTransferRecord(transferRecordOf(transfer, 'refunded', group.id));
          return 'refunded';
        }

        const at = now.toISOString();
        // The group's money is now the lines': released, nothing payable, balanced by one adjustment.
        const settled: Payment = { ...current, escrowStatus: 'released', releasedAt: at, payableAmount: 0, updatedAt: at };
        await tx.setPayment(settled);
        await tx.addLedgerEntry({
          id: deps.ids.newId(),
          type: 'adjustment',
          paymentId: group.id,
          subjectType: 'payment_group',
          subjectId: group.id,
          accountOwnerId: 'platform_escrow',
          amount: -group.amount,
          note: `Split into the lines of payment group ${group.id}`,
          at,
        });
        for (const l of read.lines) {
          const paid: Payment = {
            ...l.payment,
            status: 'paid',
            escrowStatus: 'held',
            receivedAmount: l.payment.amount,
            paidAt: at,
            payer: settled.payer,
            updatedAt: at,
          };
          await tx.setPayment(paid);
          await tx.addLedgerEntry(receivedEntry(deps, paid, now));
          if (l.kind === 'booking') {
            await moveDraftToRequested(tx, deps, l.booking as Booking, paid, now, passCode);
            continue;
          }
          if (ridesOnTicket(l)) continue;
          const ev = fold.event(l.eventId as string) as EventRecord;
          const ticket = ticketPaidUpdate({ ev, reg: l.reg as RegistrationDoc, paymentId: paid.id, contact, now, passCode });
          await tx.putRegistration(ticket.registration);
          if (ticket.contact !== null) await tx.putRegistrationContact(ev.id, ticket.registration.id, ticket.contact);
          fold.putEvent(ticket.event);
          fold.addDelta(ev.id, ticket.day);
        }
        await fold.flush(tx, now);
        await tx.putGroupView(groupViewOf(settled, read.children.map(lineOf), 'paid', now));
        if (passCode !== null) await writePass(tx, groupPass(read, group, passCode, now));
        const out = applied.excess > 0 ? 'paid_with_refund' : 'paid';
        await tx.saveTransferRecord(transferRecordOf(transfer, out, group.id));
        return out;
      });

      if (outcome !== 'duplicate' && pending.length > 0) await dispatch(pending, provider);
      return outcome;
    },

    async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
      let refund: Refund | null = null;
      let provider: PaymentProvider = deps.gateway.provider;
      const expired = await groups.runTransaction(async (tx) => {
        refund = null;
        const group = await tx.getPayment(paymentId);
        if (!group || group.subjectType !== 'payment_group' || group.status !== 'created' || !group.expiresAt) return false;
        if (Date.parse(group.expiresAt) > now.getTime()) return false;
        provider = group.provider;
        const fold = new EntryFold();
        const read = await readGroup(tx, group, fold);
        const out = expireUnpaid({
          payment: group, refundId: deps.ids.newId(), ledgerEntryId: deps.ids.newId(), destination: group.payer, now,
        });
        await tx.setPayment(out.payment);
        if (out.refund && out.ledgerEntry) {
          await tx.addRefund(out.refund);
          await tx.addLedgerEntry(out.ledgerEntry);
          refund = out.refund;
        }
        await expireGroupLines(tx, read, fold, out.payment, now);
        await fold.flush(tx, now);
        return true;
      });
      if (!expired) return 'unchanged';
      if (refund !== null) await dispatch([refund], provider);
      return 'expired';
    },

    async dispatchRefund(refund: Refund, payment: Payment): Promise<Refund> {
      const res = await dispatch([refund], payment.provider);
      return res[0] ?? refund;
    },

    /** The booking's status when the group has a booking line, else the first ticket's, else the group's. */
    async statusOf(payment: Payment): Promise<string> {
      return groups.runTransaction(async (tx) => {
        const children = await tx.childrenOf(payment.subjectType === 'payment_group' ? payment.id : (payment.groupId ?? payment.id));
        const b = children.find((c) => c.subjectType === 'booking');
        if (b) return (await tx.getBooking(b.subjectId))?.status ?? 'gone';
        const t = children.find((c) => c.eventId !== undefined);
        if (t?.eventId) return (await tx.getRegistration(t.eventId, t.subjectId))?.status ?? 'gone';
        return payment.status;
      });
    },
  };
}
