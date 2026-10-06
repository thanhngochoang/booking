import * as logger from 'firebase-functions/logger';
import { reconcileBadges, type BadgeDeps } from '@photobooking/domain';
import { liveBadgeDeps } from '../infra/live_badge.js';

/** Nightly: syncs the catalogue docs and re-evaluates `new_member` holders past their 30 days. */
export async function handleReconcileBadges(
  deps: BadgeDeps = liveBadgeDeps(),
): Promise<{ catalogWrites: number; reevaluated: number }> {
  try {
    const r = await reconcileBadges(deps);
    logger.info('reconcileBadges completed', r);
    return r;
  } catch (e) {
    logger.error('reconcileBadges failed', { error: String(e) });
    throw e;
  }
}
