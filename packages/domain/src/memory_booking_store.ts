/**
 * In-memory reference implementation of BookingStore.
 */

import type { Booking, BookingContactSnapshot, BookingEventRecord } from './booking.js';
import type {
  AvailabilityDayRecord,
  StudioBookingStore,
  StudioBookingTx,
  StudioCounterField,
  StudioDayLoad,
  TransferRecord,
} from './booking_ports.js';
import { parseVnDateTime } from './booking_policy.js';
import type { DeliveryRound, DeliverySample, PrivateDelivery } from './delivery.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { Spot } from './spot.js';
import type { SpotSchedule } from './spot_schedule.js';
import type { SlotOffer } from './spot_slots.js';
import type { SpotDay } from './spot_booking.js';

export class MemoryBookingStore implements StudioBookingStore {
  readonly bookings = new Map<string, Booking>();
  readonly availability = new Map<string, AvailabilityDayRecord>(); // key: `${photographerId}_${day}`
  readonly contacts = new Map<string, BookingContactSnapshot>();
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly ledgerEntries = new Map<string, LedgerEntry>();
  readonly events: BookingEventRecord[] = [];
  readonly transferRecords = new Map<string, TransferRecord>();
  readonly deliveries = new Map<string, DeliveryRound>(); // key: `${bookingId}_${round}`
  readonly deliverySamples = new Map<string, DeliverySample>(); // key: `${bookingId}_${fileId}`
  readonly privateDeliveries = new Map<string, PrivateDelivery>(); // key: bookingId
  /** studio_day_load, key `${studioId}_${day}`. */
  readonly studioDayLoads = new Map<string, StudioDayLoad>();
  /** Active member uids per studio (the store's view of `photographers where studioId == X`). */
  readonly studioMembers = new Map<string, string[]>();
  /** Counters on `photographers/{studioId}`. */
  readonly studioCounters = new Map<string, Partial<Record<StudioCounterField, number>>>();
  /** Whether a member may be assigned (verified and onboarded); a test world wires it to its provider gate. */
  memberVerified: (uid: string) => boolean = () => true;

  counterOf(studioId: string, field: StudioCounterField): number {
    return this.studioCounters.get(studioId)?.[field] ?? 0;
  }

  getStudioDayLoad(studioId: string, day: string): StudioDayLoad | null {
    const l = this.studioDayLoads.get(`${studioId}_${day}`);
    return l ? { ...l, unassignedIds: [...l.unassignedIds], assignedIds: [...l.assignedIds] } : null;
  }
  readonly spots = new Map<string, Spot>();
  readonly schedules = new Map<string, SpotSchedule>();
  readonly offers = new Map<string, SlotOffer>();
  readonly spotDays = new Map<string, SpotDay>(); // key: `${scheduleId}_${day}`

  private txTail: Promise<unknown> = Promise.resolve();

  private availabilityKey(photographerId: string, day: string): string {
    return `${photographerId}_${day}`;
  }

