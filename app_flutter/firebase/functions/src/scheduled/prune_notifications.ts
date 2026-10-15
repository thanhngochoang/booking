import * as logger from 'firebase-functions/logger';
import { pruneReadNotifications, type NotifyDeps } from '@photobooking/domain';
import { liveNotifyDeps } from '../infra/live_notification.js';

/** Nightly (ruling R2): deletes read inbox rows older than 90 days; unread rows stay. */
export async function handlePruneNotifications(deps: NotifyDeps = liveNotifyDeps()): Promise<number> {
  try {
    const deleted = await pruneReadNotifications(deps);
    logger.info('pruneNotifications completed', { deleted });
    return deleted;
  } catch (e) {
    logger.error('pruneNotifications failed', { error: String(e) });
    throw e;
  }
}
