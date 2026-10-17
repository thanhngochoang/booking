import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  canDeliver,
  deliveryNotices,
  parseDeliveryUploadPath,
  revisionAllowance,
  validateRevisionRequest,
  validateSubmitDelivery,
  watermarkLabel,
} from '../src/delivery.js';
import type { Booking } from '../src/booking.js';
import { DomainError } from '../src/errors.js';

describe('delivery domain unit tests', () => {
  const baseBooking: Booking = {
    id: 'b1',
    customerId: 'c1',
    photographerId: 'p1',
    serviceId: 's1',
    serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Studio' },
    status: 'shot',
    deposit: 1_000_000,
    remaining: 0,
    version: 1,
    createdAt: '2026-10-10T10:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('canDeliver returns true only for photographerId', () => {
    assert.equal(canDeliver(baseBooking, 'p1'), true);
    assert.equal(canDeliver(baseBooking, 'c1'), false);
    assert.equal(canDeliver(baseBooking, 'other'), false);
  });

  describe('validateSubmitDelivery', () => {
    const validSamples = ['01ARZ3NDEKTSV4RRFFQ69G5FAV', '01ARZ3NDEKTSV4RRFFQ69G5FAW', '01ARZ3NDEKTSV4RRFFQ69G5FAX'];

    it('validateSubmitDelivery accepts 3 and 20 samples, refuses 2 and 21', () => {
      const res3 = validateSubmitDelivery({
        bookingId: 'b1',
        sampleIds: validSamples,
        link: 'https://drive.google.com/drive/folders/123',
        photoCount: 50,
      });
      assert.equal(res3.sampleIds.length, 3);

      const samples20 = Array.from({ length: 20 }, (_, i) => `01ARZ3NDEKTSV4RRFFQ69G5FA${String(i).padStart(2, '0')}`);
      const res20 = validateSubmitDelivery({
        bookingId: 'b1',
        sampleIds: samples20,
        link: 'https://drive.google.com/drive/folders/123',
        photoCount: 50,
      });
      assert.equal(res20.sampleIds.length, 20);

      // refuses 2
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples.slice(0, 2),
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      // refuses 21
      const samples21 = Array.from({ length: 21 }, (_, i) => `01ARZ3NDEKTSV4RRFFQ69G5FA${String(i).padStart(2, '0')}`);
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: samples21,
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('refuses duplicate sample ids', () => {
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: [validSamples[0], validSamples[0], validSamples[1]],
            link: 'https://drive.google.com/drive/folders/123',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('refuses ftp://, a link without a host dot, a link with spaces and a 2,001-char link', () => {
      // ftp://
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'ftp://drive.google.com/folder',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      // link without host dot
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://localhost/folder',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      // link with spaces
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://drive.google.com/my folder',
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      // 2001 chars
      const longLink = `https://drive.google.com/${'a'.repeat(2001)}`;
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: longLink,
            photoCount: 50,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('linkHost is the URL host', () => {
      const res = validateSubmitDelivery({
        bookingId: 'b1',
        sampleIds: validSamples,
        link: 'https://drive.google.com/drive/folders/xyz?usp=sharing',
        photoCount: 50,
      });
      assert.equal(res.linkHost, 'drive.google.com');
    });

    it('photoCount must be 1..10000 integer', () => {
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://drive.google.com/folder',
            photoCount: 0,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://drive.google.com/folder',
            photoCount: 10001,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://drive.google.com/folder',
            photoCount: 50.5,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('note over 500 graphemes is invalid', () => {
      assert.throws(
        () =>
          validateSubmitDelivery({
            bookingId: 'b1',
            sampleIds: validSamples,
            link: 'https://drive.google.com/folder',
            photoCount: 50,
            note: 'a'.repeat(501),
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });
  });

  describe('validateRevisionRequest', () => {
    it('validateRevisionRequest refuses an empty request', () => {
      assert.throws(
        () =>
          validateRevisionRequest({
            bookingId: 'b1',
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      assert.throws(
        () =>
          validateRevisionRequest({
            bookingId: 'b1',
            note: '   ',
            photoNotes: [],
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });

    it('refuses a photo note over 120 graphemes and a duplicate index', () => {
      assert.throws(
        () =>
          validateRevisionRequest({
            bookingId: 'b1',
            photoNotes: [{ sampleIndex: 0, note: 'a'.repeat(121) }],
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      assert.throws(
        () =>
          validateRevisionRequest({
            bookingId: 'b1',
            photoNotes: [
              { sampleIndex: 0, note: 'Sửa da' },
              { sampleIndex: 0, note: 'Chỉnh sáng' },
            ],
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });
  });

  describe('parseDeliveryUploadPath', () => {
    it('parseDeliveryUploadPath accepts deliveryUploads/b1/u1/{ULID}.jpg and refuses other prefixes, extra segments and non-ULID names', () => {
      const ok = parseDeliveryUploadPath('deliveryUploads/b1/u1/01ARZ3NDEKTSV4RRFFQ69G5FAV.jpg');
      assert.deepEqual(ok, {
        bookingId: 'b1',
        uploaderId: 'u1',
        fileId: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
      });

      assert.equal(parseDeliveryUploadPath('uploads/b1/u1/01ARZ3NDEKTSV4RRFFQ69G5FAV.jpg'), null);
      assert.equal(parseDeliveryUploadPath('deliveryUploads/b1/u1/extra/01ARZ3NDEKTSV4RRFFQ69G5FAV.jpg'), null);
      assert.equal(parseDeliveryUploadPath('deliveryUploads/b1/u1/not-a-ulid.jpg'), null);
      assert.equal(parseDeliveryUploadPath('deliveryUploads/b1/u1/01ARZ3NDEKTSV4RRFFQ69G5FAV.png'), null);
    });
  });

  describe('watermarkLabel', () => {
    it('watermarkLabel falls back to "Nhiếp ảnh gia · Bản xem trước"', () => {
      assert.equal(watermarkLabel('Minh Trí'), 'Minh Trí · Bản xem trước');
      assert.equal(watermarkLabel(null), 'Nhiếp ảnh gia · Bản xem trước');
      assert.equal(watermarkLabel('   '), 'Nhiếp ảnh gia · Bản xem trước');
      assert.equal(watermarkLabel(undefined), 'Nhiếp ảnh gia · Bản xem trước');
    });
  });

  describe('revisionAllowance', () => {
    it('revisionAllowance adds granted rounds', () => {
      const b: Booking = {
        ...baseBooking,
        revisionsIncluded: 2,
        revisionsGranted: 1,
        revisionsUsed: 1,
      };
      const res = revisionAllowance(b);
      assert.equal(res.total, 3);
      assert.equal(res.used, 1);
      assert.equal(res.left, 2);
    });

    it('revisionAllowance of a booking without revisionsIncluded counts 1 free round', () => {
      const b: Booking = {
        ...baseBooking,
        revisionsIncluded: undefined,
        revisionsUsed: 1,
      };
      const res = revisionAllowance(b);
      assert.equal(res.total, 1);
      assert.equal(res.used, 1);
      assert.equal(res.left, 0);
    });
  });

  describe('deliveryNotices', () => {
    it('deliveryNotices: shot → delivered is submitted (round 1)', () => {
      const before: Booking = { ...baseBooking, status: 'shot' };
      const after: Booking = { ...baseBooking, status: 'delivered', deliveryRound: 1 };
      assert.deepEqual(deliveryNotices(before, after), [{ kind: 'submitted', round: 1 }]);
    });

    it('delivered → revision_requested by a request is revision_requested', () => {
      const before: Booking = { ...baseBooking, status: 'delivered', deliveryRound: 1 };
      const after: Booking = { ...baseBooking, status: 'revision_requested', deliveryRound: 1 };
      assert.deepEqual(deliveryNotices(before, after), [{ kind: 'revision_requested', round: 1 }]);
    });

    it('a granted extra round is extra_round granted and not revision_requested', () => {
      const before: Booking = {
        ...baseBooking,
        status: 'delivered',
        deliveryRound: 1,
        extraRound: { status: 'pending', at: '2026-10-12T10:00:00.000Z', note: null, photoNotes: [] },
      };
      const after: Booking = {
        ...baseBooking,
        status: 'revision_requested',
        deliveryRound: 1,
        extraRound: { status: 'granted', at: '2026-10-12T10:05:00.000Z', note: null, photoNotes: [] },
      };
      assert.deepEqual(deliveryNotices(before, after), [{ kind: 'extra_round', round: 1, granted: true }]);
    });

    it('a declined extra round is extra_round granted false', () => {
      const before: Booking = {
        ...baseBooking,
        status: 'delivered',
        deliveryRound: 1,
        extraRound: { status: 'pending', at: '2026-10-12T10:00:00.000Z', note: null, photoNotes: [] },
      };
      const after: Booking = {
        ...baseBooking,
        status: 'delivered',
        deliveryRound: 1,
        extraRound: { status: 'declined', at: '2026-10-12T10:05:00.000Z', note: null, photoNotes: [] },
      };
      assert.deepEqual(deliveryNotices(before, after), [{ kind: 'extra_round', round: 1, granted: false }]);
    });

    it('delivered → approved (customer or auto) is approved', () => {
      const before: Booking = { ...baseBooking, status: 'delivered', deliveryRound: 1 };
      const after: Booking = { ...baseBooking, status: 'approved', deliveryRound: 1 };
      assert.deepEqual(deliveryNotices(before, after), [{ kind: 'approved' }]);
    });

    it('an unrelated write (chat id) gives no notice', () => {
      const before: Booking = { ...baseBooking, status: 'delivered', deliveryRound: 1 };
      const after: Booking = { ...baseBooking, status: 'delivered', deliveryRound: 1, chatId: 'c123' };
      assert.deepEqual(deliveryNotices(before, after), []);
    });
  });

  describe('findDueAutoApproveNotices (memory store)', () => {
    it('returns delivered bookings whose autoApproveAt is within 24 h and autoApproveNoticeAt is null', async () => {
      const { MemoryBookingStore } = await import('../src/memory_booking_store.js');
      const store = new MemoryBookingStore();
      const now = new Date('2026-10-15T10:00:00.000Z');

      // Booking 1: autoApproveAt is in 12h (within 24h), notice null -> returned
      const b1: Booking = {
        ...baseBooking,
        id: 'b1',
        status: 'delivered',
        autoApproveAt: new Date(now.getTime() + 12 * 3600 * 1000).toISOString(),
        autoApproveNoticeAt: null,
      };
      // Booking 2: autoApproveAt in 30h -> not returned
      const b2: Booking = {
        ...baseBooking,
        id: 'b2',
        status: 'delivered',
        autoApproveAt: new Date(now.getTime() + 30 * 3600 * 1000).toISOString(),
        autoApproveNoticeAt: null,
      };
      // Booking 3: autoApproveNoticeAt already set -> not returned
      const b3: Booking = {
        ...baseBooking,
        id: 'b3',
        status: 'delivered',
        autoApproveAt: new Date(now.getTime() + 12 * 3600 * 1000).toISOString(),
        autoApproveNoticeAt: '2026-10-15T09:00:00.000Z',
      };
      // Booking 4: not delivered -> not returned
      const b4: Booking = {
        ...baseBooking,
        id: 'b4',
        status: 'shot',
        autoApproveAt: new Date(now.getTime() + 12 * 3600 * 1000).toISOString(),
        autoApproveNoticeAt: null,
      };

      store.bookings.set(b1.id, b1);
      store.bookings.set(b2.id, b2);
      store.bookings.set(b3.id, b3);
      store.bookings.set(b4.id, b4);

      const due = await store.findDueAutoApproveNotices(now);
      assert.equal(due.length, 1);
      assert.equal(due[0]?.id, 'b1');
    });
  });
});