  async runTransaction<T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> {
    const run = async () => {
      const tx: StudioBookingTx = {
        incrementStudioCounter: (studioId, field) => {
          const c = { ...(this.studioCounters.get(studioId) ?? {}) };
          c[field] = (c[field] ?? 0) + 1;
          this.studioCounters.set(studioId, c);
        },
        getStudioDayLoad: async (studioId, day) => this.getStudioDayLoad(studioId, day),
        setStudioDayLoad: async (load) => {
          this.studioDayLoads.set(`${load.studioId}_${load.day}`, {
            ...load,
            unassignedIds: [...load.unassignedIds],
            assignedIds: [...load.assignedIds],
          });
        },
        getMemberStudio: async (uid) => {
          for (const [studioId, members] of this.studioMembers) if (members.includes(uid)) return studioId;
          return null;
        },
        getMemberDays: async (studioId, day) =>
          (this.studioMembers.get(studioId) ?? []).map((uid) => ({
            uid,
            verified: this.memberVerified(uid),
            free: !this.availability.has(this.availabilityKey(uid, day)),
          })),
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
        getRefund: async (id) => this.getRefund(id),
        addRefund: async (refund) => {
          this.refunds.set(refund.id, { ...refund });
        },
        addLedgerEntry: async (entry) => {
          this.ledgerEntries.set(entry.id, { ...entry });
        },
        addBookingEvent: async (event) => {
          this.events.push({ ...event });
        },
        getTransferRecord: async (id) => this.getTransferRecord(id),
        saveTransferRecord: async (record) => {
          this.transferRecords.set(record.id, { ...record });
        },
        getDelivery: async (bookingId, round) => {
          const d = this.deliveries.get(`${bookingId}_${round}`);
          return d ? { ...d } : null;
        },
        setDelivery: async (d) => {
          this.deliveries.set(`${d.bookingId}_${d.round}`, { ...d });
        },
        getDeliverySamples: async (bookingId, fileIds) => {
          return fileIds.map((fid) => {
            const s = this.deliverySamples.get(`${bookingId}_${fid}`);
            return s ? { ...s } : null;
          });
        },
        deleteDeliverySamples: async (bookingId, fileIds) => {
          for (const fid of fileIds) {
            this.deliverySamples.delete(`${bookingId}_${fid}`);
          }
        },
        setPrivateDelivery: async (bookingId, p) => {
          this.privateDeliveries.set(bookingId, { ...p });
        },
        getPrivateDelivery: async (bookingId) => {
          const p = this.privateDeliveries.get(bookingId);
          return p ? { ...p } : null;
        },
        getSpot: async (id) => this.getSpot(id),
        getSpotSchedule: async (id) => this.getSpotSchedule(id),
        getSlotOffer: async (id) => this.getSlotOffer(id),
        getSpotDay: async (scheduleId, day) => this.getSpotDay(scheduleId, day),
        setSpotDay: async (spotDay) => this.setSpotDay(spotDay),
      };

      return fn(tx);
    };

    const next = this.txTail.then(run, run);
    this.txTail = next;
    return next as Promise<T>;
  }

  async getSpot(id: string): Promise<Spot | null> {
    const s = this.spots.get(id);
    return s ? { ...s } : null;
  }

  async getSpotSchedule(id: string): Promise<SpotSchedule | null> {
    const s = this.schedules.get(id);
    return s ? { ...s } : null;
  }

  async getSlotOffer(id: string): Promise<SlotOffer | null> {
    const o = this.offers.get(id);
    return o ? { ...o } : null;
  }

  async getSpotDay(scheduleId: string, day: string): Promise<SpotDay | null> {
    const d = this.spotDays.get(`${scheduleId}_${day}`);
    return d ? { ...d } : null;
  }

