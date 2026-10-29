/**
 * Firestore mapping and SpotScheduleStore implementation for Firebase Cloud Functions.
 */

import {
  Timestamp,
  GeoPoint,
  type DocumentData,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  type Spot,
  type SpotAccess,
  type SpotOpenHours,
  type SpotSchedule,
  type SlotOffer,
  type SpotDay,
  type SpotInterval,
  type SpotScheduleStore,
  type SpotScheduleTx,
  type AvailabilityDayRecord,
  type ServiceRecord,
  scheduleLastDay,
  scheduleReachesDay,
} from '@photobooking/domain';
import { db } from './admin.js';
import { serviceRecordOf } from './booking_readers.js';

export const SPOTS_COLLECTION = 'spots';
export const SPOT_SCHEDULES_COLLECTION = 'spot_schedules';
export const SPOT_SLOT_OFFERS_COLLECTION = 'spot_slot_offers';
export const SPOT_DAYS_COLLECTION = 'spot_days';
export const AVAILABILITY_COLLECTION = 'availability';

function toIsoString(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return null;
}

function toTimestamp(iso: string | null | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

/** `spots/{id}.access` (S30, #223); a malformed block reads as null (unknown fees). */
function accessFromFirestore(v: unknown): SpotAccess | null {
  if (!v || typeof v !== 'object') return null;
  const a = v as Record<string, unknown>;
  if (a.type !== 'open' && a.type !== 'ticket') return null;
  if (a.source !== 'staff' && a.source !== 'organizer') return null;
  const updatedAt = toIsoString(a.updatedAt);
  if (!updatedAt) return null;
  const fees = Array.isArray(a.fees)
    ? a.fees.flatMap((f: unknown) => {
        const x = f && typeof f === 'object' ? (f as Record<string, unknown>) : {};
        return typeof x.label === 'string' && typeof x.amountVnd === 'number' ? [{ label: x.label, amountVnd: x.amountVnd }] : [];
      })
    : [];
  return { type: a.type, fees, note: typeof a.note === 'string' ? a.note : '', updatedAt, source: a.source };
}

function openHoursFromFirestore(v: unknown): SpotOpenHours | null {
  if (!v || typeof v !== 'object') return null;
  const h = v as Record<string, unknown>;
  return typeof h.start === 'string' && typeof h.end === 'string' ? { start: h.start, end: h.end } : null;
}

export function spotFromFirestore(id: string, d: DocumentData | undefined): Spot | null {
  if (!d) return null;
  const status = d.status;
  if (status !== 'active' && status !== 'archived') return null;

  const lat =
    typeof d.point?.latitude === 'number'
      ? d.point.latitude
      : typeof d.point?.lat === 'number'
        ? d.point.lat
        : undefined;
  const lng =
    typeof d.point?.longitude === 'number'
      ? d.point.longitude
      : typeof d.point?.lng === 'number'
        ? d.point.lng
        : undefined;
  if (lat === undefined || lng === undefined) return null;

  const createdAt = toIsoString(d.createdAt);
  const updatedAt = toIsoString(d.updatedAt);
  if (!createdAt || !updatedAt) return null;

  const stats =
    d.stats && typeof d.stats === 'object'
      ? {
          posts14d: typeof d.stats.posts14d === 'number' ? d.stats.posts14d : 0,
          events: typeof d.stats.events === 'number' ? d.stats.events : 0,
          bookings14d: typeof d.stats.bookings14d === 'number' ? d.stats.bookings14d : 0,
          openSchedules: typeof d.stats.openSchedules === 'number' ? d.stats.openSchedules : 0,
          providersWeek: typeof d.stats.providersWeek === 'number' ? d.stats.providersWeek : 0,
          providersWeekend: typeof d.stats.providersWeekend === 'number' ? d.stats.providersWeekend : 0,
        }
      : {
          posts14d: 0,
          events: 0,
          bookings14d: 0,
          openSchedules: 0,
          providersWeek: 0,
          providersWeekend: 0,
        };

  const cover =
    d.cover &&
    typeof d.cover === 'object' &&
    typeof d.cover.url === 'string' &&
    typeof d.cover.cardUrl === 'string' &&
    typeof d.cover.path === 'string'
      ? { url: d.cover.url, cardUrl: d.cover.cardUrl, path: d.cover.path }
      : null;

  return {
    id,
    name: typeof d.name === 'string' ? d.name : '',
    city: typeof d.city === 'string' ? d.city : '',
    areaCode: typeof d.areaCode === 'string' ? d.areaCode : '',
    point: { lat, lng },
    geohash: typeof d.geohash === 'string' ? d.geohash : '',
    radiusM: typeof d.radiusM === 'number' ? d.radiusM : 1000,
    cover,
    description: typeof d.description === 'string' ? d.description : '',
    tips: Array.isArray(d.tips) ? d.tips.filter((t: unknown): t is string => typeof t === 'string') : [],
    seasonMonths: Array.isArray(d.seasonMonths)
      ? d.seasonMonths.filter((m: unknown): m is number => typeof m === 'number')
      : [],
    pinned: d.pinned === true,
    hidden: d.hidden === true,
    status,
    hotScore: typeof d.hotScore === 'number' ? d.hotScore : 0,
    stats,
    createdAt,
    updatedAt,
    rankedAt: toIsoString(d.rankedAt),
    updatedBy: typeof d.updatedBy === 'string' ? d.updatedBy : 'system',
    managedBy: typeof d.managedBy === 'string' && d.managedBy !== '' ? d.managedBy : null,
    access: accessFromFirestore(d.access),
    openHours: openHoursFromFirestore(d.openHours),
  };
}

export function spotToFirestore(s: Spot): DocumentData {
  return {
    name: s.name,
    city: s.city,
    areaCode: s.areaCode,
    point: new GeoPoint(s.point.lat, s.point.lng),
    geohash: s.geohash,
    radiusM: s.radiusM,
    cover: s.cover ? { url: s.cover.url, cardUrl: s.cover.cardUrl, path: s.cover.path } : null,
    description: s.description,
    tips: [...s.tips],
    seasonMonths: [...s.seasonMonths],
    pinned: s.pinned,
    hidden: s.hidden,
    status: s.status,
    hotScore: s.hotScore,
    stats: { ...s.stats },
    createdAt: toTimestamp(s.createdAt),
    updatedAt: toTimestamp(s.updatedAt),
    rankedAt: toTimestamp(s.rankedAt),
    updatedBy: s.updatedBy,
    managedBy: s.managedBy,
    access: s.access
      ? {
          type: s.access.type,
          fees: s.access.fees.map((f) => ({ label: f.label, amountVnd: f.amountVnd })),
          note: s.access.note,
          updatedAt: toTimestamp(s.access.updatedAt),
          source: s.access.source,
        }
      : null,
    openHours: s.openHours ? { start: s.openHours.start, end: s.openHours.end } : null,
  };
}

export function scheduleFromFirestore(id: string, d: DocumentData | undefined): SpotSchedule | null {
  if (!d) return null;
  const status = d.status;
  if (status !== 'open' && status !== 'cancelled') return null;

  const createdAt = toIsoString(d.createdAt);
  const updatedAt = toIsoString(d.updatedAt);
  if (!createdAt || !updatedAt) return null;

  const wStart = typeof d.window?.start === 'string' ? d.window.start : '';
  const wEnd = typeof d.window?.end === 'string' ? d.window.end : '';
  if (!wStart || !wEnd) return null;

  return {
    id,
    providerId: typeof d.providerId === 'string' ? d.providerId : '',
    assigneeId: typeof d.assigneeId === 'string' ? d.assigneeId : null,
    spotId: typeof d.spotId === 'string' ? d.spotId : '',
    days: Array.isArray(d.days) ? d.days.filter((x: unknown): x is string => typeof x === 'string') : [],
    window: { start: wStart, end: wEnd },
    serviceIds: Array.isArray(d.serviceIds)
      ? d.serviceIds.filter((x: unknown): x is string => typeof x === 'string')
      : [],
    priceFrom: typeof d.priceFrom === 'number' ? d.priceFrom : null,
    status,
    createdAt,
    updatedAt,
    // Older documents have no lastDay: scheduleLastDay falls back to days.
    ...(typeof d.lastDay === 'string' ? { lastDay: d.lastDay } : {}),
  };
}

export function scheduleToFirestore(s: SpotSchedule): DocumentData {
  return {
    providerId: s.providerId,
    assigneeId: s.assigneeId ?? null,
    spotId: s.spotId,
    days: [...s.days],
    window: { start: s.window.start, end: s.window.end },
    serviceIds: [...s.serviceIds],
    priceFrom: s.priceFrom ?? null,
    status: s.status,
    createdAt: toTimestamp(s.createdAt),
    updatedAt: toTimestamp(s.updatedAt),
    // Always written (from days when the caller left it out) so the
    // "open with a day from today" queries are one range on lastDay.
    lastDay: scheduleLastDay(s),
  };
}

export function offerFromFirestore(id: string, d: DocumentData | undefined): SlotOffer | null {
  if (!d) return null;
  const status = d.status;
  if (status !== 'open' && status !== 'closed') return null;

  const createdAt = toIsoString(d.createdAt);
  const updatedAt = toIsoString(d.updatedAt);
  if (!createdAt || !updatedAt) return null;

  return {
    id,
    providerId: typeof d.providerId === 'string' ? d.providerId : '',
    scheduleId: typeof d.scheduleId === 'string' ? d.scheduleId : '',
    spotId: typeof d.spotId === 'string' ? d.spotId : '',
    name: typeof d.name === 'string' ? d.name : '',
    price: typeof d.price === 'number' ? d.price : 0,
    slotMinutes: typeof d.slotMinutes === 'number' ? d.slotMinutes : 30,
    gapMinutes: typeof d.gapMinutes === 'number' ? d.gapMinutes : 0,
    photoCount: typeof d.photoCount === 'number' ? d.photoCount : 0,
    editedCount: typeof d.editedCount === 'number' ? d.editedCount : 0,
    deliveryDays: typeof d.deliveryDays === 'number' ? d.deliveryDays : 7,
    status,
    createdAt,
    updatedAt,
  };
}

export function offerToFirestore(o: SlotOffer): DocumentData {
  return {
    providerId: o.providerId,
    scheduleId: o.scheduleId,
    spotId: o.spotId,
    name: o.name,
    price: o.price,
    slotMinutes: o.slotMinutes,
    gapMinutes: o.gapMinutes,
    photoCount: o.photoCount,
    editedCount: o.editedCount,
    deliveryDays: o.deliveryDays,
    status: o.status,
    createdAt: toTimestamp(o.createdAt),
    updatedAt: toTimestamp(o.updatedAt),
  };
}

export function spotDayFromFirestore(d: DocumentData | undefined): SpotDay | null {
  if (!d) return null;
  const scheduleId = typeof d.scheduleId === 'string' ? d.scheduleId : '';
  const spotId = typeof d.spotId === 'string' ? d.spotId : '';
  const providerId = typeof d.providerId === 'string' ? d.providerId : '';
  const day = typeof d.day === 'string' ? d.day : '';
  if (!scheduleId || !day) return null;

  const taken: SpotInterval[] = [];
  if (Array.isArray(d.taken)) {
    for (const item of d.taken) {
      if (item && typeof item === 'object' && typeof item.start === 'string' && typeof item.end === 'string') {
        taken.push({
          start: item.start,
          end: item.end,
          ...(typeof item.offerId === 'string' ? { offerId: item.offerId } : {}),
        });
      }
    }
  }

  const updatedAt = toIsoString(d.updatedAt) ?? new Date().toISOString();

  return {
    scheduleId,
    spotId,
    providerId,
    day,
    taken,
    updatedAt,
  };
}

export function spotDayToFirestore(d: SpotDay): DocumentData {
  return {
    scheduleId: d.scheduleId,
    spotId: d.spotId,
    providerId: d.providerId,
    day: d.day,
    taken: d.taken.map((t) => ({
      start: t.start,
      end: t.end,
      ...(t.offerId !== undefined ? { offerId: t.offerId } : {}),
    })),
    updatedAt: toTimestamp(d.updatedAt),
  };
}

export class FirestoreSpotScheduleStore implements SpotScheduleStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async runTransaction<T>(fn: (tx: SpotScheduleTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx: SpotScheduleTx = {
        lockProvider: async (providerId: string): Promise<void> => {
          await fTx.get(this.firestore.doc(`photographers/${providerId}/private/spot_schedules`));
        },
        getSpot: async (id: string): Promise<Spot | null> => {
          const snap = await fTx.get(this.firestore.collection(SPOTS_COLLECTION).doc(id));
          return spotFromFirestore(snap.id, snap.data());
        },
        getSchedule: async (id: string): Promise<SpotSchedule | null> => {
          const snap = await fTx.get(this.firestore.collection(SPOT_SCHEDULES_COLLECTION).doc(id));
          return scheduleFromFirestore(snap.id, snap.data());
        },
        openSchedulesOf: async (providerId: string, today: string): Promise<SpotSchedule[]> => {
          // Only schedules still reaching today (≤ 8 by the limit), never the
          // provider's whole history; index (providerId, status, lastDay).
          const snap = await fTx.get(
            this.firestore
              .collection(SPOT_SCHEDULES_COLLECTION)
              .where('providerId', '==', providerId)
              .where('status', '==', 'open')
              .where('lastDay', '>=', today),
          );
          const out: SpotSchedule[] = [];
          for (const doc of snap.docs) {
            const s = scheduleFromFirestore(doc.id, doc.data());
            if (s && scheduleReachesDay(s, today)) {
              out.push(s);
            }
          }
          return out;
        },
        activeServices: async (providerId: string): Promise<ServiceRecord[]> => {
          const snap = await fTx.get(
            this.firestore
              .collection('photographers')
              .doc(providerId)
              .collection('services')
              .where('active', '==', true),
          );
          return snap.docs.map((doc) => serviceRecordOf(doc.id, providerId, doc.data()));
        },
        availability: async (uid: string, day: string): Promise<AvailabilityDayRecord | null> => {
          const snap = await fTx.get(this.firestore.doc(`availability/${uid}/days/${day}`));
          if (!snap.exists) return null;
          const d = snap.data();
          if (!d) return null;
          return {
            state: d.state,
            bookingId: typeof d.bookingId === 'string' ? d.bookingId : undefined,
            scheduleId: typeof d.scheduleId === 'string' ? d.scheduleId : undefined,
            spotId: typeof d.spotId === 'string' ? d.spotId : undefined,
          };
        },
        getSpotDay: async (scheduleId: string, day: string): Promise<SpotDay | null> => {
          const snap = await fTx.get(this.firestore.collection(SPOT_DAYS_COLLECTION).doc(`${scheduleId}_${day}`));
          return spotDayFromFirestore(snap.data());
        },
        offersOf: async (scheduleId: string): Promise<SlotOffer[]> => {
          const snap = await fTx.get(
            this.firestore.collection(SPOT_SLOT_OFFERS_COLLECTION).where('scheduleId', '==', scheduleId),
          );
          const out: SlotOffer[] = [];
          for (const doc of snap.docs) {
            const o = offerFromFirestore(doc.id, doc.data());
            if (o) out.push(o);
          }
          return out;
        },
        getOffer: async (id: string): Promise<SlotOffer | null> => {
          const snap = await fTx.get(this.firestore.collection(SPOT_SLOT_OFFERS_COLLECTION).doc(id));
          return offerFromFirestore(snap.id, snap.data());
        },
        putSchedule: (s: SpotSchedule): void => {
          fTx.set(this.firestore.collection(SPOT_SCHEDULES_COLLECTION).doc(s.id), scheduleToFirestore(s));
        },
        putOffer: (o: SlotOffer): void => {
          fTx.set(this.firestore.collection(SPOT_SLOT_OFFERS_COLLECTION).doc(o.id), offerToFirestore(o));
        },
        touchLock: (providerId: string, now: string): void => {
          fTx.set(
            this.firestore.doc(`photographers/${providerId}/private/spot_schedules`),
            { updatedAt: toTimestamp(now) },
            { merge: true },
          );
        },
        setSpotAvailability: (uid: string, day: string, rec: { scheduleId: string; spotId: string }, now: string): void => {
          fTx.set(this.firestore.doc(`availability/${uid}/days/${day}`), {
            state: 'spot',
            scheduleId: rec.scheduleId,
            spotId: rec.spotId,
            updatedAt: toTimestamp(now),
          });
        },
        deleteAvailability: (uid: string, day: string): void => {
          fTx.delete(this.firestore.doc(`availability/${uid}/days/${day}`));
        },
      };

      return fn(tx);
    });
  }
}
