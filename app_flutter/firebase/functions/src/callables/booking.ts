import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  createBookingDraft,
  transitionBooking,
  type Booking,
  type BookingDeps,
  type TransitionAction,
} from '@photobooking/domain';
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

/** Logs a refusal by its code only (an unexpected failure by its error kind) and throws the HttpsError. */
export function handleCallableError(operation: string, e: unknown): never {
  const error = toHttpsError(e);
  if (error.code === 'internal') {
    logger.error(`${operation} failed`, { code: error.message, ...errorKind(e) });
  } else {
    logger.info(`${operation} refused`, { code: error.message });
  }
  throw error;
}

export async function handleCreateBooking(request: CallableInput, deps: BookingDeps): Promise<Booking> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await createBookingDraft(deps, { ...data, customerId: uid });
  } catch (e) {
    handleCallableError('createBooking', e);
  }
}

export async function handleTransitionBooking(request: CallableInput, deps: BookingDeps): Promise<Booking> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await transitionBooking(deps, {
      bookingId: String(data.bookingId ?? ''),
      action: data.action as TransitionAction,
      actorId: uid,
      reason: typeof data.reason === 'string' ? data.reason : undefined,
    });
  } catch (e) {
    handleCallableError('transitionBooking', e);
  }
}
