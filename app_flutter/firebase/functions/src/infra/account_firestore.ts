import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { db, adminAuth } from './admin.js';
import {
  type AccountDeletionDeps,
  type AccountSnapshot,
  type BlockerItem,
  OPEN_BOOKING_EXCLUDED,
  type PayerMoneyItem,
} from '@photobooking/domain';

/**
 * Active studio relations of `uid` (#136): as the member (`memberId`, titled with the studio) and as the studio
 * (`studioId`, titled with the member). Relations carry no `userId` field (#205).
 */
export async function studioRelationBlockers(firestore: Firestore, uid: string): Promise<BlockerItem[]> {
  const active = (field: 'memberId' | 'studioId') =>
    firestore.collection('studio_members').where(field, '==', uid).where('status', '==', 'active').limit(5).get();
  const [asMember, asStudio] = await Promise.all([active('memberId'), active('studioId')]);
  return [
    ...asMember.docs.map((doc) => ({ id: doc.id, title: (doc.data().studioName as string | undefined) || doc.id, day: null })),
    ...asStudio.docs.map((doc) => ({ id: doc.id, title: (doc.data().memberName as string | undefined) || doc.id, day: null })),
  ];
}

export class FirestoreAccountDeletionDeps implements AccountDeletionDeps {
  constructor(private readonly firestore: Firestore = db()) {}

  readonly clock = {
    now: () => new Date(),
  };

  async revokeSessions(uid: string): Promise<void> {
    try {
      await adminAuth().revokeRefreshTokens(uid);
    } catch (e: unknown) {
      const err = e as { code?: string };
      if (err?.code !== 'auth/user-not-found') throw e;
    }
  }

