import { HttpsError } from 'firebase-functions/v2/https';
import {
  createJob,
  updateJob,
  extendJob,
  closeJob,
  inviteToJob,
  submitQuote,
  withdrawQuote,
  declineQuote,
  acceptQuote,
  openJobInquiry,
  type JobDeps,
  type BookingDeps,
  type ChatDeps,
  type BookingCheckout,
  type OpenJobInquiryInput,
} from '@photobooking/domain';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

function requireAuth(req: CallableInput): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

export async function handleCreateJob(
  req: CallableInput,
  deps: JobDeps,
): Promise<{ jobId: string; matched: number }> {
  const uid = requireAuth(req);
  try {
    return await createJob(deps, uid, req.data);
  } catch (e) {
    return handleCallableError('createJob', e);
  }
}

export async function handleUpdateJob(
  req: CallableInput,
  deps: JobDeps,
): Promise<{ jobId: string }> {
  const uid = requireAuth(req);
  try {
    return await updateJob(deps, uid, req.data);
  } catch (e) {
    return handleCallableError('updateJob', e);
  }
}

export async function handleExtendJob(
  req: CallableInput,
  deps: JobDeps,
): Promise<{ quoteDeadline: string }> {
  const uid = requireAuth(req);
  try {
    const res = await extendJob(deps, uid, req.data);
    return { quoteDeadline: res.quoteDeadline.toISOString() };
  } catch (e) {
    return handleCallableError('extendJob', e);
  }
}

export async function handleCloseJob(
  req: CallableInput,
  deps: JobDeps,
): Promise<Record<string, never>> {
  const uid = requireAuth(req);
  try {
    await closeJob(deps, uid, req.data);
    return {};
  } catch (e) {
    return handleCallableError('closeJob', e);
  }
}

export async function handleInviteToJob(
  req: CallableInput,
  deps: JobDeps,
): Promise<{ invited: string[] }> {
  const uid = requireAuth(req);
  try {
    return await inviteToJob(deps, uid, req.data);
  } catch (e) {
    return handleCallableError('inviteToJob', e);
  }
}

export async function handleSubmitQuote(
  req: CallableInput,
  deps: JobDeps,
): Promise<{ status: 'submitted'; fit: number }> {
  const uid = requireAuth(req);
  try {
    return await submitQuote(deps, uid, req.data);
  } catch (e) {
    return handleCallableError('submitQuote', e);
  }
}

export async function handleWithdrawQuote(
  req: CallableInput,
  deps: JobDeps,
): Promise<Record<string, never>> {
  const uid = requireAuth(req);
  try {
    await withdrawQuote(deps, uid, req.data);
    return {};
  } catch (e) {
    return handleCallableError('withdrawQuote', e);
  }
}

export async function handleDeclineQuote(
  req: CallableInput,
  deps: JobDeps,
): Promise<Record<string, never>> {
  const uid = requireAuth(req);
  try {
    await declineQuote(deps, uid, req.data);
    return {};
  } catch (e) {
    return handleCallableError('declineQuote', e);
  }
}

export async function handleAcceptQuote(
  req: CallableInput,
  deps: JobDeps,
  bookingDeps: BookingDeps,
): Promise<{ bookingId: string; paymentId: string; checkout: BookingCheckout }> {
  const uid = requireAuth(req);
  try {
    return await acceptQuote(deps, bookingDeps, uid, req.data);
  } catch (e) {
    return handleCallableError('acceptQuote', e);
  }
}

export async function handleOpenJobInquiry(
  req: CallableInput,
  chatDeps: ChatDeps,
  deps: JobDeps,
): Promise<{ chatId: string }> {
  const uid = requireAuth(req);
  try {
    return await openJobInquiry({ job: deps, chat: chatDeps }, uid, req.data as OpenJobInquiryInput);
  } catch (e) {
    return handleCallableError('openJobInquiry', e);
  }
}
