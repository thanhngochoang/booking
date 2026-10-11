import type { DocumentData } from 'firebase-admin/firestore';
import {
  refreshEngagementCount,
  type EngagementKind,
  type DiscoveryDeps,
  type RefreshOutcome,
} from '@photobooking/domain';

export async function handleEngagementWrite(
  kind: EngagementKind,
  before: DocumentData | undefined,
  after: DocumentData | undefined,
  deps: DiscoveryDeps,
): Promise<RefreshOutcome | 'skipped'> {
  // Only recount on create (before undefined, after exists) or delete (before exists, after undefined)
  const isCreated = before === undefined && after !== undefined;
  const isDeleted = before !== undefined && after === undefined;

  if (!isCreated && !isDeleted) {
    return 'skipped';
  }

  const postId = after?.postId ?? before?.postId;
  if (typeof postId !== 'string' || postId.length === 0) {
    return 'skipped';
  }

  return refreshEngagementCount(deps, kind, postId);
}
