/**
 * S18 disputes (#142): open (freeze the money of the window), resolve (release / refund / split
 * through the existing milestone, release and refund paths) and send the dispute refund.
 * Plan 2026-10-07-s18-disputes-help, Decisions 1–8 and 10. No payout is ever written here.
 */

import {
  disputeProviderName,
  disputeThreadId,
  disputeWindow,
  outcomeAmounts,
  parseOpenDisputeInput,
  parseResolveDisputeInput,
  type Dispute,
  type DisputeOutcomeKind,
} from './dispute.js';
import { formatVnDate, formatVnTime } from './booking_policy.js';
import type { DisputeDeps, DisputeSubjectView } from './dispute_ports.js';
import { DomainError } from './errors.js';
import {
  applyRefundToPayment,
  disputeEscrowPayment,
  escrowRefundedTotal,
  isSettledPayment,
  releaseEscrowPayment,
  type Payment,
  type Refund,
} from './escrow.js';
import {
  disputeMilestone,
  releaseMilestone,
  withMilestones,
  type MilestoneKind,
  type PaymentMilestone,
} from './milestones.js';
import { formatVnd, truncateGraphemes } from './notification_render.js';
import { mergeRefundOutcome, sendRefundOnce } from './refunds.js';
import type { SupportMessage, SupportThread } from './support_thread.js';

const PLATFORM = 'platform';
const SYSTEM_NAME = 'Hệ thống';
const PREVIEW_MAX = 80;

/** The system line that opens every dispute thread, `Đã mở khiếu nại · 10:12 14/10` (Vietnam time; the seed writes the same). */
export function disputeOpenedText(at: string): string {
  const when = new Date(at);
  const [, m, d] = formatVnDate(when).split('-');
  return `Đã mở khiếu nại · ${formatVnTime(when)} ${d}/${m}`;
}

function newDisputeThread(d: Dispute, at: string): SupportThread {
  return {
    id: d.threadId,
    kind: 'dispute',
    ownerId: null,
    disputeId: d.id,
    participants: d.parties,
    status: 'open',
    awaitingStaff: true,
    lastMessageAt: null,
    lastMessagePreview: null,
    lastSenderRole: null,
    rate: {},
    createdAt: at,
    updatedAt: at,
  };
}

function systemMessage(threadId: string, id: string, body: string, at: string): SupportMessage {
  return { id, threadId, senderId: null, senderRole: 'system', senderName: SYSTEM_NAME, body, createdAt: at };
}

/** The same customer sending the same dispute id again gets it back unchanged (Decision 4). */
function sameOpen(existing: Dispute, callerId: string): Dispute {
  if (existing.customerId !== callerId) throw new DomainError('permission_denied');
  return existing;
}

/**
 * Customer opens a dispute (Decisions 2–5): only the paying customer, inside the window, one open
 * dispute per subject (a booking's two milestones can each be disputed once, in their own windows). Freezes the window's milestone (#152's `disputeMilestone`), or a payment
 * without milestones whole (`escrowStatus: disputed`, `prevEscrowStatus` kept), mirrors the subject,
 * and opens the three-party thread with a system message and the description as the first message.
 */
