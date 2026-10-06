import type { EventRecord, RegistrationContact, RegistrationDoc } from './event.js';
import {
  RetryableConflict,
  type AvailabilityRecord,
  type EventGroupChatSeed,
  type EventStore,
  type EventTx,
} from './event_ports.js';

const MAX_ATTEMPTS = 3;

export class MemoryEventStore implements EventStore {
  readonly events = new Map<string, EventRecord>();
  readonly registrations = new Map<string, RegistrationDoc>(); // `${eventId}/${regId}`
  readonly contacts = new Map<string, RegistrationContact>(); // `${eventId}/${regId}`
  readonly hashtags = new Map<string, string>();
  readonly ticketCodes = new Map<string, { eventId: string; registrationId: string }>();
  readonly availabilityDays = new Map<string, AvailabilityRecord>(); // `${uid}/${dayKey}`
  readonly chats = new Map<string, EventGroupChatSeed>();
  readonly chatReadOnlyAt = new Map<string, Date>();
  /** Committed write count. */
  writes = 0;
  /** Number of transaction attempts that were retried. */
  retries = 0;

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

  registrationsOf(eventId: string): RegistrationDoc[] {
    return [...this.registrations.values()].filter((r) => r.eventId === eventId);
  }

  async runTransaction<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await this.attempt(fn);
      } catch (e) {
        if (!(e instanceof RetryableConflict) || attempt >= MAX_ATTEMPTS) throw e;
        this.retries += 1;
      }
    }
  }

  private async attempt<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const read = (name: string): void => {
      if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
    };
    const write = (apply: () => void): void => {
      hasWritten = true;
      staged.push(() => {
        apply();
        this.writes += 1;
      });
    };
    const key = (eventId: string, regId: string): string => `${eventId}/${regId}`;

    const tx: EventTx = {
      getEvent: async (id) => {
        read('getEvent');
        return this.events.get(id) ?? null;
      },
      hashtagOwner: async (k) => {
        read('hashtagOwner');
        return this.hashtags.get(k) ?? null;
      },
      ticketCodeTaken: async (code) => {
        read('ticketCodeTaken');
        return this.ticketCodes.has(code);
      },
      findTicket: async (code) => {
        read('findTicket');
        return this.ticketCodes.get(code) ?? null;
      },
      getRegistration: async (eventId, regId) => {
        read('getRegistration');
        return this.registrations.get(key(eventId, regId)) ?? null;
      },
      activeRegistrationOf: async (eventId, userId) => {
        read('activeRegistrationOf');
        return this.registrationsOf(eventId)
          .find((r) => r.userId === userId && (r.status === 'held' || r.status === 'paid')) ?? null;
      },
      activeRegistrations: async (eventId) => {
        read('activeRegistrations');
        return this.registrationsOf(eventId).filter((r) => r.status === 'held' || r.status === 'paid');
      },
      expiredHolds: async (eventId, now) => {
        read('expiredHolds');
        return this.registrationsOf(eventId).filter(
          (r) => r.status === 'held' && r.holdExpiresAt !== null && r.holdExpiresAt.getTime() <= now.getTime(),
        );
      },
      availability: async (uid, dayKey) => {
        read('availability');
        return this.availabilityDays.get(`${uid}/${dayKey}`) ?? null;
      },
      putEvent: (e) => write(() => { this.events.set(e.id, e); }),
      putHashtag: (k, eventId) => write(() => { this.hashtags.set(k, eventId); }),
      deleteHashtag: (k) => write(() => { this.hashtags.delete(k); }),
      putTicketCode: (code, eventId, registrationId) =>
        write(() => { this.ticketCodes.set(code, { eventId, registrationId }); }),
      putRegistration: (r) => write(() => { this.registrations.set(key(r.eventId, r.id), r); }),
      putRegistrationContact: (eventId, regId, c) => write(() => { this.contacts.set(key(eventId, regId), c); }),
      setAvailabilityBooked: (uid, dayKey, eventId) =>
        write(() => { this.availabilityDays.set(`${uid}/${dayKey}`, { state: 'booked', eventId }); }),
      deleteAvailability: (uid, dayKey) => write(() => { this.availabilityDays.delete(`${uid}/${dayKey}`); }),
      putGroupChat: (chat) => write(() => { this.chats.set(chat.id, chat); }),
      setChatReadOnlyAt: (chatId, at) => write(() => { this.chatReadOnlyAt.set(chatId, at); }),
    };

    const result = await fn(tx);
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

  async dueForConsentExpiry(now: Date, limit: number): Promise<EventRecord[]> {
    return [...this.events.values()]
      .filter((e) => e.status === 'draft' && e.hostConsent === 'pending'
        && e.hostConsentExpiresAt !== null && e.hostConsentExpiresAt.getTime() <= now.getTime())
      .slice(0, limit);
  }
}
