/**
 * S30 (#223 Decision 7): `passes/{code8}` created → `pass_ready` to its customer, once per pass (deterministic
 * notification id). The pass is server-only; the notice never carries the code (only `private/pass` holds it).
 */

import { notifyPassReady, type NotifyDeps } from '@photobooking/domain';
import type { DocumentData } from 'firebase-admin/firestore';
import { passFromFirestore } from '../infra/pass_firestore.js';

export async function handlePassCreated(code8: string, data: DocumentData | undefined, notify: NotifyDeps): Promise<void> {
  const pass = passFromFirestore(code8, data);
  if (pass === null) return;
  await notifyPassReady(notify, {
    customerId: pass.customerId,
    day: pass.day,
    bookingId: pass.bookingId,
    eventId: pass.eventId,
    registrationId: pass.registrationIds[0] ?? null,
  });
}
