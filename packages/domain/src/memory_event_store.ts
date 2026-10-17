import type { EventRecord, RegistrationContact, RegistrationDoc } from './event.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { TransferRecord } from './booking_ports.js';
import {
  RetryableConflict,
  type AvailabilityRecord,
  type EventGroupChatSeed,
  type EventStore,
  type EventTx,
} from './event_ports.js';
import type { PaymentSource } from './memory_payment_lookup.js';

/** Like the Firestore adapter: a transaction that lost a race is run again a few times. */
export const MAX_TX_ATTEMPTS = 5;

export class MemoryEventStore implements EventStore, PaymentSource {
  readonly events = new Map<string, EventRecord>();
  readonly registrations = new Map<string, RegistrationDoc>(); // `${eventId}/${regId}`
  readonly contacts = new Map<string, RegistrationContact>(); // `${eventId}/${regId}`
  readonly hashtags = new Map<string, string>();
  readonly ticketCodes = new Map<string, { eventId: string; registrationId: string }>();
  readonly availabilityDays = new Map<string, AvailabilityRecord>(); // `${uid}/${dayKey}`
  readonly chats = new Map<string, EventGroupChatSeed>();
  readonly chatReadOnlyAt = new Map<string, Date>();
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly transferRecords = new Map<string, TransferRecord>();
  readonly ledger: LedgerEntry[] = [];
  /** Test hook: the next transaction attempts throw this before committing (a crash or outage). */
  failNext: { error: Error; times: number } | null = null;
  /** Committed write count. */
  writes = 0;
  /** Number of transaction attempts that were retried. */
  retries = 0;
  /** Revision per document (and per registrations collection), bumped by every committed write. */
  private readonly revs = new Map<string, number>();

  private rev(key: string): number {
    return this.revs.get(key) ?? 0;
  }

  private bump(key: string): void {
    this.revs.set(key, this.rev(key) + 1);
  }

  seedEvent(e: EventRecord): void {
    this.events.set(e.id, e);
    if (e.hashtagKey !== '') this.hashtags.set(e.hashtagKey, e.id);
  }

  seedRegistration(r: RegistrationDoc): void {
    this.registrations.set(`${r.eventId}/${r.id}`, r);
    this.ticketCodes.set(r.ticketCode, { eventId: r.eventId, registrationId: r.id });
  }

  seedAvailability(uid: string, dayKey: string, rec: AvailabilityRecord): void {
    this.availabilityDays.set(`${uid}/${dayKey}`, rec);
  }

  seedPayment(p: Payment): void {
    this.payments.set(p.id, p);
  }

  refundsOf(paymentId: string): Refund[] {
    return [...this.refunds.values()].filter((r) => r.paymentId === paymentId);
  }

  ledgerOf(paymentId: string): LedgerEntry[] {
    return this.ledger.filter((e) => e.paymentId === paymentId);
  }

