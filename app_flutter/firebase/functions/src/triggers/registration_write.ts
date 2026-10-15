import * as logger from 'firebase-functions/logger';
import { syncEventChatMembership, type EventChatDeps } from '@photobooking/domain';
import type { DocumentData } from 'firebase-admin/firestore';
import { registrationFromFirestore } from '../infra/event_firestore.js';

/**
 * A registration write keeps the event group chat's membership in step. The change is only a
 * wake-up: the domain derives membership inside its transaction from the user's `paid`
 * registrations now (I1), so late, repeated or out-of-order deliveries are safe.
 */
export async function handleRegistrationWrite(
  input: { eventId: string; regId: string; before: DocumentData | undefined; after: DocumentData | undefined },
  deps: EventChatDeps,
): Promise<'joined' | 'left' | 'none'> {
  const of = (d: DocumentData | undefined) => (d === undefined ? null : registrationFromFirestore(input.regId, d));
  const outcome = await syncEventChatMembership(deps, { before: of(input.before), after: of(input.after) });
  if (outcome !== 'none') logger.info('onRegistrationWrite', { eventId: input.eventId, outcome });
  return outcome;
}
