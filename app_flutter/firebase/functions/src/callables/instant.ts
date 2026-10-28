/**
 * Chụp ngay callables (plan #140 Contract "Callables"): thin wrappers over the domain use cases.
 * Unauthenticated → `unauthenticated` with `details.code = permission_denied`; domain refusals keep
 * their code in `details.code` (and `details.field` when present) through `toHttpsError`.
 */
import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  answerInstantOffer,
  cancelInstantRequest,
  checkInstantPayment,
  confirmInstantComplete,
  createInstantRequest,
  inviteInstant,
  nextInstantCandidates,
  saveInstantSettings,
  setLiveShutter,
  tickInstantRequest,
  updateInstantJob,
  type InstantCaller,
  type InstantDeps,
  type InviteResult,
  type SettlementDeps,
} from '@photobooking/domain';
import { checkoutGatewayAvailable } from '../infra/fake_payments.js';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

export type InstantCallableInput = CallableInput;

/** The signed-in caller, else `unauthenticated` (`permission_denied`). */
export function instantCallerOf(request: InstantCallableInput): InstantCaller {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  return { uid };
}

async function run<T>(operation: string, request: InstantCallableInput, fn: (caller: InstantCaller) => Promise<T>): Promise<T> {
  const caller = instantCallerOf(request);
  try {
    return await fn(caller);
  } catch (e) {
    const error = toHttpsError(e);
    // Codes only: never the payload (positions, notes) or the error's message.
    if (error.code === 'internal') logger.error(`${operation} failed`, { code: error.message, kind: e instanceof Error ? e.name : typeof e });
    else logger.info(`${operation} refused`, { code: error.message });
    throw error;
  }
}

export async function handleCreateInstantRequest(request: InstantCallableInput, deps: InstantDeps) {
  return run('createInstantRequest', request, (c) => createInstantRequest(deps, c, request.data));
}

export async function handleNextInstantCandidates(request: InstantCallableInput, deps: InstantDeps) {
  return run('nextInstantCandidates', request, (c) => nextInstantCandidates(deps, c, request.data));
}

/**
 * The first invite opens a payment (#202, Decision 5): where no checkout gateway is available
 * (V1's `checkoutGatewayAvailable`, today the fake rails' dev project and `demo-*` emulators only),
 * payments are off and every invite is `not_eligible`, like `createPayment` and the S21 fee.
 */
export async function handleInviteInstant(
  request: InstantCallableInput,
  deps: InstantDeps,
  env: NodeJS.ProcessEnv = process.env,
): Promise<InviteResult> {
  return run('inviteInstant', request, (c) => {
    if (!checkoutGatewayAvailable(env)) throw new HttpsError('failed-precondition', 'not_eligible', { code: 'not_eligible' });
    return inviteInstant(deps, c, request.data);
  });
}

/** S04.04 on resume (payer only): V1's `checkSubjectPayments` over the request's open payments. */
export async function handleCheckInstantPayment(
  request: InstantCallableInput,
  deps: InstantDeps & { readonly settlement: SettlementDeps },
) {
  return run('checkInstantPayment', request, (c) => checkInstantPayment(deps, c, request.data));
}

export async function handleCancelInstantRequest(request: InstantCallableInput, deps: InstantDeps) {
  return run('cancelInstantRequest', request, (c) => cancelInstantRequest(deps, c, request.data));
}

export async function handleConfirmInstantComplete(request: InstantCallableInput, deps: InstantDeps) {
  return run('confirmInstantComplete', request, (c) => confirmInstantComplete(deps, c, request.data));
}

export async function handleTickInstantRequest(request: InstantCallableInput, deps: InstantDeps) {
  return run('tickInstantRequest', request, (c) => tickInstantRequest(deps, c, request.data));
}

export async function handleSetLiveShutter(request: InstantCallableInput, deps: InstantDeps) {
  return run('setLiveShutter', request, (c) => setLiveShutter(deps, c, request.data));
}

export async function handleSaveInstantSettings(request: InstantCallableInput, deps: InstantDeps) {
  return run('saveInstantSettings', request, (c) => saveInstantSettings(deps, c, request.data));
}

export async function handleAnswerInstantOffer(request: InstantCallableInput, deps: InstantDeps) {
  return run('answerInstantOffer', request, (c) => answerInstantOffer(deps, c, request.data));
}

export async function handleUpdateInstantJob(request: InstantCallableInput, deps: InstantDeps) {
  return run('updateInstantJob', request, (c) => updateInstantJob(deps, c, request.data));
}
