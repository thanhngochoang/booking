/**
 * The 14 S26 callables (#136 Contract §Callables): thin wrappers that pass the caller's uid as the right party.
 * Membership callables send #138's notices after the commit (logged, never thrown, Decision 23).
 */

import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import type { Firestore } from 'firebase-admin/firestore';
import {
  assignBooking,
  assignmentOptions,
  cancelInvite,
  cancelJoinRequest,
  declineAssigneeChange,
  inviteMember,
  leaveStudio,
  membershipNotices,
  notifyStudioInvite,
  notifyStudioInviteAccepted,
  notifyStudioJoinApproved,
  notifyStudioJoinRequest,
  notifyStudioRemoved,
  removeMember,
  requestAssigneeChange,
  requestToJoin,
  respondInvite,
  respondJoinRequest,
  returnAssignment,
  type AssignmentOption,
  type Booking,
  type Clock,
  type MemberDayReader,
  type NotifyDeps,
  type RelationChange,
  type RelationStatus,
  type StudioBookingDeps,
  type StudioDeps,
} from '@photobooking/domain';
import { searchInviteCandidates, type InviteCandidateRow } from '../infra/studio_firestore.js';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

function requireUid(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  return uid;
}

/** Runs one use case for the signed-in caller and maps a refusal to its HttpsError. */
async function run<T>(operation: string, request: CallableInput, fn: (uid: string) => Promise<T>): Promise<T> {
  const uid = requireUid(request);
  try {
    return await fn(uid);
  } catch (e) {
    handleCallableError(operation, e);
  }
}

/** Calls the #138 hook of each notice of a committed relation change; a failure is logged, never thrown. */
export async function sendMembershipNotices(notify: NotifyDeps, change: RelationChange): Promise<void> {
  const r = change.after;
  const jobs = membershipNotices(change).map((n) => {
    switch (n) {
      case 'invite':
        return notifyStudioInvite(notify, { photographerId: r.memberId, studioId: r.studioId, inviteId: r.id });
      case 'join_request':
        return notifyStudioJoinRequest(notify, { studioId: r.studioId, photographerId: r.memberId, requestId: r.id });
      case 'invite_accepted':
        return notifyStudioInviteAccepted(notify, { studioId: r.studioId, photographerId: r.memberId, inviteId: r.id });
      case 'join_approved':
        return notifyStudioJoinApproved(notify, { photographerId: r.memberId, studioId: r.studioId, requestId: r.id });
      case 'removed':
        return notifyStudioRemoved(notify, { photographerId: r.memberId, studioId: r.studioId, membershipId: r.id });
    }
  });
  const results = await Promise.allSettled(jobs);
  for (const failed of results.filter((x): x is PromiseRejectedResult => x.status === 'rejected')) {
    logger.error('studio membership notice failed', { relationId: r.id, error: String(failed.reason) });
  }
}

async function membership(
  operation: string,
  request: CallableInput,
  notify: NotifyDeps | undefined,
  fn: (uid: string) => Promise<RelationChange>,
): Promise<RelationChange> {
  const change = await run(operation, request, fn);
  if (notify) await sendMembershipNotices(notify, change);
  return change;
}

// ── membership ──

export async function handleInviteMember(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<{ relationId: string }> {
  const c = await membership('inviteMember', request, notify, (uid) => inviteMember(deps, uid, request.data));
  return { relationId: c.after.id };
}

export async function handleCancelInvite(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<Record<string, never>> {
  await membership('cancelInvite', request, notify, (uid) => cancelInvite(deps, uid, request.data));
  return {};
}

export async function handleRequestToJoin(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<{ relationId: string }> {
  const c = await membership('requestToJoin', request, notify, (uid) => requestToJoin(deps, uid, request.data));
  return { relationId: c.after.id };
}

export async function handleCancelJoinRequest(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<Record<string, never>> {
  await membership('cancelJoinRequest', request, notify, (uid) => cancelJoinRequest(deps, uid, request.data));
  return {};
}

export async function handleRespondInvite(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<{ status: RelationStatus }> {
  const c = await membership('respondInvite', request, notify, (uid) => respondInvite(deps, uid, request.data));
  return { status: c.after.status };
}

export async function handleRespondJoinRequest(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<{ status: RelationStatus }> {
  const c = await membership('respondJoinRequest', request, notify, (uid) =>
    respondJoinRequest(deps, uid, request.data),
  );
  return { status: c.after.status };
}

export async function handleLeaveStudio(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<Record<string, never>> {
  await membership('leaveStudio', request, notify, (uid) => leaveStudio(deps, uid));
  return {};
}

export async function handleRemoveMember(
  request: CallableInput,
  deps: StudioDeps,
  notify?: NotifyDeps,
): Promise<Record<string, never>> {
  await membership('removeMember', request, notify, (uid) => removeMember(deps, uid, request.data));
  return {};
}

// ── invite search (S26.02) ──

export async function handleSearchPhotographersToInvite(
  request: CallableInput,
  deps: { readonly firestore: Firestore; readonly clock: Clock },
): Promise<{ rows: InviteCandidateRow[] }> {
  const data = request.data && typeof request.data === 'object' ? (request.data as Record<string, unknown>) : {};
  return run('searchPhotographersToInvite', request, async (uid) => ({
    rows: await searchInviteCandidates(deps.firestore, uid, data.query, deps.clock.now()),
  }));
}

// ── assignment (S26.04, S26.05, "Trả việc") ──

export async function handleAssignmentOptions(
  request: CallableInput,
  deps: StudioBookingDeps & { readonly availability: MemberDayReader },
): Promise<{ deadline: string | null; options: AssignmentOption[] }> {
  return run('assignmentOptions', request, async (uid) => {
    const options = await assignmentOptions(deps, uid, request.data);
    // The domain checked the booking and the caller; the deadline is shown above the list.
    const bookingId = String((request.data as Record<string, unknown>).bookingId);
    const booking = await deps.store.getBooking(bookingId);
    return { deadline: booking?.assignDeadline ?? null, options };
  });
}

export function handleAssignBooking(request: CallableInput, deps: StudioBookingDeps): Promise<Booking> {
  return run('assignBooking', request, (uid) => assignBooking(deps, uid, request.data));
}

export function handleRequestAssigneeChange(request: CallableInput, deps: StudioBookingDeps): Promise<Booking> {
  return run('requestAssigneeChange', request, (uid) => requestAssigneeChange(deps, uid, request.data));
}

export function handleDeclineAssigneeChange(request: CallableInput, deps: StudioBookingDeps): Promise<Booking> {
  return run('declineAssigneeChange', request, (uid) => declineAssigneeChange(deps, uid, request.data));
}

export function handleReturnAssignment(request: CallableInput, deps: StudioBookingDeps): Promise<Booking> {
  return run('returnAssignment', request, (uid) => returnAssignment(deps, uid, request.data));
}
