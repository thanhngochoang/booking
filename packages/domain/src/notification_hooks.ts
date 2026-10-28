/**
 * One hook per notification event of the S17 catalogue (plan 2026-10-07, Decisions 1 and 12): each
 * decides the recipient(s), copy content, target, dedupe or group key and actor, then calls `notify`.
 * Each hook has exactly one emitter (named in the plan's hooks table), which calls it after its own
 * write commits, never inside a transaction. Pure: everything goes through `NotifyDeps`.
 */

import { formatVnDate, formatVnTime } from './booking_policy.js';
import type { NotificationActor, NotifyDeps, NotifyRequest } from './notification_ports.js';
import { notify, type NotifyResult } from './notification_use_cases.js';
import { bankByCode } from './vn_banks.js';

const CUSTOMER = 'Khách hàng';
const PHOTOGRAPHER = 'Nhiếp ảnh gia';
const STUDIO = 'Studio';
/** A dispute message comes from either party; the hook does not know which. */
const PARTY = 'Người dùng';

async function actorOf(deps: NotifyDeps, id: string, fallback: string): Promise<NotificationActor> {
  const u = await deps.users.get(id);
  return { id, name: u?.name ?? fallback, avatarUrl: u?.avatarUrl ?? null };
}

/** The request fields that name the counterpart: actor and its avatar as the thumbnail. */
const from = (actor: NotificationActor): Pick<NotifyRequest, 'actor' | 'thumbUrl'> => ({ actor, thumbUrl: actor.avatarUrl });

/**
 * Sends every request; a failing recipient never blocks the others, and one error is thrown at the
 * end (same contract as `notifyBookingChange`, so the emitter's trigger retries; dedupe stops doubles).
 */
async function notifyAll(deps: NotifyDeps, reqs: readonly NotifyRequest[]): Promise<NotifyResult[]> {
  const settled = await Promise.allSettled(reqs.map((r) => notify(deps, r)));
  const failed = settled.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failed.length > 0) {
    throw new Error(`notification failed for ${failed.length} recipient(s): ${String(failed[0]?.reason)}`);
  }
  return settled.map((r) => (r as PromiseFulfilledResult<NotifyResult>).value);
}

/** ISO instant → 'HH:mm dd/MM' in Vietnam time; an unparseable string is shown as given (never throws). */
function vnTimeDay(iso: string): string {
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) return iso;
  const [, m, d] = formatVnDate(at).split('-');
  return `${formatVnTime(at)} ${d}/${m}`;
}

// ── #139 job posts and quotes ────────────────────────────────────────────────────────────────

/**
 * Grouped per job: the customer's row counts quotes and names the latest three photographers. Called for
 * every quote. The event id is the photographer (not the quote version), and any repeat inside the unread
 * row's 20-id window (`recentEventIds`, Ruling 8) is a duplicate, so a re-quote never counts again: the
 * customer sees the updated quote in S15.03. Once the row is read, the next quote restarts the count.
 */
export async function notifyQuoteNew(
  deps: NotifyDeps,
  e: { customerId: string; jobId: string; jobTitle: string; photographerId: string; quoteVersion: number },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'quote_new', jobTitle: e.jobTitle, count: 1, names: [p.name] },
    target: `/jobs/${e.jobId}/applications`,
    dedupeKey: `quote_new_${e.jobId}`,
    groupKey: `job:${e.jobId}:quotes`,
    eventId: e.photographerId,
    ...from(p),
  });
}

export async function notifyQuoteWithdrawn(
  deps: NotifyDeps,
  e: { customerId: string; jobId: string; jobTitle: string; photographerId: string; quoteVersion: number; auto: boolean },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'quote_withdrawn', photographer: p.name, jobTitle: e.jobTitle, auto: e.auto },
    target: `/jobs/${e.jobId}/applications`,
    dedupeKey: `quote_withdrawn_${e.jobId}_${e.photographerId}_${e.quoteVersion}`,
    ...from(p),
  });
}

/** One notice per quote deadline: an extended deadline gets a new one. */
export async function notifyJobExpiring(
  deps: NotifyDeps,
  e: { customerId: string; jobId: string; jobTitle: string; quoteCount: number; quoteDeadline: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'job_expiring', jobTitle: e.jobTitle, quoteCount: e.quoteCount },
    target: `/jobs/${e.jobId}/applications`,
    dedupeKey: `job_expiring_${e.jobId}_${e.quoteDeadline}`,
  });
}

