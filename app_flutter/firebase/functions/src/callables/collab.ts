/**
 * The 9 S27 collaboration callables (#151 Contract §Callables, S27.06–S27.07): thin wrappers that pass the
 * caller's uid as the right party. `assignBooking` with `assigneeKind: 'collaborator'` stays S26's callable
 * (`callables/studio.ts`), which hands the whole input to the domain.
 */

import {
  cancelCollabInvite,
  confirmCollabPay,
  endCollaboration,
  inviteCollaborator,
  openCollabChat,
  reportCollabPaid,
  respondCollabInvite,
  respondCollabOffer,
  setCollabDefaultFee,
  type CollabChatDeps,
  type RecruitDeps,
  type StudioBookingDeps,
} from '@photobooking/domain';
import {
  closeCollabChat,
  reopenCollabChat,
  requireUid,
  run,
  type CallableInput,
  type CollabChatWriter,
} from './collab_shared.js';

/** Studio: `{collaboratorId, defaultFee?}` → `{}` */
export async function handleInviteCollaborator(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('inviteCollaborator', async () => {
    await inviteCollaborator(deps, uid, request.data);
    return {};
  });
}

/** Studio: `{collaboratorId}` → `{}` */
export async function handleCancelCollabInvite(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('cancelCollabInvite', async () => {
    await cancelCollabInvite(deps, uid, request.data);
    return {};
  });
}

/** Invited photographer: `{studioId, accept, acceptTerms}` → `{status}`; acceptance reopens a read-only collab chat. */
export async function handleRespondCollabInvite(
  request: CallableInput,
  deps: RecruitDeps,
  chats: CollabChatWriter,
): Promise<{ status: 'active' | 'declined' }> {
  const uid = requireUid(request);
  const out = await run('respondCollabInvite', () => respondCollabInvite(deps, uid, request.data));
  const studioId = (request.data as { studioId?: unknown }).studioId;
  if (out.status === 'active' && typeof studioId === 'string') await reopenCollabChat(deps, chats, studioId, uid);
  return out;
}

/** Either side: `{studioId}` (collaborator) or `{collaboratorId}` (studio) → `{}`; the chat turns read-only. */
export async function handleEndCollaboration(
  request: CallableInput,
  deps: RecruitDeps,
  chats: CollabChatWriter,
): Promise<Record<string, never>> {
  const uid = requireUid(request);
  const { chatId } = await run('endCollaboration', () => endCollaboration(deps, uid, request.data));
  await closeCollabChat(chats, chatId, deps.clock.now());
  return {};
}

/** Studio: `{collaboratorId, defaultFee: number | null}` → `{}` */
export async function handleSetCollabDefaultFee(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('setCollabDefaultFee', async () => {
    await setCollabDefaultFee(deps, uid, request.data);
    return {};
  });
}

/** Collaborator (S27.07): `{bookingId, accept}` → `{offerStatus}` */
export async function handleRespondCollabOffer(
  request: CallableInput,
  deps: StudioBookingDeps,
): Promise<{ offerStatus: 'accepted' | 'declined' }> {
  const uid = requireUid(request);
  return run('respondCollabOffer', () => respondCollabOffer(deps, uid, request.data));
}

/** Studio "Đã trả": `{bookingId, collaboratorId, paidOn, method}` → `{}` */
export async function handleReportCollabPaid(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('reportCollabPaid', async () => {
    await reportCollabPaid(deps, uid, request.data);
    return {};
  });
}

/** Collaborator "Đã nhận" / "Chưa nhận": `{bookingId, received}` → `{payStatus}` */
export async function handleConfirmCollabPay(
  request: CallableInput,
  deps: RecruitDeps,
): Promise<{ payStatus: 'received' | 'disputed' }> {
  const uid = requireUid(request);
  return run('confirmCollabPay', () => confirmCollabPay(deps, uid, request.data));
}

/** S27.06 "Nhắn tin": `{studioId}` or `{collaboratorId}` → `{chatId}` */
export async function handleOpenCollabChat(request: CallableInput, deps: CollabChatDeps): Promise<{ chatId: string }> {
  const uid = requireUid(request);
  return run('openCollabChat', () => openCollabChat(deps, uid, request.data));
}
