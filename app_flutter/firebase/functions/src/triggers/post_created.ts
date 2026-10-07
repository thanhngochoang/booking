import * as logger from 'firebase-functions/logger';
import {
  appendNewPost,
  evaluateUserBadges,
  linkEventPosts,
  type AlbumDeps,
  type BadgeDeps,
  type TimelineDeps,
} from '@photobooking/domain';

/**
 * A new post that names an album lands last in it (plan C Decision 2). The use case is idempotent
 * (a post that already has `albumPosition` is skipped), so a retried event never counts twice.
 */
export async function handlePostCreated(
  postId: string,
  deps: AlbumDeps,
): Promise<'appended' | 'skipped' | 'detached'> {
  const outcome = await appendNewPost(deps, postId);
  if (outcome !== 'skipped') logger.info('onPostCreated', { postId, outcome });
  return outcome;
}

/** A new post can complete `complete_profile` or `sharer`: evaluate its author. */
export async function evaluatePostAuthor(authorId: unknown, deps: BadgeDeps): Promise<boolean> {
  if (typeof authorId !== 'string' || authorId === '') return false;
  await evaluateUserBadges(deps, authorId);
  return true;
}

/** A post with hashtags, or one that names an event, may belong on an event timeline. */
export function mayLinkEventPosts(hashtags: unknown, eventId: unknown): boolean {
  return (Array.isArray(hashtags) && hashtags.length > 0) || (typeof eventId === 'string' && eventId !== '');
}

/** Puts the post on the timeline of every open event whose hashtag it carries; idempotent. */
export async function handleLinkEventPosts(postId: string, deps: TimelineDeps): Promise<string[]> {
  const { linked } = await linkEventPosts(deps, postId);
  if (linked.length > 0) logger.info('onPostCreated timeline', { postId, events: linked.length });
  return linked;
}
