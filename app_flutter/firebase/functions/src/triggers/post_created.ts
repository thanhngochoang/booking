import * as logger from 'firebase-functions/logger';
import { appendNewPost, evaluateUserBadges, type AlbumDeps, type BadgeDeps } from '@photobooking/domain';

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
