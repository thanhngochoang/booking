import * as logger from 'firebase-functions/logger';
import { notifyRecruitMatches, type RecruitDeps } from '@photobooking/domain';
import { MAX_EVENT_AGE_MS } from './photographer_write.js';

/**
 * `recruitPosts/{postId}` created (#151 Decision 8): notify matching providers, at most 200 and 3 notices per
 * provider per VN day. The domain counts each post once per provider (`notices.postIds`), so a retried event
 * neither re-sends nor spends the cap again. An event older than 1 hour is dropped (deployed with retries).
 */
export async function handleRecruitPostCreated(
  event: { readonly postId: string; readonly time: string },
  deps: RecruitDeps,
  now: Date = new Date(),
  fanOut: typeof notifyRecruitMatches = notifyRecruitMatches,
): Promise<{ sent: number; capped: number } | 'expired'> {
  if (now.getTime() - Date.parse(event.time) > MAX_EVENT_AGE_MS) {
    logger.error('onRecruitPostCreated: event older than 1 hour dropped', { postId: event.postId });
    return 'expired';
  }
  const out = await fanOut(deps, event.postId);
  logger.info('onRecruitPostCreated', { postId: event.postId, ...out });
  return out;
}
