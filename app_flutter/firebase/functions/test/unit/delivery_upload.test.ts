import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import type { Booking } from '@photobooking/domain';
import {
  handleDeliveryUpload,
  type DeliveryUploadDeps,
} from '../../src/triggers/delivery_upload.js';
import { loadWatermarkFont } from '../../src/infra/watermark.js';

describe('delivery_upload trigger', () => {
  const font = loadWatermarkFont();

  function makeDeps(overrides: Partial<DeliveryUploadDeps> = {}): {
    deps: DeliveryUploadDeps;
    writtenSamples: Record<string, any>;
    uploadedFiles: Record<string, Buffer>;
    deletedFiles: string[];
  } {
    const writtenSamples: Record<string, any> = {};
    const uploadedFiles: Record<string, Buffer> = {};
    const deletedFiles: string[] = [];

    const defaultBooking: Booking = {
      id: 'b1',
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 's1',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-15',
      start: '14:00',
      end: '16:00',
      place: { name: 'Hồ Gươm' },
      status: 'shot',
      deposit: 1_000_000,
      remaining: 0,
      escrowStatus: 'held',
      version: 1,
      createdAt: '2026-10-15T08:00:00.000Z',
      updatedAt: '2026-10-15T16:00:00.000Z',
    };

    const deps: DeliveryUploadDeps = {
      readBooking: async (id) => (id === 'b1' ? defaultBooking : null),
      providerName: async (uid) => (uid === 'p1' ? 'Nguyễn Văn An' : null),
      download: async () =>
        await sharp({
          create: { width: 1000, height: 800, channels: 3, background: '#7aa' },
        })
          .jpeg()
          .toBuffer(),
      upload: async (path, data) => {
        uploadedFiles[path] = data;
      },
      remove: async (path) => {
        deletedFiles.push(path);
      },
      sampleDoc: async () => null,
      writeSample: async (_bId, fId, data) => {
        writtenSamples[fId] = data;
      },
      font: () => font,
      now: () => new Date('2026-10-17T12:00:00.000Z'),
      ...overrides,
    };

    return { deps, writtenSamples, uploadedFiles, deletedFiles };
  }

  it('handleDeliveryUpload ignores other paths', async () => {
    let downloadCalled = false;
    let removeCalled = false;
    const { deps } = makeDeps({
      download: async () => {
        downloadCalled = true;
        return Buffer.alloc(0);
      },
      remove: async () => {
        removeCalled = true;
      },
    });

    const res = await handleDeliveryUpload({ name: 'other/folder/file.jpg' }, deps);
    assert.equal(res, 'ignored');
    assert.equal(downloadCalled, false);
    assert.equal(removeCalled, false);
  });

  it('writes the sample, the thumbnail and a ready doc for the provider of a shot booking', async () => {
    const { deps, writtenSamples, uploadedFiles, deletedFiles } = makeDeps();

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/p1/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/jpeg', size: 100_000 },
      deps,
    );

    assert.equal(res, 'ready');
    assert.equal(deletedFiles.includes(uploadPath), true);
    assert.ok(uploadedFiles[`deliveries/b1/${ulid}.jpg`]);
    assert.ok(uploadedFiles[`deliveries/b1/${ulid}_t.jpg`]);

    const sampleDoc = writtenSamples[ulid];
    assert.ok(sampleDoc);
    assert.equal(sampleDoc.status, 'ready');
    assert.equal(sampleDoc.uploaderId, 'p1');
    assert.equal(sampleDoc.failure, null);
  });

  it('refuses an uploader who is not booking.photographerId: failed doc not_allowed', async () => {
    const { deps, writtenSamples, deletedFiles } = makeDeps();

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/stranger/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/jpeg', size: 100_000 },
      deps,
    );

    assert.equal(res, 'failed');
    assert.equal(deletedFiles.includes(uploadPath), true);
    assert.equal(writtenSamples[ulid]?.status, 'failed');
    assert.equal(writtenSamples[ulid]?.failure, 'not_allowed');
  });

  it('refuses a booking that is not shot or revision_requested', async () => {
    const { deps, writtenSamples, deletedFiles } = makeDeps({
      readBooking: async () => ({
        id: 'b1',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
        day: '2026-10-15',
        start: '14:00',
        end: '16:00',
        place: { name: 'Hồ Gươm' },
        status: 'upcoming',
        deposit: 1_000_000,
        remaining: 0,
        escrowStatus: 'held',
        version: 1,
        createdAt: '2026-10-15T08:00:00.000Z',
        updatedAt: '2026-10-15T16:00:00.000Z',
      }),
    });

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/p1/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/jpeg', size: 100_000 },
      deps,
    );

    assert.equal(res, 'failed');
    assert.equal(deletedFiles.includes(uploadPath), true);
    assert.equal(writtenSamples[ulid]?.status, 'failed');
    assert.equal(writtenSamples[ulid]?.failure, 'not_eligible');
  });

  it('marks an oversized upload too_large without downloading it', async () => {
    let downloadCalled = false;
    const { deps, writtenSamples, deletedFiles } = makeDeps({
      download: async () => {
        downloadCalled = true;
        return Buffer.alloc(0);
      },
    });

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/p1/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/jpeg', size: 3 * 1024 * 1024 },
      deps,
    );

    assert.equal(res, 'failed');
    assert.equal(downloadCalled, false);
    assert.equal(deletedFiles.includes(uploadPath), true);
    assert.equal(writtenSamples[ulid]?.failure, 'too_large');
  });

  it('marks a non-JPEG unsupported', async () => {
    let downloadCalled = false;
    const { deps, writtenSamples, deletedFiles } = makeDeps({
      download: async () => {
        downloadCalled = true;
        return Buffer.alloc(0);
      },
    });

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/p1/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/png', size: 100_000 },
      deps,
    );

    assert.equal(res, 'failed');
    assert.equal(downloadCalled, false);
    assert.equal(deletedFiles.includes(uploadPath), true);
    assert.equal(writtenSamples[ulid]?.failure, 'unsupported');
  });

  it('a retry of an already ready sample returns already and only deletes the clean upload', async () => {
    let downloadCalled = false;
    const { deps, deletedFiles } = makeDeps({
      sampleDoc: async () => ({ status: 'ready' }),
      download: async () => {
        downloadCalled = true;
        return Buffer.alloc(0);
      },
    });

    const ulid = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
    const uploadPath = `deliveryUploads/b1/p1/${ulid}.jpg`;

    const res = await handleDeliveryUpload(
      { name: uploadPath, contentType: 'image/jpeg', size: 100_000 },
      deps,
    );

    assert.equal(res, 'already');
    assert.equal(downloadCalled, false);
    assert.equal(deletedFiles.includes(uploadPath), true);
  });
});
