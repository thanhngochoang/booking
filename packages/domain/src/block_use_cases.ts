import {
  blockedEitherWay,
  MAX_BLOCKS,
  withBlock,
  withoutBlock,
  type BlockRecord,
  type BlockSource,
} from './block.js';
import type { BlockDeps } from './block_ports.js';
import { chatIdFor } from './chat.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export function parseBlockInput(
  raw: unknown,
  callerId: string,
): { userId: string; source: BlockSource } {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const userId = r.userId;
  if (!isId(userId) || userId === callerId) {
    throw new DomainError('invalid_argument');
  }
  const sourceRaw = r.source ?? 'menu';
  if (sourceRaw !== 'menu' && sourceRaw !== 'report') {
    throw new DomainError('invalid_argument');
  }
  return { userId, source: sourceRaw };
}

export function parseUnblockInput(
  raw: unknown,
  callerId: string,
): { userId: string } {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const userId = r.userId;
  if (!isId(userId) || userId === callerId) {
    throw new DomainError('invalid_argument');
  }
  return { userId };
}

/** `{userId, source?}`; idempotent; throws invalid_argument (self/malformed), not_found, limit_exceeded. */
export async function blockUser(
  deps: BlockDeps,
  callerId: string,
  raw: unknown,
): Promise<BlockRecord> {
  const { userId, source } = parseBlockInput(raw, callerId);
  const profile = await deps.profiles.get(userId);
  if (!profile) throw new DomainError('not_found');
  const at = deps.clock.now().toISOString();

  return deps.store.runTransaction(async (tx) => {
    const existing = await tx.getBlock(callerId, userId);
    const mine = await tx.getIndex(callerId);
    const theirs = await tx.getIndex(userId);
    const chats = [chatIdFor(callerId, userId), chatIdFor(userId, callerId)];
    const exists = await Promise.all(chats.map((c) => tx.chatExists(c)));

    if (existing) return existing;
    if (mine.blockedIds.length >= MAX_BLOCKS) throw new DomainError('limit_exceeded');

    const rec: BlockRecord = {
      blockerId: callerId,
      blockedId: userId,
      blockedName: profile.name,
      blockedAvatarUrl: profile.avatarUrl,
      source,
      createdAt: at,
    };

    tx.putBlock(rec);
    tx.putIndex(callerId, withBlock(mine, userId, 'blocked'), at);
    tx.putIndex(userId, withBlock(theirs, callerId, 'blockedBy'), at);
    chats.forEach((c, i) => {
      if (exists[i]) tx.setChatBlockedAt(c, at);
    });
    tx.deleteFollowMarkers(callerId, userId);
    return rec;
  });
}

/** `{userId}`; a missing block is a no-op. Clears chat blockedAt only when no block remains either way. */
export async function unblockUser(
  deps: BlockDeps,
  callerId: string,
  raw: unknown,
): Promise<void> {
  const { userId } = parseUnblockInput(raw, callerId);
  const at = deps.clock.now().toISOString();

  return deps.store.runTransaction(async (tx) => {
    // 1. ALL READS FIRST
    const existing = await tx.getBlock(callerId, userId);
    if (!existing) return;

    const mine = await tx.getIndex(callerId);
    const theirs = await tx.getIndex(userId);
    const chats = [chatIdFor(callerId, userId), chatIdFor(userId, callerId)];
    const exists = await Promise.all(chats.map((c) => tx.chatExists(c)));

    // 2. ALL WRITES AFTER
    const nextMine = withoutBlock(mine, userId, 'blocked');
    const nextTheirs = withoutBlock(theirs, callerId, 'blockedBy');

    tx.deleteBlock(callerId, userId);
    tx.putIndex(callerId, nextMine, at);
    tx.putIndex(userId, nextTheirs, at);

    // Mutual block: check if any block remains either way between callerId and userId
    const stillBlocked = blockedEitherWay(nextMine, userId);
    if (!stillBlocked) {
      chats.forEach((c, i) => {
        if (exists[i]) tx.setChatBlockedAt(c, null);
      });
    }
  });
}
