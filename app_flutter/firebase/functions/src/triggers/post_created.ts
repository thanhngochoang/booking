import * as logger from 'firebase-functions/logger';
import { appendNewPost, type AlbumDeps } from '@photobooking/domain';

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
