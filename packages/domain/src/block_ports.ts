import type { BlockIndex, BlockRecord } from './block.js';
import type { Clock } from './ports.js';

/** "blockerId blocked blockedId" is the document `blocks/{blockDocId(blockerId, blockedId)}`. */
export const blockDocId = (blockerId: string, blockedId: string): string => `${blockerId}_${blockedId}`;

/** Whether either user blocked the other. */
export interface BlockGate {
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;
}

export interface BlockTx {
  getBlock(blockerId: string, blockedId: string): Promise<BlockRecord | null>;
  getIndex(uid: string): Promise<BlockIndex>; // EMPTY_BLOCK_INDEX when missing
  chatExists(chatId: string): Promise<boolean>;
  putBlock(b: BlockRecord): void;
  deleteBlock(blockerId: string, blockedId: string): void;
  putIndex(uid: string, index: BlockIndex, at: string): void;
  setChatBlockedAt(chatId: string, at: string | null): void;
  deleteFollowMarkers(a: string, b: string): void; // follows + savedPhotographers, both directions
}

export interface BlockStore {
  runTransaction<T>(fn: (tx: BlockTx) => Promise<T>): Promise<T>;
}

export interface PublicProfiles {
  get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>;
}

export interface BlockDeps {
  readonly store: BlockStore;
  readonly profiles: PublicProfiles;
  readonly clock: Clock;
}
