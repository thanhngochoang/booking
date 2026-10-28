import { HttpsError } from 'firebase-functions/v2/https';
import {
  submitDelivery,
  approveDelivery,
  cancelLateDelivery,
  requestRevision,
  answerExtraRound,
  type BookingDeps,
} from '@photobooking/domain';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

export async function handleSubmitDelivery(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ round: number }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    return await submitDelivery(deps, uid, data);
  } catch (e) {
    handleCallableError('submitDelivery', e);
  }
}

export async function handleApproveDelivery(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ status: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    const bookingId = String(data.bookingId ?? '');
    const booking = await approveDelivery(deps, { bookingId, actorId: uid });
    return { status: booking.status };
  } catch (e) {
    handleCallableError('approveDelivery', e);
  }
}

export async function handleCancelLateDelivery(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ status: string; refundedAmount: number }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    const bookingId = String(data.bookingId ?? '');
    const booking = await cancelLateDelivery(deps, { bookingId, customerId: uid });
    return {
      status: booking.status,
      refundedAmount: booking.deliveryCancel?.refundedAmount ?? 0,
    };
  } catch (e) {
    handleCallableError('cancelLateDelivery', e);
  }
}

export async function handleRequestRevision(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ status: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    const booking = await requestRevision(deps, uid, data);
    return { status: booking.status };
  } catch (e) {
    handleCallableError('requestRevision', e);
  }
}

export async function handleAnswerExtraRound(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ status: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;
    const bookingId = String(data.bookingId ?? '');
    const grant = Boolean(data.grant);
    const booking = await answerExtraRound(deps, uid, { bookingId, grant });
    return { status: booking.status };
  } catch (e) {
    handleCallableError('answerExtraRound', e);
  }
}
