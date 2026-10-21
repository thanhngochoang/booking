/**
 * Firestore implementations of ServiceCatalog and CustomerContactReader.
 */

import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { db } from './admin.js';
import { acceptsOrders } from '@photobooking/domain';
import type {
  CustomerContactReader,
  CustomerContactRecord,
  ProviderOrderGate,
  ServiceCatalog,
  ServiceRecord,
} from '@photobooking/domain';

export function serviceRecordOf(id: string, photographerId: string, d: DocumentData): ServiceRecord {
  const revisions = typeof d.deliverables?.revisions === 'number' ? d.deliverables.revisions : undefined;
  return {
    id,
    photographerId,
    name: d.name ?? '',
    price: typeof d.price === 'number' ? d.price : 0,
    durationMinutes: typeof d.durationMinutes === 'number' ? d.durationMinutes : 60,
    active: d.active !== false,
    ...(revisions !== undefined ? { revisions } : {}),
  };
}

export class FirestoreServiceCatalog implements ServiceCatalog {
  constructor(private readonly firestore: Firestore) {}

  /** Packages live at `photographers/{uid}/services/{id}` (written by the app, see firestore.rules). */
  async getService(photographerId: string, serviceId: string): Promise<ServiceRecord | null> {
    const snap = await this.firestore
      .collection('photographers').doc(photographerId)
      .collection('services').doc(serviceId)
      .get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;

    return serviceRecordOf(snap.id, photographerId, d);
  }
}

export class FirestoreCustomerContactReader implements CustomerContactReader {
  constructor(private readonly firestore: Firestore) {}

  async get(uid: string): Promise<CustomerContactRecord | null> {
    const snap = await this.firestore.collection('users').doc(uid).collection('private').doc('contact').get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;

    return {
      phone: typeof d.phone === 'string' ? d.phone : '',
      allowZalo: d.allowZalo === true,
      allowWhatsApp: d.allowWhatsApp === true,
      name: typeof d.name === 'string' ? d.name : undefined,
    };
  }
}

/**
 * Live gate for createBooking: the rule is computed from `verified` and `onboardingComplete`
 * (never from the derived `acceptingOrders` field, which a lagging trigger could leave stale).
 * A missing profile cannot take orders.
 */
export class FirestoreProviderOrderGate implements ProviderOrderGate {
  constructor(private readonly firestore: Firestore = db()) {}

  async acceptsOrders(photographerId: string): Promise<boolean> {
    const snap = await this.firestore.collection('photographers').doc(photographerId).get();
    if (!snap.exists) return false;
    const data = snap.data();
    if (data?.deletionPending === true) return false;
    return acceptsOrders(data);
  }
}