  async snapshot(uid: string, now: Date): Promise<AccountSnapshot> {
    // 1. openBookings: customerId == uid and status not in OPEN_BOOKING_EXCLUDED
    const openBookingsSnap = await this.firestore
      .collection('bookings')
      .where('customerId', '==', uid)
      .where('status', 'not-in', OPEN_BOOKING_EXCLUDED as unknown as string[])
      .limit(50)
      .get();

    const openBookings: BlockerItem[] = openBookingsSnap.docs.map((doc) => {
      const d = doc.data();
      return {
        id: doc.id,
        title: d.serviceTitle ?? d.packageName ?? doc.id,
        day: d.bookingDate ?? d.day ?? null,
      };
    });

    // 2. openJobs: photographerId == uid or assigneeId == uid, status not in OPEN_BOOKING_EXCLUDED
    const openJobsSnap1 = await this.firestore
      .collection('bookings')
      .where('photographerId', '==', uid)
      .where('status', 'not-in', OPEN_BOOKING_EXCLUDED as unknown as string[])
      .limit(50)
      .get();

    const openJobsSnap2 = await this.firestore
      .collection('bookings')
      .where('assigneeId', '==', uid)
      .where('status', 'not-in', OPEN_BOOKING_EXCLUDED as unknown as string[])
      .limit(50)
      .get();

    const openJobDocs = new Map<string, FirebaseFirestore.DocumentData>();
    for (const doc of openJobsSnap1.docs) openJobDocs.set(doc.id, doc.data());
    for (const doc of openJobsSnap2.docs) openJobDocs.set(doc.id, doc.data());

    const openJobs: BlockerItem[] = Array.from(openJobDocs.entries()).map(([id, d]) => ({
      id,
      title: d.serviceTitle ?? d.packageName ?? id,
      day: d.bookingDate ?? d.day ?? null,
    }));

    // 3. openJobPosts (#139): customerId == uid, status in ['open', 'draft']
    const openJobPosts: BlockerItem[] = [];
    try {
      const jpSnap = await this.firestore
        .collection('jobs')
        .where('customerId', '==', uid)
        .where('status', 'in', ['open', 'draft'])
        .limit(5)
        .get();
      for (const doc of jpSnap.docs) {
        const d = doc.data();
        openJobPosts.push({
          id: doc.id,
          title: d.title ?? doc.id,
          day: d.eventDate ?? null,
        });
      }
    } catch {
      // collection might not exist yet
    }

    // 4. openQuotes (#139): photographerId == uid, status == 'submitted' / 'pending'
    const openQuotes: BlockerItem[] = [];
    try {
      const qSnap = await this.firestore
        .collection('quotes')
        .where('photographerId', '==', uid)
        .where('status', 'in', ['submitted', 'pending'])
        .limit(5)
        .get();
      for (const doc of qSnap.docs) {
        const d = doc.data();
        openQuotes.push({
          id: doc.id,
          title: d.title ?? doc.id,
          day: null,
        });
      }
    } catch {
      // collection might not exist
    }

    // 5. activeInstants (#140): customerId or photographerId == uid, active status
    const activeInstants: BlockerItem[] = [];
    try {
      const instSnap1 = await this.firestore
        .collection('instant_requests')
        .where('customerId', '==', uid)
        .where('status', 'in', ['searching', 'matched', 'accepted', 'in_progress'])
        .limit(5)
        .get();
      const instSnap2 = await this.firestore
        .collection('instant_requests')
        .where('photographerId', '==', uid)
        .where('status', 'in', ['searching', 'matched', 'accepted', 'in_progress'])
        .limit(5)
        .get();
      const instMap = new Map<string, FirebaseFirestore.DocumentData>();
      for (const doc of instSnap1.docs) instMap.set(doc.id, doc.data());
      for (const doc of instSnap2.docs) instMap.set(doc.id, doc.data());
      for (const [id, d] of instMap.entries()) {
        activeInstants.push({
          id,
          title: d.area ? `Chụp ngay · ${d.area}` : id,
          day: null,
        });
      }
    } catch {
      // collection might not exist
    }

    // 6. studioRelations (#136, #151): member or owner
    const studioRelations = await studioRelationBlockers(this.firestore, uid);

    // 7. openCollabs (#136, #151)
    const openCollabs: BlockerItem[] = [];
    try {
      const collabSnap = await this.firestore
        .collection('collab_jobs')
        .where('assigneeId', '==', uid)
        .where('status', 'in', ['assigned', 'in_progress'])
        .limit(5)
        .get();
      for (const doc of collabSnap.docs) {
        const d = doc.data();
        openCollabs.push({
          id: doc.id,
          title: d.title ?? doc.id,
          day: d.day ?? null,
        });
      }
    } catch {
      // collection might not exist
    }

    // 8. liveTickets: registrations collection group userId == uid, orderBy createdAt desc limit 50
    const liveTickets: BlockerItem[] = [];
    try {
      const regSnap = await this.firestore
        .collectionGroup('registrations')
        .where('userId', '==', uid)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      for (const doc of regSnap.docs) {
        const d = doc.data();
        if (['held', 'paid'].includes(d.status)) {
          // Check event endAt > now
          const eventId = d.eventId ?? doc.ref.parent.parent?.id;
          let endAt: Date | null = null;
          let title = d.eventTitle ?? 'Sự kiện';
          if (eventId) {
            const evSnap = await this.firestore.collection('events').doc(eventId).get();
            if (evSnap.exists) {
              const evData = evSnap.data();
              if (evData?.endAt) endAt = (evData.endAt as Timestamp).toDate();
              if (evData?.title) title = evData.title;
            }
          }
          if (!endAt || endAt.getTime() > now.getTime()) {
            liveTickets.push({
              id: doc.id,
              title,
              day: endAt ? endAt.toISOString().slice(0, 10) : null,
              eventId,
            });
          }
        }
      }
    } catch {
      // group might not exist or empty
    }

    // 9. hostedEvents: events hostId == uid, orderBy startAt desc limit 50, filter open|full|closed
    const hostedEvents: BlockerItem[] = [];
    try {
      const evSnap = await this.firestore
        .collection('events')
        .where('hostId', '==', uid)
        .orderBy('startAt', 'desc')
        .limit(50)
        .get();
      for (const doc of evSnap.docs) {
        const d = doc.data();
        if (['open', 'full', 'closed'].includes(d.status)) {
          hostedEvents.push({
            id: doc.id,
            title: d.title ?? doc.id,
            day: d.startAt ? (d.startAt as Timestamp).toDate().toISOString().slice(0, 10) : null,
          });
        }
      }
    } catch {
      // empty
    }

    // 10. payerMoney: payments where payerId == uid, limit 200, and their refunds
    const payerMoney: PayerMoneyItem[] = [];
    try {
      const paySnap = await this.firestore
        .collection('payments')
        .where('payerId', '==', uid)
        .orderBy('createdAt', 'desc')
        .limit(200)
        .get();

      const paymentIds = paySnap.docs.map((d) => d.id);
      const refundsByPayment = new Map<string, FirebaseFirestore.DocumentData[]>();

      for (let i = 0; i < paymentIds.length; i += 30) {
        const chunk = paymentIds.slice(i, i + 30);
        const refSnap = await this.firestore
          .collection('refunds')
          .where('paymentId', 'in', chunk)
          .get();
        for (const doc of refSnap.docs) {
          const rd = doc.data();
          const pid = rd.paymentId;
          const list = refundsByPayment.get(pid) ?? [];
          list.push(rd);
          refundsByPayment.set(pid, list);
        }
      }

      for (const doc of paySnap.docs) {
        const pd = doc.data();
        const pStatus = pd.status;
        const item: BlockerItem = {
          id: doc.id,
          title: pd.title ?? pd.subjectTitle ?? doc.id,
          day: pd.createdAt ? (pd.createdAt as Timestamp).toDate().toISOString().slice(0, 10) : null,
        };

        if (pStatus === 'held') {
          payerMoney.push({
            paymentId: doc.id,
            state: 'held',
            amount: pd.amount ?? 0,
            item,
          });
        } else if (pStatus === 'disputed') {
          payerMoney.push({
            paymentId: doc.id,
            state: 'disputed',
            amount: pd.amount ?? 0,
            item,
          });
        }

        const refunds = refundsByPayment.get(doc.id) ?? [];
        for (const ref of refunds) {
          if (['awaiting_account', 'pending'].includes(ref.status)) {
            payerMoney.push({
              paymentId: doc.id,
              state: 'refunding',
              amount: ref.amount ?? 0,
              item,
            });
          }
        }
      }
    } catch {
      // empty
    }

    // 11. unpaidEarnings: earnings/{uid}
    let unpaidEarnings = 0;
    try {
      const earnSnap = await this.firestore.collection('earnings').doc(uid).get();
      if (earnSnap.exists) {
        const ed = earnSnap.data();
        unpaidEarnings = ed?.unpaid ?? ed?.pendingPayoutAmount ?? 0;
      }
    } catch {
      // empty
    }

    return {
      openBookings,
      openJobs,
      openJobPosts,
      openQuotes,
      activeInstants,
      studioRelations,
      openCollabs,
      liveTickets,
      hostedEvents,
      payerMoney,
      unpaidEarnings,
    };
  }

