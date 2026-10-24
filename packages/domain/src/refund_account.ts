/**
 * S22.04 Tài khoản nhận hoàn (#141, plan 2026-10-07-s22-payments-account, Decisions 5–7).
 *
 * A policy refund of a bank-QR payment (customer cancel, decline, expired request, event cancel, a
 * dispute outcome) starts `awaiting_account` (`applyRefundToPayment({waitForAccount: true})`): the
 * customer confirms the paying account or another one whose holder name the bank looked up, and
 * after `confirmBy` (24 h) the payment clock sends it to the paying account. A refund without a
 * paying account has no `confirmBy` and waits for the customer. Excess refunds and wallet refunds
 * never wait (V2 / #129).
 *
 * Exactly one dispatch per refund: `chooseRefundAccount` and `confirmDueRefundAccounts` move a refund
 * from `awaiting_account` to `pending` in one transaction that re-reads it, and only the caller that
 * made the move sends it (V2's `sendRefundOnce` under the refund id).
 *
 * The refund is stored with its subject's ledger: bookings through the booking store, tickets through
 * the event store, dispute outcomes through the dispute store (in Firestore the three are the same
 * `refunds` collection; in memory each world keeps its own). Each is sent by its own existing
 * dispatcher (`dispatchRefund`, `dispatchTicketRefund`, `dispatchDisputeRefund`), which keeps its
 * mirrors (booking `depositRefundedAt`, registration `refundStatus`).
 */

import type { AccountNameLookup } from './account_lookup.js';
import type { BookingDeps, BookingStore } from './booking_ports.js';
import type { DisputeDeps } from './dispute_ports.js';
import { dispatchDisputeRefund } from './dispute_use_cases.js';
import { DomainError } from './errors.js';
import {
  canChooseRefundAccount,
  type Payment,
  type Refund,
  type RefundDestination,
  type RefundStatus,
  type StoredBankAccount,
} from './escrow.js';
import { dispatchTicketRefund } from './event_payments.js';
import type { EventPaymentDeps } from './event_ports.js';
import { isId } from './ids.js';
import { notifyRefundAccountNeeded } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { formatVnDate } from './booking_policy.js';
import { accountLast4, NAME_LOOKUPS_PER_DAY, normalizeAccountNumber } from './payout_account.js';
import type { Clock } from './ports.js';
import { refundWithoutPayment } from './refund_subjects.js';
import { dispatchRefund } from './refunds.js';
import { bankByCode } from './vn_banks.js';

/** Which waiting refund S22.04 opens for: a booking (S05.02/S05.03), a ticket (S11.04) or a dispute (S18.02). */
export type RefundSubjectRef =
  | { readonly bookingId: string }
  | { readonly eventId: string; readonly registrationId: string }
  | { readonly disputeId: string };

/** What S22.04 shows: the amount and the paying account masked (bank, last 4, holder), never the number. */
export interface PendingRefundView {
  readonly refundId: string;
  readonly amount: number;
  readonly payer: { readonly bankName: string; readonly accountLast4: string; readonly holderName: string } | null;
  readonly confirmBy: string | null;
}

export interface RefundAccountDeps {
  /** Booking refunds; its store also answers `awaitingRefundsDue` for every subject (one collection in Firestore). */
  readonly bookings: BookingDeps;
  /** Ticket refunds (`dispatchTicketRefund` mirrors the registration). */
  readonly events: EventPaymentDeps;
  /** Dispute refunds (#142's `dispatchDisputeRefund`) and `pendingRefundFor({disputeId})`. */
  readonly disputes: DisputeDeps;
  /** The bank's holder-name lookup (#134's port; the fake echoes the caller's normalised display name). */
  readonly lookup: AccountNameLookup;
  readonly clock: Clock;
}

// ── Where a refund lives ───────────────────────────────────────────────────────────────────────

type LedgerKind = 'booking' | 'ticket' | 'dispute';

