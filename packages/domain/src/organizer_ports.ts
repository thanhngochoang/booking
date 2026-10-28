/**
 * Ports of the organizer use cases (S30, plan #223). The Firestore adapter (Task 6) implements
 * `OrganizerStore` over `organizers`, `organizers/{uid}/gate_staff`, `spot_claims`, `spots` and
 * `spots/{id}/residents`; `MemoryOrganizerStore` is the reference implementation.
 */

import type { BlockGate } from './block_ports.js';
import type { ProviderOrderGate } from './booking_ports.js';
import type { EventRecord } from './event.js';
import type { EventPaymentDeps } from './event_ports.js';
import type { NotifyDeps } from './notification_ports.js';
import type { GateStaff, Organizer, Resident, SpotClaim } from './organizer.js';
import type { Clock, IdGenerator } from './ports.js';
import type { Spot } from './spot.js';

/** Every organizer of `pendingClaimsOf`. */
export const ANY_ORGANIZER = '*';

/** One transaction: every read before the first write (Firestore rule; the memory store enforces it). */
export interface OrganizerTx {
  getOrganizer(uid: string): Promise<Organizer | null>;
  putOrganizer(o: Organizer): void;
  /** #194's Spot with `managedBy`, `access`, `openHours`. */
  getSpot(id: string): Promise<Spot | null>;
  putSpot(s: Spot): void;
  getClaim(id: string): Promise<SpotClaim | null>;
  /**
   * Pending claims of `spotId` (null = spot proposals) by `organizerId`, or by every organizer when
   * `organizerId` is `ANY_ORGANIZER`.
   */
  pendingClaimsOf(spotId: string | null, organizerId: string): Promise<SpotClaim[]>;
  putClaim(c: SpotClaim): void;
  residentsOf(spotId: string): Promise<Resident[]>;
  getResident(spotId: string, providerId: string): Promise<Resident | null>;
  putResident(spotId: string, r: Resident): void;
  deleteResident(spotId: string, providerId: string): void;
  /** Every row (any status) of `organizers/{organizerId}/gate_staff`. */
  gateStaffOf(organizerId: string): Promise<GateStaff[]>;
  putGateStaff(organizerId: string, g: GateStaff): void;
  /** Events hosted by the organizer (`host.type == 'organizer'`) that are not cancelled or completed. */
  openEventsOf(organizerId: string): Promise<EventRecord[]>;
}

export interface ExpiredResidentRef {
  readonly spotId: string;
  readonly providerId: string;
}

export interface OrganizerStore {
  runTransaction<T>(fn: (tx: OrganizerTx) => Promise<T>): Promise<T>;
  getOrganizer(uid: string): Promise<Organizer | null>;
  /** Collection-group query: residents whose `validUntil` is before `today` (yyyy-MM-dd), at most `limit`. */
  expiredResidents(today: string, limit: number): Promise<ExpiredResidentRef[]>;
}

export interface OrganizerPeople {
  phoneVerified(uid: string): Promise<boolean>;
  /** S21.04 business verification approved for this user. */
  businessVerified(uid: string): Promise<boolean>;
  /** S06.06 payout account in the business's name. */
  payoutAccountOk(uid: string): Promise<boolean>;
  /**
   * Resolves a phone number or `@username` typed in S30.06 to an account; null when none. The adapter
   * (Task 6) normalizes the phone to E.164 and queries `users/*\/private/contact.phone`, or `usernameLower`.
   */
  lookup(phoneOrUsername: string): Promise<{ uid: string; name: string } | null>;
  /** Staff admin (claims review, access, suspension). */
  isStaff(uid: string): Promise<boolean>;
}

export interface OrganizerDeps {
  readonly organizers: OrganizerStore;
  readonly people: OrganizerPeople;
  readonly providers: ProviderOrderGate;
  /** Missing → blocks are not checked. Every live deps sets it. */
  readonly blocks?: BlockGate;
  readonly notify: NotifyDeps;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

/** `suspendOrganizer` also cancels the organizer's open events with refunds, so it needs the event side. */
export interface SuspendOrganizerDeps extends OrganizerDeps {
  readonly eventPayments: EventPaymentDeps;
}
