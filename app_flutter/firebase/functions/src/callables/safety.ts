import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  blockUser,
  unblockUser,
  submitReport,
  type BlockDeps,
  type ReportDeps,
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

export async function handleBlockUser(
  request: CallableInput,
  deps: BlockDeps,
): Promise<{ blockedId: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const res = await blockUser(deps, uid, request.data);
    return { blockedId: res.blockedId };
  } catch (e) {
    handleCallableError('blockUser', e);
  }
}

export async function handleUnblockUser(
  request: CallableInput,
  deps: BlockDeps,
): Promise<Record<string, never>> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    await unblockUser(deps, uid, request.data);
    return {};
  } catch (e) {
    handleCallableError('unblockUser', e);
  }
}

export async function handleSubmitReport(
  request: CallableInput,
  deps: ReportDeps,
): Promise<{ reportId: string; duplicate: boolean; blocked: boolean }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    return await submitReport(deps, uid, request.data);
  } catch (e) {
    handleCallableError('submitReport', e);
  }
}
