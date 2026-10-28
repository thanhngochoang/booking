import type { PaymentGateway, TransferRecord } from './booking_ports.js';
import type { PaymentLookup } from './payment_settlement.js';
import type { EventRecord, RegistrationContact, RegistrationDoc } from './event.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { AccountCipher } from './payout_ports.js';
import type { Clock, IdGenerator, UserContactReader } from './ports.js';
import type { RandomBytes } from './ids.js';
import type { Spot } from './spot.js';
import type { EntryDay } from './entry_tickets.js';
import type { Organizer, Resident } from './organizer.js';
import type { PassRecord, PrivatePassRef } from './pass.js';

/** Thrown inside a transaction to ask the adapter to run it again (it holds no state of its own). */
export class RetryableConflict extends Error {
  constructor() {
    super('retryable_conflict');
    this.name = 'RetryableConflict';
  }
}

export type AvailabilityRecord = { state: 'off' | 'booked' | 'pending' | 'spot'; eventId?: string; bookingId?: string };

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
  /** `spots/{id}` (S29): an event may be tagged with an active spot that covers its place. */
  getSpot(id: string): Promise<Spot | null>;
  /** `event_hashtags/{key}.eventId`. */
  hashtagOwner(key: string): Promise<string | null>;
  ticketCodeTaken(code: string): Promise<boolean>;
  findTicket(code: string): Promise<{ eventId: string; registrationId: string } | null>;
  getRegistration(eventId: string, regId: string): Promise<RegistrationDoc | null>;
  /**
   * held | paid. With `visitDay` (entry events, S30 Decision 11): the customer's lone ticket of that day,
   * ignoring tickets bought with a booking (`bookingId` set).
   */
  activeRegistrationOf(eventId: string, userId: string, visitDay?: string): Promise<RegistrationDoc | null>;
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
  /** `refunds/{id}`. */
  getRefund(id: string): Promise<Refund | null>;
  /** `entry_days/{eventId}_{day}` (S30). */
  getEntryDay(eventId: string, day: string): Promise<EntryDay | null>;
  /** Paid registrations of an entry event's visit day (closing a day). */
  registrationsOfDay(eventId: string, day: string): Promise<RegistrationDoc[]>;
  /** `organizers/{uid}` (S30): the host of an entry event. */
  getOrganizer(uid: string): Promise<Organizer | null>;
  /** `spots/{spotId}/residents/{providerId}` (S30; read by bookings with tickets, Task 3). */
  residentOf(spotId: string, providerId: string): Promise<Resident | null>;
  /** `passes/{code8}` (S30 Decision 7). */
  getPass(code8: string): Promise<PassRecord | null>;
  passTaken(code8: string): Promise<boolean>;
  putEvent(e: EventRecord): void;
  putPass(p: PassRecord): void;
  /** The customer's copy of a pass (`…/private/pass {code}`). */
  putPrivatePass(ref: PrivatePassRef, code8: string): void;
  putEntryDay(d: EntryDay): void;
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
  getTransferRecord(id: string): Promise<TransferRecord | null>;
  putTransferRecord(r: TransferRecord): void;
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
  /** S17: open | full | closed, `soonNoticeAt == null`, `now < startAt <= horizon` (the 48-hour reminder). */
  dueForSoonNotice(now: Date, horizon: Date, limit: number): Promise<EventRecord[]>;
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

import type { BlockGate } from './block_ports.js';

export interface EventDeps {
  readonly events: EventStore;
  readonly people: EventPeople;
  readonly contacts: UserContactReader;
  readonly media: { isOwnUpload(url: string, path: string, uid: string, eventId: string): boolean };
  readonly blocks?: BlockGate;
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly random: RandomBytes;
}

/** Paid tickets: the booking payment gateway (fake in phase 1; VietQR/intermediary later, #129). */
export interface EventPaymentDeps extends EventDeps {
  readonly gateway: PaymentGateway;
  readonly payments: PaymentLookup;
  readonly cipher: AccountCipher;
}