/**
 * `dispute:<id>` is #142's reason for an outcome refund; a ticket refund carries its subject; a
 * refund without a subject is a booking's (written before the field). Chụp ngay and S21-fee refunds
 * (null) are not S22.04's: they never get a 24-hour window and are refused here (`not_eligible`).
 */
function kindOf(r: Pick<Refund, 'reason' | 'subjectType'>): LedgerKind | null {
  if (!canChooseRefundAccount(r)) return null;
  if (r.reason?.startsWith('dispute:') === true) return 'dispute';
  return r.subjectType === 'event_registration' ? 'ticket' : 'booking';
}

/** The refund changed by `next`, or null to leave it (no write). */
type RefundChange = (current: Refund, payment: Payment) => Refund | null;

interface Ledger {
  read(refundId: string): Promise<{ refund: Refund; payment: Payment | null } | null>;
  /** One transaction: re-read the refund and its payment, then write `change`'s result (reads before writes). */
  update(refundId: string, change: RefundChange): Promise<{ refund: Refund; payment: Payment } | null>;
  dispatch(refund: Refund, payment: Payment): Promise<Refund>;
}

function ledgerOf(deps: RefundAccountDeps, kind: LedgerKind): Ledger {
  switch (kind) {
    case 'booking':
      return {
        read: async (id) => {
          const refund = await deps.bookings.store.getRefund(id);
          return refund === null ? null : { refund, payment: await deps.bookings.store.getPayment(refund.paymentId) };
        },
        update: (id, change) =>
          deps.bookings.store.runTransaction(async (tx) => {
            const current = await tx.getRefund(id);
            const payment = current === null ? null : await tx.getPayment(current.paymentId);
            if (current === null || payment === null) return null;
            const next = change(current, payment);
            if (next === null) return null;
            // The booking's S05.02 flag goes down when its refund leaves the wait (a booking has one
            // waiting refund: its cancel/decline/expiry; dispute refunds never raise the flag).
            const booking =
              next.status !== 'awaiting_account' && payment.subjectType === 'booking'
                ? await tx.getBooking(payment.subjectId)
                : null;
            await tx.addRefund(next);
            if (booking?.refundAccountNeeded === true) {
              await tx.setBooking({ ...booking, refundAccountNeeded: false, updatedAt: next.updatedAt });
            }
            return { refund: next, payment };
          }),
        dispatch: (refund, payment) => dispatchRefund(deps.bookings, refund, payment.provider),
      };
    case 'ticket':
      return {
        read: (id) =>
          deps.events.events.runTransaction(async (tx) => {
            const refund = await tx.getRefund(id);
            return refund === null ? null : { refund, payment: await tx.getPayment(refund.paymentId) };
          }),
        update: (id, change) =>
          deps.events.events.runTransaction(async (tx) => {
            const current = await tx.getRefund(id);
            const payment = current === null ? null : await tx.getPayment(current.paymentId);
            if (current === null || payment === null) return null;
            const next = change(current, payment);
            if (next === null) return null;
            tx.putRefund(next);
            return { refund: next, payment };
          }),
        dispatch: (refund, payment) => dispatchTicketRefund(deps.events, refund, payment),
      };
    case 'dispute':
      return {
        read: (id) =>
          deps.disputes.store.runTransaction(async (tx) => {
            const refund = await tx.getRefund(id);
            return refund === null ? null : { refund, payment: await tx.getPayment(refund.paymentId) };
          }),
        update: (id, change) =>
          deps.disputes.store.runTransaction(async (tx) => {
            const current = await tx.getRefund(id);
            const payment = current === null ? null : await tx.getPayment(current.paymentId);
            if (current === null || payment === null) return null;
            const next = change(current, payment);
            if (next === null) return null;
            tx.addRefund(next);
            return { refund: next, payment };
          }),
        dispatch: (refund, payment) => dispatchDisputeRefund(deps.disputes, payment, refund),
      };
  }
}