export async function notifyJobExpired(
  deps: NotifyDeps,
  e: { customerId: string; jobId: string; jobTitle: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'job_expired', jobTitle: e.jobTitle },
    target: `/jobs/${e.jobId}`,
    dedupeKey: `job_expired_${e.jobId}`,
  });
}

export async function notifyJobMatch(
  deps: NotifyDeps,
  e: { photographerId: string; jobId: string; jobTitle: string; day: string; area: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'job_match', jobTitle: e.jobTitle, day: e.day, area: e.area },
    target: `/jobs/${e.jobId}`,
    dedupeKey: `job_match_${e.jobId}_${e.photographerId}`,
  });
}

export async function notifyJobInvited(
  deps: NotifyDeps,
  e: { photographerId: string; customerId: string; jobId: string; jobTitle: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'job_invited', customer: c.name, jobTitle: e.jobTitle },
    target: `/jobs/${e.jobId}`,
    dedupeKey: `job_invited_${e.jobId}_${e.photographerId}`,
    ...from(c),
  });
}

export async function notifyQuoteAccepted(
  deps: NotifyDeps,
  e: { photographerId: string; customerId: string; jobId: string; bookingId: string; jobTitle: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'quote_accepted', customer: c.name, jobTitle: e.jobTitle },
    target: `/b/${e.bookingId}`,
    dedupeKey: `quote_accepted_${e.jobId}_${e.photographerId}`,
    ...from(c),
  });
}

export async function notifyQuoteNotSelected(
  deps: NotifyDeps,
  e: { photographerId: string; jobId: string; jobTitle: string; reason: 'awarded' | 'expired' | 'closed' | 'declined' },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'quote_not_selected', jobTitle: e.jobTitle, reason: e.reason },
    target: `/jobs/${e.jobId}`,
    dedupeKey: `quote_not_selected_${e.jobId}_${e.photographerId}`,
  });
}

// ── #140 Chụp ngay ───────────────────────────────────────────────────────────────────────────

/**
 * A request can be assigned again after a photographer cancels, so the per-job notices carry the
 * assignment (its `assignedAt` in ms) in their dedupe key: a replay of the same event still dedupes,
 * the next photographer's job gets its own rows. Absent → the request alone (older callers).
 */
const perAssignment = (base: string, assignment: string | undefined): string =>
  assignment === undefined ? base : `${base}_${assignment}`;

export async function notifyInstantAssigned(
  deps: NotifyDeps,
  e: { customerId: string; requestId: string; photographerId: string; etaMinutes: number; assignment?: string },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'instant_assigned', photographer: p.name, etaMinutes: e.etaMinutes },
    target: `/instant/${e.requestId}`,
    dedupeKey: perAssignment(`instant_assigned_${e.requestId}`, e.assignment),
    ...from(p),
  });
}

export async function notifyInstantMissed(
  deps: NotifyDeps,
  e: { photographerId: string; offerId: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'instant_missed' },
    target: '/work/instant',
    dedupeKey: `instant_missed_${e.offerId}`,
  });
}

export async function notifyInstantRoundEnded(
  deps: NotifyDeps,
  e: { customerId: string; requestId: string; round: number },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'instant_round_ended', round: e.round },
    target: `/instant/${e.requestId}`,
    dedupeKey: `instant_round_ended_${e.requestId}_${e.round}`,
  });
}

export async function notifyInstantNoMatch(
  deps: NotifyDeps,
  e: { customerId: string; requestId: string; round: number; amount: number },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'instant_no_match', amount: e.amount },
    target: `/instant/${e.requestId}`,
    dedupeKey: `instant_no_match_${e.requestId}_${e.round}`,
  });
}

export async function notifyInstantArrived(
  deps: NotifyDeps,
  e: { customerId: string; requestId: string; photographerId: string; place: string; assignment?: string },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'instant_arrived', photographer: p.name, place: e.place },
    target: `/instant/${e.requestId}`,
    dedupeKey: perAssignment(`instant_arrived_${e.requestId}`, e.assignment),
    ...from(p),
  });
}

export async function notifyInstantFinished(
  deps: NotifyDeps,
  e: { customerId: string; requestId: string; photographerId: string; assignment?: string },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'instant_finished', photographer: p.name },
    target: `/instant/${e.requestId}`,
    dedupeKey: perAssignment(`instant_finished_${e.requestId}`, e.assignment),
    ...from(p),
  });
}

