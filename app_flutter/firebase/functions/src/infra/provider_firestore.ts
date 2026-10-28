import {
  FieldValue,
  GeoPoint,
  type Firestore,
  Timestamp,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  OPEN_RELATION_STATUSES,
  providerTypeOf,
  type ProviderProfile,
  type ProviderStore,
  type ProviderTx,
} from '@photobooking/domain';
import { BOOKINGS_COLLECTION, PAYMENTS_COLLECTION } from './booking_firestore.js';
import { PHOTOGRAPHERS_COLLECTION } from './review_firestore.js';

/** `studio_members/{studioId}_{memberId}_{createdAtMs}` (#136). */
const STUDIO_MEMBERS_COLLECTION = 'studio_members';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v !== '' ? v : null;
}

export class FirestoreProviderStore implements ProviderStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: ProviderTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const photographer = (uid: string) =>
        this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid);

      const tx: ProviderTx = {
        getProfile: async (uid): Promise<ProviderProfile | null> => {
          const snap = await fTx.get(photographer(uid));
          const d = snap.data();
          if (!snap.exists || !d) return null;
          return {
            uid,
            providerType: providerTypeOf(d.providerType),
            onboardingComplete: d.onboardingComplete === true,
            artistSince: toDate(d.artistSince),
            studioDistrict: str(d.studioDistrict),
            studioCity: str(d.studioCity),
            memberCount: typeof d.memberCount === 'number' ? d.memberCount : 0,
          };
        },
        countActiveBookings: async (uid) => {
          const snap = await fTx.get(
            this.firestore
              .collection(BOOKINGS_COLLECTION)
              .where('photographerId', '==', uid)
              .where('status', 'in', ['requested', 'accepted', 'upcoming', 'shooting'])
              .limit(1),
          );
          return snap.size;
        },
        countHeldPayments: async (uid) => {
          const snap = await fTx.get(
            this.firestore
              .collection(PAYMENTS_COLLECTION)
              .where('payeeId', '==', uid)
              .where('escrowStatus', 'in', ['held', 'partially_refunded', 'disputed'])
              .limit(1),
          );
          return snap.size;
        },
        countOpenRelations: async (uid) => {
          // As studio or as member (#136 Decision 7); one open relation is enough to refuse.
          const open = (field: 'studioId' | 'memberId') =>
            fTx.get(
              this.firestore
                .collection(STUDIO_MEMBERS_COLLECTION)
                .where(field, '==', uid)
                .where('status', 'in', [...OPEN_RELATION_STATUSES])
                .limit(1),
            );
          const [asStudio, asMember] = await Promise.all([open('studioId'), open('memberId')]);
          return asStudio.size + asMember.size;
        },
        setProviderType: (uid, type, now) => {
          fTx.set(
            photographer(uid),
            {
              providerType: type,
              ...(type === 'artist' ? {} : { artistSince: FieldValue.delete() }),
              updatedAt: Timestamp.fromDate(now),
            },
            { merge: true },
          );
        },
        setStudioAddress: (uid, a, now) => {
          const at = Timestamp.fromDate(now);
          fTx.set(photographer(uid).collection('private').doc('studioAddress'), {
            line: a.line,
            ward: a.ward,
            district: a.district,
            city: a.city,
            lat: a.lat,
            lng: a.lng,
            ...(a.lat !== null && a.lng !== null ? { point: new GeoPoint(a.lat, a.lng) } : {}),
            updatedAt: at,
          });
          fTx.set(
            photographer(uid),
            { studioDistrict: a.district, studioCity: a.city, updatedAt: at },
            { merge: true },
          );
        },
      };

      return fn(tx);
    });
  }
}