  private heldTicketPaymentsNow(eventId: string): Payment[] {
    return [...this.payments.values()].filter((p) => p.subjectType === 'event_registration' && p.eventId === eventId
      && p.status === 'paid' && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded'));
  }

  registrationsOf(eventId: string): RegistrationDoc[] {
    return [...this.registrations.values()].filter((r) => r.eventId === eventId);
  }

  async runTransaction<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await this.attempt(fn);
      } catch (e) {
        if (!(e instanceof RetryableConflict) || attempt >= MAX_TX_ATTEMPTS) throw e;
        this.retries += 1;
      }
    }
  }

  private async attempt<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    if (this.failNext !== null) {
      const f = this.failNext;
      this.failNext = f.times > 1 ? { ...f, times: f.times - 1 } : null;
      throw f.error;
    }
    const staged: Array<() => void> = [];
    // Optimistic concurrency: remember the revision of everything read, check it again at commit.
    const seen = new Map<string, number>();
    let hasWritten = false;
    const read = (name: string, ...keys: string[]): void => {
      if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
      for (const k of keys) if (!seen.has(k)) seen.set(k, this.rev(k));
    };
    const write = (apply: () => void, ...keys: string[]): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        for (const k of keys) this.bump(k);
        this.writes += 1;
      });
    };
    const key = (eventId: string, regId: string): string => `${eventId}/${regId}`;
    const regsKey = (eventId: string): string => `regs:${eventId}`;
    const regWrite = (r: RegistrationDoc): string[] => [`reg:${key(r.eventId, r.id)}`, regsKey(r.eventId)];
    const payWrite = (p: Payment): string[] =>
      [`pay:${p.id}`, `paykey:${p.idempotencyKey}`, ...(p.eventId === undefined ? [] : [`evpays:${p.eventId}`])];

    const tx: EventTx = {
      getEvent: async (id) => {
        read('getEvent', `event:${id}`);
        return this.events.get(id) ?? null;
      },
      hashtagOwner: async (k) => {
        read('hashtagOwner', `hashtag:${k}`);
        return this.hashtags.get(k) ?? null;
      },
      ticketCodeTaken: async (code) => {
        read('ticketCodeTaken', `code:${code}`);
        return this.ticketCodes.has(code);
      },
      findTicket: async (code) => {
        read('findTicket', `code:${code}`);
        return this.ticketCodes.get(code) ?? null;
      },
      getRegistration: async (eventId, regId) => {
        read('getRegistration', `reg:${key(eventId, regId)}`);
        return this.registrations.get(key(eventId, regId)) ?? null;
      },
      activeRegistrationOf: async (eventId, userId) => {
        read('activeRegistrationOf', regsKey(eventId));
        return this.registrationsOf(eventId)
          .find((r) => r.userId === userId && (r.status === 'held' || r.status === 'paid')) ?? null;
      },
      activeRegistrations: async (eventId) => {
        read('activeRegistrations', regsKey(eventId));
        return this.registrationsOf(eventId).filter((r) => r.status === 'held' || r.status === 'paid');
      },
      expiredHolds: async (eventId, now) => {
        read('expiredHolds', regsKey(eventId));
        return this.registrationsOf(eventId).filter(
          (r) => r.status === 'held' && r.holdExpiresAt !== null && r.holdExpiresAt.getTime() <= now.getTime(),
        );
      },
      availability: async (uid, dayKey) => {
        read('availability', `av:${uid}/${dayKey}`);
        return this.availabilityDays.get(`${uid}/${dayKey}`) ?? null;
      },
      getPayment: async (id) => {
        read('getPayment', `pay:${id}`);
        return this.payments.get(id) ?? null;
      },
      paymentByIdempotencyKey: async (k) => {
        read('paymentByIdempotencyKey', `paykey:${k}`);
        return [...this.payments.values()].find((p) => p.idempotencyKey === k) ?? null;
      },
      heldTicketPayments: async (eventId) => {
        read('heldTicketPayments', `evpays:${eventId}`);
        return this.heldTicketPaymentsNow(eventId);
      },
      getRefund: async (id) => {
        read('getRefund', `refund:${id}`);
        return this.refunds.get(id) ?? null;
      },
      getTransferRecord: async (id) => {
        read('getTransferRecord', `transfer:${id}`);
        return this.transferRecords.get(id) ?? null;
      },
      putEvent: (e) => write(() => { this.events.set(e.id, e); }, `event:${e.id}`),
      putHashtag: (k, eventId) => write(() => { this.hashtags.set(k, eventId); }, `hashtag:${k}`),
      deleteHashtag: (k) => write(() => { this.hashtags.delete(k); }, `hashtag:${k}`),
      putTicketCode: (code, eventId, registrationId) =>
        write(() => { this.ticketCodes.set(code, { eventId, registrationId }); }, `code:${code}`),
      putRegistration: (r) => write(() => { this.registrations.set(key(r.eventId, r.id), r); }, ...regWrite(r)),
      putRegistrationContact: (eventId, regId, c) => write(() => { this.contacts.set(key(eventId, regId), c); }),
      deleteRegistrationContact: (eventId, regId) => write(() => { this.contacts.delete(key(eventId, regId)); }),
      putPayment: (p) => write(() => { this.payments.set(p.id, p); }, ...payWrite(p)),
      putRefund: (r) => write(() => { this.refunds.set(r.id, r); }, `refund:${r.id}`),
      putLedgerEntry: (e) => write(() => { this.ledger.push(e); }),
      putTransferRecord: (r) => write(() => { this.transferRecords.set(r.id, r); }, `transfer:${r.id}`),
      setAvailabilityBooked: (uid, dayKey, eventId) =>
        write(() => { this.availabilityDays.set(`${uid}/${dayKey}`, { state: 'booked', eventId }); }, `av:${uid}/${dayKey}`),
      deleteAvailability: (uid, dayKey) =>
        write(() => { this.availabilityDays.delete(`${uid}/${dayKey}`); }, `av:${uid}/${dayKey}`),
      putGroupChat: (chat) => write(() => { this.chats.set(chat.id, chat); }),
      setChatReadOnlyAt: (chatId, at) => write(() => { this.chatReadOnlyAt.set(chatId, at); }),
    };

    const result = await fn(tx);
    // Commit: nothing may have changed under us, then apply without yielding.
    for (const [k, r] of seen) if (this.rev(k) !== r) throw new RetryableConflict();
    for (const apply of staged) apply();
    return result;
  }

  async dueForClose(now: Date, limit: number): Promise<EventRecord[]> {
    return [...this.events.values()]
      .filter((e) => (e.status === 'open' || e.status === 'full')
        && e.registrationDeadline !== null && e.registrationDeadline.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async dueForCompletion(now: Date, limit: number): Promise<EventRecord[]> {
    return [...this.events.values()]
      .filter((e) => (e.status === 'open' || e.status === 'full' || e.status === 'closed')
        && e.endAt !== null && e.endAt.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async expiredHoldsAll(now: Date, limit: number): Promise<RegistrationDoc[]> {
    return [...this.registrations.values()]
      .filter((r) => r.status === 'held' && r.holdExpiresAt !== null && r.holdExpiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }

  async paidUnrefundedOfCancelled(limit: number): Promise<RegistrationDoc[]> {
    return [...this.registrations.values()].filter((r) => r.refundDue === true).slice(0, limit);
  }

  async dueForSoonNotice(now: Date, horizon: Date, limit: number): Promise<EventRecord[]> {
    return [...this.events.values()]
      .filter((e) => (e.status === 'open' || e.status === 'full' || e.status === 'closed')
        && (e.soonNoticeAt ?? null) === null && e.startAt !== null
        && e.startAt.getTime() > now.getTime() && e.startAt.getTime() <= horizon.getTime())
      .slice(0, limit);
  }

  async dueForConsentExpiry(now: Date, limit: number): Promise<EventRecord[]> {
    return [...this.events.values()]
      .filter((e) => e.status === 'draft' && e.hostConsent === 'pending'
        && e.hostConsentExpiresAt !== null && e.hostConsentExpiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }
}