/** To the party that did not cancel: the photographer (with the travel fee) or the customer. */
export async function notifyInstantCancelled(
  deps: NotifyDeps,
  e: { requestId: string; by: 'customer' | 'photographer'; customerId: string; photographerId: string; feeVnd: number; assignment?: string },
): Promise<NotifyResult> {
  const toPhotographer = e.by === 'customer';
  const other = toPhotographer
    ? await actorOf(deps, e.customerId, CUSTOMER)
    : await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: toPhotographer ? e.photographerId : e.customerId,
    content: { type: 'instant_cancelled', to: toPhotographer ? 'photographer' : 'customer', name: other.name, feeVnd: e.feeVnd },
    target: toPhotographer ? `/work/instant/${e.requestId}` : `/instant/${e.requestId}`,
    dedupeKey: perAssignment(`instant_cancelled_${e.requestId}_${e.by}`, e.assignment),
    ...from(other),
  });
}

// ── #130 reviews, #152 delivery ──────────────────────────────────────────────────────────────

export async function notifyReviewVerdict(
  deps: NotifyDeps,
  e: {
    bookingId: string;
    subjectUserId: string;
    customerId: string;
    verdict: 'tomato' | 'brick';
    hits: number;
    day: string;
    text: string;
  },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.subjectUserId,
    content:
      e.verdict === 'tomato'
        ? { type: 'review_tomato', hits: e.hits, day: e.day, text: e.text }
        : { type: 'review_brick', day: e.day, text: e.text },
    target: `/u/${e.subjectUserId}?tab=reviews`,
    dedupeKey: `review_${e.verdict}_${e.bookingId}_${e.subjectUserId}`,
    ...from(c),
  });
}

export async function notifyDeliverySubmitted(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; delivererId: string; round: number; count: number },
): Promise<NotifyResult> {
  const d = await actorOf(deps, e.delivererId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'delivery_submitted', deliverer: d.name, count: e.count },
    target: `/b/${e.bookingId}/delivery`,
    dedupeKey: `delivery_submitted_${e.bookingId}_${e.round}`,
    ...from(d),
  });
}

export async function notifyDeliveryRevisionRequested(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; delivererId: string; round: number },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.delivererId,
    content: { type: 'delivery_revision_requested', customer: c.name, round: e.round },
    target: `/b/${e.bookingId}`,
    dedupeKey: `delivery_revision_${e.bookingId}_${e.round}`,
    ...from(c),
  });
}

export async function notifyDeliveryApproved(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; delivererId: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.delivererId,
    content: { type: 'delivery_approved', customer: c.name },
    target: `/b/${e.bookingId}`,
    dedupeKey: `delivery_approved_${e.bookingId}`,
    ...from(c),
  });
}

export async function notifyDeliveryAutoApproveSoon(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; delivererId: string; round: number },
): Promise<NotifyResult> {
  const d = await actorOf(deps, e.delivererId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'delivery_auto_approve_soon', deliverer: d.name },
    target: `/b/${e.bookingId}/delivery`,
    dedupeKey: `delivery_auto_soon_${e.bookingId}_${e.round}`,
    ...from(d),
  });
}

export async function notifyDeliveryExtraRound(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; delivererId: string; round: number; granted: boolean },
): Promise<NotifyResult> {
  const d = await actorOf(deps, e.delivererId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'delivery_extra_round', deliverer: d.name, granted: e.granted },
    target: `/b/${e.bookingId}/delivery`,
    dedupeKey: `delivery_extra_${e.bookingId}_${e.round}`,
    ...from(d),
  });
}

// ── #136 studio members and assignment ───────────────────────────────────────────────────────

export async function notifyStudioInvite(
  deps: NotifyDeps,
  e: { photographerId: string; studioId: string; inviteId: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'studio_invite', studio: s.name },
    target: '/me/studio',
    dedupeKey: `studio_invite_${e.inviteId}`,
    ...from(s),
  });
}

export async function notifyStudioJoinRequest(
  deps: NotifyDeps,
  e: { studioId: string; photographerId: string; requestId: string },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'studio_join_request', photographer: p.name },
    target: '/studio/members',
    dedupeKey: `studio_join_request_${e.requestId}`,
    ...from(p),
  });
}

export async function notifyStudioInviteAccepted(
  deps: NotifyDeps,
  e: { studioId: string; photographerId: string; inviteId: string },
): Promise<NotifyResult> {
  const p = await actorOf(deps, e.photographerId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'studio_invite_accepted', photographer: p.name },
    target: '/studio/members',
    dedupeKey: `studio_invite_accepted_${e.inviteId}`,
    ...from(p),
  });
}

