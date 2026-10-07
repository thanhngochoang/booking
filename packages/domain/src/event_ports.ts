import type { PaymentGateway } from './booking_ports.js';
import type { EventRecord, RegistrationContact, RegistrationDoc } from './event.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { Clock, IdGenerator, UserContactReader } from './ports.js';
import type { RandomBytes } from './ids.js';

/** Thrown inside a transaction to ask the adapter to run it again (it holds no state of its own). */
export class RetryableConflict extends Error {
  constructor() {
    super('retryable_conflict');
    this.name = 'RetryableConflict';
  }
}

export type AvailabilityRecord = { state: 'off' | 'booked' | 'pending'; eventId?: string; bookingId?: string };

/** Decision 18 shape, created at publish (`chats/event_{eventId}`). */
export interface EventGroupChatSeed {
  readonly id: string;
  readonly kind: 'event_group';
  readonly eventId: string;
  readonly title: string;
  readonly members: readonly string[];
  readonly moderators: readonly string[];
  /** Name and avatar of each moderator, written as their member docs (the member list shows names only). */
  readonly memberProfiles: ReadonlyArray<{ readonly uid: string; readonly name: string; readonly avatarUrl: string | null }>;
  readonly memberCount: number;
  readonly moderatorsOnly: boolean;
  readonly lastMessageAt: Date | null;
  readonly lastMessagePreview: string | null;
  readonly lastSenderId: string | null;
  readonly readOnlyAt: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** Every read must come before the first write (Firestore transactions; the memory store enforces it). */
export interface EventTx {
  getEvent(id: string): Promise<EventRecord | null>;
  /** `event_hashtags/{key}.eventId`. */
  hashtagOwner(key: string): Promise<string | null>;
  ticketCodeTaken(code: string): Promise<boolean>;
  findTicket(code: string): Promise<{ eventId: string; registrationId: string } | null>;
  getRegistration(eventId: string, regId: string): Promise<RegistrationDoc | null>;
  /** held | paid. */
  activeRegistrationOf(eventId: string, userId: string): Promise<RegistrationDoc | null>;
  /** All held | paid registrations of the event (cancelling an event). */
  activeRegistrations(eventId: string): Promise<RegistrationDoc[]>;
  /** held, `holdExpiresAt <= now`. */
  expiredHolds(eventId: string, now: Date): Promise<RegistrationDoc[]>;
  availability(photographerId: string, dayKey: string): Promise<AvailabilityRecord | null>;
  /** `payments/{id}` (the same collection as booking deposits). */
  getPayment(id: string): Promise<Payment | null>;
  paymentByIdempotencyKey(key: string): Promise<Payment | null>;
  /**
   * Ticket payments of the event whose money is held: `status == paid` and escrow `held` or
   * `partially_refunded` (late-cancelled tickets included; refunded and unpaid intents excluded).
   */
  heldTicketPayments(eventId: string): Promise<Payment[]>;
  putEvent(e: EventRecord): void;
  putHashtag(key: string, eventId: string): void;
  deleteHashtag(key: string): void;
  putTicketCode(code: string, eventId: string, registrationId: string): void;
  putRegistration(r: RegistrationDoc): void;
  putRegistrationContact(eventId: string, regId: string, c: RegistrationContact): void;
  /** The phone snapshot goes when the ticket stops unlocking contact (cancelled or refunded). */
  deleteRegistrationContact(eventId: string, regId: string): void;
  putPayment(p: Payment): void;
  putRefund(r: Refund): void;
  putLedgerEntry(e: LedgerEntry): void;
  setAvailabilityBooked(photographerId: string, dayKey: string, eventId: string): void;
  deleteAvailability(photographerId: string, dayKey: string): void;
  putGroupChat(chat: EventGroupChatSeed): void;
  /** The group chat closes for writing (7 days after the event completes). */
  setChatReadOnlyAt(chatId: string, at: Date): void;
}

export interface EventStore {
  runTransaction<T>(fn: (tx: EventTx) => Promise<T>): Promise<T>;
  /** open | full, deadline <= now. */
  dueForClose(now: Date, limit: number): Promise<EventRecord[]>;
  /** open | full | closed, endAt <= now. */
  dueForCompletion(now: Date, limit: number): Promise<EventRecord[]>;
  /** O1: drafts with `hostConsent = pending` and `hostConsentExpiresAt <= now`. */
  dueForConsentExpiry(now: Date, limit: number): Promise<EventRecord[]>;
  /** `held` registrations of any event with `holdExpiresAt <= now` (the 1-minute hold sweep). */
  expiredHoldsAll(now: Date, limit: number): Promise<RegistrationDoc[]>;
  /** Registrations with `refundDue == true`: tickets of a cancelled event still to refund. */
  paidUnrefundedOfCancelled(limit: number): Promise<RegistrationDoc[]>;
}

export interface EventPeople {
  photographer(uid: string): Promise<
    { onboardingComplete: boolean; name: string; avatarUrl: string | null; verified: boolean } | null
  >;
  user(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>;
}

export interface EventDeps {
  readonly events: EventStore;
  readonly people: EventPeople;
  readonly contacts: UserContactReader;
  readonly media: { isOwnUpload(url: string, path: string, uid: string, eventId: string): boolean };
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly random: RandomBytes;
}

/** Paid tickets: the booking payment gateway (fake in phase 1; VietQR/intermediary later, #129). */
export interface EventPaymentDeps extends EventDeps {
  readonly gateway: PaymentGateway;
}
