import type { Kysely } from 'kysely';

import { isForeignKeyViolation, type ContactChannelCode, type Database } from '../db/database.js';
import { newId } from '../ids.js';

/** One round trip: booking, last completion instant, the photographer's flags and numbers. */
export const bookingContactQuery = (db: Kysely<Database>, bookingId: string) =>
  db
    .selectFrom('bookings as b')
    .leftJoin('photographer_contact_channels as c', 'c.photographer_id', 'b.photographer_id')
    .leftJoin('photographer_contact_numbers as n', 'n.photographer_id', 'b.photographer_id')
    .select((eb) => [
      'b.customer_id',
      'b.status',
      eb
        .selectFrom('booking_events as e')
        .select((e) => e.fn.max('e.at').as('at'))
        .whereRef('e.booking_id', '=', 'b.id')
        .where('e.status', '=', 'completed')
        .as('completed_at'),
      'c.call_enabled',
      'c.zalo_enabled',
      'c.whatsapp_enabled',
      'n.phone_e164',
      'n.zalo_phone_e164',
      'n.whatsapp_phone_e164',
    ])
    .where('b.id', '=', bookingId);

export interface ContactAccess {
  requesterId: string;
  subjectType: 'booking' | 'event_registration';
  subjectId: string;
  channel: ContactChannelCode;
  granted: boolean;
  at: Date;
}

/** ContactAccessLog (domain-model.md §2.7): who asked for which channel of what, and the answer. Never a number. */
export async function logContactAccess(db: Kysely<Database>, a: ContactAccess): Promise<void> {
  try {
    await db
      .insertInto('contact_access_log')
      .values({
        id: newId(a.at.getTime()),
        requester_id: a.requesterId,
        subject_type: a.subjectType,
        subject_id: a.subjectId,
        channel: a.channel,
        granted: a.granted,
        at: a.at,
      })
      .execute();
  } catch (e) {
    // A token whose uid has no users row (never called POST /v1/me) cannot own a booking: nothing to audit.
    if (!isForeignKeyViolation(e)) throw e;
  }
}
