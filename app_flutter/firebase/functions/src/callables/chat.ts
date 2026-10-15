import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  openInquiry,
  sendMessage,
  proposeReschedule,
  answerReschedule,
  type BookingStore,
  type ChatDeps,
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

export async function handleOpenInquiry(
  request: CallableInput,
  deps: ChatDeps,
): Promise<{ chatId: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<
      string,
      unknown
    >;
    const photographerId = String(data.photographerId ?? '');
    const res = await openInquiry(deps, { customerId: uid, photographerId });
    return { chatId: res.chatId };
  } catch (e) {
    handleCallableError('openInquiry', e);
  }
}

export async function handleSendMessage(
  request: CallableInput,
  deps: ChatDeps,
): Promise<{ id: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<
      string,
      unknown
    >;
    const chatId = String(data.chatId ?? '');
    const message = data.message;
    const res = await sendMessage(deps, { senderId: uid, chatId, message });
    return { id: res.id };
  } catch (e) {
    handleCallableError('sendMessage', e);
  }
}

export async function handleProposeReschedule(
  request: CallableInput,
  deps: ChatDeps & { bookings: BookingStore },
): Promise<{ id: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<
      string,
      unknown
    >;
    const bookingId = String(data.bookingId ?? '');
    const day = String(data.day ?? '');
    const start = String(data.start ?? '');
    const clientId = String(data.clientId ?? '');
    const res = await proposeReschedule(deps, {
      actorId: uid,
      bookingId,
      day,
      start,
      clientId,
    });
    return { id: res.id };
  } catch (e) {
    handleCallableError('proposeReschedule', e);
  }
}

export async function handleAnswerReschedule(
  request: CallableInput,
  deps: ChatDeps & { bookings: BookingStore },
): Promise<{ answer: 'accepted' | 'declined' }> {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  try {
    const data = (request.data && typeof request.data === 'object' ? request.data : {}) as Record<
      string,
      unknown
    >;
    const chatId = String(data.chatId ?? '');
    const messageId = String(data.messageId ?? '');
    const accept = Boolean(data.accept);
    return await answerReschedule(deps, {
      actorId: uid,
      chatId,
      messageId,
      accept,
    });
  } catch (e) {
    handleCallableError('answerReschedule', e);
  }
}
