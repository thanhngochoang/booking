import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  cancelEvent,
  cancelRegistration,
  checkInRegistration,
  publishEvent,
  registerEvent,
  respondToHostConsent,
  saveEventDraft,
  updateEvent,
  type EventCaller,
  type EventDeps,
  type RegisterResult,
  type RegistrationStatus,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';

/** The part of a callable request the event handlers use (a `CallableRequest` fits). */
export interface EventCallableInput {
  readonly auth?: { readonly uid: string; readonly token?: Readonly<Record<string, unknown>> } | undefined;
  readonly data: unknown;
}

/** Event deps plus the side effect that tells a photographer staff named them as host (O1). */
export type EventCallableDeps = EventDeps & {
  notifyHostInvited?: (hostId: string, eventId: string, title: string, expiresAt: Date) => Promise<void>;
};

/** `uid` from the token, `staffRole` from the custom claim; any other claim value is ignored. */
export function eventCallerOf(request: EventCallableInput): EventCaller {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  const role = request.auth?.token?.staffRole;
  return { uid, staffRole: role === 'admin' || role === 'sales' ? role : null };
}

export async function runEventCallable<T>(operation: string, fn: () => Promise<T>): Promise<T> {
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

const dataOf = (request: EventCallableInput): unknown => request.data ?? {};

/** `{eventId?, …fields, hostPhotographerId?}` → `{eventId, hashtag}` */
export async function handleSaveEventDraft(
  request: EventCallableInput,
  deps: EventCallableDeps,
): Promise<{ eventId: string; hashtag: string }> {
  const caller = eventCallerOf(request);
  const result = await runEventCallable('saveEventDraft', () => saveEventDraft(deps, caller, dataOf(request)));
  await tellHostInvited(deps, caller, result.eventId);
  return result;
}

/** O1: a staff draft that names a photographer sends that photographer one inbox/push message. */
async function tellHostInvited(deps: EventCallableDeps, caller: EventCaller, eventId: string): Promise<void> {
  if (caller.staffRole === null || deps.notifyHostInvited === undefined) return;
  try {
    const ev = await deps.events.runTransaction((tx) => tx.getEvent(eventId));
    if (ev === null || ev.status !== 'draft' || ev.hostConsent !== 'pending' || ev.host.id === null
      || ev.hostConsentExpiresAt === null) return;
    // A fresh 24 h window (first invitation, or staff changed an accepted draft) is a new notice.
    await deps.notifyHostInvited(ev.host.id, ev.id, ev.title, ev.hostConsentExpiresAt);
  } catch (e) {
    // The draft is saved; a missed notice only means the 24 h window runs without a nudge.
    logger.warn('event host invitation notice failed', { error: e instanceof Error ? e.name : 'unknown' });
  }
}

/** `{eventId}` → `{}` */
export async function handlePublishEvent(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('publishEvent', () => publishEvent(deps, caller, dataOf(request)));
  return {};
}

/** `{eventId, …fields}` → `{}` */
export async function handleUpdateEvent(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('updateEvent', () => updateEvent(deps, caller, dataOf(request)));
  return {};
}

/** `{eventId}` → `{paidRegistrationIds}` (refunds of paid tickets arrive with the paid path) */
export async function handleCancelEvent(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<{ paidRegistrationIds: string[] }> {
  const caller = eventCallerOf(request);
  return runEventCallable('cancelEvent', () => cancelEvent(deps, caller, dataOf(request)));
}

/** `{eventId, accept}` → `{}`; the hosting photographer only (checked in the domain). */
export async function handleRespondToHostConsent(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('respondToHostConsent', () => respondToHostConsent(deps, caller, dataOf(request)));
  return {};
}

/** `{eventId, quantity, name}` → `{registrationId, status, paymentId, payUrl, holdExpiresAt}` */
export async function handleRegisterEvent(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<{
  registrationId: string;
  status: RegistrationStatus;
  paymentId: string | null;
  payUrl: string | null;
  holdExpiresAt: string | null;
}> {
  const caller = eventCallerOf(request);
  const r: RegisterResult = await runEventCallable('registerEvent', () => registerEvent(deps, caller, dataOf(request)));
  return {
    registrationId: r.registrationId,
    status: r.status,
    paymentId: r.paymentId,
    payUrl: r.payUrl,
    holdExpiresAt: r.holdExpiresAt === null ? null : r.holdExpiresAt.toISOString(),
  };
}

/** `{eventId, registrationId}` → `{status, refundPercent}` */
export async function handleCancelRegistration(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<{ status: RegistrationStatus; refundPercent: number | null }> {
  const caller = eventCallerOf(request);
  return runEventCallable('cancelRegistration', () => cancelRegistration(deps, caller, dataOf(request)));
}

/** `{eventId, ticketCode}` → `{name, quantity}` */
export async function handleCheckInRegistration(
  request: EventCallableInput,
  deps: EventDeps,
): Promise<{ name: string; quantity: number }> {
  const caller = eventCallerOf(request);
  return runEventCallable('checkInRegistration', () => checkInRegistration(deps, caller, dataOf(request)));
}
