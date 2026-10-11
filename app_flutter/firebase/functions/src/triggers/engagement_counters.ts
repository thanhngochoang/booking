import type { FollowerCounter, ApplyOutcome } from '../infra/follower_counter.js';

export interface FollowEventData {
  userId?: string;
  photographerId?: string;
}

export interface FollowWriteEvent {
  time: string;
  before: FollowEventData | null;
  after: FollowEventData | null;
}

export async function handleFollowWrite(
  event: FollowWriteEvent,
  counter: FollowerCounter,
): Promise<ApplyOutcome | 'ignored'> {
  const before = event.before;
  const after = event.after;

  // In-place update of same marker is ignored
  if (before && after && before.photographerId === after.photographerId && before.userId === after.userId) {
    return 'ignored';
  }

  const pid = after?.photographerId ?? before?.photographerId;
  if (!pid) {
    return 'ignored';
  }

  const recount = await counter.recount(pid);
  return counter.apply(pid, event.time, recount);
}
