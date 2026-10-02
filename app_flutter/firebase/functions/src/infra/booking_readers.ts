/**
 * Firestore implementations of ServiceCatalog and CustomerContactReader.
 */

import type { Firestore } from 'firebase-admin/firestore';
import type {
  CustomerContactReader,
  CustomerContactRecord,
  ServiceCatalog,
  ServiceRecord,
} from '@photobooking/domain';

export class FirestoreServiceCatalog implements ServiceCatalog {
  constructor(private readonly firestore: Firestore) {}

  async getService(serviceId: string): Promise<ServiceRecord | null> {
    const snap = await this.firestore.collection('services').doc(serviceId).get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;

    return {
      id: snap.id,
      photographerId: d.photographerId ?? '',
      name: d.name ?? '',
      price: typeof d.price === 'number' ? d.price : 0,
      durationMinutes: typeof d.durationMinutes === 'number' ? d.durationMinutes : 60,
      active: d.active !== false,
    };
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
