import * as logger from 'firebase-functions/logger';
import { pruneReadNotifications, type NotifyDeps } from '@photobooking/domain';
import { liveNotifyDeps } from '../infra/live_notification.js';
import { pruneDataExports } from './prune_data_exports.js';
import { handleStartDueAccountPurges } from './start_account_purges.js';
import { bucket } from '../infra/admin.js';

/** Nightly (ruling R2): deletes read inbox rows older than 90 days; unread rows stay. */
export async function handlePruneNotifications(deps: NotifyDeps = liveNotifyDeps()): Promise<number> {
  try {
    const deleted = await pruneReadNotifications(deps);
    logger.info('pruneNotifications completed', { deleted });

    // Named step: startDueAccountPurges
    try {
      await handleStartDueAccountPurges();
    } catch (e) {
      logger.error('step startDueAccountPurges failed inside pruneNotifications', { error: String(e) });
    }

    // Named step: pruneDataExports
    try {
      await pruneDataExports(bucket());
    } catch (e) {
      logger.error('step pruneDataExports failed inside pruneNotifications', { error: String(e) });
    }

    return deleted;
  } catch (e) {
    logger.error('pruneNotifications failed', { error: String(e) });
    throw e;
  }
}
