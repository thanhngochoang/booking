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
  cancelLateDelivery,
} from '../src/delivery_use_cases.js';
import { DomainError } from '../src/errors.js';
import { splitMilestones, withMilestones, releaseMilestone } from '../src/milestones.js';
import type { Payment } from '../src/escrow.js';

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

    it('auto-approve proceeds while an extra round is pending and clears it', async () => {
      seedBooking('delivered', {
        deliveryRound: 1,
        extraRound: { status: 'pending', at: '2026-10-15T09:00:00.000Z', note: 'Xin thêm 1 vòng', photoNotes: [] },
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

      const updated = await approveDelivery(world.deps, { bookingId: 'b1' });
      assert.equal(updated.status, 'approved');
      assert.equal(updated.extraRound, null);
      const delivery = world.store.deliveries.get('b1_1');
      assert.equal(delivery?.decision?.auto, true);
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

  describe('cancelLateDelivery', () => {
    const shotAt = new Date('2026-10-07T10:00:00.000Z'); // now (2026-10-15T10:00Z) - 8 days

    function seedLateShotBooking(overrides: Partial<Booking> = {}): Booking {
      return seedBooking('shot', {
        shotAt: shotAt.toISOString(),
        deliveryDays: 5,
        escrowStatus: 'released',
        ...overrides,
      });
    }

    function seedMilestonePayment(overrides: Partial<Payment> = {}): Payment {
      const ms = splitMilestones(1_000_000, shotAt);
      const base = withMilestones(
        {
          id: 'pay_1',
          subjectType: 'booking',
          subjectId: 'b1',
          payerId: 'c1',
          payeeId: 'p1',
          amount: 1_000_000,
          receivedAmount: 1_000_000,
          status: 'paid',
          escrowStatus: 'held',
          method: 'bank_qr',
          provider: 'fake',
          idempotencyKey: 'k_1',
          payer: {
            bankCode: 'VCB',
            bankName: 'Vietcombank',
            accountNumberEnc: 'enc:6543210001700',
            accountLast4: '3456',
            holderName: 'NGUYEN THANH HA',
          },
          createdAt: shotAt.toISOString(),
          updatedAt: shotAt.toISOString(),
          ...overrides,
        },
        ms,
        shotAt.toISOString(),
      );
      const released = releaseMilestone(base, 'shoot', 'led_shoot_1', new Date(shotAt.getTime() + 25 * 3600 * 1000));
      const finalPayment = { ...released.payment, ...overrides };
      world.store.payments.set(finalPayment.id, finalPayment);
      return finalPayment;
    }

    it('cancelLateDelivery by the customer past the deadline: booking completed with completedAt, deliveryCancel {at, dueAt, refundedAmount 500000}, depositRefunded 500000, escrowStatus from the payment, version + 1; one refund row; one ledger row; booking event completed with actorId c1', async () => {
      seedLateShotBooking();
      seedMilestonePayment();

      const updated = await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });

      assert.equal(updated.status, 'completed');
      assert.equal(updated.completedAt, '2026-10-15T10:00:00.000Z');
      assert.deepEqual(updated.deliveryCancel, {
        at: '2026-10-15T10:00:00.000Z',
        dueAt: '2026-10-12T10:00:00.000Z',
        refundedAmount: 500_000,
      });
      assert.equal(updated.depositRefunded, 500_000);
      assert.equal(updated.escrowStatus, 'released');
      assert.equal(updated.version, 2);

      const refunds = [...world.store.refunds.values()];
      assert.equal(refunds.length, 1);
      assert.equal(refunds[0]?.amount, 500_000);
      assert.equal(refunds[0]?.reason, 'late_delivery');

      const ledgerEntries = [...world.store.ledgerEntries.values()];
      assert.equal(ledgerEntries.length, 1);
      assert.equal(ledgerEntries[0]?.type, 'refund_issued');
      assert.equal(ledgerEntries[0]?.amount, -500_000);
      assert.equal(ledgerEntries[0]?.accountOwnerId, 'c1');

      const events = world.store.events.filter((e) => e.bookingId === 'b1');
      assert.equal(events.length, 1);
      assert.equal(events[0]?.status, 'completed');
      assert.equal(events[0]?.actorId, 'c1');
    });

    it('the provider calling it is permission_denied; a stranger is permission_denied; an unknown booking is not_found; a bad id is invalid_argument', async () => {
      seedLateShotBooking();
      seedMilestonePayment();

      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'p1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'stranger' }),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'unknown_bk', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_found',
      );
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: '../bad', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: '' }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('before the deadline it is not_eligible field not_late and nothing is written; exactly at dueAt it is not_eligible field not_late', async () => {
      seedLateShotBooking();
      seedMilestonePayment();

      // 1 hour before dueAt (2026-10-12T09:00Z)
      world.clock.setTime(new Date('2026-10-12T09:00:00.000Z'));
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'not_late',
      );
      assert.equal(world.store.refunds.size, 0);
      assert.equal(world.store.bookings.get('b1')?.status, 'shot');

      // Exactly at dueAt (2026-10-12T10:00Z)
      world.clock.setTime(new Date('2026-10-12T10:00:00.000Z'));
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'not_late',
      );
      assert.equal(world.store.refunds.size, 0);
    });

    it('on delivered, revision_requested, approved it is not_eligible field delivered; on completed, upcoming it is not_eligible field status', async () => {
      seedMilestonePayment();

      for (const status of ['delivered', 'revision_requested', 'approved'] as const) {
        seedLateShotBooking({ status });
        await assert.rejects(
          () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
          (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'delivered',
        );
      }

      for (const status of ['completed', 'upcoming'] as const) {
        seedLateShotBooking({ status });
        await assert.rejects(
          () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
          (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'status',
        );
      }
    });

    it('a payout stamping payoutId on the shoot milestone between the lookup and the transaction is kept', async () => {
      seedLateShotBooking();
      const initialPayment = seedMilestonePayment();

      const origGetPayments = world.store.getPaymentsForBooking.bind(world.store);
      world.store.getPaymentsForBooking = async (bookingId: string) => {
        const list = await origGetPayments(bookingId);
        // Simulate concurrent payout stamping payoutId on the stored payment right after the query returns the stale snapshot
        assert.ok(initialPayment.milestones);
        const stampedMilestones = initialPayment.milestones.map((m) =>
          m.kind === 'shoot'
            ? { ...m, status: 'paid_out' as const, payoutId: 'po_concurrent', paidOutAt: '2026-10-15T09:59:00.000Z' }
            : m,
        );
        world.store.payments.set(
          initialPayment.id,
          withMilestones(initialPayment, stampedMilestones, '2026-10-15T09:59:00.000Z'),
        );
        return list;
      };

      await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });
      const storedPayment = world.store.payments.get('pay_1');
      const shootMilestone = storedPayment?.milestones?.find((m) => m.kind === 'shoot');
      assert.equal(shootMilestone?.payoutId, 'po_concurrent');
      assert.equal(shootMilestone?.status, 'paid_out');
    });

    it('cancelLateDelivery on a disputed booking is conflict and writes nothing', async () => {
      seedLateShotBooking({ escrowStatus: 'disputed' });
      seedMilestonePayment();

      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
      assert.equal(world.store.refunds.size, 0);
      assert.equal(world.store.ledgerEntries.size, 0);
      assert.equal(world.store.bookings.get('b1')?.status, 'shot');
    });

    it('a legacy payment without milestones is not_eligible', async () => {
      seedLateShotBooking();
      const legacyPayment = { ...seedMilestonePayment(), milestones: undefined };
      world.store.payments.set(legacyPayment.id, legacyPayment);

      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'status',
      );
      assert.equal(world.store.refunds.size, 0);
    });

    it('a second cancelLateDelivery is not_eligible', async () => {
      seedLateShotBooking();
      seedMilestonePayment();

      await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'status',
      );
      assert.equal(world.store.refunds.size, 1);
    });

    it('cancelLateDelivery after a concurrent submitDelivery is not_eligible and submitDelivery after cancelLateDelivery is not_eligible', async () => {
      seedLateShotBooking();
      seedMilestonePayment();
      seedSamples('b1', 'p1');

      // Case 1: submitDelivery wins first -> status is delivered -> cancelLateDelivery refused with field delivered
      await submitDelivery(world.deps, 'p1', {
        bookingId: 'b1',
        sampleIds,
        link: 'https://drive.google.com/drive/folders/123',
        photoCount: 40,
      });
      await assert.rejects(
        () => cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' }),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible' && err.field === 'delivered',
      );

      // Case 2: cancelLateDelivery wins first -> status is completed -> submitDelivery refused with not_eligible
      seedLateShotBooking();
      seedMilestonePayment();
      seedSamples('b1', 'p1');
      await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });
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

    it('the gateway is called once after commit with the refund and a gateway failure leaves the refund pending for the clock', async () => {
      seedLateShotBooking();
      seedMilestonePayment();

      await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });
      const firstRefund = [...world.store.refunds.values()][0];
      assert.ok(firstRefund);
      assert.deepEqual(world.gateway.refundCalls, [firstRefund.id]);
      assert.equal(firstRefund.status, 'done');

      // Reset with gateway outage
      world = createBookingWorld(new Date('2026-10-15T10:00:00.000Z'));
      seedLateShotBooking();
      seedMilestonePayment();
      world.gateway.refundThrowCount = 1;

      const updated = await cancelLateDelivery(world.deps, { bookingId: 'b1', customerId: 'c1' });
      assert.equal(updated.status, 'completed');
      const failedRefund = [...world.store.refunds.values()][0];
      assert.ok(failedRefund);
      assert.equal(failedRefund.status, 'pending');
    });
  });
});
