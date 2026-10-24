/**
 * S27.06 "Nhắn tin": the studio ↔ collaborator chat (plan #151 Decision 16). Kind `collab`, id
 * `collab_{studioId}_{collaboratorId}`, the studio in the `customerId` slot and the collaborator in
 * `photographerId`, so `roleInChat`, `assertCanSend` and `sendMessage` work unchanged (no inquiry limit).
 * Created lazily while the collaboration is `active`; an `ended` one keeps the chat readable for 30 days.
 */

import type { Chat } from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import { DomainError } from './errors.js';
import type { RecruitStore } from './recruit_ports.js';
import { COLLAB_CHAT_READ_DAYS, collabPairOf, type Collaboration } from './studio_collaboration.js';

const DAY_MS = 24 * 60 * 60 * 1000;

export const collabChatId = (studioId: string, collaboratorId: string): string => `collab_${studioId}_${collaboratorId}`;

export type CollabChatDeps = ChatDeps & { readonly recruit: RecruitStore };

/** null = writable (active); a date = read-only since then (ended < 30 days); undefined = no chat allowed. */
function readOnlyAtOf(c: Collaboration | null, now: Date): Date | null | undefined {
  if (c === null) return undefined;
  if (c.status === 'active') return null;
  if (c.status === 'ended' && c.endedAt !== null && now.getTime() < c.endedAt.getTime() + COLLAB_CHAT_READ_DAYS * DAY_MS) {
    return c.endedAt;
  }
  return undefined;
}

/**
 * Opens (or returns) the pair's chat: `{collaboratorId}` from the studio, `{studioId}` from the collaborator.
 * `not_eligible` without an active collaboration (or one ended less than 30 days ago, returned read-only);
 * `blocked` when creating it between parties who blocked each other. Re-activation clears `readOnlyAt`.
 */
export async function openCollabChat(deps: CollabChatDeps, callerId: string, raw: unknown): Promise<{ chatId: string }> {
  const { studioId, collaboratorId } = collabPairOf(callerId, raw);
  const now = deps.clock.now();
  const collab = await deps.recruit.runTransaction((tx) => tx.getCollaboration(studioId, collaboratorId));
  const readOnlyAt = readOnlyAtOf(collab, now);
  if (readOnlyAt === undefined) throw new DomainError('not_eligible');
  const chatId = collabChatId(studioId, collaboratorId);

  return deps.chats.runTransaction(async (tx) => {
    const existing = await tx.getChat(chatId);
    if (existing) {
      // active → writable again; ended → read-only from endedAt if the post-commit step never ran.
      if (readOnlyAt === null ? existing.readOnlyAt !== null : existing.readOnlyAt === null) {
        tx.setChat({ ...existing, readOnlyAt, updatedAt: now });
      }
      return { chatId };
    }
    if (await deps.blocks.isBlockedEitherWay(studioId, collaboratorId)) throw new DomainError('blocked');
    const chat: Chat = {
      id: chatId,
      kind: 'collab',
      customerId: studioId,
      photographerId: collaboratorId,
      assigneeId: null,
      bookingId: null,
      bookingStatus: null,
      photographerRepliedAt: null,
      customerMessagesBeforeReply: 0,
      lastMessageAt: null,
      lastMessagePreview: null,
      lastSenderId: null,
      readOnlyAt,
      blockedAt: null,
      rescheduleUsed: false,
      createdAt: now,
      updatedAt: now,
    };
    tx.setChat(chat);
    tx.incrementUnread(chatId, studioId, 0);
    tx.incrementUnread(chatId, collaboratorId, 0);
    return { chatId };
  });
}
