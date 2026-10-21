/**
 * Firestore implementations of SpotCounter, SpotRankStore, and SpotAdminStore.
 */

import {
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  type Spot,
  type SpotCounter,
  type SpotRankStore,
  type SpotRankings,
  type DirectoryEntry,
  type SpotAdminStore,
} from '@photobooking/domain';
import { db } from './admin.js';
import { spotFromFirestore, spotToFirestore } from './spot_firestore.js';

export const SPOT_RANKINGS_COLLECTION = 'spot_rankings';
export const SPOT_DIRECTORY_COLLECTION = 'spot_directory';
export const SPOTS_COLLECTION = 'spots';

export class FirestoreSpotCounter implements SpotCounter {
  constructor(private readonly firestore: Firestore = db()) {}

  async posts(spotId: string, sinceIso: string): Promise<number> {
    const snap = await this.firestore
      .collection('posts')
      .where('spotId', '==', spotId)
      .where('createdAt', '>=', Timestamp.fromDate(new Date(sinceIso)))
      .count()
      .get();
    return snap.data().count;
  }

  async events(spotId: string, fromIso: string, toIso: string): Promise<number> {
    const snap = await this.firestore
      .collection('events')
      .where('spotId', '==', spotId)
      .where('status', 'in', ['open', 'full'])
      .where('startAt', '>=', Timestamp.fromDate(new Date(fromIso)))
      .where('startAt', '<=', Timestamp.fromDate(new Date(toIso)))
      .count()
      .get();
    return snap.data().count;
  }

  async paidBookings(spotId: string, sinceIso: string): Promise<number> {
    const snap = await this.firestore
      .collection('bookings')
      .where('spotId', '==', spotId)
      .where('depositPaidAt', '>=', Timestamp.fromDate(new Date(sinceIso)))
      .count()
      .get();
    return snap.data().count;
  }

  async schedulesWithDay(spotId: string, days: readonly string[]): Promise<number> {
    if (days.length === 0) return 0;
    const snap = await this.firestore
      .collection('spot_schedules')
      .where('spotId', '==', spotId)
      .where('status', '==', 'open')
      .where('days', 'array-contains-any', days.slice(0, 30))
      .count()
      .get();
    return snap.data().count;
  }
}

export class FirestoreSpotRankStore implements SpotRankStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async listSpots(): Promise<Spot[]> {
    const snap = await this.firestore.collection(SPOTS_COLLECTION).get();
    return snap.docs
      .map((d) => spotFromFirestore(d.id, d.data()))
      .filter((s): s is Spot => s !== null);
  }

  async saveSpot(s: Spot): Promise<void> {
    await this.firestore
      .collection(SPOTS_COLLECTION)
      .doc(s.id)
      .set(spotToFirestore(s), { merge: true });
  }

  async listRankingKeys(): Promise<string[]> {
    const snap = await this.firestore.collection(SPOT_RANKINGS_COLLECTION).get();
    return snap.docs.map((d) => d.id);
  }

  async saveRankings(r: readonly SpotRankings[], staleKeys: readonly string[]): Promise<void> {
    const batch = this.firestore.batch();
    for (const ranking of r) {
      const ref = this.firestore.collection(SPOT_RANKINGS_COLLECTION).doc(ranking.key);
      batch.set(ref, {
        key: ranking.key,
        rankedAt: Timestamp.fromDate(new Date(ranking.rankedAt)),
        entries: ranking.entries,
      });
    }
    for (const staleKey of staleKeys) {
      const ref = this.firestore.collection(SPOT_RANKINGS_COLLECTION).doc(staleKey);
      batch.delete(ref);
    }
    await batch.commit();
  }

  async saveDirectory(e: readonly DirectoryEntry[], now: string): Promise<void> {
    await this.firestore
      .collection(SPOT_DIRECTORY_COLLECTION)
      .doc('all')
      .set({
        key: 'all',
        updatedAt: Timestamp.fromDate(new Date(now)),
        entries: e,
      });
  }
}

export class FirestoreSpotAdminStore implements SpotAdminStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async getSpot(id: string): Promise<Spot | null> {
    const doc = await this.firestore.collection(SPOTS_COLLECTION).doc(id).get();
    return spotFromFirestore(doc.id, doc.data());
  }

  async putSpot(s: Spot): Promise<void> {
    await this.firestore.collection(SPOTS_COLLECTION).doc(s.id).set(spotToFirestore(s));
  }
}
