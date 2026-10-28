import type { Firestore, DocumentData } from 'firebase-admin/firestore';
import { FieldPath, Timestamp } from 'firebase-admin/firestore';
import type {
  DiscoveryStatsStore,
  EngagementStore,
  ExploreCatalogStore,
} from '@photobooking/domain';
import {
  type PhotographerStatsSnapshot,
  type DiscoveryStatsPatch,
  type EngagementKind,
  type ExploreCategoryStat,
  ENGAGEMENT_FIELD,
} from '@photobooking/domain';

export class FirestoreDiscoveryStatsStore implements DiscoveryStatsStore {
  constructor(private readonly firestore: Firestore) {}

  async snapshot(uid: string): Promise<PhotographerStatsSnapshot | null> {
    const snap = await this.firestore.collection('photographers').doc(uid).get();
    if (!snap.exists) return null;
    const data = snap.data() ?? {};
    const stats = (data.stats as Record<string, unknown> | undefined) ?? {};
    return {
      nextFreeDate: stats.nextFreeDate,
      score: stats.score,
      completedCount: stats.completedCount,
      startingPrice: data.startingPrice,
    };
  }

  async blockedDays(
    uid: string,
    from: string,
    toExclusive: string,
  ): Promise<Set<string>> {
    const snaps = await this.firestore
      .collection('availability')
      .doc(uid)
      .collection('days')
      .where(FieldPath.documentId(), '>=', from)
      .where(FieldPath.documentId(), '<', toExclusive)
      .select()
      .get();

    const result = new Set<string>();
    for (const d of snaps.docs) {
      result.add(d.id);
    }
    return result;
  }

  async activeServicePrices(uid: string): Promise<number[]> {
    const snaps = await this.firestore
      .collection('photographers')
      .doc(uid)
      .collection('services')
      .where('active', '==', true)
      .select('price')
      .get();

    const prices: number[] = [];
    for (const d of snaps.docs) {
      const p = d.get('price');
      if (typeof p === 'number') {
        prices.push(p);
      }
    }
    return prices;
  }

  async completedBookings(uid: string): Promise<number> {
    const snap = await this.firestore
      .collection('bookings')
      .where('photographerId', '==', uid)
      .where('status', 'in', ['completed', 'reviewed'])
      .where('deliveryCancel', '==', null)
      .count()
      .get();
    return snap.data().count;
  }

  async apply(uid: string, patch: DiscoveryStatsPatch): Promise<void> {
    const ref = this.firestore.collection('photographers').doc(uid);
    const updateData: Record<string, unknown> = {
      'stats.discoveryAt': Timestamp.now(),
    };

    if (patch.nextFreeDate !== undefined) {
      updateData['stats.nextFreeDate'] = patch.nextFreeDate;
    }
    if (patch.ensureScore) {
      updateData['stats.score'] = 0;
    }
    if (patch.completedCount !== undefined) {
      updateData['stats.completedCount'] = patch.completedCount;
    }
    if (patch.startingPrice !== undefined) {
      updateData['startingPrice'] = patch.startingPrice;
    }

    try {
      await ref.update(updateData);
    } catch (e: unknown) {
      // NOT_FOUND (code 5) is a no-op
      if (typeof e === 'object' && e !== null && 'code' in e && (e as { code: number }).code === 5) {
        return;
      }
      throw e;
    }
  }

  async staleNextFree(
    beforeDay: string,
    limit: number,
    afterUid: string | null,
  ): Promise<string[]> {
    let q = this.firestore
      .collection('photographers')
      .where('stats.nextFreeDate', '<', beforeDay)
      .orderBy('stats.nextFreeDate', 'asc')
      .orderBy(FieldPath.documentId(), 'asc')
      .limit(limit);

    if (afterUid !== null) {
      // To paginate after afterUid when order is [stats.nextFreeDate, __name__],
      // fetch cursor doc or use query cursor
      const cursorDoc = await this.firestore.collection('photographers').doc(afterUid).get();
      if (cursorDoc.exists) {
        q = q.startAfter(cursorDoc);
      }
    }

    const snap = await q.select().get();
    return snap.docs.map((d) => d.id);
  }
}

export class FirestoreEngagementStore implements EngagementStore {
  constructor(private readonly firestore: Firestore) {}

  async recount(
    kind: EngagementKind,
    postId: string,
  ): Promise<'written' | 'unchanged' | 'missing'> {
    const postRef = this.firestore.collection('posts').doc(postId);
    const markers = this.firestore
      .collection(kind === 'like' ? 'likes' : 'saves')
      .where('postId', '==', postId);

    return this.firestore.runTransaction(async (tx) => {
      const [snap, agg] = await Promise.all([
        tx.get(postRef),
        tx.get(markers.count()),
      ]);

      if (!snap.exists) return 'missing';

      const field = ENGAGEMENT_FIELD[kind];
      const n = agg.data().count;
      if (snap.get(field) === n) return 'unchanged';

      tx.update(postRef, { [field]: n });
      return 'written';
    });
  }
}

export class FirestoreExploreCatalogStore implements ExploreCatalogStore {
  constructor(private readonly firestore: Firestore) {}

  async activeServiceCount(specialty: string): Promise<number> {
    const snap = await this.firestore
      .collectionGroup('services')
      .where('specialty', '==', specialty)
      .where('active', '==', true)
      .count()
      .get();
    return snap.data().count;
  }

  async latestActiveCover(specialty: string): Promise<string | null> {
    const snap = await this.firestore
      .collectionGroup('services')
      .where('specialty', '==', specialty)
      .where('active', '==', true)
      .orderBy('updatedAt', 'desc')
      .limit(5)
      .get();

    for (const doc of snap.docs) {
      const url = doc.get('coverUrl');
      if (typeof url === 'string' && url.length > 0) {
        return url;
      }
    }
    return null;
  }

  async current(specialty: string): Promise<ExploreCategoryStat | null> {
    const snap = await this.firestore.collection('catalog').doc('explore').get();
    if (!snap.exists) return null;
    const specialties = (snap.get('specialties') as Record<string, DocumentData> | undefined) ?? {};
    const cat = specialties[specialty];
    if (!cat) return null;
    return {
      serviceCount: typeof cat.serviceCount === 'number' ? cat.serviceCount : 0,
      coverUrl: typeof cat.coverUrl === 'string' ? cat.coverUrl : null,
    };
  }

  async put(specialty: string, stat: ExploreCategoryStat): Promise<void> {
    const ref = this.firestore.collection('catalog').doc('explore');
    const now = Timestamp.now();

    await this.firestore.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const catData = {
        serviceCount: stat.serviceCount,
        coverUrl: stat.coverUrl,
        updatedAt: now,
      };

      if (!snap.exists) {
        tx.set(ref, {
          specialties: { [specialty]: catData },
          updatedAt: now,
        });
      } else {
        tx.update(ref, {
          [`specialties.${specialty}`]: catData,
          updatedAt: now,
        });
      }
    });
  }
}