export async function notifyStudioJoinApproved(
  deps: NotifyDeps,
  e: { photographerId: string; studioId: string; requestId: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'studio_join_approved', studio: s.name },
    target: '/me/studio',
    dedupeKey: `studio_join_approved_${e.requestId}`,
    ...from(s),
  });
}

export async function notifyStudioRemoved(
  deps: NotifyDeps,
  e: { photographerId: string; studioId: string; membershipId: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'studio_removed', studio: s.name },
    target: '/me/studio',
    dedupeKey: `studio_removed_${e.membershipId}`,
    ...from(s),
  });
}

export async function notifyStudioInviteExpiring(
  deps: NotifyDeps,
  e: { photographerId: string; studioId: string; inviteId: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.photographerId,
    content: { type: 'studio_invite_expiring', studio: s.name },
    target: '/me/studio',
    dedupeKey: `studio_invite_expiring_${e.inviteId}`,
    ...from(s),
  });
}

/**
 * To the customer and the assignee, each with their own copy (or only `recipients`); the studio is the actor.
 * `assignedAt` (S27) dates the key when the same assignee is put back after a collaborator offer had replaced
 * them, so that second notice is not taken for a retry of the first.
 */
export async function notifyBookingAssigned(
  deps: NotifyDeps,
  e: {
    bookingId: string;
    customerId: string;
    studioId: string;
    assigneeId: string;
    day: string;
    start: string;
    assignedAt?: string;
    recipients?: readonly ('customer' | 'assignee')[];
  },
): Promise<NotifyResult[]> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  const a = await actorOf(deps, e.assigneeId, PHOTOGRAPHER);
  const req = (userId: string, to: 'customer' | 'assignee'): NotifyRequest => ({
    userId,
    content: { type: 'booking_assigned', to, studio: s.name, assignee: a.name, day: e.day, start: e.start },
    target: `/b/${e.bookingId}`,
    dedupeKey: `booking_assigned_${e.bookingId}_${e.assigneeId}${e.assignedAt ? `_${e.assignedAt}` : ''}_${to}`,
    ...from(s),
  });
  const userOf = { customer: e.customerId, assignee: e.assigneeId } as const;
  const to = e.recipients ?? (['customer', 'assignee'] as const);
  return notifyAll(deps, to.map((t) => req(userOf[t], t)));
}

/**
 * To the customer, the old and the new assignee (or only `recipients`: S27 tells the old assignee when a
 * collaborator offer replaces them, and the customer and the collaborator once the offer is accepted). The
 * key holds the old → new pair, so a retry of the same pair is a duplicate; `reassignedAt` (the reassignment
 * instant, when the emitter passes it) tells a later A → B after B → A apart from a retry.
 */
export async function notifyBookingReassigned(
  deps: NotifyDeps,
  e: {
    bookingId: string;
    customerId: string;
    studioId: string;
    oldAssigneeId: string;
    newAssigneeId: string;
    day: string;
    start: string;
    reassignedAt?: string;
    recipients?: readonly ('customer' | 'old' | 'new')[];
  },
): Promise<NotifyResult[]> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  const a = await actorOf(deps, e.newAssigneeId, PHOTOGRAPHER);
  const req = (userId: string, to: 'customer' | 'old' | 'new'): NotifyRequest => ({
    userId,
    content: { type: 'booking_reassigned', to, studio: s.name, assignee: a.name, day: e.day, start: e.start },
    target: `/b/${e.bookingId}`,
    dedupeKey: `booking_reassigned_${e.bookingId}_${e.oldAssigneeId}_${e.newAssigneeId}${e.reassignedAt ? `_${e.reassignedAt}` : ''}_${to}`,
    ...from(s),
  });
  const userOf = { customer: e.customerId, old: e.oldAssigneeId, new: e.newAssigneeId } as const;
  const to = e.recipients ?? (['customer', 'old', 'new'] as const);
  return notifyAll(deps, to.map((t) => req(userOf[t], t)));
}

export async function notifyAssignReminder(
  deps: NotifyDeps,
  e: { bookingId: string; studioId: string; hours: 48 | 26; day: string; start: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'assign_reminder', hours: e.hours, day: e.day, start: e.start },
    target: `/b/${e.bookingId}`,
    dedupeKey: `assign_reminder_${e.bookingId}_${e.hours}`,
  });
}

