import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, type BookingWorld } from './support/booking_world.js';
import type { Booking } from '../src/booking.js';
import type { DeliverySample } from '../src/delivery.js';
import {
  submitDelivery,
  approveDelivery,
  requestRevision,
  answerExtraRound,
} from '../src/delivery_use_cases.js';
import { DomainError } from '../src/errors.js';

describe('delivery use cases', () => {
  let world: BookingWorld;
  const sampleIds = ['01ARZ3NDEKTSV4RRFFQ69G5FA1', '01ARZ3NDEKTSV4RRFFQ69G5FA2', '01ARZ3NDEKTSV4RRFFQ69G5FA3'];

  beforeEach(() => {
    world = createBookingWorld(new Date('2026-10-15T10:00:00.000Z'));
  });

  function seedBooking(status: Booking['status'] = 'shot', overrides: Partial<Booking> = {}): Booking {
    const booking: Booking = {
      id: 'b1',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '14:00',
      end: '16:00',
      place: { name: 'Studio' },
      status,
      deposit: 1_000_000,
      remaining: 0,
      revisionsIncluded: 1,
      revisionsUsed: 0,
      revisionsGranted: 0,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
      ...overrides,
    };
    world.store.bookings.set(booking.id, booking);
    return booking;
  }

  function seedSamples(bookingId: string, uploaderId: string, ids = sampleIds, status: 'ready' | 'failed' = 'ready') {
    for (const id of ids) {
      const sample: DeliverySample = {
        fileId: id,
        uploaderId,
        status,
        path: `deliveries/${bookingId}/${id}.jpg`,
        thumbPath: `deliveries/${bookingId}/${id}_t.jpg`,
        width: 1600,
        height: 1200,
        bytes: 250000,
        failure: status === 'failed' ? 'error' : null,
      };
      world.store.deliverySamples.set(`${bookingId}_${id}`, sample);
    }
  }

  describe('submitDelivery', () => {
    it('submitDelivery round 1 from shot', async () => {
      seedBooking('shot');
      seedSamples('b1', 'p1');

      const res = await submitDelivery(world.deps, 'p1', {
        bookingId: 'b1',
        sampleIds,
        link: 'https://drive.google.com/drive/folders/123',
        photoCount: 40,
        note: 'Ảnh đã chỉnh xong màu',
      });

      assert.equal(res.round, 1);

      // Verify round doc
      const roundDoc = world.store.deliveries.get('b1_1');
      assert.ok(roundDoc);
      assert.equal(roundDoc.round, 1);
      assert.equal(roundDoc.photoCount, 40);
      assert.equal(roundDoc.linkHost, 'drive.google.com');
      assert.equal((roundDoc as unknown as Record<string, unknown>).link, undefined);
      assert.equal(roundDoc.samples.length, 3);
      assert.equal(roundDoc.note, 'Ảnh đã chỉnh xong màu');

      // Verify private delivery
      const privateDoc = world.store.privateDeliveries.get('b1');
      assert.ok(privateDoc);
      assert.equal(privateDoc.link, 'https://drive.google.com/drive/folders/123');
      assert.equal(privateDoc.round, 1);
      assert.equal(privateDoc.unlockedAt, null);

      // Verify booking updated
      const updated = world.store.bookings.get('b1');
      assert.ok(updated);
      assert.equal(updated.status, 'delivered');
      assert.equal(updated.deliveryRound, 1);
      assert.ok(updated.deliveredAt);
      assert.equal(updated.autoApproveNoticeAt, null);
      // autoApproveAt = now + 72h
      const expectedAutoApprove = new Date(new Date('2026-10-15T10:00:00.000Z').getTime() + 72 * 3600 * 1000).toISOString();
      assert.equal(updated.autoApproveAt, expectedAutoApprove);

      // Verify samples consumed
      for (const id of sampleIds) {
        assert.equal(world.store.deliverySamples.get(`b1_${id}`), undefined);
      }
    });

    it('submitDelivery from revision_requested opens round 2 and resets autoApproveAt and autoApproveNoticeAt', async () => {
      seedBooking('revision_requested', {
        deliveryRound: 1,
        autoApproveNoticeAt: '2026-10-16T10:00:00.000Z',
      });
      seedSamples('b1', 'p1');

      const res = await submitDelivery(world.deps, 'p1', {
        bookingId: 'b1',
        sampleIds,
        link: 'https://drive.google.com/drive/folders/123',
        photoCount: 42,
      });

      assert.equal(res.round, 2);
      const updated = world.store.bookings.get('b1');
      assert.ok(updated);
      assert.equal(updated.status, 'delivered');
      assert.equal(updated.deliveryRound, 2);
      assert.equal(updated.autoApproveNoticeAt, null);
      assert.ok(updated.autoApproveAt);
    });

    it('refuses a caller who is not booking.photographerId with permission_denied', async () => {
      seedBooking('shot');
      seedSamples('b1', 'p1');

      await assert.rejects(
        () =>
          submitDelivery(world.deps, 'c1', {
            bookingId: 'b1',
            sampleIds,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 40,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });

    it('refuses status upcoming with not_eligible', async () => {
      seedBooking('upcoming');
      seedSamples('b1', 'p1');

      await assert.rejects(
        () =>
          submitDelivery(world.deps, 'p1', {
            bookingId: 'b1',
            sampleIds,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 40,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('refuses an unprocessed sample with not_ready (missing doc and failed doc)', async () => {
      seedBooking('shot');
      // missing sample
      await assert.rejects(
        () =>
          submitDelivery(world.deps, 'p1', {
            bookingId: 'b1',
            sampleIds,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 40,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_ready',
      );

      // failed sample
      seedSamples('b1', 'p1', sampleIds, 'failed');
      await assert.rejects(
        () =>
          submitDelivery(world.deps, 'p1', {
            bookingId: 'b1',
            sampleIds,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 40,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_ready',
      );
    });

    it('refuses a sample uploaded by someone else with permission_denied', async () => {
      seedBooking('shot');
      seedSamples('b1', 'other_user');

      await assert.rejects(
        () =>
          submitDelivery(world.deps, 'p1', {
            bookingId: 'b1',
            sampleIds,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 40,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });
  });

  describe('approveDelivery', () => {
    it('approveDelivery by the customer', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        autoApproveAt: '2026-10-18T10:00:00.000Z',
        extraRound: { status: 'pending', at: '2026-10-15T09:00:00.000Z', note: null, photoNotes: [] },
      });
      world.store.deliveries.set('b1_1', {
        bookingId: 'b1',
        round: 1,
        samples: [],
        photoCount: 40,
        linkHost: 'drive.google.com',
        note: null,
        submittedAt: '2026-10-15T08:00:00.000Z',
        submittedBy: 'p1',
        decision: null,
      });
      world.store.privateDeliveries.set('b1', {
        link: 'https://drive.google.com/123',
        round: 1,
        unlockedAt: null,
        updatedAt: '2026-10-15T08:00:00.000Z',
      });

      const updated = await approveDelivery(world.deps, { bookingId: 'b1', actorId: 'c1' });

      assert.equal(updated.status, 'approved');
      assert.ok(updated.approvedAt);
      assert.equal(updated.autoApproveAt, undefined);
      assert.equal(updated.extraRound, null);
      const expectedCheckUntil = new Date(new Date('2026-10-15T10:00:00.000Z').getTime() + 48 * 3600 * 1000).toISOString();
      assert.equal(updated.checkUntil, expectedCheckUntil);

      const delivery = world.store.deliveries.get('b1_1');
      assert.ok(delivery);
      assert.deepEqual(delivery.decision, {
        kind: 'approve',
        note: null,
        photoNotes: [],
        at: '2026-10-15T10:00:00.000Z',
        auto: false,
        extra: false,
      });

      const priv = world.store.privateDeliveries.get('b1');
      assert.ok(priv);
      assert.equal(priv.unlockedAt, '2026-10-15T10:00:00.000Z');
    });

    it('system approve records auto true', async () => {
      seedBooking('delivered', { deliveryRound: 1 });
      world.store.deliveries.set('b1_1', {
        bookingId: 'b1',
        round: 1,
        samples: [],
        photoCount: 40,
        linkHost: 'drive.google.com',
        note: null,
        submittedAt: '2026-10-15T08:00:00.000Z',
        submittedBy: 'p1',
        decision: null,
      });

      await approveDelivery(world.deps, { bookingId: 'b1' }); // no actorId = system

      const delivery = world.store.deliveries.get('b1_1');
      assert.ok(delivery);
      assert.equal(delivery.decision?.auto, true);
    });

    it('approve from revision_requested is not_eligible', async () => {
      seedBooking('revision_requested');
      await assert.rejects(
        () => approveDelivery(world.deps, { bookingId: 'b1', actorId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });
  });

  describe('requestRevision', () => {
    it('requestRevision with rounds left', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 0,
        autoApproveAt: '2026-10-18T10:00:00.000Z',
      });
      world.store.deliveries.set('b1_1', {
        bookingId: 'b1',
        round: 1,
        samples: [],
        photoCount: 40,
        linkHost: 'drive.google.com',
        note: null,
        submittedAt: '2026-10-15T08:00:00.000Z',
        submittedBy: 'p1',
        decision: null,
      });

      const updated = await requestRevision(world.deps, 'c1', {
        bookingId: 'b1',
        note: 'Sửa lại da',
        photoNotes: [{ sampleIndex: 0, note: 'Bớt vàng' }],
      });

      assert.equal(updated.status, 'revision_requested');
      assert.equal(updated.revisionsUsed, 1);
      assert.equal(updated.autoApproveAt, undefined);

      const delivery = world.store.deliveries.get('b1_1');
      assert.ok(delivery);
      assert.deepEqual(delivery.decision, {
        kind: 'request_revision',
        note: 'Sửa lại da',
        photoNotes: [{ sampleIndex: 0, note: 'Bớt vàng' }],
        at: '2026-10-15T10:00:00.000Z',
        auto: false,
        extra: false,
      });
    });

    it('requestRevision without rounds left is not_eligible', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
      });

      await assert.rejects(
        () => requestRevision(world.deps, 'c1', { bookingId: 'b1', note: 'Sửa tiếp' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('extra request with rounds left is not_eligible', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 2,
        revisionsUsed: 1,
      });

      await assert.rejects(
        () => requestRevision(world.deps, 'c1', { bookingId: 'b1', note: 'Xin thêm', extra: true }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('extra request stores a pending extraRound and keeps delivered', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
      });

      const updated = await requestRevision(world.deps, 'c1', {
        bookingId: 'b1',
        note: 'Xin thêm 1 vòng để chỉnh nốt',
        extra: true,
      });

      assert.equal(updated.status, 'delivered');
      assert.deepEqual(updated.extraRound, {
        status: 'pending',
        at: '2026-10-15T10:00:00.000Z',
        note: 'Xin thêm 1 vòng để chỉnh nốt',
        photoNotes: [],
      });
    });

    it('a second extra request while pending is conflict', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
        extraRound: { status: 'pending', at: '2026-10-15T09:00:00.000Z', note: null, photoNotes: [] },
      });

      await assert.rejects(
        () => requestRevision(world.deps, 'c1', { bookingId: 'b1', note: 'Xin thêm nữa', extra: true }),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });
  });

  describe('answerExtraRound', () => {
    it('answerExtraRound grant', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
        revisionsGranted: 0,
        extraRound: {
          status: 'pending',
          at: '2026-10-15T09:00:00.000Z',
          note: 'Cho thêm vòng nhé',
          photoNotes: [{ sampleIndex: 1, note: 'Tăng sáng' }],
        },
      });
      world.store.deliveries.set('b1_1', {
        bookingId: 'b1',
        round: 1,
        samples: [],
        photoCount: 40,
        linkHost: 'drive.google.com',
        note: null,
        submittedAt: '2026-10-15T08:00:00.000Z',
        submittedBy: 'p1',
        decision: null,
      });

      const updated = await answerExtraRound(world.deps, 'p1', { bookingId: 'b1', grant: true });

      assert.equal(updated.status, 'revision_requested');
      assert.equal(updated.revisionsGranted, 1);
      assert.equal(updated.revisionsUsed, 2);
      assert.equal(updated.extraRound?.status, 'granted');

      const delivery = world.store.deliveries.get('b1_1');
      assert.ok(delivery);
      assert.deepEqual(delivery.decision, {
        kind: 'request_revision',
        note: 'Cho thêm vòng nhé',
        photoNotes: [{ sampleIndex: 1, note: 'Tăng sáng' }],
        at: '2026-10-15T10:00:00.000Z',
        auto: false,
        extra: true,
      });
    });

    it('answerExtraRound decline', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
        revisionsGranted: 0,
        extraRound: { status: 'pending', at: '2026-10-15T09:00:00.000Z', note: 'Thêm vòng nhé', photoNotes: [] },
      });

      const updated = await answerExtraRound(world.deps, 'p1', { bookingId: 'b1', grant: false });

      assert.equal(updated.status, 'delivered');
      assert.equal(updated.extraRound?.status, 'declined');
      assert.equal(updated.revisionsGranted, 0);
      assert.equal(updated.revisionsUsed, 1);
    });

    it('answer by the customer is permission_denied', async () => {
      seedBooking('delivered', {
        extraRound: { status: 'pending', at: '2026-10-15T09:00:00.000Z', note: null, photoNotes: [] },
      });

      await assert.rejects(
        () => answerExtraRound(world.deps, 'c1', { bookingId: 'b1', grant: true }),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });

    it('answer with nothing pending is not_eligible', async () => {
      seedBooking('delivered', { extraRound: null });

      await assert.rejects(
        () => answerExtraRound(world.deps, 'p1', { bookingId: 'b1', grant: true }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });
  });
});
