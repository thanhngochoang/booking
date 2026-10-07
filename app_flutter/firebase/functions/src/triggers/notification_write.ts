import { reconcileUnread, type NotifyDeps } from '@photobooking/domain';

type Row = { readAt?: unknown } | undefined;

/**
 * Recounts the unread rows of `uid` when a row write can change the count (created, deleted while
 * unread, or read/unread flipped). Count based, so retries and out-of-order events converge.
 */
export async function handleNotificationWrite(
  uid: string,
  before: Row,
  after: Row,
  deps: NotifyDeps,
): Promise<number | null> {
  const unread = (r: Row): boolean => r !== undefined && (r.readAt ?? null) === null;
  if (unread(before) === unread(after)) return null;
  return reconcileUnread(deps, uid);
}