/** Critical: the customer may now cancel with a 100% refund. */
export async function notifyAssignOverdue(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; studioId: string; day: string; start: string },
): Promise<NotifyResult[]> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  const req = (userId: string, to: 'customer' | 'studio', other: NotificationActor): NotifyRequest => ({
    userId,
    content: { type: 'assign_overdue', to, day: e.day, start: e.start },
    target: `/b/${e.bookingId}`,
    dedupeKey: `assign_overdue_${e.bookingId}_${to}`,
    ...from(other),
  });
  return notifyAll(deps, [req(e.customerId, 'customer', s), req(e.studioId, 'studio', c)]);
}

export async function notifyChangeRequested(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; studioId: string; day: string; respondBy: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'change_requested', customer: c.name, day: e.day, respondBy: e.respondBy },
    target: `/b/${e.bookingId}`,
    dedupeKey: `change_requested_${e.bookingId}`,
    ...from(c),
  });
}

export async function notifyChangeAnswered(
  deps: NotifyDeps,
  e: { bookingId: string; customerId: string; studioId: string; outcome: 'reassigned' | 'declined' | 'expired' },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.customerId,
    content: { type: 'change_answered', studio: s.name, outcome: e.outcome },
    target: `/b/${e.bookingId}`,
    dedupeKey: `change_answered_${e.bookingId}_${e.outcome}`,
    ...from(s),
  });
}

export async function notifyAssignmentReturned(
  deps: NotifyDeps,
  e: { bookingId: string; studioId: string; assigneeId: string; day: string; start: string },
): Promise<NotifyResult> {
  const a = await actorOf(deps, e.assigneeId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'assignment_returned', assignee: a.name, day: e.day, start: e.start },
    target: `/b/${e.bookingId}`,
    dedupeKey: `assignment_returned_${e.bookingId}_${e.assigneeId}`,
    ...from(a),
  });
}

// ── #134 payouts, #138 payout released ───────────────────────────────────────────────────────

export async function notifyPayoutAccountNeeded(
  deps: NotifyDeps,
  e: { payeeId: string; amount: number },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.payeeId,
    content: { type: 'payout_account_needed', amount: e.amount },
    target: '/work/earnings/account',
    dedupeKey: `payout_account_needed_${e.payeeId}`,
  });
}

/** Critical: `bank` is the catalogue short name (the code itself when unknown), the time Vietnam 'HH:mm dd/MM'. */
export async function notifyPayoutAccountChanged(
  deps: NotifyDeps,
  e: { uid: string; accountId: string; bankCode: string; accountLast4: string; activeFrom: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.uid,
    content: {
      type: 'payout_account_changed',
      bank: bankByCode(e.bankCode)?.shortName ?? e.bankCode,
      last4: e.accountLast4,
      activeFrom: vnTimeDay(e.activeFrom),
    },
    target: '/work/earnings/account',
    dedupeKey: `payout_account_changed_${e.accountId}`,
  });
}

/** Sent by `onPayoutWritten` when a payout becomes `paid` (S17 Decision 5). */
export async function notifyPayoutReleased(
  deps: NotifyDeps,
  e: { payoutId: string; payeeId: string; amount: number; count: number },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.payeeId,
    content: { type: 'payout_released', amount: e.amount, count: e.count },
    target: '/work/earnings',
    dedupeKey: `payout_released_${e.payoutId}`,
  });
}

// ── #135 verification ────────────────────────────────────────────────────────────────────────

export async function notifyVerificationDecision(
  deps: NotifyDeps,
  e: { uid: string; outcome: 'approved' | 'rejected' | 'revoked'; decidedAt: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.uid,
    content: { type: `verification_${e.outcome}` },
    target: '/verify/start',
    dedupeKey: `verification_${e.outcome}_${e.uid}_${e.decidedAt}`,
  });
}

export async function notifyBusinessDecision(
  deps: NotifyDeps,
  e: { uid: string; outcome: 'verified' | 'rejected'; decidedAt: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.uid,
    content: { type: `business_${e.outcome}` },
    target: '/verify/business',
    dedupeKey: `business_${e.outcome}_${e.uid}_${e.decidedAt}`,
  });
}

export async function notifyVerificationReminder(
  deps: NotifyDeps,
  e: { uid: string; stepsLeft: number; since: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.uid,
    content: { type: 'verification_reminder', stepsLeft: e.stepsLeft },
    target: '/verify/start',
    dedupeKey: `verification_reminder_${e.uid}_${e.since}`,
  });
}

