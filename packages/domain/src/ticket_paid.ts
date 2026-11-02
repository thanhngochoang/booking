/**
 * What paying (or releasing) a held ticket does, as pure updates: shared by the ticket settler
 * (`TicketPaymentSettler`) and the group settler (S30 Decision 6), which write them in their own
 * transaction. Internal: not exported from index.ts.
 */

import type { EntryDayDelta } from './entry_days.js';
import { visitDayOf } from './entry_days.js';
import {
  registrationContactOf,
  statusAfterSeats,
  type EventRecord,
  type RegistrationContact,
  type RegistrationDoc,
} from './event.js';
import { passCode4 } from './pass.js';
import { isVnE164 } from './phone.js';
import type { UserContactRecord } from './ports.js';

export interface TicketUpdate {
  readonly registration: RegistrationDoc;
  readonly event: EventRecord;
  /** The visit day's change (entry tickets only). */
  readonly day: EntryDayDelta | null;
}

/**
 * The paid path: the registration turns `paid` with `paymentId` and unlocks contact (O3), its seats
 * move from held to registered, an entry ticket's day from `held` to `sold`; the contact snapshot is
 * written only for a valid Vietnamese phone.
 */
export function ticketPaidUpdate(p: {
  readonly ev: EventRecord;
  readonly reg: RegistrationDoc;
  readonly paymentId: string;
  readonly contact: UserContactRecord | null;
  readonly now: Date;
  /** The ticket's pass (S30 Decision 7): the registration shows its last 4 characters. */
  readonly passCode?: string | null;
}): TicketUpdate & { readonly contact: RegistrationContact | null } {
  const { ev, reg, now } = p;
  const registration: RegistrationDoc = {
    ...reg,
    status: 'paid',
    paymentId: p.paymentId,
    contactEligible: true,
    ...(p.passCode != null ? { ticketCodeLast4: passCode4(p.passCode) } : {}),
    updatedAt: now,
    version: reg.version + 1,
  };
  const phone = p.contact?.phone;
  const contact = isVnE164(phone) ? registrationContactOf(reg.userName, phone, p.contact) : null;
  const visitDay = visitDayOf(ev, reg);
  const next = {
    ...ev,
    heldCount: Math.max(0, ev.heldCount - reg.quantity),
    registeredCount: ev.registeredCount + reg.quantity,
  };
  return {
    registration,
    contact,
    event: { ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now },
    day: visitDay === null ? null : { day: visitDay, held: -reg.quantity, sold: reg.quantity },
  };
}

/** A hold that will not be paid: the registration is `cancelled`, its seats and its day's `held` go back. */
export function ticketHoldReleased(ev: EventRecord, reg: RegistrationDoc, now: Date): TicketUpdate {
  const visitDay = visitDayOf(ev, reg);
  const next = { ...ev, heldCount: Math.max(0, ev.heldCount - reg.quantity) };
  return {
    registration: { ...reg, status: 'cancelled', cancelledAt: now, updatedAt: now, version: reg.version + 1 },
    event: { ...next, status: statusAfterSeats(next, now), version: ev.version + 1, updatedAt: now },
    day: visitDay === null ? null : { day: visitDay, held: -reg.quantity },
  };
}
