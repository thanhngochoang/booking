import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  type Booking,
  type BookingDeps,
  MemoryBookingStore,
  FakePaymentGateway,
  FakeBlockGate,
  type ServiceRecord,
  type CustomerContactRecord,
  MemoryAddonStore,
} from '@photobooking/domain';
import {
  handleSubmitDelivery,
  handleApproveDelivery,
  handleRequestRevision,
  handleAnswerExtraRound,
} from '../../src/callables/delivery.js';
import type { CallableInput } from '../../src/callables/get_contact_link.js';

function createTestDeps(): {
  deps: BookingDeps;
  store: MemoryBookingStore;
} {
  const store = new MemoryBookingStore();
  const addonStore = new MemoryAddonStore();
  const gateway = new FakePaymentGateway();
  const blocks = new FakeBlockGate();
  let idCounter = 1;

  const servicesMap = new Map<string, ServiceRecord>([
    ['svc1', { id: 'svc1', photographerId: 'p1', name: 'Gói chụp chân dung', price: 1_000_000, durationMinutes: 120, active: true }],
  ]);

  const contactsMap = new Map<string, CustomerContactRecord>([
    ['c1', { name: 'Nguyễn Văn A', phone: '+84903123456', allowZalo: true, allowWhatsApp: false }],
  ]);

  const deps: BookingDeps = {
    store,
    services: {
      getService: async (photographerId, id) => {
        const svc = servicesMap.get(id);
        return svc === undefined ? null : { ...svc, photographerId };
      },
    },
    addons: addonStore,
    contacts: {
      get: async (uid) => contactsMap.get(uid) ?? null,
    },
    providers: { acceptsOrders: async () => true },
    blocks,
    gateway,
    cipher: {
      encrypt: async (text: string) => `enc_${text}`,
      decrypt: async (text: string) => text.replace(/^enc_/, ''),
    },
    clock: { now: () => new Date('2026-10-17T12:00:00.000Z') },
    ids: { newId: () => `id_${idCounter++}` },
  };

  return { deps, store };
}