// ── #142 disputes and support ────────────────────────────────────────────────────────────────

/** To the provider; null for a platform event (`providerId === 'platform'`, nobody to tell). */
export async function notifyDisputeOpened(
  deps: NotifyDeps,
  e: { disputeId: string; providerId: string; customerId: string; subject: string; ticket: boolean },
): Promise<NotifyResult | null> {
  if (e.providerId === 'platform') return null;
  const c = await actorOf(deps, e.customerId, CUSTOMER);
  return notify(deps, {
    userId: e.providerId,
    content: { type: 'dispute_opened', customer: c.name, subject: e.subject, ticket: e.ticket },
    target: `/disputes/${e.disputeId}`,
    dedupeKey: `dispute_opened:${e.disputeId}`,
    ...from(c),
  });
}

/** `providerName` is "ứng dụng" for a platform event (the emitter decides). */
export async function notifyDisputeResolved(
  deps: NotifyDeps,
  e: {
    disputeId: string;
    recipientIds: readonly string[];
    subject: string;
    kind: 'release' | 'refund' | 'split';
    providerName: string;
    refund: number;
    release: number;
  },
): Promise<NotifyResult[]> {
  return notifyAll(
    deps,
    e.recipientIds.map((userId) => ({
      userId,
      content: {
        type: 'dispute_resolved',
        subject: e.subject,
        kind: e.kind,
        provider: e.providerName,
        refund: e.refund,
        release: e.release,
      },
      target: `/disputes/${e.disputeId}`,
      dedupeKey: `dispute_resolved:${e.disputeId}`,
    })),
  );
}

/** Grouped per dispute, the sender as actor; `messageId`, when given, makes a retried message a duplicate. */
export async function notifyDisputeMessage(
  deps: NotifyDeps,
  e: { disputeId: string; recipientIds: readonly string[]; senderId: string; preview: string; messageId?: string },
): Promise<NotifyResult[]> {
  const s = await actorOf(deps, e.senderId, PARTY);
  return notifyAll(
    deps,
    e.recipientIds.map((userId) => ({
      userId,
      content: { type: 'dispute_message', sender: s.name, preview: e.preview, count: 1 },
      target: `/disputes/${e.disputeId}`,
      dedupeKey: `dispute_message:${e.disputeId}`,
      groupKey: `dispute:${e.disputeId}`,
      ...(e.messageId !== undefined ? { eventId: e.messageId } : {}),
      ...from(s),
    })),
  );
}

export async function notifySupportReply(
  deps: NotifyDeps,
  e: { threadId: string; disputeId: string | null; messageId: string; recipientIds: readonly string[]; preview: string },
): Promise<NotifyResult[]> {
  const target = e.disputeId !== null ? `/disputes/${e.disputeId}` : '/help/chat';
  return notifyAll(
    deps,
    e.recipientIds.map((userId) => ({
      userId,
      content: { type: 'support_reply', preview: e.preview },
      target,
      dedupeKey: `support_reply:${e.messageId}`,
    })),
  );
}

// ── #141 refund account ──────────────────────────────────────────────────────────────────────

export async function notifyRefundAccountNeeded(
  deps: NotifyDeps,
  e: { uid: string; refundId: string; amount: number; hasPayer: boolean },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.uid,
    content: { type: 'refund_account_needed', amount: e.amount, hasPayer: e.hasPayer },
    target: '/me/payments',
    dedupeKey: `refund_account_needed:${e.refundId}`,
  });
}

// ── #151 recruiting and collaborators ────────────────────────────────────────────────────────

export async function notifyRecruitPostNew(
  deps: NotifyDeps,
  e: { recipientId: string; studioId: string; postId: string; title: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.recipientId,
    content: { type: 'recruit_post_new', studio: s.name, title: e.title },
    target: `/recruit/${e.postId}`,
    dedupeKey: `recruit_post_new:${e.postId}`,
    ...from(s),
  });
}

/** Grouped per post: the studio's row counts applicants. */
export async function notifyRecruitApplicationNew(
  deps: NotifyDeps,
  e: { studioId: string; postId: string; title: string; applicantId: string },
): Promise<NotifyResult> {
  const a = await actorOf(deps, e.applicantId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'recruit_application_new', names: [a.name], title: e.title, count: 1 },
    target: `/studio/recruit?post=${e.postId}`,
    dedupeKey: `recruit_application_new:${e.postId}`,
    groupKey: `recruit:${e.postId}:apps`,
    eventId: e.applicantId,
    ...from(a),
  });
}

