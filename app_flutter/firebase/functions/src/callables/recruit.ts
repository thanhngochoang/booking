/**
 * The 7 S27 recruit callables (#151 Contract §Callables, S27.01–S27.05): thin wrappers that pass the caller's
 * uid to the domain and map a refusal to its HttpsError (`details.code`, `details.field`). Notifications are
 * sent by the domain after its commit.
 */

import {
  applyToRecruitPost,
  closeRecruitPost,
  createRecruitPost,
  renewRecruitPost,
  respondRecruitApplication,
  updateRecruitPost,
  withdrawRecruitApplication,
  type RecruitDeps,
} from '@photobooking/domain';
import { reopenCollabChat, requireUid, run, type CollabChatWriter, type CallableInput } from './collab_shared.js';

/** `{kind, title, specialties, areas, frequency, feeHint, requirements}` → `{postId}` */
export async function handleCreateRecruitPost(request: CallableInput, deps: RecruitDeps): Promise<{ postId: string }> {
  const uid = requireUid(request);
  return run('createRecruitPost', () => createRecruitPost(deps, uid, request.data));
}

/** `{postId, title, specialties, areas, frequency, feeHint, requirements}` → `{}` */
export async function handleUpdateRecruitPost(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('updateRecruitPost', async () => {
    await updateRecruitPost(deps, uid, request.data);
    return {};
  });
}

/** `{postId}` → `{}`; the post's `applied` applications are declined. */
export async function handleCloseRecruitPost(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('closeRecruitPost', async () => {
    await closeRecruitPost(deps, uid, request.data);
    return {};
  });
}

/** `{postId}` → `{expiresAt}` (ISO instant). */
export async function handleRenewRecruitPost(request: CallableInput, deps: RecruitDeps): Promise<{ expiresAt: string }> {
  const uid = requireUid(request);
  return run('renewRecruitPost', async () => {
    const { expiresAt } = await renewRecruitPost(deps, uid, request.data);
    return { expiresAt: expiresAt.toISOString() };
  });
}

/** `{postId, message, samplePostIds, acceptTerms}` → `{applicationId}` */
export async function handleApplyToRecruitPost(request: CallableInput, deps: RecruitDeps): Promise<{ applicationId: string }> {
  const uid = requireUid(request);
  return run('applyToRecruitPost', () => applyToRecruitPost(deps, uid, request.data));
}

/** `{postId}` → `{}` */
export async function handleWithdrawRecruitApplication(request: CallableInput, deps: RecruitDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('withdrawRecruitApplication', async () => {
    await withdrawRecruitApplication(deps, uid, request.data);
    return {};
  });
}

/**
 * `{postId, applicantId, accept}` → `{status}`. Accepting a collaborator application activates the pair; a collab
 * chat left read-only by an earlier collaboration becomes writable again after the commit (Decision 16).
 */
export async function handleRespondRecruitApplication(
  request: CallableInput,
  deps: RecruitDeps,
  chats: CollabChatWriter,
): Promise<{ status: 'accepted' | 'declined' }> {
  const uid = requireUid(request);
  const out = await run('respondRecruitApplication', () => respondRecruitApplication(deps, uid, request.data));
  const applicantId = (request.data as { applicantId?: unknown }).applicantId;
  if (out.status === 'accepted' && typeof applicantId === 'string') {
    await reopenCollabChat(deps, chats, uid, applicantId);
  }
  return out;
}
