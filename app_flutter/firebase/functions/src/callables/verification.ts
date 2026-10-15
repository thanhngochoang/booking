import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  acceptVerificationRules,
  completeIdentityVerification,
  confirmPhoneVerified,
  lookupTaxCode,
  notifyVerificationChange,
  resubmitVerification,
  reviewVerification,
  startIdentityVerification,
  submitBusinessVerification,
  submitVerification,
  type NotifyDeps,
  type TaxCodeInfo,
  type VerificationChange,
  type VerificationDeps,
  type VerificationStatus,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';

/** The use cases' deps plus the notification deps the decision hooks (#138) are called with. */
export interface VerificationCallableDeps {
  readonly verification: VerificationDeps;
  readonly notify: NotifyDeps;
}

/** The part of a callable request the verification handlers use (a `CallableRequest` fits). */
export interface VerificationCallableInput {
  readonly auth?: { readonly uid: string; readonly token?: Readonly<Record<string, unknown>> } | undefined;
  readonly data: unknown;
}

function requireUid(request: VerificationCallableInput): string {
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
      logger.error(`${operation} failed`, { code: error.message, error: e instanceof Error ? e.name : 'unknown' });
    } else {
      logger.info(`${operation} refused`, { code: error.message });
    }
    throw error;
  }
}

/**
 * After the use case committed: the #138 hooks for whatever the change decided (Decision 22).
 * The state change already happened, so a failed notice is logged and never reaches the caller.
 */
export async function notifyAfterCommit(notify: NotifyDeps, change: VerificationChange, operation: string): Promise<void> {
  try {
    await notifyVerificationChange(notify, change);
  } catch (e) {
    logger.error(`${operation} notification failed`, { uid: change.after.uid, error: e instanceof Error ? e.name : 'unknown' });
  }
}

/** `{}` → `{phoneVerified: true}`: the Auth phone (OTP-linked in the app) matches the contact phone. */
export async function handleConfirmPhoneVerified(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ phoneVerified: true }> {
  const uid = requireUid(request);
  return run('confirmPhoneVerified', async () => {
    const change = await confirmPhoneVerified(deps.verification, uid);
    await notifyAfterCommit(deps.notify, change, 'confirmPhoneVerified');
    return { phoneVerified: true };
  });
}

/** `{method: 'vneid' | 'nfc'}` → `{sessionId, redirectUrl}`; `not_eligible` where no verifier is wired. */
export async function handleStartIdentityVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ sessionId: string; redirectUrl: string | null }> {
  const uid = requireUid(request);
  return run('startIdentityVerification', () => startIdentityVerification(deps.verification, uid, request.data));
}

/** `{sessionId}` → `{result: 'passed', maskedName}`; refusals `underage`, `identity_in_use`, `not_found`… */
export async function handleCompleteIdentityVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ result: 'passed'; maskedName: string }> {
  const uid = requireUid(request);
  return run('completeIdentityVerification', () => completeIdentityVerification(deps.verification, uid, request.data));
}

/** `{version}` → `{}` */
export async function handleAcceptVerificationRules(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<Record<string, never>> {
  const uid = requireUid(request);
  return run('acceptVerificationRules', async () => {
    const change = await acceptVerificationRules(deps.verification, uid, request.data);
    await notifyAfterCommit(deps.notify, change, 'acceptVerificationRules');
    return {};
  });
}

/** `{}` → `{status: 'submitted'}` */
export async function handleSubmitVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ status: 'submitted' }> {
  const uid = requireUid(request);
  return run('submitVerification', async () => {
    const change = await submitVerification(deps.verification, uid);
    await notifyAfterCommit(deps.notify, change, 'submitVerification');
    return { status: 'submitted' };
  });
}

/** `{}` → `{status: 'submitted' | 'in_progress'}` */
export async function handleResubmitVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ status: VerificationStatus }> {
  const uid = requireUid(request);
  return run('resubmitVerification', async () => {
    const change = await resubmitVerification(deps.verification, uid);
    await notifyAfterCommit(deps.notify, change, 'resubmitVerification');
    return { status: change.after.status };
  });
}

/** `{taxCode}` → `{name, address, status, kind}` (read only). */
export async function handleLookupTaxCode(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<TaxCodeInfo> {
  const uid = requireUid(request);
  return run('lookupTaxCode', async () => {
    const info = await lookupTaxCode(deps.verification, uid, request.data);
    return { name: info.name, address: info.address, status: info.status, kind: info.kind };
  });
}

/** `{taxCode, docPath?}` → `{status: 'approved' | 'submitted' | 'rejected'}` */
export async function handleSubmitBusinessVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ status: 'approved' | 'submitted' | 'rejected' }> {
  const uid = requireUid(request);
  return run('submitBusinessVerification', async () => {
    const change = await submitBusinessVerification(deps.verification, uid, request.data);
    await notifyAfterCommit(deps.notify, change, 'submitBusinessVerification');
    const status = change.after.business?.status;
    if (status === undefined) throw new Error('submitBusinessVerification left no business record');
    return { status };
  });
}

/** The status a staff decision answers with: the identity status, or the business sub-record's. */
export function reviewedStatusOf(change: VerificationChange, target: unknown): string {
  if (target === 'business') return change.after.business?.status ?? change.after.status;
  return change.after.status;
}

/** Staff only (custom claim `staffRole == 'admin'`): `{uid, target?, action, reason?, note?}` → `{status}` */
export async function handleReviewVerification(
  request: VerificationCallableInput,
  deps: VerificationCallableDeps,
): Promise<{ status: string }> {
  const uid = requireUid(request);
  const isAdmin = request.auth?.token?.staffRole === 'admin';
  return run('reviewVerification', async () => {
    const change = await reviewVerification(deps.verification, { uid, isAdmin }, request.data);
    await notifyAfterCommit(deps.notify, change, 'reviewVerification');
    const target = (request.data as { target?: unknown } | null)?.target;
    return { status: reviewedStatusOf(change, target) };
  });
}
