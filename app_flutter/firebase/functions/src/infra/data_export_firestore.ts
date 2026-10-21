import { Firestore, Timestamp } from 'firebase-admin/firestore';
import type { Bucket } from '@google-cloud/storage';
import { db, bucket as getBucket } from './admin.js';
import {
  type DataExportDeps,
  type ExportParts,
  EXPORT_LIMITS,
} from '@photobooking/domain';
import { randomUUID } from 'node:crypto';

export class FirestoreDataExportDeps implements DataExportDeps {
  constructor(
    private readonly firestore: Firestore = db(),
    private readonly bucket: Bucket = getBucket(),
  ) {}

  readonly clock = {
    now: () => new Date(),
  };

  readonly ids = {
    newId: () => randomUUID(),
  };

  async pending(uid: string): Promise<boolean> {
    const delSnap = await this.firestore.collection('account_deletions').doc(uid).get();
    if (!delSnap.exists) return false;
    return delSnap.data()?.status === 'pending';
  }

  async last(uid: string): Promise<Date | null> {
    const snap = await this.firestore
      .collection('exports')
      .doc(uid)
      .collection('items')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (snap.empty || !snap.docs[0]) return null;
    const d = snap.docs[0].data();
    if (!d.createdAt) return null;
    return (d.createdAt as Timestamp).toDate();
  }

  async gather(uid: string, limits: typeof EXPORT_LIMITS): Promise<ExportParts> {
    const parts: Record<string, unknown> = {};

    // 1. Profile
    const userDoc = await this.firestore.collection('users').doc(uid).get();
    if (userDoc.exists) parts.profile = userDoc.data();

    // 2. Photographer profile if any
    const photDoc = await this.firestore.collection('photographers').doc(uid).get();
    if (photDoc.exists) parts.photographer = photDoc.data();

    // 3. Bookings
    const bSnap1 = await this.firestore.collection('bookings').where('customerId', '==', uid).limit(limits.bookings).get();
    const bSnap2 = await this.firestore.collection('bookings').where('photographerId', '==', uid).limit(limits.bookings).get();
    const bMap = new Map<string, unknown>();
    for (const d of bSnap1.docs) bMap.set(d.id, d.data());
    for (const d of bSnap2.docs) bMap.set(d.id, d.data());
    parts.bookings = Array.from(bMap.values());

    // 4. Registrations
    const regSnap = await this.firestore.collectionGroup('registrations').where('userId', '==', uid).limit(limits.registrations).get();
    parts.registrations = regSnap.docs.map((d) => d.data());

    // 5. Payments
    const paySnap = await this.firestore.collection('payments').where('payerId', '==', uid).limit(limits.payments).get();
    parts.payments = paySnap.docs.map((d) => d.data());

    // 6. Posts
    const postSnap = await this.firestore.collection('posts').where('authorId', '==', uid).limit(limits.posts).get();
    parts.posts = postSnap.docs.map((d) => d.data());

    // 7. Reviews
    const revSnap = await this.firestore.collection('reviews').where('authorId', '==', uid).limit(limits.reviews).get();
    parts.reviews = revSnap.docs.map((d) => d.data());

    // 8. Notifications
    const notifSnap = await this.firestore.collection('notifications').where('userId', '==', uid).limit(limits.notifications).get();
    parts.notifications = notifSnap.docs.map((d) => d.data());

    return parts;
  }

  async write(uid: string, exportId: string, json: string): Promise<{ path: string; sizeBytes: number }> {
    const objectPath = `exports/${uid}/${exportId}.json`;
    const file = this.bucket.file(objectPath);
    const buffer = Buffer.from(json, 'utf8');

    await file.save(buffer, {
      contentType: 'application/json',
      resumable: false,
    });

    return {
      path: objectPath,
      sizeBytes: buffer.length,
    };
  }

  async record(
    uid: string,
    rec: { path: string; sizeBytes: number; createdAt: Date; expiresAt: Date },
  ): Promise<void> {
    await this.firestore
      .collection('exports')
      .doc(uid)
      .collection('items')
      .add({
        path: rec.path,
        sizeBytes: rec.sizeBytes,
        createdAt: Timestamp.fromDate(rec.createdAt),
        expiresAt: Timestamp.fromDate(rec.expiresAt),
      });

    // Also update parent document for easy lookup
    await this.firestore.collection('exports').doc(uid).set(
      {
        lastPath: rec.path,
        lastSizeBytes: rec.sizeBytes,
        createdAt: Timestamp.fromDate(rec.createdAt),
        expiresAt: Timestamp.fromDate(rec.expiresAt),
      },
      { merge: true },
    );
  }
}

export function liveDataExportDeps(
  firestore: Firestore = db(),
  bucket: Bucket = getBucket(),
): DataExportDeps {
  return new FirestoreDataExportDeps(firestore, bucket);
}
