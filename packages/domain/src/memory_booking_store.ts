/**
 * In-memory reference implementation of BookingStore.
 */

import type { Booking, BookingContactSnapshot, BookingEventRecord } from './booking.js';
import type { AvailabilityDayRecord, BookingStore, BookingTx } from './booking_ports.js';
import { parseVnDateTime } from './booking_policy.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';

export class MemoryBookingStore implements BookingStore {
  readonly bookings = new Map<string, Booking>();
  readonly availability = new Map<string, AvailabilityDayRecord>(); // key: `${photographerId}_${day}`
  readonly contacts = new Map<string, BookingContactSnapshot>();
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly ledgerEntries = new Map<string, LedgerEntry>();
  readonly events: BookingEventRecord[] = [];

  private availabilityKey(photographerId: string, day: string): string {
    return `${photographerId}_${day}`;
  }

  async runTransaction<T>(fn: (tx: BookingTx) => Promise<T>): Promise<T> {
    // Clone maps for transaction isolation if rollback is needed
    const tx: BookingTx = {
      getBooking: async (id) => this.getBooking(id),
      getAvailabilityDay: async (photographerId, day) => this.getAvailabilityDay(photographerId, day),
      getCustomerDraftForDay: async (customerId, photographerId, day) =>
        this.getCustomerDraftForDay(customerId, photographerId, day),
      setBooking: async (booking) => {
        this.bookings.set(booking.id, { ...booking });
      },
      deleteBooking: async (id) => {
        this.bookings.delete(id);
      },
      setAvailabilityDay: async (photographerId, day, record) => {
        this.availability.set(this.availabilityKey(photographerId, day), { ...record });
      },
      deleteAvailabilityDay: async (photographerId, day) => {
        this.availability.delete(this.availabilityKey(photographerId, day));
      },
      setContactSnapshot: async (bookingId, contact) => {
        this.contacts.set(bookingId, { ...contact });
      },
      getContactSnapshot: async (bookingId) => this.getContactSnapshot(bookingId),
      deleteContactSnapshot: async (bookingId) => {
        this.contacts.delete(bookingId);
      },
      getPayment: async (id) => this.getPayment(id),
      getPaymentByIdempotencyKey: async (key) => this.getPaymentByIdempotencyKey(key),
      setPayment: async (payment) => {
        this.payments.set(payment.id, { ...payment });
      },
      addRefund: async (refund) => {
        this.refunds.set(refund.id, { ...refund });
      },
      addLedgerEntry: async (entry) => {
        this.ledgerEntries.set(entry.id, { ...entry });
      },
      addBookingEvent: async (event) => {
        this.events.push({ ...event });
      },
    };

    return fn(tx);
  }

  async getBooking(id: string): Promise<Booking | null> {
    const b = this.bookings.get(id);
    return b ? { ...b } : null;
  }

  async deleteBooking(id: string): Promise<void> {
    this.bookings.delete(id);
  }

  async getAvailabilityDay(photographerId: string, day: string): Promise<AvailabilityDayRecord | null> {
    const a = this.availability.get(this.availabilityKey(photographerId, day));
    return a ? { ...a } : null;
  }

  async setAvailabilityDay(photographerId: string, day: string, record: AvailabilityDayRecord): Promise<void> {
    this.availability.set(this.availabilityKey(photographerId, day), { ...record });
  }

  async getCustomerDraftForDay(
    customerId: string,
    photographerId: string,
    day: string,
  ): Promise<Booking | null> {
    for (const b of this.bookings.values()) {
      if (
        b.customerId === customerId &&
        b.photographerId === photographerId &&
        b.day === day &&
        b.status === 'draft'
      ) {
        return { ...b };
      }
    }
    return null;
  }

  async getContactSnapshot(bookingId: string): Promise<BookingContactSnapshot | null> {
    const c = this.contacts.get(bookingId);
    return c ? { ...c } : null;
  }

  async getPayment(id: string): Promise<Payment | null> {
    const p = this.payments.get(id);
    return p ? { ...p } : null;
  }

  async getPaymentByIdempotencyKey(key: string): Promise<Payment | null> {
    for (const p of this.payments.values()) {
      if (p.idempotencyKey === key) {
        return { ...p };
      }
    }
    return null;
  }

  async getPaymentsForBooking(bookingId: string): Promise<readonly Payment[]> {
    const res: Payment[] = [];
    for (const p of this.payments.values()) {
      if (p.subjectType === 'booking' && p.subjectId === bookingId) {
        res.push({ ...p });
      }
    }
    return res;
  }

  async getRefundsForPayment(paymentId: string): Promise<readonly Refund[]> {
    const res: Refund[] = [];
    for (const r of this.refunds.values()) {
      if (r.paymentId === paymentId) {
        res.push({ ...r });
      }
    }
    return res;
  }

  async getLedgerEntriesForPayment(paymentId: string): Promise<readonly LedgerEntry[]> {
    const res: LedgerEntry[] = [];
    for (const e of this.ledgerEntries.values()) {
      if (e.paymentId === paymentId) {
        res.push({ ...e });
      }
    }
    return res;
  }

  async findUnpaidDraftsOlderThan(cutoff: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'draft' && new Date(b.createdAt).getTime() <= cutoff.getTime()) {
        res.push({ ...b });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findExpiredRequests(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (
        b.status === 'requested' &&
        b.acceptDeadline &&
        new Date(b.acceptDeadline).getTime() <= now.getTime()
      ) {
        res.push({ ...b });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findUpcomingTransitions(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'accepted') {
        const startsAt = parseVnDateTime(b.day, b.start);
        const hoursLeft = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
        if (hoursLeft <= 24) {
          res.push({ ...b });
          if (res.length >= limit) break;
        }
      }
    }
    return res;
  }

  async findAutoCompletions(cutoff: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'upcoming' || b.status === 'accepted') {
        const endsAt = parseVnDateTime(b.day, b.end);
        // cutoff is now - 24 hours
        if (endsAt.getTime() <= cutoff.getTime()) {
          res.push({ ...b });
          if (res.length >= limit) break;
        }
      }
    }
    return res;
  }

  async findReleasableEscrows(cutoff: Date, limit = 100): Promise<readonly Payment[]> {
    const res: Payment[] = [];
    for (const p of this.payments.values()) {
      if (
        (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded') &&
        p.releaseAfter &&
        new Date(p.releaseAfter).getTime() <= cutoff.getTime()
      ) {
        res.push({ ...p });
        if (res.length >= limit) break;
      }
    }
    return res;
  }
}
