/**
 * In-memory BlockGate for tests and emulators. Directed pairs, like the `blocks` documents:
 * `block(a, b)` means "a blocked b".
 */

import { blockDocId, type BlockGate } from './block_ports.js';

export class FakeBlockGate implements BlockGate {
  private readonly blocked = new Set<string>();
  private readonly seen: [string, string][] = [];

  constructor(pairs: Iterable<readonly [blockerId: string, blockedId: string]> = []) {
    for (const [blockerId, blockedId] of pairs) this.block(blockerId, blockedId);
  }

  block(blockerId: string, blockedId: string): void {
    this.blocked.add(blockDocId(blockerId, blockedId));
  }

  /** Removes only the "blockerId blocked blockedId" direction. */
  unblock(blockerId: string, blockedId: string): void {
    this.blocked.delete(blockDocId(blockerId, blockedId));
  }

  /** Every isBlockedEitherWay call as [a, b], in order. */
  get calls(): ReadonlyArray<readonly [string, string]> {
    return this.seen;
  }

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    this.seen.push([a, b]);
    return this.blocked.has(blockDocId(a, b)) || this.blocked.has(blockDocId(b, a));
  }
}
