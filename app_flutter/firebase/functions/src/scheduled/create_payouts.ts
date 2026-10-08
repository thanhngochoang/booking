import * as logger from 'firebase-functions/logger';
import { runDailyPayouts, type DailyPayoutReport, type PayoutDeps } from '@photobooking/domain';
import { PAYOUT_ACCOUNT_KEY, payoutsMode } from '../config.js';
import { errorCodeOf, livePayoutDeps, payoutGateway } from '../infra/live_payout.js';

/**
 * `createPayouts` (daily 10:00 Asia/Ho_Chi_Minh; payments spec M5 "chi tự động mỗi ngày"): batches
 * each due payee's released money into a payout and sends every `pending` one, through the domain's
 * `runDailyPayouts`. Only the fake gateway exists (owner ruling 2): in `off` mode the job logs and
 * returns null without reading anything or touching the key. Logs the report counts and, per
 * failed item, its id (payee or payout), step and error code; never a number, a name or a message.
 */
export async function handleCreatePayouts(
  deps?: PayoutDeps,
  mode: 'fake' | 'off' = payoutsMode(),
): Promise<DailyPayoutReport | null> {
  if (mode === 'off') {
    logger.info('createPayouts skipped', { mode });
    return null;
  }
  const live = deps ?? livePayoutDeps(PAYOUT_ACCOUNT_KEY.value(), payoutGateway(mode));
  let report: DailyPayoutReport;
  try {
    report = await runDailyPayouts(live, (id, step, e) => {
      logger.error('createPayouts item failed', { id, step, code: errorCodeOf(e) });
    });
  } catch (e) {
    logger.error('createPayouts failed', { code: errorCodeOf(e) });
    throw e;
  }
  logger.info('createPayouts', report);
  return report;
}