export async function notifyRecruitApplicationResult(
  deps: NotifyDeps,
  e: {
    applicantId: string;
    studioId: string;
    postId: string;
    title: string;
    outcome: 'collaborator' | 'member' | 'declined' | 'expired';
  },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.applicantId,
    content: { type: 'recruit_application_result', outcome: e.outcome, studio: s.name, title: e.title },
    target: `/recruit/${e.postId}`,
    dedupeKey: `recruit_application_result:${e.postId}:${e.outcome}`,
    ...from(s),
  });
}

export async function notifyCollabInvite(
  deps: NotifyDeps,
  e: { collaboratorId: string; studioId: string; invitedAt: string },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.collaboratorId,
    content: { type: 'collab_invite', studio: s.name },
    target: '/collab',
    dedupeKey: `collab_invite:${e.studioId}_${e.invitedAt}`,
    ...from(s),
  });
}

export async function notifyCollabInviteResult(
  deps: NotifyDeps,
  e: { studioId: string; collaboratorId: string; invitedAt: string; outcome: 'accepted' | 'declined' | 'expired' },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.collaboratorId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'collab_invite_result', outcome: e.outcome, name: c.name },
    target: '/collab',
    dedupeKey: `collab_invite_result:${e.collaboratorId}_${e.invitedAt}:${e.outcome}`,
    ...from(c),
  });
}

/** Critical: the offer is time-boxed. `offerAt` (ISO) keys each offer, so a new offer after a decline is sent again. */
export async function notifyCollabAssignmentOffer(
  deps: NotifyDeps,
  e: {
    collaboratorId: string;
    studioId: string;
    bookingId: string;
    offerAt: string;
    service: string;
    day: string;
    start: string;
    fee: number;
    deadline: string;
  },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.collaboratorId,
    content: {
      type: 'collab_assignment_offer',
      studio: s.name,
      service: e.service,
      day: e.day,
      start: e.start,
      fee: e.fee,
      deadline: e.deadline,
    },
    target: `/collab?offer=${e.bookingId}`,
    dedupeKey: `collab_assignment_offer:${e.bookingId}_${e.collaboratorId}_${e.offerAt}`,
    ...from(s),
  });
}

/** `offerAt` (ISO) of the answered offer keys the result; `ended`: the collaboration ended while the offer waited. */
export async function notifyCollabAssignmentResult(
  deps: NotifyDeps,
  e: {
    studioId: string;
    collaboratorId: string;
    bookingId: string;
    offerAt: string;
    outcome: 'accepted' | 'declined' | 'expired' | 'ended';
    service: string;
    day: string;
    start: string;
    deadline: string;
  },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.collaboratorId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: {
      type: 'collab_assignment_result',
      outcome: e.outcome,
      name: c.name,
      service: e.service,
      day: e.day,
      start: e.start,
      deadline: e.deadline,
    },
    target: `/b/${e.bookingId}`,
    dedupeKey: `collab_assignment_result:${e.bookingId}_${e.collaboratorId}_${e.offerAt}:${e.outcome}`,
    ...from(c),
  });
}

export async function notifyCollabPayDue(
  deps: NotifyDeps,
  e: { studioId: string; collaboratorId: string; bookingId: string; amount: number; service: string; day: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.collaboratorId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'collab_pay_due', name: c.name, amount: e.amount, service: e.service, day: e.day },
    target: '/collab',
    dedupeKey: `collab_pay_due:${e.bookingId}_${e.collaboratorId}`,
    ...from(c),
  });
}

/** `reportedAt` (ISO) keys each report, so a report after a dispute is sent again. */
export async function notifyCollabPayReported(
  deps: NotifyDeps,
  e: { collaboratorId: string; studioId: string; bookingId: string; reportedAt: string; amount: number; method: 'bank' | 'cash' | 'other' },
): Promise<NotifyResult> {
  const s = await actorOf(deps, e.studioId, STUDIO);
  return notify(deps, {
    userId: e.collaboratorId,
    content: { type: 'collab_pay_reported', studio: s.name, amount: e.amount, method: e.method },
    target: '/collab',
    dedupeKey: `collab_pay_reported:${e.bookingId}_${e.collaboratorId}_${e.reportedAt}`,
    ...from(s),
  });
}

