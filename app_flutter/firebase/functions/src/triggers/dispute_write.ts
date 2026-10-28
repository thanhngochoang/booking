import { notifyDisputeChange, type NotifyDeps } from '@photobooking/domain';
import type { DocumentData } from 'firebase-admin/firestore';
import { disputeFromFirestore } from '../infra/dispute_mapping.js';

/**
 * `onDisputeWrite` (S18, #142 Decision 11): maps both sides of a `disputes/{id}` write and lets the
 * domain decide (`notifyDisputeChange`: created open → the provider, open → resolved → both parties,
 * anything else, a delete included → nobody). #138's hooks own the copy and the dedupe keys, so a
 * replayed event writes no second row.
 */
export async function handleDisputeWrite(
  before: DocumentData | undefined,
  after: DocumentData | undefined,
  deps: NotifyDeps,
): Promise<void> {
  await notifyDisputeChange(deps, disputeFromFirestore(before), disputeFromFirestore(after));
}
