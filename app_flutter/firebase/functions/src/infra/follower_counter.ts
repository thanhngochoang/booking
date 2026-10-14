import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { counterPatch } from '@photobooking/domain';

export type ApplyOutcome = 'written' | 'unchanged' | 'stale' | 'missing';

export interface FollowerCounter {
  recount(pid: string): Promise<number>;
  apply(pid: string, eventAt: string, recount: number): Promise<ApplyOutcome>;
}

export class FirestoreFollowerCounter implements FollowerCounter {
  constructor(private readonly db: Firestore) {}

  async recount(pid: string): Promise<number> {
    const snap = await this.db
      .collection('follows')
      .where('photographerId', '==', pid)
      .count()
      .get();
    return snap.data().count;
  }

  async apply(pid: string, eventAt: string, recount: number): Promise<ApplyOutcome> {
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection('photographers').doc(pid);
      const snap = await tx.get(ref);
      if (!snap.exists) return 'missing' as const;
      const d = snap.data() ?? {};
      const stored = {
        value: typeof d.followerCount === 'number' ? d.followerCount : null,
        at: d.followerCountAt instanceof Timestamp ? d.followerCountAt.toDate().toISOString() : null,
      };
      const patch = counterPatch(stored, recount, eventAt);
      if (patch === null) {
        return stored.at !== null && stored.at > eventAt ? ('stale' as const) : ('unchanged' as const);
      }
      tx.update(ref, {
        followerCount: patch.value,
        followerCountAt: Timestamp.fromDate(new Date(patch.at)),
      });
      return 'written' as const;
    });
  }
}
