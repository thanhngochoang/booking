// packages/domain/src/get_contact_link.ts
import {
  bookingContactUnlocked,
  contactUrlFor,
  parseContactLinkRequest,
  ticketContactUnlocked,
  type ContactSubject,
  type ExternalChannel,
} from './contact.js';
import { DomainError, type ErrorCode } from './errors.js';
import type {
  BookingReader,
  Clock,
  ContactAccessLogWriter,
  IdGenerator,
  PhotographerContactReader,
  RegistrationReader,
} from './ports.js';

export interface GetContactLinkDeps {
  readonly bookings: BookingReader;
  /** Absent until event registrations exist (events plan): registration requests are then `not_found`. */
  readonly registrations?: RegistrationReader;
  readonly photographers: PhotographerContactReader;
  readonly log: ContactAccessLogWriter;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

type Outcome = { readonly url: string } | { readonly error: ErrorCode };
type Party = { readonly photographerId: string } | { readonly error: ErrorCode };

/**
 * Use case `get_contact_link` (data-model README §5). Order of checks: request shape, caller is the
 * customer of the subject, contact unlocked, channel switched on and stored number valid.
 * Every well-formed request writes exactly one ContactAccessLog row (granted or not) before it is
 * answered; the number only ever leaves inside the returned URL.
 * Reads: the subject (1 document), then the photographer's flags and numbers (2 documents, 1 round trip).
 */
export async function getContactLink(
  requesterId: string,
  data: unknown,
  deps: GetContactLinkDeps,
): Promise<{ url: string }> {
  const { subject, channel } = parseContactLinkRequest(data);
  const at = deps.clock.now();
  const outcome = await decide(requesterId, subject, channel, at, deps);
  await deps.log.append({
    id: deps.ids.newId(),
    requesterId,
    subjectType: subject.type,
    subjectId: subject.id,
    channel,
    granted: 'url' in outcome,
    at,
  });
  if ('error' in outcome) throw new DomainError(outcome.error);
  return { url: outcome.url };
}

async function decide(
  requesterId: string,
  subject: ContactSubject,
  channel: ExternalChannel,
  now: Date,
  deps: GetContactLinkDeps,
): Promise<Outcome> {
  const party = await findParty(requesterId, subject, now, deps);
  if ('error' in party) return party;
  const { channels, numbers } = await deps.photographers.read(party.photographerId);
  if (channels === null || !channels[channel] || numbers === null) return { error: 'not_found' };
  const url = contactUrlFor(channel, numbers);
  return url === null ? { error: 'not_found' } : { url };
}

async function findParty(
  requesterId: string,
  subject: ContactSubject,
  now: Date,
  deps: GetContactLinkDeps,
): Promise<Party> {
  if (subject.type === 'booking') {
    const booking = await deps.bookings.get(subject.id);
    if (booking === null) return { error: 'not_found' };
    if (booking.customerId !== requesterId) return { error: 'permission_denied' };
    if (!bookingContactUnlocked(booking, now)) return { error: 'contact_locked' };
    return { photographerId: booking.photographerId };
  }
  const registration = deps.registrations ? await deps.registrations.get(subject.id) : null;
  if (registration === null || registration.photographerId === null) return { error: 'not_found' };
  if (registration.userId !== requesterId) return { error: 'permission_denied' };
  if (!ticketContactUnlocked(registration, now)) return { error: 'contact_locked' };
  return { photographerId: registration.photographerId };
}
