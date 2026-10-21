import * as logger from 'firebase-functions/logger';
import {
  startDueAccountPurges,
  type AccountDeletionDeps,
} from '@photobooking/domain';
import { liveAccountDeletionDeps } from '../infra/account_firestore.js';

export async function handleStartDueAccountPurges(
  deps: AccountDeletionDeps = liveAccountDeletionDeps(),
  now: Date = new Date(),
  limit: number = 50,
): Promise<number> {
  try {
    const started = await startDueAccountPurges(deps, now, limit);
    logger.info('startDueAccountPurges completed', { started });
    return started;
  } catch (e) {
    logger.error('startDueAccountPurges failed', { error: String(e) });
    throw e;
  }
}