function makeShotBooking(id = 'b1'): Booking {
  return {
    id,
    customerId: 'c1',
    photographerId: 'p1',
    serviceId: 'svc1',
    serviceSnapshot: { name: 'Gói chụp', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Studio', point: { lat: 10, lng: 106 } },
    status: 'shot',
    deposit: 1_000_000,
    remaining: 0,
    escrowStatus: 'held',
    revisionsIncluded: 1,
    revisionsUsed: 0,
    revisionsGranted: 0,
    version: 1,
    createdAt: '2026-10-15T08:00:00.000Z',
    updatedAt: '2026-10-15T16:00:00.000Z',
  };
}

describe('delivery callables', () => {
  describe('unauthenticated requests', () => {
    test('refuses unauthenticated callers', async () => {
      const { deps } = createTestDeps();
      const unauthReq: CallableInput = { auth: undefined, data: {} };

      await assert.rejects(
        () => handleSubmitDelivery(unauthReq, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'unauthenticated',
      );
      await assert.rejects(
        () => handleApproveDelivery(unauthReq, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'unauthenticated',
      );
      await assert.rejects(
        () => handleRequestRevision(unauthReq, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'unauthenticated',
      );
      await assert.rejects(
        () => handleAnswerExtraRound(unauthReq, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'unauthenticated',
      );
    });
  });

  describe('handleSubmitDelivery', () => {
    test('succeeds for provider with ready samples', async () => {
      const { deps, store } = createTestDeps();
      const b = makeShotBooking();
      await store.runTransaction(async (tx) => {
        await tx.setBooking(b);
      });
      store.deliverySamples.set(`${b.id}_s1`, {
        fileId: 's1',
        uploaderId: 'p1',
        status: 'ready',
        path: 'p1.jpg',
        thumbPath: 't1.jpg',
        width: 800,
        height: 600,
        bytes: 1000,
        failure: null,
      });
      store.deliverySamples.set(`${b.id}_s2`, {
        fileId: 's2',
        uploaderId: 'p1',
        status: 'ready',
        path: 'p2.jpg',
        thumbPath: 't2.jpg',
        width: 800,
        height: 600,
        bytes: 1000,
        failure: null,
      });
      store.deliverySamples.set(`${b.id}_s3`, {
        fileId: 's3',
        uploaderId: 'p1',
        status: 'ready',
        path: 'p3.jpg',
        thumbPath: 't3.jpg',
        width: 800,
        height: 600,
        bytes: 1000,
        failure: null,
      });

      const req: CallableInput = {
        auth: { uid: 'p1' },
        data: {
          bookingId: 'b1',
          sampleIds: ['s1', 's2', 's3'],
          link: 'https://drive.google.com/folders/xyz',
          photoCount: 50,
          note: 'Gửi bạn ảnh nhé',
        },
      };

      const res = await handleSubmitDelivery(req, deps);
      assert.deepEqual(res, { round: 1 });
    });

    test('refuses caller who is not provider with permission_denied', async () => {
      const { deps, store } = createTestDeps();
      await store.runTransaction(async (tx) => {
        await tx.setBooking(makeShotBooking());
      });

      const req: CallableInput = {
        auth: { uid: 'c1' },
        data: {
          bookingId: 'b1',
          sampleIds: ['s1', 's2', 's3'],
          link: 'https://drive.google.com/folders/xyz',
          photoCount: 50,
        },
      };

      await assert.rejects(
        () => handleSubmitDelivery(req, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'permission-denied',
      );
    });

    test('maps not_ready to failed-precondition when sample not ready', async () => {
      const { deps, store } = createTestDeps();
      await store.runTransaction(async (tx) => {
        await tx.setBooking(makeShotBooking());
      });
      store.deliverySamples.set('b1_s1', {
        fileId: 's1',
        uploaderId: 'p1',
        status: 'failed',
        path: 'p1.jpg',
        thumbPath: 't1.jpg',
        width: 800,
        height: 600,
        bytes: 1000,
        failure: 'corrupt',
      });

      const req: CallableInput = {
        auth: { uid: 'p1' },
        data: {
          bookingId: 'b1',
          sampleIds: ['s1', 's2', 's3'],
          link: 'https://drive.google.com/folders/xyz',
          photoCount: 50,
        },
      };

      await assert.rejects(
        () => handleSubmitDelivery(req, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'failed-precondition' && (err.details as { code?: unknown } | undefined)?.code === 'not_ready',
      );
    });
  });

  describe('handleApproveDelivery', () => {
    test('succeeds for customer', async () => {
      const { deps, store } = createTestDeps();
      const b: Booking = {
        ...makeShotBooking(),
        status: 'delivered',
        deliveryRound: 1,
        deliveredAt: '2026-10-16T12:00:00.000Z',
      };
      await store.runTransaction(async (tx) => {
        await tx.setBooking(b);
        await tx.setDelivery({
          bookingId: b.id,
          round: 1,
          samples: [],
          photoCount: 50,
          linkHost: 'drive.google.com',
          note: null,
          submittedAt: '2026-10-16T12:00:00.000Z',
          submittedBy: 'p1',
          decision: null,
        });
        await tx.setPrivateDelivery(b.id, {
          link: 'https://drive.google.com/x',
          round: 1,
          unlockedAt: null,
          updatedAt: '2026-10-16T12:00:00.000Z',
        });
      });

      const req: CallableInput = { auth: { uid: 'c1' }, data: { bookingId: 'b1' } };
      const res = await handleApproveDelivery(req, deps);
      assert.deepEqual(res, { status: 'approved' });
    });

    test('refuses provider with permission-denied', async () => {
      const { deps, store } = createTestDeps();
      await store.runTransaction(async (tx) => {
        await tx.setBooking({ ...makeShotBooking(), status: 'delivered' });
      });

      const req: CallableInput = { auth: { uid: 'p1' }, data: { bookingId: 'b1' } };
      await assert.rejects(
        () => handleApproveDelivery(req, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'permission-denied',
      );
    });
  });

  describe('handleRequestRevision', () => {
    test('succeeds when revisions left', async () => {
      const { deps, store } = createTestDeps();
      const b: Booking = {
        ...makeShotBooking(),
        status: 'delivered',
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 0,
      };
      await store.runTransaction(async (tx) => {
        await tx.setBooking(b);
        await tx.setDelivery({
          bookingId: b.id,
          round: 1,
          samples: [{ fileId: 's1', path: 'p1', thumbPath: 't1', width: 800, height: 600 }],
          photoCount: 50,
          linkHost: 'drive.google.com',
          note: null,
          submittedAt: '2026-10-16T12:00:00.000Z',
          submittedBy: 'p1',
          decision: null,
        });
      });

      const req: CallableInput = {
        auth: { uid: 'c1' },
        data: {
          bookingId: 'b1',
          note: 'Chỉnh thêm giúp mình',
          photoNotes: [{ sampleIndex: 0, note: 'Làm mịn da' }],
        },
      };

      const res = await handleRequestRevision(req, deps);
      assert.deepEqual(res, { status: 'revision_requested' });
    });

    test('refuses empty revision request with invalid-argument', async () => {
      const { deps, store } = createTestDeps();
      await store.runTransaction(async (tx) => {
        await tx.setBooking({ ...makeShotBooking(), status: 'delivered' });
      });

      const req: CallableInput = {
        auth: { uid: 'c1' },
        data: { bookingId: 'b1' },
      };

      await assert.rejects(
        () => handleRequestRevision(req, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'invalid-argument',
      );
    });
  });

  describe('handleAnswerExtraRound', () => {
    test('succeeds for provider granting round', async () => {
      const { deps, store } = createTestDeps();
      const b: Booking = {
        ...makeShotBooking(),
        status: 'delivered',
        deliveryRound: 1,
        revisionsIncluded: 1,
        revisionsUsed: 1,
        extraRound: {
          status: 'pending',
          at: '2026-10-17T10:00:00.000Z',
          note: 'Xin thêm lượt',
          photoNotes: [],
        },
      };
      await store.runTransaction(async (tx) => {
        await tx.setBooking(b);
        await tx.setDelivery({
          bookingId: b.id,
          round: 1,
          samples: [],
          photoCount: 50,
          linkHost: 'drive.google.com',
          note: null,
          submittedAt: '2026-10-16T12:00:00.000Z',
          submittedBy: 'p1',
          decision: null,
        });
      });

      const req: CallableInput = {
        auth: { uid: 'p1' },
        data: { bookingId: 'b1', grant: true },
      };

      const res = await handleAnswerExtraRound(req, deps);
      assert.deepEqual(res, { status: 'revision_requested' });
    });

    test('refuses customer with permission-denied', async () => {
      const { deps, store } = createTestDeps();
      await store.runTransaction(async (tx) => {
        await tx.setBooking({
          ...makeShotBooking(),
          status: 'delivered',
          extraRound: { status: 'pending', at: '2026-10-17T10:00:00.000Z', note: null, photoNotes: [] },
        });
      });

      const req: CallableInput = {
        auth: { uid: 'c1' },
        data: { bookingId: 'b1', grant: true },
      };

      await assert.rejects(
        () => handleAnswerExtraRound(req, deps),
        (err: unknown) => err instanceof HttpsError && err.code === 'permission-denied',
      );
    });
  });
});
