import {
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  isAddonKind,
  isAddonUnit,
  type AddonCatalog,
  type AddonStore,
  type AddonTx,
  type ServiceAddon,
} from '@photobooking/domain';
import { db } from './admin.js';

/** `photographers/{uid}/addons/{id}`; the provider id comes from the path, never from the document. */
export function addonToFirestore(a: ServiceAddon): DocumentData {
  return {
    kind: a.kind,
    name: a.name,
    ...(a.description !== undefined ? { description: a.description } : {}),
    price: a.price,
    unit: a.unit,
    maxQty: a.maxQty,
    serviceIds: [...a.serviceIds],
    active: a.active,
    createdAt: Timestamp.fromDate(new Date(a.createdAt)),
    updatedAt: Timestamp.fromDate(new Date(a.updatedAt)),
  };
}

function iso(v: unknown): string {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  return new Date(0).toISOString();
}

export function addonFromFirestore(
  providerId: string,
  id: string,
  d: DocumentData | undefined,
): ServiceAddon | null {
  if (!d) return null;
  if (!isAddonKind(d.kind) || !isAddonUnit(d.unit)) return null;
  if (typeof d.name !== 'string' || typeof d.price !== 'number') return null;
  return {
    id,
    providerId,
    kind: d.kind,
    name: d.name,
    ...(typeof d.description === 'string' && d.description !== '' ? { description: d.description } : {}),
    price: d.price,
    unit: d.unit,
    maxQty: typeof d.maxQty === 'number' ? d.maxQty : 1,
    serviceIds: Array.isArray(d.serviceIds) ? d.serviceIds.filter((x): x is string => typeof x === 'string') : [],
    active: d.active === true,
    createdAt: iso(d.createdAt),
    updatedAt: iso(d.updatedAt),
  };
}

async function listAddonsOf(
  firestore: Firestore,
  read: (q: ReturnType<Firestore['collection']>) => Promise<FirebaseFirestore.QuerySnapshot>,
  providerId: string,
): Promise<ServiceAddon[]> {
  const snap = await read(firestore.collection('photographers').doc(providerId).collection('addons'));
  const out: ServiceAddon[] = [];
  for (const s of snap.docs) {
    const a = addonFromFirestore(providerId, s.id, s.data());
    if (a) out.push(a);
  }
  return out.sort((x, y) => (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
}

/**
 * Add-ons in Firestore. Every transaction reads the lock document `photographers/{uid}/private/addons`
 * and writes it back with the active count, so concurrent saves conflict and retry (Decision 8).
 * Writes are buffered until the callback has finished its reads (Admin SDK rule).
 */
export class FirestoreAddonStore implements AddonStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async runTransaction<T>(fn: (tx: AddonTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const providerRef = (uid: string): DocumentReference => this.firestore.collection('photographers').doc(uid);
      const lockRef = (uid: string): DocumentReference => providerRef(uid).collection('private').doc('addons');
      const addonRef = (uid: string, id: string): DocumentReference => providerRef(uid).collection('addons').doc(id);
      const writes: Array<() => void> = [];

      const tx: AddonTx = {
        isProvider: async (uid) => {
          const [photographer, user] = await Promise.all([
            fTx.get(providerRef(uid)),
            fTx.get(this.firestore.collection('users').doc(uid)),
          ]);
          return photographer.exists && user.data()?.role === 'photographer';
        },
        listAddons: (providerId) => listAddonsOf(this.firestore, (c) => fTx.get(c), providerId),
        lockProvider: async (providerId) => {
          await fTx.get(lockRef(providerId));
        },
        putAddon: (a) => {
          writes.push(() => {
            fTx.set(addonRef(a.providerId, a.id), addonToFirestore(a));
          });
        },
        deleteAddon: (providerId, addonId) => {
          writes.push(() => {
            fTx.delete(addonRef(providerId, addonId));
          });
        },
        setActiveCount: (providerId, n, now) => {
          writes.push(() => {
            fTx.set(
              lockRef(providerId),
              { activeCount: n, updatedAt: Timestamp.fromDate(new Date(now)) },
              { merge: true },
            );
          });
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}

/** Read side for createBooking (outside its transaction). */
export class FirestoreAddonCatalog implements AddonCatalog {
  constructor(private readonly firestore: Firestore = db()) {}

  listAddons(providerId: string): Promise<ServiceAddon[]> {
    return listAddonsOf(this.firestore, (c) => c.get(), providerId);
  }
}