/** `disputedAt` (ISO) keys each dispute, so a second "Chưa nhận" after a new report is sent again. */
export async function notifyCollabPayDisputed(
  deps: NotifyDeps,
  e: { studioId: string; collaboratorId: string; bookingId: string; disputedAt: string; amount: number; service: string; day: string },
): Promise<NotifyResult> {
  const c = await actorOf(deps, e.collaboratorId, PHOTOGRAPHER);
  return notify(deps, {
    userId: e.studioId,
    content: { type: 'collab_pay_disputed', name: c.name, amount: e.amount, service: e.service, day: e.day },
    target: '/collab',
    dedupeKey: `collab_pay_disputed:${e.bookingId}_${e.collaboratorId}_${e.disputedAt}`,
    ...from(c),
  });
}

// ── S30 organizers (#223) ───────────────────────────────────────────────────────────────────

/** An organizer as the actor: its own name and avatar (the organizer document), not the user profile's. */
const organizerActor = (e: { organizerId: string; organizerName: string; organizerAvatarUrl?: string | null }): NotificationActor => ({
  id: e.organizerId,
  name: e.organizerName,
  avatarUrl: e.organizerAvatarUrl ?? null,
});

/** Emitter: `reviewSpotClaim` (approve). Opens S30.03 of the spot. */
export async function notifySpotClaimApproved(
  deps: NotifyDeps,
  e: { organizerId: string; claimId: string; spotId: string; spotName: string },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.organizerId,
    content: { type: 'spot_claim_approved', spot: e.spotName },
    target: `/organizer/spots/${e.spotId}`,
    dedupeKey: `spot_claim_approved:${e.claimId}`,
  });
}

/**
 * Emitter: `reviewSpotClaim` (reject, or another claim of the spot approved: reason `spot_managed`).
 * Opens S30.02, which shows the rejected claim and "Gửi lại".
 */
export async function notifySpotClaimRejected(
  deps: NotifyDeps,
  e: { organizerId: string; claimId: string; spotName: string | null; reason: string | null },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.organizerId,
    content: { type: 'spot_claim_rejected', spot: e.spotName, reason: e.reason },
    target: '/organizer/spots/claim',
    dedupeKey: `spot_claim_rejected:${e.claimId}`,
  });
}

/** Emitter: `saveResident` when the provider is newly added (not on an edit). Opens the spot page (S29.02). */
export async function notifySpotResidentAdded(
  deps: NotifyDeps,
  e: { providerId: string; organizerId: string; organizerName: string; organizerAvatarUrl?: string | null; spotId: string; spotName: string; addedAt: string },
): Promise<NotifyResult> {
  const actor = organizerActor(e);
  return notify(deps, {
    userId: e.providerId,
    content: { type: 'spot_resident_added', organizer: actor.name, spot: e.spotName },
    target: `/spots/${e.spotId}`,
    dedupeKey: `spot_resident_added:${e.spotId}_${e.providerId}_${e.addedAt}`,
    ...from(actor),
  });
}

/** Emitter: `inviteGateStaff` (a new or renewed invite). Opens S30.06, where the invitee accepts or declines. */
export async function notifyGateStaffInvited(
  deps: NotifyDeps,
  e: { staffUid: string; organizerId: string; organizerName: string; organizerAvatarUrl?: string | null; invitedAt: string },
): Promise<NotifyResult> {
  const actor = organizerActor(e);
  return notify(deps, {
    userId: e.staffUid,
    content: { type: 'gate_staff_invited', organizer: actor.name },
    target: '/organizer/gate-staff',
    dedupeKey: `gate_staff_invited:${e.organizerId}_${e.staffUid}_${e.invitedAt}`,
    ...from(actor),
  });
}

/**
 * Emitter: `closeEntryDay` (S30), once per paid ticket of the closed day. Opens the event (S11.02),
 * whose tickets tab shows "Ngày đóng cửa · đang hoàn 100%".
 */
export async function notifyEntryDayClosed(
  deps: NotifyDeps,
  e: { userId: string; eventId: string; registrationId: string; spot: string; day: string; thumbUrl?: string | null },
): Promise<NotifyResult> {
  return notify(deps, {
    userId: e.userId,
    content: { type: 'entry_day_closed', spot: e.spot, day: e.day },
    target: `/e/${e.eventId}`,
    dedupeKey: `entry_day_closed:${e.eventId}_${e.day}_${e.registrationId}`,
    thumbUrl: e.thumbUrl ?? null,
  });
}
