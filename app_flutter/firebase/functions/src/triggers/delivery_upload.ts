import * as logger from 'firebase-functions/logger';
import { getStorage } from 'firebase-admin/storage';
import { getFirestore } from 'firebase-admin/firestore';
import type { Booking } from '@photobooking/domain';
import { parseDeliveryUploadPath, watermarkLabel } from '@photobooking/domain';
import { bookingFromFirestore, BOOKINGS_COLLECTION } from '../infra/booking_firestore.js';
import {
  loadWatermarkFont,
  MAX_UPLOAD_BYTES,
  watermarkSample,
} from '../infra/watermark.js';
import type opentype from 'opentype.js';

export interface DeliveryUploadDeps {
  readBooking(id: string): Promise<Booking | null>;
  providerName(uid: string): Promise<string | null>;
  download(path: string): Promise<Buffer>;
  upload(path: string, data: Buffer): Promise<void>;
  remove(path: string): Promise<void>;
  sampleDoc(bookingId: string, fileId: string): Promise<{ status: string } | null>;
  writeSample(bookingId: string, fileId: string, data: Record<string, unknown>): Promise<void>;
  font(): opentype.Font;
  now(): Date;
}

export function liveDeliveryUploadDeps(): DeliveryUploadDeps {
  const db = getFirestore();
  const bucket = getStorage().bucket();

  return {
    async readBooking(id: string): Promise<Booking | null> {
      const snap = await db.collection(BOOKINGS_COLLECTION).doc(id).get();
      return snap.exists ? bookingFromFirestore(snap.id, snap.data()) : null;
    },
    async providerName(uid: string): Promise<string | null> {
      const snap = await db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      const data = snap.data();
      return typeof data?.displayName === 'string' ? data.displayName : null;
    },
    async download(path: string): Promise<Buffer> {
      const [buf] = await bucket.file(path).download();
      return buf;
    },
    async upload(path: string, data: Buffer): Promise<void> {
      await bucket.file(path).save(data, {
        contentType: 'image/jpeg',
        metadata: {
          cacheControl: 'private, max-age=31536000, immutable',
        },
      });
    },
    async remove(path: string): Promise<void> {
      await bucket.file(path).delete({ ignoreNotFound: true }).catch(() => {});
    },
    async sampleDoc(bookingId: string, fileId: string): Promise<{ status: string } | null> {
      const snap = await db.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('deliverySamples').doc(fileId).get();
      if (!snap.exists) return null;
      const data = snap.data();
      return data && typeof data.status === 'string' ? { status: data.status } : null;
    },
    async writeSample(bookingId: string, fileId: string, data: Record<string, unknown>): Promise<void> {
      await db.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('deliverySamples').doc(fileId).set(data, { merge: true });
    },
    font(): opentype.Font {
      return loadWatermarkFont();
    },
    now(): Date {
      return new Date();
    },
  };
}

export async function handleDeliveryUpload(
  object: { name: string; contentType?: string; size?: number | string },
  deps: DeliveryUploadDeps,
): Promise<'ignored' | 'ready' | 'failed' | 'already'> {
  const parsed = parseDeliveryUploadPath(object.name);
  if (!parsed) {
    return 'ignored';
  }

  const { bookingId, uploaderId, fileId } = parsed;

  try {
    // 1. Check if already processed
    const existing = await deps.sampleDoc(bookingId, fileId);
    if (existing?.status === 'ready') {
      await deps.remove(object.name);
      return 'already';
    }

    // 2. Content-type check
    if (object.contentType && object.contentType !== 'image/jpeg') {
      await deps.writeSample(bookingId, fileId, {
        fileId,
        uploaderId,
        status: 'failed',
        failure: 'unsupported',
        createdAt: deps.now().toISOString(),
      });
      logger.warn('Delivery upload unsupported content-type', { bookingId, fileId, failure: 'unsupported' });
      return 'failed';
    }

    // 3. Size check (before downloading)
    const size = Number(object.size ?? 0);
    if (size > MAX_UPLOAD_BYTES) {
      await deps.writeSample(bookingId, fileId, {
        fileId,
        uploaderId,
        status: 'failed',
        failure: 'too_large',
        createdAt: deps.now().toISOString(),
      });
      logger.warn('Delivery upload too large', { bookingId, fileId, failure: 'too_large' });
      return 'failed';
    }

    // 4. Booking and uploader check
    const booking = await deps.readBooking(bookingId);
    if (!booking) {
      await deps.writeSample(bookingId, fileId, {
        fileId,
        uploaderId,
        status: 'failed',
        failure: 'not_found',
        createdAt: deps.now().toISOString(),
      });
      logger.warn('Delivery upload booking not found', { bookingId, fileId, failure: 'not_found' });
      return 'failed';
    }

    if (booking.photographerId !== uploaderId) {
      await deps.writeSample(bookingId, fileId, {
        fileId,
        uploaderId,
        status: 'failed',
        failure: 'not_allowed',
        createdAt: deps.now().toISOString(),
      });
      logger.warn('Delivery upload not allowed for uploader', { bookingId, fileId, failure: 'not_allowed' });
      return 'failed';
    }

    if (booking.status !== 'shot' && booking.status !== 'revision_requested') {
      await deps.writeSample(bookingId, fileId, {
        fileId,
        uploaderId,
        status: 'failed',
        failure: 'not_eligible',
        createdAt: deps.now().toISOString(),
      });
      logger.warn('Delivery upload status not eligible', { bookingId, fileId, failure: 'not_eligible' });
      return 'failed';
    }

    // 5. Download and process
    const rawBuffer = await deps.download(object.name);
    const providerDisplayName = await deps.providerName(uploaderId);
    const label = watermarkLabel(providerDisplayName);

    const { sample, thumb, width, height } = await watermarkSample(rawBuffer, label, deps.font());

    // 6. Upload processed sample and thumbnail to deliveries/{bookingId}/
    const samplePath = `deliveries/${bookingId}/${fileId}.jpg`;
    const thumbPath = `deliveries/${bookingId}/${fileId}_t.jpg`;

    await deps.upload(samplePath, sample);
    await deps.upload(thumbPath, thumb);

    // 7. Write ready sample doc
    await deps.writeSample(bookingId, fileId, {
      fileId,
      uploaderId,
      status: 'ready',
      path: samplePath,
      thumbPath,
      width,
      height,
      bytes: sample.length,
      failure: null,
      createdAt: deps.now().toISOString(),
    });

    return 'ready';
  } catch (e) {
    logger.error('Failed to process delivery upload', { bookingId, fileId, failure: String(e) });
    await deps.writeSample(bookingId, fileId, {
      fileId,
      uploaderId,
      status: 'failed',
      failure: 'processing_error',
      createdAt: deps.now().toISOString(),
    });
    return 'failed';
  } finally {
    // Delete the clean upload in every outcome
    await deps.remove(object.name);
  }
}