export async function openDispute(deps: DisputeDeps, callerId: string, raw: unknown): Promise<Dispute> {
  const input = parseOpenDisputeInput(raw, callerId);
  const now = deps.clock.now();
  const at = now.toISOString();

  // What escrow already gave back (#129: fromEscrow false never counts) is read outside the transaction.
  const pre = await deps.store.runTransaction(async (tx) => {
    const existing = await tx.getDispute(input.disputeId);
    if (existing) return { existing, paymentId: null };
    const subject = await tx.getSubject(input.subjectType, input.subjectId, input.eventId);
    const payment = subject ? await tx.findSubjectPayment(subject) : null;
    return { existing: null, paymentId: payment?.id ?? null };
  });
  if (pre.existing) return sameOpen(pre.existing, callerId);
  const refundsSoFar = pre.paymentId ? escrowRefundedTotal(await deps.store.getRefundsForPayment(pre.paymentId)) : 0;
  const customerName = (await deps.names.displayName(callerId)) || 'Khách';

  return deps.store.runTransaction(async (tx) => {
    const existing = await tx.getDispute(input.disputeId);
    if (existing) return sameOpen(existing, callerId);
    const subject = await tx.getSubject(input.subjectType, input.subjectId, input.eventId);
    if (!subject) throw new DomainError('not_found');
    if (subject.customerId !== callerId) throw new DomainError('permission_denied');
    const payment = await tx.findSubjectPayment(subject);
    const window = disputeWindow(subject, now, payment?.milestones !== undefined);
    // One OPEN dispute per subject (spec §3i.1). After a resolved shoot dispute the delivery milestone
    // may still be disputed in its own window; the held-milestone check below refuses the same one twice.
    if (subject.disputeId) {
      const current = await tx.getDispute(subject.disputeId);
      if (current?.status === 'open') throw new DomainError('conflict');
    }
    if (!payment || !isSettledPayment(payment)) throw new DomainError('not_eligible');
    // The refunds read above belong to another payment: let the caller retry.
    if (!payment.milestones && payment.id !== pre.paymentId) throw new DomainError('conflict');

    let frozen: Payment;
    let amountHeld: number;
    if (payment.milestones) {
      const ms = window.milestone ? payment.milestones.find((m) => m.kind === window.milestone) : undefined;
      if (!window.milestone || !ms || ms.status !== 'held') throw new DomainError('not_eligible');
      amountHeld = ms.amount;
      frozen = {
        ...disputeMilestone(payment, window.milestone, now),
        dispute: { reason: input.reason, openedAt: at, disputeId: input.disputeId, milestone: window.milestone },
      };
    } else {
      const prev = payment.escrowStatus;
      if (prev !== 'held' && prev !== 'partially_refunded') throw new DomainError('not_eligible');
      amountHeld = payment.amount - refundsSoFar;
      frozen = {
        ...disputeEscrowPayment(payment, now),
        dispute: { reason: input.reason, openedAt: at, disputeId: input.disputeId, milestone: null, prevEscrowStatus: prev },
      };
    }
    if (amountHeld <= 0) throw new DomainError('not_eligible');

    const dispute: Dispute = {
      id: input.disputeId,
      subjectType: subject.type,
      subjectId: subject.id,
      eventId: subject.eventId,
      paymentId: payment.id,
      customerId: subject.customerId,
      providerId: subject.providerId,
      parties: subject.providerId === PLATFORM ? [subject.customerId] : [subject.customerId, subject.providerId],
      openedBy: 'customer',
      reason: input.reason,
      description: input.description,
      evidencePaths: input.evidencePaths,
      snapshot: subject.snapshot,
      amountHeld,
      status: 'open',
      outcome: null,
      threadId: disputeThreadId(input.disputeId),
      createdAt: at,
      updatedAt: at,
      resolvedAt: null,
      version: 1,
    };
    // The description is the first message; it is stamped 1 ms after the system line so both sort in order.
    // `opening` keeps it out of the message notices (the provider gets `dispute_opened` for it).
    const firstAt = new Date(now.getTime() + 1).toISOString();
    const first: SupportMessage = {
      id: deps.ids.newId(),
      threadId: dispute.threadId,
      senderId: callerId,
      senderRole: 'customer',
      senderName: customerName,
      body: input.description,
      createdAt: firstAt,
      opening: true,
    };
    const thread: SupportThread = {
      ...newDisputeThread(dispute, at),
      lastMessageAt: firstAt,
      lastMessagePreview: truncateGraphemes(input.description, PREVIEW_MAX),
      lastSenderRole: 'customer',
    };

    tx.setPayment(frozen);
    tx.linkSubject(subject, { disputeId: dispute.id, escrowStatus: frozen.escrowStatus });
    tx.setDispute(dispute);
    tx.putThread(thread);
    tx.addMessage(systemMessage(dispute.threadId, deps.ids.newId(), disputeOpenedText(at), at));
    tx.addMessage(first);
    return dispute;
  });
}

