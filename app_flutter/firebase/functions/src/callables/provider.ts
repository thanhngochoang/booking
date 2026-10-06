import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  setProviderType,
  setStudioAddress,
  type ProviderDeps,
  type ProviderType,
  type StudioAddress,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

function handleCallableError(operation: string, e: unknown): never {
  const error = toHttpsError(e);
  if (error.code === 'internal') {
    logger.error(`${operation} failed`, { code: error.message });
  } else {
    logger.info(`${operation} refused`, { code: error.message });
  }
  throw error;
}

function requireUid(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

export async function handleSetProviderType(
  request: CallableInput,
  deps: ProviderDeps,
): Promise<{ providerType: ProviderType }> {
  const uid = requireUid(request);
  try {
    return await setProviderType(deps, uid, request.data);
  } catch (e) {
    handleCallableError('setProviderType', e);
  }
}

export async function handleSetStudioAddress(
  request: CallableInput,
  deps: ProviderDeps,
): Promise<StudioAddress> {
  const uid = requireUid(request);
  try {
    return await setStudioAddress(deps, uid, request.data);
  } catch (e) {
    handleCallableError('setStudioAddress', e);
  }
}
