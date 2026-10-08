/** "blockerId blocked blockedId" is the document `blocks/{blockDocId(blockerId, blockedId)}`. */
export const blockDocId = (blockerId: string, blockedId: string): string => `${blockerId}_${blockedId}`;

/** Whether either user blocked the other. */
export interface BlockGate {
  isBlockedEitherWay(a: string, b: string): Promise<boolean>;
}