function outcomeLine(kind: DisputeOutcomeKind, refund: number, release: number, provider: string): string {
  if (kind === 'release') return `chuyển ${formatVnd(release)} cho ${provider}`;
  if (kind === 'refund') return `hoàn ${formatVnd(refund)} cho khách`;
  return `hoàn ${formatVnd(refund)} cho khách, chuyển ${formatVnd(release)} cho ${provider}`;
}

/**
 * The milestone a dispute froze: `payment.dispute.milestone`; for a milestone payment whose record
 * lacks it, the single `disputed` milestone. Null only for a payment without milestones.
 * Throws conflict when a milestone payment has no single disputed milestone to resolve.
 */
function frozenMilestone(p: Payment): MilestoneKind | null {
  if (!p.milestones) return null;
  const recorded = p.dispute?.milestone;
  if (recorded) return recorded;
  const disputed = p.milestones.filter((m) => m.status === 'disputed');
  if (disputed.length !== 1 || !disputed[0]) throw new DomainError('conflict');
  return disputed[0].kind;
}

/**
 * Staff decide (Decisions 7 and 10; the adapter has already checked the `admin` role). In one
 * transaction: the frozen milestone (or the whole payment) back to its previous status, then #129's
 * `applyRefundToPayment` with the exact refund share (`fromEscrow: true`), then #152's
 * `releaseMilestone` (or `releaseEscrowPayment` without milestones) for the release share. A split
 * shrinks the frozen milestone to its release share before releasing it, so payouts and earnings
 * see only what the provider keeps. The refund is sent after the commit (`dispatchDisputeRefund`).
 */
