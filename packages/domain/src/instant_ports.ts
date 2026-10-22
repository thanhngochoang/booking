/**
 * Ports of the Chụp ngay use cases (plan #140 Contract). The Firestore adapters live in
 * app_flutter/firebase/functions/src/infra/instant_*.ts (Task 4); MemoryInstantStore is the
 * reference adapter for tests. Inside a transaction every read comes before the first write.
 */
import type { BlockGate } from './block_ports.js';
import type { BookingContactSnapshot } from './booking.js';
import type { CustomerContactReader, ProviderOrderGate } from './booking_ports.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { InstantConfig, InstantPresence, InstantOffer, InstantRequest } from './instant.js';
import type { InstantDayState } from './instant_match.js';
import type { PushSender, UserDirectory } from './notification_ports.js';
import type { OrderGateDeps } from './order_gate.js';
import type { Clock, IdGenerator } from './ports.js';

/** `instant_tracks/{requestId}`: the photographer's last position, only while `en_route` (Decision 11). */
export interface InstantTrackDoc {
  readonly customerId: string; readonly photographerId: string; readonly active: boolean;
  readonly lat: number; readonly lng: number; readonly accuracyM: number; readonly heading: number | null; readonly at: Date;
}

export interface InstantTx {
  getRequest(id: string): Promise<InstantRequest | null>;
  getOffer(photographerId: string, offerId: string): Promise<InstantOffer | null>;
  getPresence(uid: string): Promise<InstantPresence | null>;
  /** #202 (Task 11); nothing in #140 reads or writes money. */
  getPayment(id: string): Promise<Payment | null>;
  getRefund(id: string): Promise<Refund | null>;
  /** `customerId == uid && active == true`, limit 1. */
  findActiveRequestOfCustomer(customerId: string): Promise<InstantRequest | null>;
  putRequest(r: InstantRequest): void;
  putOffer(o: InstantOffer): void;
  putPresence(p: InstantPresence): void;
  putPayment(p: Payment): void;
  putRefund(r: Refund): void;
  putLedgerEntry(e: LedgerEntry): void;
  /** `instant_requests/{id}/private/contact` (Decision 22). */
  putContact(requestId: string, c: BookingContactSnapshot): void;
  deleteContact(requestId: string): void;
  putTrack(requestId: string, t: InstantTrackDoc): void;
  deleteTrack(requestId: string): void;
}

export interface InstantStore {
  runTransaction<T>(fn: (tx: InstantTx) => Promise<T>): Promise<T>;
  /** `active == true && nextDeadlineAt <= now`, oldest deadline first (the clock step, Decision 3). */
  findDue(now: Date, limit: number): Promise<readonly InstantRequest[]>;
}

export interface PresenceDirectory {
  /** `online == true && {field} in cells`, at most `limit` (Decision 12). */
  nearby(q: { field: 'geohash5' | 'geohash4'; cells: readonly string[]; limit: number }): Promise<readonly InstantPresence[]>;
}

export interface InstantConfigReader {
  get(): Promise<InstantConfig>;
}

/** `photographers/{uid}/private/contact.phone` is a VN E.164 number. */
export interface PhotographerPhoneReader {
  hasPhone(uid: string): Promise<boolean>;
}

/** users + photographers + the 3 latest work photos; null when the provider has no profile. */
export interface InstantProfileReader {
  snapshot(uid: string): Promise<InstantPresence['profile'] | null>;
}

/**
 * The state of `availability/{uid}/days/{day}` (`day` = Vietnam date `yyyy-MM-dd`); null when no record.
 * A `spot` or `full` day keeps the provider out of instant rounds, offers and accepts (Task 2 ruling).
 */
export interface InstantDayReader {
  stateOf(uid: string, day: string): Promise<InstantDayState | null>;
}

/**
 * #198's OrderGateDeps: providers + blocks. `blocks` is optional there, so every InstantDeps literal sets it:
 * liveInstantDeps() → liveBlockGate(), the test world → FakeBlockGate. The payment gateway joins with #202.
 */
export interface InstantDeps extends OrderGateDeps {
  readonly store: InstantStore;
  readonly presences: PresenceDirectory;
  readonly config: InstantConfigReader;
  readonly providers: ProviderOrderGate;
  readonly blocks: BlockGate;
  readonly contacts: CustomerContactReader;
  readonly phones: PhotographerPhoneReader;
  readonly profiles: InstantProfileReader;
  readonly days: InstantDayReader;
  readonly users: UserDirectory;
  readonly push: PushSender;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

export interface InstantCaller {
  readonly uid: string;
}
