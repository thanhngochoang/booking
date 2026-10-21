/**
 * Ports and interfaces for spot schedules and slot offers.
 */

import type { Clock, IdGenerator } from './ports.js';
import type { AvailabilityDayRecord, ProviderOrderGate, ServiceRecord } from './booking_ports.js';
import type { StudioRoster } from './studio_ports.js';
import type { Spot } from './spot.js';
import type { SpotSchedule } from './spot_schedule.js';
import type { SlotOffer } from './spot_slots.js';
import type { SpotDay } from './spot_booking.js';

export interface SpotScheduleTx {
  lockProvider(providerId: string): Promise<void>;
  getSpot(id: string): Promise<Spot | null>;
  getSchedule(id: string): Promise<SpotSchedule | null>;
  openSchedulesOf(providerId: string, today: string): Promise<SpotSchedule[]>;
  activeServices(providerId: string): Promise<ServiceRecord[]>;
  availability(uid: string, day: string): Promise<AvailabilityDayRecord | null>;
  getSpotDay(scheduleId: string, day: string): Promise<SpotDay | null>;
  offersOf(scheduleId: string): Promise<SlotOffer[]>;
  getOffer(id: string): Promise<SlotOffer | null>;
  putSchedule(s: SpotSchedule): void;
  putOffer(o: SlotOffer): void;
  touchLock(providerId: string, now: string): void;
  setSpotAvailability(
    uid: string,
    day: string,
    rec: { scheduleId: string; spotId: string },
    now: string,
  ): void;
  deleteAvailability(uid: string, day: string): void;
}

export interface SpotScheduleStore {
  runTransaction<T>(fn: (tx: SpotScheduleTx) => Promise<T>): Promise<T>;
}

export interface SpotScheduleDeps {
  readonly schedules: SpotScheduleStore;
  readonly providers: ProviderOrderGate;
  readonly roster: StudioRoster;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
