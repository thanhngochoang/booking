import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { getContactLink, type GetContactLinkDeps } from '@photobooking/domain';
import { toHttpsError } from './errors.js';

/** The part of a callable request the handler uses (a `CallableRequest` fits). */
export interface CallableInput {
  readonly auth?: { readonly uid: string } | undefined;
  readonly data: unknown;
}

/**
 * Callable `getContactLink` (contract: plan 2b "Out of scope"): `{bookingId | registrationId, channel}`
 * → `{url}`. Errors carry `details.code`: `contact_locked`, `permission_denied`, `not_found`,
 * `invalid_argument`.
 */
export async function handleGetContactLink(request: CallableInput, deps: GetContactLinkDeps): Promise<{ url: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    return await getContactLink(uid, request.data, deps);
  } catch (e) {
    const error = toHttpsError(e);
    // Codes only: never the request, the URL, a number or the error's message/data.
    if (error.code === 'internal') {
      logger.error('getContactLink failed', { code: error.message, ...errorKind(e) });
    } else {
      logger.info('getContactLink refused', { code: error.message });
    }
    throw error;
  }
}

/** `name` and `code` of an unexpected error, for diagnosis; nothing that could carry data. */
function errorKind(e: unknown): { name?: string; errorCode?: string | number } {
  if (typeof e !== 'object' || e === null) return {};
  const { name, code } = e as { name?: unknown; code?: unknown };
  return {
    ...(typeof name === 'string' ? { name } : {}),
    ...(typeof code === 'string' || typeof code === 'number' ? { errorCode: code } : {}),
  };
}
