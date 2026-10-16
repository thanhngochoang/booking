import type { PaymentGateway } from './booking_ports.js';
import type { EventDeps } from './event_ports.js';
import { GROUP_READONLY_DAYS } from './event_chat.js';
import { TICKET_REFUND_RESEND_AFTER_MINUTES, refundTicket, resendTicketRefund, stampTicketRelease } from './event_payments.js';
import { expireHostConsent } from './event_use_cases.js';
import { MemoryPaymentLookup, type PaymentSource } from './memory_payment_lookup.js';

export type EventSweepStep = 'close' | 'complete' | 'consent' | 'refund' | 'refund_resend';

const BATCH = 200;
const DAY_MS = 86_400_000;

/**
 * The event clock (every 5 minutes): closes registration after the deadline, completes events after
 * `endAt` (stamping `releaseAfter` on their held ticket money, Task 9), cancels drafts whose
 * photographer did not answer within 24 h (O1), refunds tickets of cancelled events that are
 * still due, and sends again ticket refunds left `pending` for `TICKET_REFUND_RESEND_AFTER_MINUTES`
 * (both need the gateway; the gateway keys refunds by id). Every step re-reads inside its own
 * transaction, so a second run (or a parallel one) changes nothing more. The `onError` id is the
 * event's, or the refund's for `refund_resend`.
 */
export async function runEventSweeps(
  deps: EventDeps & { readonly gateway?: PaymentGateway },
  onError: (eventId: string, step: EventSweepStep, error: unknown) => void = () => undefined,
): Promise<{ closed: number; completed: number; consentExpired: number; refunded: number; refundsResent: number }> {
  // One bad event must not block the others: log it, go on with the rest of the batch.
  const guarded = async (id: string, step: EventSweepStep, fn: () => Promise<boolean>): Promise<boolean> => {
    try {
      return await fn();
    } catch (e) {
      onError(id, step, e);
      return false;
    }
  };
  let closed = 0;
  let completed = 0;
  let consentExpired = 0;

  for (const due of await deps.events.dueForClose(deps.clock.now(), BATCH)) {
    const did = await guarded(due.id, 'close', async () => deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || (ev.status !== 'open' && ev.status !== 'full')) return false;
      if (ev.registrationDeadline === null || ev.registrationDeadline.getTime() > now.getTime()) return false;
      tx.putEvent({ ...ev, status: 'closed', version: ev.version + 1, updatedAt: now });
      return true;
    }));
    if (did) closed += 1;
  }

  for (const due of await deps.events.dueForCompletion(deps.clock.now(), BATCH)) {
    const did = await guarded(due.id, 'complete', async () => deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || (ev.status !== 'open' && ev.status !== 'full' && ev.status !== 'closed')) return false;
      if (ev.endAt === null || ev.endAt.getTime() > now.getTime()) return false;
      const tickets = await tx.heldTicketPayments(ev.id);
      stampTicketRelease(tx, ev, tickets, now);
      if (ev.chatId !== null) tx.setChatReadOnlyAt(ev.chatId, new Date(now.getTime() + GROUP_READONLY_DAYS * DAY_MS));
      tx.putEvent({ ...ev, status: 'completed', completedAt: now, version: ev.version + 1, updatedAt: now });
      return true;
    }));
    if (did) completed += 1;
  }

  for (const due of await deps.events.dueForConsentExpiry(deps.clock.now(), BATCH)) {
    const did = await guarded(due.id, 'consent', async () => deps.events.runTransaction(async (tx) => {
      const now = deps.clock.now();
      const ev = await tx.getEvent(due.id);
      if (ev === null || ev.status !== 'draft' || ev.hostConsent !== 'pending') return false;
      if (ev.hostConsentExpiresAt === null || ev.hostConsentExpiresAt.getTime() > now.getTime()) return false;
      expireHostConsent(tx, ev, now);
      return true;
    }));
    if (did) consentExpired += 1;
  }

  let refunded = 0;
  let refundsResent = 0;
  const { gateway } = deps;
  if (gateway !== undefined) {
    const payments = new MemoryPaymentLookup([deps.events as unknown as PaymentSource]);
    const payDeps = { ...deps, gateway, payments };
    for (const due of await deps.events.paidUnrefundedOfCancelled(BATCH)) {
      const did = await guarded(due.eventId, 'refund', async () =>
        (await refundTicket(payDeps, due.eventId, due.id, 100, 'event_cancelled')) === 'refunded');
      if (did) refunded += 1;
    }
    const before = new Date(deps.clock.now().getTime() - TICKET_REFUND_RESEND_AFTER_MINUTES * 60_000);
    for (const r of await deps.events.pendingTicketRefunds(before, BATCH)) {
      const did = await guarded(r.id, 'refund_resend', async () => resendTicketRefund(payDeps, r.id));
      if (did) refundsResent += 1;
    }
  }

  return { closed, completed, consentExpired, refunded, refundsResent };
}
