/**
 * S30 entry-ticket and venue callables (#223, plan Task 6): `registerEntry` (S30.05), `closeEntryDay`
 * (S12.03-entry) and `respondVenueConsent` (S11.02-venue-consent). Thin adapters over the domain.
 */

import {
  closeEntryDay,
  registerEntry,
  respondVenueConsent,
  type EventDeps,
  type EventPaymentDeps,
  type NotifyDeps,
  type PaymentInstructions,
  type RegistrationStatus,
} from '@photobooking/domain';
import { eventCallerOf, runEventCallable, type EventCallableInput } from './event.js';

const dataOf = (request: EventCallableInput): unknown => request.data ?? {};

/**
 * `{eventId, visitDay, items: [{ticketTypeId, qty}], name, method}` → the registerEvent answer: a 15-minute hold
 * with the payment and its instructions.
 */
export async function handleRegisterEntry(
  request: EventCallableInput,
  deps: EventPaymentDeps,
): Promise<{
  registrationId: string;
  status: RegistrationStatus;
  paymentId: string | null;
  instructions: PaymentInstructions | null;
  holdExpiresAt: string | null;
}> {
  const caller = eventCallerOf(request);
  const r = await runEventCallable('registerEntry', () => registerEntry(deps, caller, dataOf(request)));
  return {
    registrationId: r.registrationId,
    status: r.status,
    paymentId: r.paymentId,
    instructions: r.instructions,
    holdExpiresAt: r.holdExpiresAt === null ? null : r.holdExpiresAt.toISOString(),
  };
}

/** `{eventId, day}` → `{refunded, left}`: the organizer closes a visit day (100% refunds; the rest by eventClock). */
export async function handleCloseEntryDay(
  request: EventCallableInput,
  deps: EventPaymentDeps & { readonly notify?: NotifyDeps },
): Promise<{ refunded: number; left: number }> {
  const caller = eventCallerOf(request);
  return runEventCallable('closeEntryDay', () => closeEntryDay(deps, caller, dataOf(request)));
}

/** `{eventId, accept, venueFeePerGuest?}` → `{}`: the spot's manager answers an event's venue request (72 h). */
export async function handleRespondVenueConsent(
  request: EventCallableInput,
  deps: EventDeps & { readonly notify?: NotifyDeps },
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('respondVenueConsent', () => respondVenueConsent(deps, caller, dataOf(request)));
  return {};
}
