import type { EventDeps } from './event_ports.js';
import { expireHostConsent } from './event_use_cases.js';

const BATCH = 200;
const CHAT_READ_ONLY_DAYS = 7;
const DAY_MS = 86_400_000;

/**
 * The event clock (every 5 minutes): closes registration after the deadline, completes events after
 * `endAt`, and cancels drafts whose photographer did not answer within 24 h (O1). Every step re-reads
 * the event inside its own transaction, so a second run (or a parallel one) changes nothing more.
 */
export async function runEventSweeps(
  deps: EventDeps,
): Promise<{ closed: number; completed: number; consentExpired: number }> {
  let closed = 0;
  let completed = 0;
  let consentExpired = 0;

  for (const due of await deps.events.dueForClose(deps.clock.now(), BATCH)) {
    const did = await deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || (ev.status !== 'open' && ev.status !== 'full')) return false;
      if (ev.registrationDeadline === null || ev.registrationDeadline.getTime() > now.getTime()) return false;
      tx.putEvent({ ...ev, status: 'closed', version: ev.version + 1, updatedAt: now });
      return true;
    });
    if (did) closed += 1;
  }

  for (const due of await deps.events.dueForCompletion(deps.clock.now(), BATCH)) {
    const did = await deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || (ev.status !== 'open' && ev.status !== 'full' && ev.status !== 'closed')) return false;
      if (ev.endAt === null || ev.endAt.getTime() > now.getTime()) return false;
      if (ev.chatId !== null) tx.setChatReadOnlyAt(ev.chatId, new Date(now.getTime() + CHAT_READ_ONLY_DAYS * DAY_MS));
      tx.putEvent({ ...ev, status: 'completed', completedAt: now, version: ev.version + 1, updatedAt: now });
      return true;
    });
    if (did) completed += 1;
  }

  for (const due of await deps.events.dueForConsentExpiry(deps.clock.now(), BATCH)) {
    const did = await deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || ev.status !== 'draft' || ev.hostConsent !== 'pending') return false;
      if (ev.hostConsentExpiresAt === null || ev.hostConsentExpiresAt.getTime() > now.getTime()) return false;
      expireHostConsent(tx, ev, now);
      return true;
    });
    if (did) consentExpired += 1;
  }

  return { closed, completed, consentExpired };
}