  async lock(uid: string, requestedAt: Date, restoreUntil: Date): Promise<'locked' | 'already'> {
    const delRef = this.firestore.collection('account_deletions').doc(uid);
    const userRef = this.firestore.collection('users').doc(uid);
    const photRef = this.firestore.collection('photographers').doc(uid);

    return await this.firestore.runTransaction(async (tx) => {
      const delSnap = await tx.get(delRef);
      if (delSnap.exists && delSnap.data()?.status === 'pending') {
        return 'already';
      }

      const photSnap = await tx.get(photRef);

      tx.set(
        delRef,
        {
          uid,
          status: 'pending',
          requestedAt: requestedAt.toISOString(),
          restoreUntil: restoreUntil.toISOString(),
          done: [],
        },
        { merge: true },
      );

      tx.set(
        userRef,
        {
          accountStatus: 'deletion_pending',
          restoreUntil: restoreUntil.toISOString(),
        },
        { merge: true },
      );

      if (photSnap.exists) {
        tx.update(photRef, { deletionPending: true });
      }

      return 'locked';
    });
  }

  async unlock(uid: string, now: Date): Promise<'restored' | 'not_pending' | 'expired'> {
    const delRef = this.firestore.collection('account_deletions').doc(uid);
    const userRef = this.firestore.collection('users').doc(uid);
    const photRef = this.firestore.collection('photographers').doc(uid);

    return await this.firestore.runTransaction(async (tx) => {
      const delSnap = await tx.get(delRef);
      if (!delSnap.exists) return 'not_pending';
      const dd = delSnap.data();
      if (dd?.status !== 'pending') return 'not_pending';

      const restoreUntil = new Date(dd.restoreUntil);
      if (now.getTime() >= restoreUntil.getTime()) {
        return 'expired';
      }

      const photSnap = await tx.get(photRef);

      tx.update(delRef, { status: 'restored' });
      tx.set(
        userRef,
        {
          accountStatus: 'active',
          restoreUntil: null,
        },
        { merge: true },
      );

      if (photSnap.exists) {
        tx.update(photRef, { deletionPending: false });
      }

      return 'restored';
    });
  }

  async startPurge(uid: string, now: Date): Promise<boolean> {
    const delRef = this.firestore.collection('account_deletions').doc(uid);
    return await this.firestore.runTransaction(async (tx) => {
      const delSnap = await tx.get(delRef);
      if (!delSnap.exists) return false;
      const dd = delSnap.data();
      if (dd?.status !== 'pending') return false;

      const restoreUntil = new Date(dd.restoreUntil);
      if (now.getTime() < restoreUntil.getTime()) {
        return false;
      }

      tx.update(delRef, { status: 'purging' });
      return true;
    });
  }

  async duePending(now: Date, limit: number): Promise<readonly string[]> {
    const snap = await this.firestore
      .collection('account_deletions')
      .where('status', '==', 'pending')
      .where('restoreUntil', '<=', now.toISOString())
      .limit(limit)
      .get();

    return snap.docs.map((d) => d.id);
  }
}

export function liveAccountDeletionDeps(firestore: Firestore = db()): AccountDeletionDeps {
  return new FirestoreAccountDeletionDeps(firestore);
}
