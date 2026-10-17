export const MAX_BLOCKS = 500;
export const BLOCK_SOURCES = ['menu', 'report'] as const;
export type BlockSource = (typeof BLOCK_SOURCES)[number];

export interface BlockRecord {
  readonly blockerId: string;
  readonly blockedId: string;
  readonly blockedName: string;
  readonly blockedAvatarUrl: string | null;
  readonly source: BlockSource;
  readonly createdAt: string;
}

export interface BlockIndex {
  readonly blockedIds: readonly string[];
  readonly blockedByIds: readonly string[];
}

export const EMPTY_BLOCK_INDEX: BlockIndex = {
  blockedIds: [],
  blockedByIds: [],
};

export function withBlock(
  index: BlockIndex,
  other: string,
  direction: 'blocked' | 'blockedBy',
): BlockIndex {
  if (direction === 'blocked') {
    if (index.blockedIds.includes(other)) return index;
    return {
      ...index,
      blockedIds: [...index.blockedIds, other],
    };
  }
  if (index.blockedByIds.includes(other)) return index;
  return {
    ...index,
    blockedByIds: [...index.blockedByIds, other],
  };
}

export function withoutBlock(
  index: BlockIndex,
  other: string,
  direction: 'blocked' | 'blockedBy',
): BlockIndex {
  if (direction === 'blocked') {
    if (!index.blockedIds.includes(other)) return index;
    return {
      ...index,
      blockedIds: index.blockedIds.filter((id) => id !== other),
    };
  }
  if (!index.blockedByIds.includes(other)) return index;
  return {
    ...index,
    blockedByIds: index.blockedByIds.filter((id) => id !== other),
  };
}

export function blockedEitherWay(index: BlockIndex, other: string): boolean {
  return index.blockedIds.includes(other) || index.blockedByIds.includes(other);
}
