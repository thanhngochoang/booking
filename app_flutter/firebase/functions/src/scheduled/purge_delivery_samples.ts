import * as logger from 'firebase-functions/logger';
import type { Firestore } from 'firebase-admin/firestore';
import type { Bucket } from '@google-cloud/storage';
import { BOOKINGS_COLLECTION } from '../infra/booking_firestore.js';

export interface PurgeDeliverySamplesDeps {
  readonly db: Firestore;
  readonly bucket: Bucket;
  readonly now: Date;
  readonly limit?: number;
}

export async function purgeDeliverySamples(deps: PurgeDeliverySamplesDeps): Promise<number> {
  const limit = deps.limit ?? 50;
  const snap = await deps.db
    .collection(BOOKINGS_COLLECTION)
    .where('status', '==', 'completed')
    .where('samplesPurged', '==', false)
    .where('samplesPurgeAfter', '<=', deps.now)
    .limit(limit)
    .get();

  let purgedCount = 0;
  for (const doc of snap.docs) {
    const booking = doc.data();
    // Skip disputed bookings
    if (booking.escrowStatus === 'disputed') continue;

    const bookingId = doc.id;
    try {
      // List all delivery rounds to get sample paths
      const roundsSnap = await doc.ref.collection('deliveries').get();
      for (const roundDoc of roundsSnap.docs) {
        const roundData = roundDoc.data();
        if (Array.isArray(roundData.samples)) {
          for (const s of roundData.samples) {
            if (s && typeof s === 'object') {
              if (typeof s.path === 'string' && s.path) {
                await deps.bucket.file(s.path).delete({ ignoreNotFound: true }).catch(() => {});
              }
              if (typeof s.thumbPath === 'string' && s.thumbPath) {
                await deps.bucket.file(s.thumbPath).delete({ ignoreNotFound: true }).catch(() => {});
              }
            }
          }
        }
      }

      await doc.ref.update({
        samplesPurged: true,
        samplesPurgeAfter: null,
      });
      purgedCount++;
    } catch (e) {
      logger.error('Failed to purge delivery samples for booking', { bookingId, error: String(e) });
    }
  }

  return purgedCount;
}
