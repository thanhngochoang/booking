import { HttpsError } from 'firebase-functions/v2/https';
import { sendSupportMessage, type SupportDeps } from '@photobooking/domain';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

export async function handleSendSupportMessage(
  request: CallableInput,
  deps: SupportDeps,
): Promise<{ threadId: string; messageId: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }

  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await sendSupportMessage(deps, uid, data);
  } catch (e) {
    handleCallableError('sendSupportMessage', e);
  }
}
