import type { Change } from 'firebase-functions/v2';
import type { DocumentSnapshot } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { purgeAccount, type PurgeDeps, livePurgeDeps } from '../infra/account_purge.js';

export async function handleAccountDeletionUpdated(
  change: Change<DocumentSnapshot>,
  deps: PurgeDeps = livePurgeDeps(),
): Promise<void> {
  const before = change.before.data();
  const after = change.after.data();

  // Runs only when status becomes 'purging'
  if (before?.status === 'purging' || after?.status !== 'purging') {
    return;
  }

  const uid = change.after.id;
  logger.info(`Starting account purge for uid=${uid}`);

  try {
    const outcome = await purgeAccount(uid, deps);
    logger.info(`Account purge finished for uid=${uid} outcome=${outcome}`);
  } catch (e) {
    logger.error(`Account purge failed for uid=${uid}`, { error: String(e) });
    throw e;
  }
}
