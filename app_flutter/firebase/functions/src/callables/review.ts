import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { submitReview, type ReviewDeps } from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

function errorKind(e: unknown): { name?: string; errorCode?: string | number } {
  if (typeof e !== 'object' || e === null) return {};
  const { name, code } = e as { name?: unknown; code?: unknown };
  return {
    ...(typeof name === 'string' ? { name } : {}),
    ...(typeof code === 'string' || typeof code === 'number' ? { errorCode: code } : {}),
  };
}

function handleCallableError(operation: string, e: unknown): never {
  const error = toHttpsError(e);
  if (error.code === 'internal') {
    logger.error(`${operation} failed`, { code: error.message, ...errorKind(e) });
  } else {
    logger.info(`${operation} refused`, { code: error.message });
  }
  throw error;
}

export async function handleSubmitReview(
  request: CallableInput,
  deps: ReviewDeps
): Promise<{ postId: string | null }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', {
      code: 'permission_denied',
    });
  }

  try {
    const res = await submitReview(deps, uid, request.data);
    return { postId: res.postId };
  } catch (e) {
    handleCallableError('submitReview', e);
  }
}