/**
 * The refund, its payment and its ledger. Read through the booking store first (in Firestore it
 * holds every refund), then the event and dispute stores (separate memory worlds).
 */
async function findRefund(deps: RefundAccountDeps, refundId: string): Promise<{ refund: Refund; payment: Payment; ledger: Ledger }> {
  for (const where of ['booking', 'ticket', 'dispute'] as const) {
    const found = await ledgerOf(deps, where).read(refundId);
    if (found === null) continue;
    const kind = kindOf(found.refund);
    if (kind === null) throw new DomainError('not_eligible');
    const ledger = ledgerOf(deps, kind);
    const own = kind === where ? found : await ledger.read(refundId);
    if (own === null || own.payment === null) break;
    return { refund: own.refund, payment: own.payment, ledger };
  }
  throw new DomainError('not_found');
}

// ── Input ──────────────────────────────────────────────────────────────────────────────────────

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function id(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

function subjectRef(raw: unknown): RefundSubjectRef {
  const r = obj(raw);
  const keys = Object.keys(r).sort().join(',');
  if (keys === 'bookingId') return { bookingId: id(r.bookingId) };
  if (keys === 'eventId,registrationId') return { eventId: id(r.eventId), registrationId: id(r.registrationId) };
  if (keys === 'disputeId') return { disputeId: id(r.disputeId) };
  throw new DomainError('invalid_argument');
}

function payerOnly(payment: Pick<Payment, 'payerId'>, caller: { uid: string }): void {
  if (payment.payerId !== caller.uid) throw new DomainError('permission_denied');
}

function viewOf(r: Refund): PendingRefundView {
  const d = r.destination;
  return {
    refundId: r.id,
    amount: r.amount,
    payer: d && d.source === 'payer' ? { bankName: d.bankName, accountLast4: d.accountLast4, holderName: d.holderName } : null,
    confirmBy: r.confirmBy ?? null,
  };
}

// ── Use cases ──────────────────────────────────────────────────────────────────────────────────

/**
 * The refunds of one payment still waiting for an account whose ledger is one of `kinds`. A refund
 * lives in the booking, event or dispute store depending on who wrote it (in Firestore all three
 * are one `refunds` collection), so the booking and dispute stores are both asked and merged by id.
 */
async function waitingRefundsOf(deps: RefundAccountDeps, paymentId: string, kinds: readonly LedgerKind[]): Promise<Refund[]> {
  const byId = new Map<string, Refund>();
  for (const list of [
    await deps.bookings.store.getRefundsForPayment(paymentId),
    await deps.disputes.store.getRefundsForPayment(paymentId),
  ]) {
    for (const r of list) {
      const kind = kindOf(r);
      if (r.status === 'awaiting_account' && kind !== null && kinds.includes(kind)) byId.set(r.id, r);
    }
  }
  return [...byId.values()];
}

/**
 * One subject can have two waiting refunds (its cancellation and a dispute outcome): the oldest
 * (`createdAt`, then id) is the one S22.04 shows and `chooseRefundAccount` commits, so the refund
 * the customer sees is the refund the choice lands on.
 */
function oldestOf(waiting: readonly Refund[]): Refund | null {
  const sorted = [...waiting].sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
  return sorted[0] ?? null;
}

/**
 * `{bookingId}` | `{eventId, registrationId}` | `{disputeId}` → the refund waiting for the caller's
 * account choice, or null when none waits. Only the customer of the subject (`permission_denied`).
 * A booking or ticket also answers with a waiting dispute refund of its payment (S22.01 offers the
 * choice for it on the booking / ticket row); with two waiting refunds the oldest is returned.
 */
export async function pendingRefundFor(
  deps: RefundAccountDeps,
  caller: { uid: string },
  raw: unknown,
): Promise<PendingRefundView | null> {
  const ref = subjectRef(raw);
  if ('bookingId' in ref) {
    const booking = await deps.bookings.store.getBooking(ref.bookingId);
    if (booking === null) throw new DomainError('not_found');
    if (booking.customerId !== caller.uid) throw new DomainError('permission_denied');
    const waiting: Refund[] = [];
    for (const p of await deps.bookings.store.getPaymentsForBooking(ref.bookingId)) {
      waiting.push(...(await waitingRefundsOf(deps, p.id, ['booking', 'dispute'])));
    }
    const oldest = oldestOf(waiting);
    return oldest === null ? null : viewOf(oldest);
  }
  if ('registrationId' in ref) {
    const found = await deps.events.events.runTransaction(async (tx) => {
      const reg = await tx.getRegistration(ref.eventId, ref.registrationId);
      const refund = reg?.refundId ? await tx.getRefund(reg.refundId) : null;
      return { reg, refund };
    });
    if (found.reg === null) throw new DomainError('not_found');
    if (found.reg.userId !== caller.uid) throw new DomainError('permission_denied');
    const waiting =
      found.reg.paymentId === null ? [] : await waitingRefundsOf(deps, found.reg.paymentId, ['ticket', 'dispute']);
    if (found.refund?.status === 'awaiting_account' && kindOf(found.refund) === 'ticket') waiting.push(found.refund);
    const oldest = oldestOf([...new Map(waiting.map((r) => [r.id, r])).values()]);
    return oldest === null ? null : viewOf(oldest);
  }
  const found = await deps.disputes.store.runTransaction(async (tx) => {
    const dispute = await tx.getDispute(ref.disputeId);
    const refundId = dispute?.outcome?.refundId ?? null;
    const refund = refundId !== null ? await tx.getRefund(refundId) : null;
    return { dispute, refund };
  });
  if (found.dispute === null) throw new DomainError('not_found');
  if (found.dispute.customerId !== caller.uid) throw new DomainError('permission_denied');
  return found.refund?.status === 'awaiting_account' ? viewOf(found.refund) : null;
}

/**
 * `{refundId, bankCode, accountNumber}` → the holder name the bank returns for another account.
 * The account is stored on the refund as its encrypted `candidate` (the customer never types the
 * name; Decision 7); `chooseRefundAccount({use: 'candidate', bankCode, accountLast4})` commits it. Errors: bad bank or
 * number `invalid_argument`; not the payer `permission_denied`; the refund no longer waits
 * `conflict`; the bank does not know it `not_found`; the bank cannot look it up `not_eligible`.
 */
export async function lookupRefundAccount(
  deps: RefundAccountDeps,
  caller: { uid: string },
  raw: unknown,
): Promise<{ holderName: string; bankName: string; accountLast4: string }> {
  const r = obj(raw);
  const refundId = id(r.refundId);
  const bank = bankByCode(r.bankCode);
  const accountNumber = normalizeAccountNumber(r.accountNumber);
  if (bank === null || accountNumber === null) throw new DomainError('invalid_argument');

  const { refund, payment, ledger } = await findRefund(deps, refundId);
  payerOnly(payment, caller);
  if (refund.status !== 'awaiting_account') throw new DomainError('conflict');

  // One transaction before the bank is asked: charge this attempt to the refund's Vietnam day (found,
  // not found and unsupported alike); the 21st is `limit_exceeded` and never reaches the bank.
  const day = formatVnDate(deps.clock.now());
  await ledger.update(refundId, (current) => {
    if (current.status !== 'awaiting_account') throw new DomainError('conflict');
    const count = current.accountLookups?.day === day ? current.accountLookups.count : 0;
    if (count >= NAME_LOOKUPS_PER_DAY) throw new DomainError('limit_exceeded');
    return { ...current, accountLookups: { day, count: count + 1 }, updatedAt: deps.clock.now().toISOString() };
  });

  const found = await deps.lookup.lookup({ bankCode: bank.code, accountNumber });
  if (found.status === 'not_found') throw new DomainError('not_found');
  if (found.status === 'unsupported') throw new DomainError('not_eligible');

  const candidate: StoredBankAccount = {
    bankCode: bank.code,
    bankName: bank.shortName,
    accountNumberEnc: await deps.bookings.cipher.encrypt(accountNumber),
    accountLast4: accountLast4(accountNumber),
    holderName: found.holderName,
  };
  const at = deps.clock.now().toISOString();
  const saved = await ledger.update(refundId, (current) => {
    if (current.status !== 'awaiting_account') throw new DomainError('conflict');
    return { ...current, candidate, updatedAt: at };
  });
  if (saved === null) throw new DomainError('not_found');
  return { holderName: candidate.holderName, bankName: candidate.bankName, accountLast4: candidate.accountLast4 };
}

/** awaiting_account → pending to `destination`, attempt time stamped so V2's re-send finds it if the send is lost. */
function claimed(current: Refund, destination: RefundDestination, at: string): Refund {
  return { ...current, status: 'pending', destination, candidate: null, lastAttemptAt: at, updatedAt: at };
}

/** The account a `candidate` choice expects: the one S22.04 showed after its lookup. */
interface ShownAccount {
  readonly bankCode: string;
  readonly accountLast4: string;
}

function shownAccount(r: Record<string, unknown>): ShownAccount {
  const bank = bankByCode(r.bankCode);
  const last4 = r.accountLast4;
  if (bank === null || typeof last4 !== 'string' || !/^[0-9]{4}$/.test(last4)) throw new DomainError('invalid_argument');
  return { bankCode: bank.code, accountLast4: last4 };
}

/** Whether a refund that left the wait went where this choice asked (a repeat of the same choice). */
function wentAsChosen(r: Refund, shown: ShownAccount | null): boolean {
  const d = r.destination;
  if (!d) return false;
  if (shown === null) return d.source === 'payer';
  return d.source === 'customer' && d.bankCode === shown.bankCode && d.accountLast4 === shown.accountLast4;
}

/**
 * `{refundId, use: 'payer'}` or `{refundId, use: 'candidate', bankCode, accountLast4}`: sends the
 * waiting refund to the paying account or to the looked-up one. A `candidate` choice names the
 * account the customer was shown, and the stored candidate must still be that account (a later
 * lookup replaces it): otherwise `conflict`, nothing sent. A refund that no longer waits answers its
 * status only when it went where this choice asks (a repeat; never a second dispatch); when it went
 * elsewhere (the 24-hour default sent it to the paying account, or another choice won) → `conflict`,
 * so the app never reports the chosen account as used. `payer` without a paying account or
 * `candidate` without a lookup → `invalid_argument`.
 */
export async function chooseRefundAccount(
  deps: RefundAccountDeps,
  caller: { uid: string },
  raw: unknown,
): Promise<{ status: RefundStatus }> {
  const r = obj(raw);
  const refundId = id(r.refundId);
  const use = r.use;
  if (use !== 'payer' && use !== 'candidate') throw new DomainError('invalid_argument');
  const shown = use === 'candidate' ? shownAccount(r) : null;

  const { refund, payment, ledger } = await findRefund(deps, refundId);
  payerOnly(payment, caller);
  const settled = (now: Refund): { status: RefundStatus } => {
    if (!wentAsChosen(now, shown)) throw new DomainError('conflict');
    return { status: now.status };
  };
  if (refund.status !== 'awaiting_account') return settled(refund);

  const at = deps.clock.now().toISOString();
  const moved = await ledger.update(refundId, (current) => {
    if (current.status !== 'awaiting_account') return null;
    if (shown === null) {
      if (current.destination?.source !== 'payer') throw new DomainError('invalid_argument');
      return claimed(current, current.destination, at);
    }
    const c = current.candidate;
    if (!c) throw new DomainError('invalid_argument');
    if (c.bankCode !== shown.bankCode || c.accountLast4 !== shown.accountLast4) throw new DomainError('conflict');
    return claimed(current, { ...c, source: 'customer' }, at);
  });
  if (moved === null) {
    // Someone else (the 24-hour default or another choice) moved it first and sends it.
    const now = await ledger.read(refundId);
    return settled(now?.refund ?? refund);
  }
  const sent = await ledger.dispatch(moved.refund, moved.payment);
  return { status: sent.status };
}

/**
 * The 24-hour default, a named step of the payment clock: every refund still `awaiting_account`
 * whose `confirmBy` has passed goes to the paying account. Refunds without a paying account have no
 * `confirmBy` and are never returned by the query. One failing refund is reported and skipped.
 * Returns how many this run moved and sent.
 */
export async function confirmDueRefundAccounts(
  deps: RefundAccountDeps,
  now: Date,
  limit: number,
  onError: (refundId: string, error: unknown) => void = () => undefined,
): Promise<number> {
  let sent = 0;
  for (const due of await deps.bookings.store.awaitingRefundsDue(now, limit)) {
    try {
      const kind = kindOf(due);
      const at = deps.clock.now().toISOString();
      const moved =
        kind === null
          ? null
          : await ledgerOf(deps, kind).update(due.id, (current) => {
              const d = current.destination;
              if (current.status !== 'awaiting_account' || !d || d.source !== 'payer') return null;
              if (!current.confirmBy || Date.parse(current.confirmBy) > now.getTime()) return null;
              return claimed(current, d, at);
            });
      if (moved === null || kind === null) {
        // Not sent: take it out of the due queue unless someone else just moved it, so a refund
        // this step can never send does not head every run (the query is oldest `confirmBy` first).
        await leaveDueQueue(deps, due.id, now);
        continue;
      }
      await ledgerOf(deps, kind).dispatch(moved.refund, moved.payment);
      sent += 1;
    } catch (e) {
      onError(due.id, e);
    }
  }
  return sent;
}

/**
 * A due refund the default cannot send leaves the queue, in the store the query read (every refund
 * in Firestore): without its payment it goes to staff (`failed`, `manual`, `payment_missing`, as V2's
 * re-send does); otherwise (no paying account, or not S22.04's subject) `confirmBy` is cleared and it
 * waits for the customer or staff. A refund no longer waiting or no longer due is left as it is.
 */
async function leaveDueQueue(deps: RefundAccountDeps, refundId: string, now: Date): Promise<void> {
  await deps.bookings.store.runTransaction(async (tx) => {
    const current = await tx.getRefund(refundId);
    if (current === null || current.status !== 'awaiting_account') return;
    if (!current.confirmBy || Date.parse(current.confirmBy) > now.getTime()) return;
    const payment = await tx.getPayment(current.paymentId);
    const at = deps.clock.now().toISOString();
    await tx.addRefund(
      payment === null
        ? refundWithoutPayment(current, deps.clock.now())
        : { ...current, confirmBy: null, updatedAt: at },
    );
  });
}

/**
 * Decision 6: the one emitter of #138's `refund_account_needed`, run by the refund-write trigger for
 * the subjects S22.04 settles (booking, ticket, dispute): when a refund enters `awaiting_account` its
 * payer is told once (#138 dedupes by refund id, so a retried trigger is harmless). Any other write
 * is `skipped`.
 */
export async function announceRefundAccountNeeded(
  deps: { readonly notify: NotifyDeps; readonly payments: Pick<BookingStore, 'getPayment'> },
  before: Pick<Refund, 'status'> | null,
  after: Refund | null,
): Promise<'notified' | 'skipped'> {
  if (after === null || after.status !== 'awaiting_account' || before?.status === 'awaiting_account') return 'skipped';
  // Only refunds S22.04 can settle (bookings, tickets, disputes); see `kindOf`.
  if (kindOf(after) === null) return 'skipped';
  const payment = await deps.payments.getPayment(after.paymentId);
  if (payment === null) return 'skipped';
  await notifyRefundAccountNeeded(deps.notify, {
    uid: payment.payerId,
    refundId: after.id,
    amount: after.amount,
    hasPayer: after.destination?.source === 'payer',
  });
  return 'notified';
}
