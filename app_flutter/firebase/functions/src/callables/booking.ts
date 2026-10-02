import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  createBookingDraft,
  createDeposit,
  confirmFakePayment,
  checkDeposit,
  transitionBooking,
  openDispute,
  type Booking,
  type BookingDeps,
  type CreateDepositResult,
  type HandlePaymentResult,
  type PaymentProvider,
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

function handleCallableError(operation: string, e: unknown): never {
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

export async function handleCreateDeposit(request: CallableInput, deps: BookingDeps): Promise<CreateDepositResult> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await createDeposit(deps, {
      bookingId: String(data.bookingId ?? ''),
      customerId: uid,
      provider: (data.provider ?? 'fake') as PaymentProvider,
      returnUrl: typeof data.returnUrl === 'string' ? data.returnUrl : undefined,
    });
  } catch (e) {
    handleCallableError('createDeposit', e);
  }
}

export async function handleConfirmFakePayment(request: CallableInput, deps: BookingDeps): Promise<HandlePaymentResult> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await confirmFakePayment(deps, {
      paymentId: String(data.paymentId ?? ''),
      customerId: uid,
    });
  } catch (e) {
    handleCallableError('confirmFakePayment', e);
  }
}

export async function handleCheckDeposit(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ paid: boolean; booking: Booking | null }> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await checkDeposit(deps, {
      bookingId: String(data.bookingId ?? ''),
      customerId: uid,
    });
  } catch (e) {
    handleCallableError('checkDeposit', e);
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

export async function handleOpenDispute(request: CallableInput, deps: BookingDeps): Promise<Booking> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await openDispute(deps, {
      bookingId: String(data.bookingId ?? ''),
      customerId: uid,
      reason: String(data.reason ?? ''),
    });
  } catch (e) {
    handleCallableError('openDispute', e);
  }
}
