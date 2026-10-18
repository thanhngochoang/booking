import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import type { DeliveryRound, PrivateDelivery, DeliverySample } from '@photobooking/domain';
import {
  deliveryRoundToFirestore,
  deliveryRoundFromFirestore,
  privateDeliveryToFirestore,
  privateDeliveryFromFirestore,
  deliverySampleToFirestore,
  deliverySampleFromFirestore,
} from '../../src/infra/delivery_firestore.js';

describe('delivery_firestore mapping', () => {
  it('the round doc has linkHost and no link', () => {
    const round: DeliveryRound = {
      bookingId: 'b_01',
      round: 1,
      samples: [
        { fileId: 's1', path: 'deliveries/b_01/s1.jpg', thumbPath: 'deliveries/b_01/s1_thumb.jpg', width: 1600, height: 1200 },
        { fileId: 's2', path: 'deliveries/b_01/s2.jpg', thumbPath: 'deliveries/b_01/s2_thumb.jpg', width: 1600, height: 1200 },
        { fileId: 's3', path: 'deliveries/b_01/s3.jpg', thumbPath: 'deliveries/b_01/s3_thumb.jpg', width: 1600, height: 1200 },
      ],
      photoCount: 45,
      linkHost: 'drive.google.com',
      note: 'Ảnh đã chỉnh màu đầy đủ',
      submittedAt: '2026-10-17T10:00:00.000Z',
      submittedBy: 'photog_01',
      decision: {
        kind: 'request_revision',
        note: 'Cần sáng thêm xíu',
        photoNotes: [{ sampleIndex: 0, note: 'Tăng sáng góc phải' }],
        at: '2026-10-17T11:00:00.000Z',
        auto: false,
        extra: false,
      },
    };

    const doc = deliveryRoundToFirestore(round);
    assert.equal(doc.linkHost, 'drive.google.com');
    assert.equal('link' in doc, false);
    assert.ok(doc.submittedAt instanceof Timestamp);
    assert.ok(doc.decision.at instanceof Timestamp);

    const restored = deliveryRoundFromFirestore(1, doc);
    assert.deepEqual(restored, round);
  });

  it('private delivery holds the link', () => {
    const priv: PrivateDelivery = {
      link: 'https://drive.google.com/drive/folders/full_res_photos_secret',
      round: 1,
      unlockedAt: '2026-10-17T12:00:00.000Z',
      updatedAt: '2026-10-17T12:00:00.000Z',
    };

    const doc = privateDeliveryToFirestore(priv);
    assert.equal(doc.link, 'https://drive.google.com/drive/folders/full_res_photos_secret');
    assert.ok(doc.unlockedAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);

    const restored = privateDeliveryFromFirestore(doc);
    assert.deepEqual(restored, priv);
  });

  it('deliverySample round-trips ready and failed docs', () => {
    const readySample: DeliverySample = {
      fileId: 's_01',
      uploaderId: 'photog_01',
      status: 'ready',
      path: 'deliveries/b_01/s_01.jpg',
      thumbPath: 'deliveries/b_01/s_01_thumb.jpg',
      width: 1600,
      height: 1200,
      bytes: 250_000,
      failure: null,
      createdAt: '2026-10-17T09:00:00.000Z',
    };

    const readyDoc = deliverySampleToFirestore(readySample);
    const restoredReady = deliverySampleFromFirestore('s_01', readyDoc);
    assert.deepEqual(restoredReady, readySample);

    const failedSample: DeliverySample = {
      fileId: 's_02',
      uploaderId: 'photog_01',
      status: 'failed',
      path: '',
      thumbPath: '',
      width: 0,
      height: 0,
      bytes: 0,
      failure: 'corrupt_jpeg',
    };

    const failedDoc = deliverySampleToFirestore(failedSample);
    const restoredFailed = deliverySampleFromFirestore('s_02', failedDoc);
    assert.deepEqual(restoredFailed, failedSample);
  });
});
