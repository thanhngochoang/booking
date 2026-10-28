/**
 * S30 (Decision 9): the memory adapter of `ScanStore`. On Firestore a scan is one transaction over
 * `passes`, `ticket_codes`, bookings, events, registrations, `entry_days` and `gate_staff`; here the
 * event side runs in one event-store transaction (reads before writes, conflicts retried), and the
 * booking and gate-staff writes are staged and applied when it commits. Tests run scans one at a time.
 */

import type { Booking, BookingEventRecord } from './booking.js';
import type { MemoryBookingStore } from './memory_booking_store.js';
import type { MemoryEventStore } from './memory_event_store.js';
import type { MemoryOrganizerStore } from './memory_organizer_store.js';
import type { GateStaff } from './organizer.js';
import type { ScanStore, ScanTx } from './pass_scan.js';

export class MemoryScanStore implements ScanStore {
  constructor(
    private readonly bookings: MemoryBookingStore,
    private readonly events: MemoryEventStore,
    private readonly organizers: MemoryOrganizerStore,
  ) {}

  async runTransaction<T>(fn: (tx: ScanTx) => Promise<T>): Promise<T> {
    let staged: Array<() => void> = [];
    const result = await this.events.runTransaction(async (etx) => {
      staged = [];
      const tx: ScanTx = {
        getPass: (code8) => etx.getPass(code8),
        findTicket: (code) => etx.findTicket(code),
        getBooking: async (id) => this.bookings.getBooking(id),
        getEvent: (id) => etx.getEvent(id),
        getRegistration: (eventId, regId) => etx.getRegistration(eventId, regId),
        getSpot: (id) => etx.getSpot(id),
        getEntryDay: (eventId, day) => etx.getEntryDay(eventId, day),
        getGateStaff: async (organizerId, staffUid) => {
          const row = this.organizers.gateStaff.get(organizerId)?.get(staffUid);
          return row ? { ...row } : null;
        },
        putPass: async (p) => etx.putPass(p),
        setBooking: async (b: Booking) => {
          staged.push(() => this.bookings.bookings.set(b.id, { ...b }));
        },
        addBookingEvent: async (e: BookingEventRecord) => {
          staged.push(() => this.bookings.events.push({ ...e }));
        },
        putRegistration: async (r) => etx.putRegistration(r),
        putEntryDay: async (d) => etx.putEntryDay(d),
        putGateStaff: async (organizerId: string, g: GateStaff) => {
          staged.push(() => this.organizers.seedGateStaff(organizerId, g));
        },
      };
      return fn(tx);
    });
    for (const apply of staged) apply();
    return result;
  }
}
