import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  isId,
  type BookingReader,
  type BookingRecord,
  type ContactAccessLogWriter,
  type ContactChannels,
  type ContactNumbers,
  type PhotographerContactReader,
  type UserContactReader,
} from '@photobooking/domain';

// Firestore adapters for the domain ports. Every read goes through `db.getAll` (one call = one
// round trip), so the read budget of each use case can be counted and asserted.

/** Firestore collection of `ContactAccessLog` (relational table `contact_access_log`). */
export const CONTACT_ACCESS_LOG = 'contact_access_log';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

/** Latest `timeline[]` entry with status `completed` (bookings have no `completedAt` field yet). */
export function lastCompletedAt(timeline: unknown): Date | null {
  if (!Array.isArray(timeline)) return null;
  let latest: Date | null = null;
  for (const entry of timeline) {
    if (typeof entry !== 'object' || entry === null) continue;
    const { status, at } = entry as { status?: unknown; at?: unknown };
    const when = toDate(at);
    if (status === 'completed' && when !== null && (latest === null || when > latest)) latest = when;
  }
  return latest;
}

export function bookingFromDoc(id: string, d: DocumentData | undefined): BookingRecord | null {
  if (d === undefined) return null;
  const customerId: unknown = d.customerId;
  const photographerId: unknown = d.photographerId;
  const status: unknown = d.status;
  if (!isId(customerId) || !isId(photographerId) || typeof status !== 'string') return null;
  return { id, customerId, photographerId, status, completedAt: toDate(d.completedAt) ?? lastCompletedAt(d.timeline) };
}

export function channelsFromDoc(d: DocumentData | undefined): ContactChannels | null {
  const raw: unknown = d?.contactChannels;
  if (typeof raw !== 'object' || raw === null) return null;
  const c = raw as Record<string, unknown>;
  return { call: c.call === true, zalo: c.zalo === true, whatsapp: c.whatsapp === true };
}

export function numbersFromDoc(d: DocumentData | undefined): ContactNumbers | null {
  if (d === undefined || typeof d.phone !== 'string') return null;
  return {
    phone: d.phone,
    zaloPhone: typeof d.zaloPhone === 'string' ? d.zaloPhone : null,
    whatsappPhone: typeof d.whatsappPhone === 'string' ? d.whatsappPhone : null,
  };
}

export function firestoreBookingReader(db: Firestore): BookingReader {
  return {
    async get(id) {
      const [snap] = await db.getAll(db.collection('bookings').doc(id));
      return bookingFromDoc(id, snap?.data());
    },
  };
}

export function firestorePhotographerContactReader(db: Firestore): PhotographerContactReader {
  return {
    async read(photographerId) {
      const [pub, priv] = await db.getAll(
        db.collection('photographers').doc(photographerId),
        db.doc(`photographers/${photographerId}/private/contact`),
      );
      return { channels: channelsFromDoc(pub?.data()), numbers: numbersFromDoc(priv?.data()) };
    },
  };
}

export function firestoreContactAccessLog(db: Firestore): ContactAccessLogWriter {
  return {
    async append(e) {
      await db.collection(CONTACT_ACCESS_LOG).doc(e.id).create({
        requesterId: e.requesterId,
        subjectType: e.subjectType,
        subjectId: e.subjectId,
        channel: e.channel,
        granted: e.granted,
        at: Timestamp.fromDate(e.at),
      });
    },
  };
}

export function firestoreUserContactReader(db: Firestore): UserContactReader {
  return {
    async get(uid) {
      const [snap] = await db.getAll(db.doc(`users/${uid}/private/contact`));
      const d = snap?.data();
      return d === undefined ? null : { phone: d.phone };
    },
  };
}
