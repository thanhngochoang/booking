import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { markAllRead, type NotifyDeps } from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

/** `{}` → `{marked}`: every unread row of the caller gets `readAt`, and the count is reconciled. */
export async function handleMarkAllNotificationsRead(
  request: CallableInput,
  deps: NotifyDeps,
): Promise<{ marked: number }> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    return { marked: await markAllRead(deps, uid) };
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('markAllNotificationsRead failed', { uid });
    throw error;
  }
}
