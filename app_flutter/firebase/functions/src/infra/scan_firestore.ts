/**
 * S30 `scanPass` (#223 Decision 9) on Firestore: ONE real transaction over `passes`, `ticket_codes`, bookings,
 * events, registrations, `entry_days`, spots and the scanner's `gate_staff` rows. The domain reads the pass and
 * its parts first, then only the role documents those parts need (the booking's shooter, the events' managers,
 * the scanner's own gate-staff row of each candidate organizer, a venue spot's manager), and writes last.
 */

import { Timestamp, type Firestore, type Transaction } from 'firebase-admin/firestore';
import { entryDayId, type ScanStore, type ScanTx } from '@photobooking/domain';
import { BOOKINGS_COLLECTION, bookingFromFirestore, bookingToFirestore } from './booking_firestore.js';
import {
  ENTRY_DAYS,
  EVENTS_COLLECTION,
  TICKET_CODES,
  entryDayFromFirestore,
  entryDayToFirestore,
  eventFromFirestore,
  registrationFromFirestore,
  registrationToFirestore,
} from './event_firestore.js';
import {
  GATE_STAFF_SUBCOLLECTION,
  ORGANIZERS_COLLECTION,
  gateStaffFromFirestore,
  gateStaffToFirestore,
} from './organizer_firestore.js';
import { PASSES_COLLECTION, passFromFirestore, passToFirestore } from './pass_firestore.js';
import { SPOTS_COLLECTION, spotFromFirestore } from './spot_firestore.js';

const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

export class FirestoreScanStore implements ScanStore {
  constructor(private readonly firestore: Firestore) {}

  runTransaction<T>(fn: (tx: ScanTx) => Promise<T>): Promise<T> {
    const fs = this.firestore;
    return fs.runTransaction(async (fTx: Transaction) => {
      const regRef = (eventId: string, regId: string) =>
        fs.collection(EVENTS_COLLECTION).doc(eventId).collection('registrations').doc(regId);
      const staffRef = (organizerId: string, staffUid: string) =>
        fs.collection(ORGANIZERS_COLLECTION).doc(organizerId).collection(GATE_STAFF_SUBCOLLECTION).doc(staffUid);
      const dayRef = (eventId: string, day: string) => fs.collection(ENTRY_DAYS).doc(entryDayId(eventId, day));
      const tx: ScanTx = {
        getPass: async (code8) => passFromFirestore(code8, (await fTx.get(fs.collection(PASSES_COLLECTION).doc(code8))).data()),
        findTicket: async (code) => {
          const d = (await fTx.get(fs.collection(TICKET_CODES).doc(code))).data();
          const eventId = str(d?.eventId);
          const registrationId = str(d?.registrationId);
          return eventId !== null && registrationId !== null ? { eventId, registrationId } : null;
        },
        getBooking: async (id) => {
          const snap = await fTx.get(fs.collection(BOOKINGS_COLLECTION).doc(id));
          return bookingFromFirestore(snap.id, snap.data());
        },
        getEvent: async (id) => {
          const snap = await fTx.get(fs.collection(EVENTS_COLLECTION).doc(id));
          const d = snap.data();
          return snap.exists && d ? eventFromFirestore(id, d) : null;
        },
        getRegistration: async (eventId, regId) => {
          const snap = await fTx.get(regRef(eventId, regId));
          const d = snap.data();
          return snap.exists && d ? registrationFromFirestore(regId, d) : null;
        },
        getSpot: async (id) => {
          const snap = await fTx.get(fs.collection(SPOTS_COLLECTION).doc(id));
          return spotFromFirestore(snap.id, snap.data());
        },
        getEntryDay: async (eventId, day) => entryDayFromFirestore((await fTx.get(dayRef(eventId, day))).data()),
        getGateStaff: async (organizerId, staffUid) =>
          gateStaffFromFirestore(staffUid, (await fTx.get(staffRef(organizerId, staffUid))).data()),
        putPass: async (p) => {
          fTx.set(fs.collection(PASSES_COLLECTION).doc(p.code8), passToFirestore(p));
        },
        setBooking: async (b) => {
          fTx.set(fs.collection(BOOKINGS_COLLECTION).doc(b.id), bookingToFirestore(b));
        },
        addBookingEvent: async (e) => {
          fTx.set(fs.collection(BOOKINGS_COLLECTION).doc(e.bookingId).collection('events').doc(e.id), {
            status: e.status,
            at: Timestamp.fromDate(new Date(e.at)),
            actorId: e.actorId ?? null,
          });
        },
        putRegistration: async (r) => {
          fTx.set(regRef(r.eventId, r.id), registrationToFirestore(r));
        },
        putEntryDay: async (d) => {
          fTx.set(dayRef(d.eventId, d.day), entryDayToFirestore(d));
        },
        putGateStaff: async (organizerId, g) => {
          fTx.set(staffRef(organizerId, g.staffUid), gateStaffToFirestore(g));
        },
      };
      return fn(tx);
    });
  }
}
