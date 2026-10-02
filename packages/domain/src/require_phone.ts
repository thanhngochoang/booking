import { DomainError } from './errors.js';
import { isVnE164 } from './phone.js';
import type { UserContactReader, UserContactRecord } from './ports.js';

/**
 * `phone_required` guard (spec §3b.2): a customer needs a valid Vietnamese number before a booking
 * request or an event registration. Returns the E.164 number to snapshot into the booking.
 */
export function requirePhone(contact: UserContactRecord | null): string {
  const phone = contact?.phone;
  if (!isVnE164(phone)) throw new DomainError('phone_required');
  return phone;
}

/** Reads `users/{uid}/private/contact` through the port and applies [requirePhone]. */
export async function requireCustomerPhone(contacts: UserContactReader, uid: string): Promise<string> {
  return requirePhone(await contacts.get(uid));
}