export async function resolveDispute(
  deps: DisputeDeps,
  staffId: string,
  raw: unknown,
): Promise<{ dispute: Dispute; refund: Refund | null }> {
  const input = parseResolveDisputeInput(raw);
  const now = deps.clock.now();
  const at = now.toISOString();

  const pre = await deps.store.runTransaction((tx) => tx.getDispute(input.disputeId));
  if (!pre) throw new DomainError('not_found');
  const refundsSoFar = escrowRefundedTotal(await deps.store.getRefundsForPayment(pre.paymentId));

  return deps.store.runTransaction(async (tx) => {
    const d = await tx.getDispute(input.disputeId);
    const p = d ? await tx.getPayment(d.paymentId) : null;
    const subject: DisputeSubjectView | null = d ? await tx.getSubject(d.subjectType, d.subjectId, d.eventId) : null;
    const thread = d ? await tx.getThread(d.threadId) : null;
    if (!d || !p || !subject) throw new DomainError('not_found');

    const kind = frozenMilestone(p);
    const ms = kind ? p.milestones?.find((m) => m.kind === kind) : undefined;
    if (d.status !== 'open' || (p.dispute?.disputeId !== undefined && p.dispute.disputeId !== d.id)) {
      throw new DomainError('conflict');
    }
    if (kind ? ms?.status !== 'disputed' : p.escrowStatus !== 'disputed') throw new DomainError('conflict');

    // Decision 7: the frozen milestone, else what a payment without milestones still holds.
    const held = ms ? ms.amount : p.amount - refundsSoFar;
    const a = outcomeAmounts(held, input.kind, input.refundPercent);

    // 1. Back to the previous status.
    let pay: Payment = kind
      ? withMilestones(p, (p.milestones ?? []).map((m): PaymentMilestone => (m.kind === kind ? { ...m, status: 'held' } : m)), at)
      : { ...p, escrowStatus: p.dispute?.prevEscrowStatus ?? 'held', updatedAt: at };

    // 2. The refund share, out of escrow.
    let refund: Refund | null = null;
    if (a.refundAmount > 0) {
      const r = applyRefundToPayment({
        payment: pay,
        refundId: deps.ids.newId(),
        percent: a.refundPercent,
        amount: a.refundAmount,
        escrowRefunded: refundsSoFar,
        ledgerEntryId: deps.ids.newId(),
        reason: `dispute:${d.id}`,
        now,
      });
      pay = r.payment;
      refund = r.refund;
      tx.addRefund(r.refund);
      tx.addLedgerEntry(r.ledgerEntry);
    }

    // 3. The release share, to the payee (a platform payee keeps it).
    if (kind) {
      const rest = (pay.milestones ?? []).map((m): PaymentMilestone =>
        m.kind !== kind ? m : a.releaseAmount > 0 ? { ...m, amount: a.releaseAmount } : { ...m, status: 'refunded' },
      );
      pay = withMilestones(pay, rest, at);
      if (a.releaseAmount > 0) {
        const r = releaseMilestone(pay, kind, deps.ids.newId(), now);
        pay = r.payment;
        tx.addLedgerEntry(r.ledgerEntry);
      }
      // A booking that completed while its shoot milestone was disputed: completion releases the
      // delivery milestone, but data from before that rule may still hold it; release it now.
      const delivery = pay.milestones?.find((m) => m.kind === 'delivery');
      const done = subject.type === 'booking' && (subject.state === 'completed' || subject.state === 'reviewed');
      if (kind !== 'delivery' && done && delivery?.status === 'held') {
        const r = releaseMilestone(pay, 'delivery', deps.ids.newId(), now);
        pay = r.payment;
        tx.addLedgerEntry(r.ledgerEntry);
      }
    } else if (a.releaseAmount > 0) {
      const r = releaseEscrowPayment({
        payment: pay,
        refundAmount: refundsSoFar + a.refundAmount,
        ledgerEntryId: deps.ids.newId(),
        now,
      });
      pay = r.payment;
      tx.addLedgerEntry(r.ledgerEntry);
    }

    const resolved: Dispute = {
      ...d,
      status: 'resolved',
      outcome: {
        kind: input.kind,
        refundPercent: a.refundPercent,
        refundAmount: a.refundAmount,
        releaseAmount: a.releaseAmount,
        note: input.note,
        decidedBy: staffId,
        decidedAt: at,
        refundId: refund?.id ?? null,
      },
      resolvedAt: at,
      updatedAt: at,
      version: d.version + 1,
    };
    const provider = disputeProviderName(d);
    const body = `Khiếu nại đã có kết quả: ${outcomeLine(input.kind, a.refundAmount, a.releaseAmount, provider)}. Ghi chú của hỗ trợ: ${input.note}`;
    const closed: SupportThread = {
      ...(thread ?? newDisputeThread(d, at)),
      status: 'closed',
      awaitingStaff: false,
      lastMessageAt: at,
      lastMessagePreview: truncateGraphemes(body, PREVIEW_MAX),
      lastSenderRole: 'system',
      updatedAt: at,
    };

    tx.setPayment(pay);
    tx.linkSubject(subject, { disputeId: d.id, escrowStatus: pay.escrowStatus });
    tx.setDispute(resolved);
    tx.putThread(closed);
    tx.addMessage(systemMessage(d.threadId, deps.ids.newId(), body, at));
    return { dispute: resolved, refund };
  });
}

/**
 * Sends a dispute refund after the resolve commit, with V2's rule (#201): the stored refund is read
 * again first and sent only while still `pending` (like V2's `bookingRefundHandler.resend`: a refund
 * settled meanwhile is never sent twice); one gateway call under the refund id (`sendRefundOnce`: a
 * throw keeps it `pending` for V2's re-send, a refusal is `failed` + `manual`, an `awaiting_account`
 * refund is not sent), then the outcome stored with `mergeRefundOutcome`, which never overwrites a
 * refund that has left `pending` meanwhile.
 */
export async function dispatchDisputeRefund(deps: DisputeDeps, payment: Payment, refund: Refund): Promise<Refund> {
  const current = await deps.store.runTransaction((tx) => tx.getRefund(refund.id));
  if (!current || current.status !== 'pending') return current ?? refund;
  const next = await sendRefundOnce(deps, current, payment);
  return deps.store.runTransaction(async (tx) => {
    const stored = await tx.getRefund(refund.id);
    const merged = stored ? mergeRefundOutcome(stored, next) : null;
    if (!merged) return stored ?? next;
    tx.addRefund(merged);
    return merged;
  });
}