  async setSpotDay(spotDay: SpotDay): Promise<void> {
    this.spotDays.set(`${spotDay.scheduleId}_${spotDay.day}`, { ...spotDay });
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

  async getRefund(id: string): Promise<Refund | null> {
    const r = this.refunds.get(id);
    return r ? { ...r } : null;
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

  async findPendingRefunds(before: Date, limit = 100): Promise<readonly Refund[]> {
    const res: Refund[] = [];
    for (const r of this.refunds.values()) {
      if (
        r.status === 'pending' &&
        r.lastAttemptAt &&
        Date.parse(r.lastAttemptAt) <= before.getTime()
      ) {
        res.push({ ...r });
      }
    }
    res.sort((a, b) => Date.parse(a.lastAttemptAt ?? '') - Date.parse(b.lastAttemptAt ?? ''));
    return res.slice(0, limit);
  }

  async awaitingRefundsDue(now: Date, limit: number): Promise<readonly Refund[]> {
    const res: Refund[] = [];
    for (const r of this.refunds.values()) {
      if (
        r.status === 'awaiting_account' &&
        r.confirmBy &&
        Date.parse(r.confirmBy) <= now.getTime()
      ) {
        res.push({ ...r });
      }
    }
    res.sort((a, b) => Date.parse(a.confirmBy ?? '') - Date.parse(b.confirmBy ?? ''));
    return res.slice(0, limit);
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

  async findPaymentsByTransferCode(code: string): Promise<readonly Payment[]> {
    return [...this.payments.values()].filter((p) => p.transferCode === code).map((p) => ({ ...p }));
  }

  async getTransferRecord(id: string): Promise<TransferRecord | null> {
    const r = this.transferRecords.get(id);
    return r ? { ...r } : null;
  }

  async findPaymentsToReconcile(createdBefore: Date, limit = 100): Promise<readonly Payment[]> {
    const res: Payment[] = [];
    for (const p of this.payments.values()) {
      if (
        p.subjectType === 'booking' &&
        p.status === 'created' &&
        new Date(p.createdAt).getTime() <= createdBefore.getTime()
      ) {
        res.push({ ...p });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findOverduePayments(now: Date, limit = 100): Promise<readonly Payment[]> {
    const res: Payment[] = [];
    for (const p of this.payments.values()) {
      if (p.status === 'created' && p.expiresAt && new Date(p.expiresAt).getTime() <= now.getTime()) {
        res.push({ ...p });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findExpiredDrafts(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'draft' && b.payableUntil && new Date(b.payableUntil).getTime() <= now.getTime()) {
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
      if ((b.status === 'upcoming' || b.status === 'accepted') && !(b.isStudio === true && !b.assigneeId)) {
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

  async findDueAutoApprovals(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'delivered' && b.autoApproveAt && new Date(b.autoApproveAt).getTime() <= now.getTime()) {
        res.push({ ...b });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findDueChecks(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    for (const b of this.bookings.values()) {
      if (b.status === 'approved' && b.checkUntil && new Date(b.checkUntil).getTime() <= now.getTime()) {
        res.push({ ...b });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findDueAutoApproveNotices(now: Date, limit = 100): Promise<readonly Booking[]> {
    const res: Booking[] = [];
    const threshold = now.getTime() + 24 * 60 * 60 * 1000;
    for (const b of this.bookings.values()) {
      if (
        b.status === 'delivered' &&
        (b.autoApproveNoticeAt === null || b.autoApproveNoticeAt === undefined) &&
        b.autoApproveAt &&
        new Date(b.autoApproveAt).getTime() <= threshold
      ) {
        res.push({ ...b });
        if (res.length >= limit) break;
      }
    }
    return res;
  }

  async findUnassignedStudioBookingsDue(now: Date, limit: number): Promise<readonly Booking[]> {
    const horizon = now.getTime() + 24 * 60 * 60 * 1000;
    return [...this.bookings.values()]
      .filter(
        (b) =>
          b.isStudio === true &&
          b.assignStatus === 'unassigned' &&
          b.assignOverdue !== true &&
          (b.status === 'requested' || b.status === 'accepted') &&
          b.assignDeadline !== undefined &&
          Date.parse(b.assignDeadline) <= horizon,
      )
      .sort((a, b) => Date.parse(a.assignDeadline ?? '') - Date.parse(b.assignDeadline ?? ''))
      .slice(0, limit)
      .map((b) => ({ ...b }));
  }

  async findUnassignedStudioBookingsStarted(now: Date, limit: number): Promise<readonly Booking[]> {
    const startOf = (b: Booking) => parseVnDateTime(b.day, b.start).getTime();
    return [...this.bookings.values()]
      .filter(
        (b) =>
          b.isStudio === true &&
          b.assignStatus === 'unassigned' &&
          (b.status === 'requested' || b.status === 'accepted') &&
          startOf(b) <= now.getTime(),
      )
      .sort((a, b) => startOf(a) - startOf(b))
      .slice(0, limit)
      .map((b) => ({ ...b }));
  }

  async findDueChangeRequests(now: Date, limit: number): Promise<readonly Booking[]> {
    return [...this.bookings.values()]
      .filter((b) => b.changeRequest?.status === 'pending' && Date.parse(b.changeRequest.respondBy) <= now.getTime())
      .sort((a, b) => Date.parse(a.changeRequest?.respondBy ?? '') - Date.parse(b.changeRequest?.respondBy ?? ''))
      .slice(0, limit)
      .map((b) => ({ ...b }));
  }
}
