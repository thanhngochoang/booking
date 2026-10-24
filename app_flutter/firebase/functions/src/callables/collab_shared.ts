/** Shared plumbing of the S27 callables (#151): caller check, refusal mapping, collab chat read-only window. */

import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { collabChatId, type RecruitDeps } from '@photobooking/domain';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

export type { CallableInput };

/** `FirestoreChatStore.setReadOnly`: the collab chat's read-only mark, written after a commit. */
export interface CollabChatWriter {
  setReadOnly(chatId: string, at: Date | null): Promise<boolean>;
}

export function requireUid(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  return uid;
}

/** Runs one use case and maps a refusal to its HttpsError (internal errors are logged as such). */
export async function run<T>(operation: string, fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    handleCallableError(operation, e);
  }
}

/**
 * After a commit that made the pair `active` (Decision 16): an existing collab chat that an earlier ended
 * collaboration left read-only becomes writable again. Re-reads the collaboration so a member-kind accept never
 * reopens it. A failure is logged, never thrown (the answer stands; `openCollabChat` also heals it).
 */
export async function reopenCollabChat(
  deps: RecruitDeps,
  chats: CollabChatWriter,
  studioId: string,
  collaboratorId: string,
): Promise<void> {
  try {
    const c = await deps.store.runTransaction((tx) => tx.getCollaboration(studioId, collaboratorId));
    if (c?.status === 'active') await chats.setReadOnly(collabChatId(studioId, collaboratorId), null);
  } catch (e) {
    logger.error('collab chat reopen failed', { error: e instanceof Error ? e.name : 'unknown' });
  }
}

/** After `endCollaboration` committed: the pair's chat is read-only from now (Decision 16); logged, never thrown. */
export async function closeCollabChat(chats: CollabChatWriter, chatId: string, at: Date): Promise<void> {
  try {
    await chats.setReadOnly(chatId, at);
  } catch (e) {
    logger.error('collab chat read-only mark failed', { error: e instanceof Error ? e.name : 'unknown' });
  }
}
