/**
 * Firestore implementations of the safety ports (blocks). `blocks/{blockerId}_{blockedId}` exists
 * exactly when the blocker blocked the other person; only the Admin SDK writes it.
 */

import type { Firestore } from 'firebase-admin/firestore';
import { blockDocId, type BlockGate } from '@photobooking/domain';
import { db } from './admin.js';

/**
 * True when either direction's block document exists. One `getAll` of both paths and no cache:
 * a block has to apply to the very next order.
 */
export class FirestoreBlockGate implements BlockGate {
  constructor(private readonly firestore: Firestore = db()) {}

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const snaps = await this.firestore.getAll(
      this.firestore.doc(`blocks/${blockDocId(a, b)}`),
      this.firestore.doc(`blocks/${blockDocId(b, a)}`),
    );
    return snaps.some((s) => s.exists);
  }
}
