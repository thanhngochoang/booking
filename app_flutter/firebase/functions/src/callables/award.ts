import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  createAward,
  deleteAward,
  reviewAward,
  updateAward,
  DomainError,
  type AwardDeps,
  type AwardStatus,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';

/** The part of a callable request the award handlers use (a `CallableRequest` fits). */
export interface AwardCallableInput {
  readonly auth?: { readonly uid: string; readonly token?: Readonly<Record<string, unknown>> } | undefined;
  readonly data: unknown;
}

function requireUid(request: AwardCallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

async function run<T>(operation: string, fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') {
      logger.error(`${operation} failed`, { code: error.message });
    } else {
      logger.info(`${operation} refused`, { code: error.message });
    }
    throw error;
  }
}

/** `{awardId, competition, year, category?, result, workPostId?, proofFiles?, proofLinks?}` → `{awardId}` */
export async function handleCreateAward(
  request: AwardCallableInput,
  deps: AwardDeps,
): Promise<{ awardId: string }> {
  const uid = requireUid(request);
  return run('createAward', async () => {
    // Only a photographer profile may claim awards.
    const profile = await deps.tiers.runTransaction((tx) => tx.getTierState(uid));
    if (profile === null) throw new DomainError('permission_denied');
    return createAward(deps, uid, request.data);
  });
}

/** Same fields as createAward → `{}` */
export async function handleUpdateAward(
  request: AwardCallableInput,
  deps: AwardDeps,
): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('updateAward', async () => {
    await updateAward(deps, uid, request.data);
    return {};
  });
}

/** `{awardId}` → `{}` */
export async function handleDeleteAward(
  request: AwardCallableInput,
  deps: AwardDeps,
): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('deleteAward', async () => {
    await deleteAward(deps, uid, request.data);
    return {};
  });
}

/** Staff only (custom claim `staffRole == 'admin'`): `{awardId, action, note?}` → `{status}` */
export async function handleReviewAward(
  request: AwardCallableInput,
  deps: AwardDeps,
): Promise<{ status: AwardStatus }> {
  const uid = requireUid(request);
  const isAdmin = request.auth?.token?.staffRole === 'admin';
  return run('reviewAward', () => reviewAward(deps, uid, isAdmin, request.data));
}
