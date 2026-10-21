/**
 * In-memory reference implementation of SpotScheduleStore with serialized
 * transactions and read-after-write guards.
 */

import type { Spot } from './spot.js';
import { scheduleReachesDay, type SpotSchedule } from './spot_schedule.js';
import type { SlotOffer } from './spot_slots.js';
import type { SpotDay } from './spot_booking.js';
import type { AvailabilityDayRecord, ServiceRecord } from './booking_ports.js';
import type { SpotScheduleStore, SpotScheduleTx } from './spot_schedule_ports.js';

export class MemorySpotStore implements SpotScheduleStore {
  readonly spots = new Map<string, Spot>();
  readonly schedules = new Map<string, SpotSchedule>();
  readonly offers = new Map<string, SlotOffer>();
  readonly spotDays = new Map<string, SpotDay>(); // key: `${scheduleId}_${day}`
  readonly availabilityMap = new Map<string, AvailabilityDayRecord>(); // key: `${uid}_${day}`
  readonly providerLocks = new Map<string, string>(); // uid -> lastTouchedIso
  readonly services = new Map<string, ServiceRecord[]>(); // providerId -> ServiceRecord[]

  private queue: Promise<unknown> = Promise.resolve();

  private availKey(uid: string, day: string): string {
    return `${uid}_${day}`;
  }

  seedSpot(s: Spot): void {
    this.spots.set(s.id, { ...s });
  }

  seedSchedule(s: SpotSchedule): void {
    this.schedules.set(s.id, { ...s });
  }

  seedOffer(o: SlotOffer): void {
    this.offers.set(o.id, { ...o });
  }

  seedSpotDay(d: SpotDay): void {
    this.spotDays.set(`${d.scheduleId}_${d.day}`, { ...d });
  }

  seedAvailability(uid: string, day: string, rec: AvailabilityDayRecord): void {
    this.availabilityMap.set(this.availKey(uid, day), { ...rec });
  }

  seedServices(providerId: string, srvs: ServiceRecord[]): void {
    this.services.set(providerId, [...srvs]);
  }

  getScheduleSync(id: string): SpotSchedule | null {
    const s = this.schedules.get(id);
    return s ? { ...s } : null;
  }

  getOfferSync(id: string): SlotOffer | null {
    const o = this.offers.get(id);
    return o ? { ...o } : null;
  }

  getAvailabilitySync(uid: string, day: string): AvailabilityDayRecord | null {
    const a = this.availabilityMap.get(this.availKey(uid, day));
    return a ? { ...a } : null;
  }

  getSpotDaySync(scheduleId: string, day: string): SpotDay | null {
    const d = this.spotDays.get(`${scheduleId}_${day}`);
    return d ? { ...d } : null;
  }

  async runTransaction<T>(fn: (tx: SpotScheduleTx) => Promise<T>): Promise<T> {
    const run = async () => {
      const staged: Array<() => void> = [];
      let hasWritten = false;

      const guardRead = (name: string): void => {
        if (hasWritten) {
          throw new Error(`Transaction read after write: ${name} called after a write operation`);
        }
      };

      const tx: SpotScheduleTx = {
        lockProvider: async () => {
          guardRead('lockProvider');
          // In real Firestore: reads photographers/{uid}/private/spot_schedules to take a lock.
          // MemorySpotStore already serializes all transactions on this.queue.
        },
        getSpot: async (id) => {
          guardRead('getSpot');
          const s = this.spots.get(id);
          return s ? { ...s } : null;
        },
        getSchedule: async (id) => {
          guardRead('getSchedule');
          const s = this.schedules.get(id);
          return s ? { ...s } : null;
        },
        openSchedulesOf: async (providerId, today) => {
          guardRead('openSchedulesOf');
          return [...this.schedules.values()]
            .filter(
              (s) =>
                s.providerId === providerId &&
                s.status === 'open' &&
                scheduleReachesDay(s, today),
            )
            .map((s) => ({ ...s }));
        },
        activeServices: async (providerId) => {
          guardRead('activeServices');
          const srvs = this.services.get(providerId) ?? [];
          return srvs.filter((s) => s.active !== false).map((s) => ({ ...s }));
        },
        availability: async (uid, day) => {
          guardRead('availability');
          const a = this.availabilityMap.get(this.availKey(uid, day));
          return a ? { ...a } : null;
        },
        getSpotDay: async (scheduleId, day) => {
          guardRead('getSpotDay');
          const d = this.spotDays.get(`${scheduleId}_${day}`);
          return d ? { ...d } : null;
        },
        offersOf: async (scheduleId) => {
          guardRead('offersOf');
          return [...this.offers.values()]
            .filter((o) => o.scheduleId === scheduleId)
            .map((o) => ({ ...o }));
        },
        getOffer: async (id) => {
          guardRead('getOffer');
          const o = this.offers.get(id);
          return o ? { ...o } : null;
        },
        putSchedule: (s) => {
          hasWritten = true;
          staged.push(() => {
            this.schedules.set(s.id, { ...s });
          });
        },
        putOffer: (o) => {
          hasWritten = true;
          staged.push(() => {
            this.offers.set(o.id, { ...o });
          });
        },
        touchLock: (providerId, now) => {
          hasWritten = true;
          staged.push(() => {
            this.providerLocks.set(providerId, now);
          });
        },
        setSpotAvailability: (uid, day, rec) => {
          hasWritten = true;
          staged.push(() => {
            this.availabilityMap.set(this.availKey(uid, day), {
              state: 'spot',
              scheduleId: rec.scheduleId,
              spotId: rec.spotId,
            });
          });
        },
        deleteAvailability: (uid, day) => {
          hasWritten = true;
          staged.push(() => {
            this.availabilityMap.delete(this.availKey(uid, day));
          });
        },
      };

      const result = await fn(tx);
      for (const apply of staged) apply();
      return result;
    };

    const next = this.queue.then(run, run);
    this.queue = next.catch(() => {});
    return next;
  }
}
