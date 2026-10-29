/**
 * S30 (Decision 6): the memory adapter of `GroupSettlementStore`, one lock over the memory booking and
 * event stores (they are one database on Firestore). Linking makes every booking transaction reach the
 * event store's entry events, `entry_days`, registrations and ticket payments (`MemoryBookingStore.entry`).
 */

import type { GroupSettlementStore, GroupSettlementTx } from './group_settlement.js';
import type { MemoryBookingStore } from './memory_booking_store.js';
import type { MemoryEventStore } from './memory_event_store.js';

export class MemoryGroupStore implements GroupSettlementStore {
  constructor(
    readonly bookings: MemoryBookingStore,
    readonly events: MemoryEventStore,
  ) {
    bookings.entry = events;
  }

  runTransaction<T>(fn: (tx: GroupSettlementTx) => Promise<T>): Promise<T> {
    return this.bookings.runTransaction(fn);
  }
}
