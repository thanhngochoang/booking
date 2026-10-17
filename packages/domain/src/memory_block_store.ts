import {
  EMPTY_BLOCK_INDEX,
  type BlockIndex,
  type BlockRecord,
} from './block.js';
import { blockDocId, type BlockGate, type BlockStore, type BlockTx } from './block_ports.js';

export class MemoryBlockStore implements BlockStore, BlockGate {
  readonly blocks = new Map<string, BlockRecord>(); // docId -> BlockRecord
  readonly indexes = new Map<string, BlockIndex>(); // uid -> BlockIndex
  readonly chats = new Map<string, { exists: boolean; blockedAt: string | null }>();
  readonly followMarkers = new Set<string>(); // e.g. "follows:a_b", "savedPhotographers:a_b"

  private lock: Promise<void> = Promise.resolve();

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const hasAB = this.blocks.has(blockDocId(a, b));
    const hasBA = this.blocks.has(blockDocId(b, a));
    return hasAB || hasBA;
  }

  async runTransaction<T>(fn: (tx: BlockTx) => Promise<T>): Promise<T> {
    const nextLock = this.lock.then(async () => {
      let hasWritten = false;
      const stagedPutBlocks = new Map<string, BlockRecord>();
      const stagedDeleteBlocks = new Set<string>();
      const stagedIndexes = new Map<string, BlockIndex>();
      const stagedChatBlockedAt = new Map<string, string | null>();
      const stagedDeleteMarkers = new Set<string>();

      const tx: BlockTx = {
        getBlock: async (blockerId: string, blockedId: string): Promise<BlockRecord | null> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const id = blockDocId(blockerId, blockedId);
          const b = this.blocks.get(id);
          return b ? { ...b } : null;
        },
        getIndex: async (uid: string): Promise<BlockIndex> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const idx = this.indexes.get(uid);
          return idx ? { blockedIds: [...idx.blockedIds], blockedByIds: [...idx.blockedByIds] } : EMPTY_BLOCK_INDEX;
        },
        chatExists: async (chatId: string): Promise<boolean> => {
          if (hasWritten) {
            throw new Error('Firestore transaction error: reads must come before writes');
          }
          const c = this.chats.get(chatId);
          return c?.exists ?? false;
        },
        putBlock: (b: BlockRecord): void => {
          hasWritten = true;
          const id = blockDocId(b.blockerId, b.blockedId);
          stagedPutBlocks.set(id, { ...b });
          stagedDeleteBlocks.delete(id);
        },
        deleteBlock: (blockerId: string, blockedId: string): void => {
          hasWritten = true;
          const id = blockDocId(blockerId, blockedId);
          stagedDeleteBlocks.add(id);
          stagedPutBlocks.delete(id);
        },
        putIndex: (uid: string, index: BlockIndex): void => {
          hasWritten = true;
          stagedIndexes.set(uid, {
            blockedIds: [...index.blockedIds],
            blockedByIds: [...index.blockedByIds],
          });
        },
        setChatBlockedAt: (chatId: string, at: string | null): void => {
          hasWritten = true;
          stagedChatBlockedAt.set(chatId, at);
        },
        deleteFollowMarkers: (a: string, b: string): void => {
          hasWritten = true;
          stagedDeleteMarkers.add(`follows:${a}_${b}`);
          stagedDeleteMarkers.add(`follows:${b}_${a}`);
          stagedDeleteMarkers.add(`savedPhotographers:${a}_${b}`);
          stagedDeleteMarkers.add(`savedPhotographers:${b}_${a}`);
        },
      };

      const result = await fn(tx);

      // Commit staged writes
      for (const [id, rec] of stagedPutBlocks) {
        this.blocks.set(id, rec);
      }
      for (const id of stagedDeleteBlocks) {
        this.blocks.delete(id);
      }
      for (const [uid, idx] of stagedIndexes) {
        this.indexes.set(uid, idx);
      }
      for (const [chatId, at] of stagedChatBlockedAt) {
        const c = this.chats.get(chatId) ?? { exists: true, blockedAt: null };
        this.chats.set(chatId, { exists: c.exists, blockedAt: at });
      }
      for (const marker of stagedDeleteMarkers) {
        this.followMarkers.delete(marker);
      }

      return result;
    });

    this.lock = nextLock.then(
      () => {},
      () => {},
    );
    return nextLock;
  }
}
