import type { EscrowStatus } from './booking.js';
import type { Dispute, DisputeStatus, DisputeSubjectType } from './dispute.js';
import {
  pickSubjectPayment, venueLinesAmong, type DisputeBookingEnd, type DisputeStore, type DisputeSubjectView, type DisputeTx,
} from './dispute_ports.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import { MemorySupportStore } from './memory_support_store.js';
import type { SupportTx } from './support_use_cases.js';
import type { SupportMessage, SupportThread } from './support_thread.js';

/** Key of a subject: `booking::{id}` or `ticket:{eventId}:{registrationId}`. */
export const disputeSubjectKey = (type: DisputeSubjectType, id: string, eventId: string | null): string =>
  `${type}:${eventId ?? ''}:${id}`;

/**
 * One in-memory world for disputes and their support threads (tests, local tools): seeded subjects,
 * payments, refunds and ledger. Like #204's support store, a transaction refuses a read after a write.
 */
export class MemoryDisputeStore extends MemorySupportStore implements DisputeStore {
  readonly disputes = new Map<string, Dispute>();
  readonly subjects = new Map<string, DisputeSubjectView>();
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly ledger: LedgerEntry[] = [];
  /** What `linkSubject` wrote, by subject key (the booking / registration mirrors). */
  readonly mirrors = new Map<
    string,
    { readonly disputeId: string; readonly escrowStatus?: EscrowStatus; readonly end?: DisputeBookingEnd }
  >();

  putSubject(view: DisputeSubjectView): void {
    this.subjects.set(disputeSubjectKey(view.type, view.id, view.eventId), view);
  }

  override async runTransaction<T>(fn: (tx: DisputeTx & SupportTx) => Promise<T>): Promise<T> {
    const disputes = new Map<string, Dispute>();
    const payments = new Map<string, Payment>();
    const refunds = new Map<string, Refund>();
    const ledger: LedgerEntry[] = [];
    const links = new Map<string, { view: DisputeSubjectView; disputeId: string; escrowStatus: EscrowStatus; end?: DisputeBookingEnd }>();
    const threads = new Map<string, SupportThread>();
    const messages: SupportMessage[] = [];
    let written = false;

    const read = <R>(get: () => R): Promise<R> => {
      if (written) return Promise.reject(new Error('Read after write in transaction'));
      return Promise.resolve(get());
    };
    const write = (apply: () => void): void => {
      written = true;
      apply();
    };

    const tx: DisputeTx & SupportTx = {
      getSubject: (type, id, eventId) => read(() => this.subjects.get(disputeSubjectKey(type, id, eventId)) ?? null),
      getDispute: (id) => read(() => this.disputes.get(id) ?? null),
      getPayment: (id) => read(() => this.payments.get(id) ?? null),
      getRefund: (id) => read(() => this.refunds.get(id) ?? null),
      getThread: (id) => read(() => this.threads.get(id) ?? null),
      getMessage: (threadId, id) => read(() => this.messages.get(threadId)?.get(id) ?? null),
      findSubjectPayment: (subject) =>
        read(() => {
          if (subject.type === 'ticket') {
            return subject.paymentId === null ? null : (this.payments.get(subject.paymentId) ?? null);
          }
          return pickSubjectPayment(
            [...this.payments.values()].filter((p) => p.subjectType === 'booking' && p.subjectId === subject.id),
          );
        }),
      venueLinesOf: (payment) => read(() => venueLinesAmong(payment, [...this.payments.values()])),
      setDispute: (d) => write(() => disputes.set(d.id, d)),
      setPayment: (p) => write(() => payments.set(p.id, p)),
      linkSubject: (view, patch) =>
        write(() => links.set(disputeSubjectKey(view.type, view.id, view.eventId), { view, ...patch })),
      addRefund: (r) => write(() => refunds.set(r.id, r)),
      addLedgerEntry: (e) => write(() => ledger.push(e)),
      putThread: (t) => write(() => threads.set(t.id, t)),
      addMessage: (m) => write(() => messages.push(m)),
    };

    const result = await fn(tx);

    for (const [id, d] of disputes) this.disputes.set(id, d);
    for (const [id, p] of payments) this.payments.set(id, p);
    for (const [id, r] of refunds) this.refunds.set(id, r);
    this.ledger.push(...ledger);
    for (const [key, { view, disputeId, escrowStatus, end }] of links) {
      const current = this.subjects.get(key) ?? view;
      this.subjects.set(key, { ...current, disputeId, ...(end !== undefined ? { state: end.status } : {}) });
      this.mirrors.set(key, view.type === 'booking' ? { disputeId, escrowStatus, ...(end !== undefined ? { end } : {}) } : { disputeId });
    }
    for (const [id, t] of threads) this.threads.set(id, t);
    for (const m of messages) {
      let byId = this.messages.get(m.threadId);
      if (!byId) {
        byId = new Map();
        this.messages.set(m.threadId, byId);
      }
      byId.set(m.id, m);
    }
    return result;
  }

  async getRefundsForPayment(paymentId: string): Promise<readonly Refund[]> {
    return [...this.refunds.values()].filter((r) => r.paymentId === paymentId);
  }

  async listByStatus(status: DisputeStatus, limit: number): Promise<readonly Dispute[]> {
    return [...this.disputes.values()]
      .filter((d) => d.status === status)
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .slice(0, limit);
  }
}
