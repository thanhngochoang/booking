import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  getAccountDeletionBlockers,
  requestAccountDeletion,
  restoreAccount,
  requestDataExport,
  type AccountDeletionDeps,
  type DataExportDeps,
  type Blocker,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';

export interface AccountCallableInput {
  readonly auth?: {
    readonly uid: string;
    readonly token?: { readonly auth_time?: number | string };
  };
  readonly data: unknown;
}

function requireUid(request: AccountCallableInput): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

export async function handleGetAccountDeletionBlockers(
  request: AccountCallableInput,
  deps: AccountDeletionDeps,
): Promise<{ blockers: readonly Blocker[] }> {
  const uid = requireUid(request);
  try {
    return await getAccountDeletionBlockers(deps, { uid });
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('getAccountDeletionBlockers failed', { code: error.message });
    else logger.info('getAccountDeletionBlockers refused', { code: error.message });
    throw error;
  }
}

export async function handleRequestAccountDeletion(
  request: AccountCallableInput,
  deps: AccountDeletionDeps,
): Promise<{ status: 'deletion_pending'; restoreUntil: string }> {
  const uid = requireUid(request);
  const rawAuthTime = request.auth?.token?.auth_time;
  let authTime: Date | null = null;
  if (typeof rawAuthTime === 'number') {
    authTime = new Date(rawAuthTime * 1000);
  } else if (typeof rawAuthTime === 'string') {
    const parsed = Date.parse(rawAuthTime);
    if (!Number.isNaN(parsed)) authTime = new Date(parsed);
  }

  try {
    return await requestAccountDeletion(deps, { uid, authTime }, request.data);
  } catch (e: unknown) {
    const err = e as { code?: string };
    if (err?.code === 'conflict') {
      // Review Focus 3 & Plan table: conflict carries details.blockers kinds
      const blockers = (await getAccountDeletionBlockers(deps, { uid })).blockers;
      const kinds = blockers.map((b) => b.kind);
      throw new HttpsError('aborted', 'conflict', {
        code: 'conflict',
        blockers: kinds,
      });
    }
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('requestAccountDeletion failed', { code: error.message });
    else logger.info('requestAccountDeletion refused', { code: error.message });
    throw error;
  }
}

export async function handleRestoreAccount(
  request: AccountCallableInput,
  deps: AccountDeletionDeps,
): Promise<{ status: 'restored' }> {
  const uid = requireUid(request);
  try {
    return await restoreAccount(deps, { uid }, request.data);
  } catch (e: unknown) {
    const err = e as { code?: string };
    if (err?.code === 'deadline_passed') {
      throw new HttpsError('failed-precondition', 'deadline_passed', { code: 'deadline_passed' });
    }
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('restoreAccount failed', { code: error.message });
    else logger.info('restoreAccount refused', { code: error.message });
    throw error;
  }
}

export async function handleRequestDataExport(
  request: AccountCallableInput,
  deps: DataExportDeps,
): Promise<{ path: string; sizeBytes: number; expiresAt: string }> {
  const uid = requireUid(request);
  try {
    return await requestDataExport(deps, { uid }, request.data);
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('requestDataExport failed', { code: error.message });
    else logger.info('requestDataExport refused', { code: error.message });
    throw error;
  }
}
