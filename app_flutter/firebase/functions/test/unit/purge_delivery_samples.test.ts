import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { purgeDeliverySamples } from '../../src/scheduled/purge_delivery_samples.js';

describe('purgeDeliverySamples', () => {
  it('deletes sample and thumbnail objects of every round, sets samplesPurged and clears samplesPurgeAfter', async () => {
    const deletedFiles: string[] = [];
    const updatedDocs: Record<string, any> = {};

    const fakeBucket: any = {
      file: (path: string) => ({
        delete: async () => {
          deletedFiles.push(path);
          return [{}];
        },
      }),
    };

    const roundDocs = [
      {
        id: '1',
        data: () => ({
          samples: [
            { path: 'deliveries/b1/s1.jpg', thumbPath: 'deliveries/b1/s1_thumb.jpg' },
            { path: 'deliveries/b1/s2.jpg', thumbPath: 'deliveries/b1/s2_thumb.jpg' },
          ],
        }),
      },
      {
        id: '2',
        data: () => ({
          samples: [
            { path: 'deliveries/b1/s3.jpg', thumbPath: 'deliveries/b1/s3_thumb.jpg' },
          ],
        }),
      },
    ];

    const bookingDoc = {
      id: 'b1',
      data: () => ({
        status: 'completed',
        samplesPurged: false,
        escrowStatus: 'released',
      }),
      ref: {
        collection: (name: string) => {
          if (name === 'deliveries') {
            return {
              get: async () => ({ docs: roundDocs }),
            };
          }
          return { get: async () => ({ docs: [] }) };
        },
        update: async (fields: any) => {
          updatedDocs['b1'] = fields;
        },
      },
    };

    const fakeDb: any = {
      collection: () => ({
        where: function () {
          return this;
        },
        limit: function () {
          return this;
        },
        get: async () => ({
          docs: [bookingDoc],
        }),
      }),
    };

    const count = await purgeDeliverySamples({
      db: fakeDb,
      bucket: fakeBucket,
      now: new Date('2026-10-17T12:00:00.000Z'),
    });

    assert.equal(count, 1);
    assert.deepEqual(deletedFiles.sort(), [
      'deliveries/b1/s1.jpg',
      'deliveries/b1/s1_thumb.jpg',
      'deliveries/b1/s2.jpg',
      'deliveries/b1/s2_thumb.jpg',
      'deliveries/b1/s3.jpg',
      'deliveries/b1/s3_thumb.jpg',
    ].sort());
    assert.deepEqual(updatedDocs['b1'], {
      samplesPurged: true,
      samplesPurgeAfter: null,
    });
  });

  it('skips a disputed booking', async () => {
    const deletedFiles: string[] = [];
    const updatedDocs: Record<string, any> = {};

    const fakeBucket: any = {
      file: (path: string) => ({
        delete: async () => {
          deletedFiles.push(path);
          return [{}];
        },
      }),
    };

    const disputedDoc = {
      id: 'b_disputed',
      data: () => ({
        status: 'completed',
        samplesPurged: false,
        escrowStatus: 'disputed',
      }),
      ref: {
        collection: () => ({ get: async () => ({ docs: [] }) }),
        update: async (fields: any) => {
          updatedDocs['b_disputed'] = fields;
        },
      },
    };

    const fakeDb: any = {
      collection: () => ({
        where: function () {
          return this;
        },
        limit: function () {
          return this;
        },
        get: async () => ({
          docs: [disputedDoc],
        }),
      }),
    };

    const count = await purgeDeliverySamples({
      db: fakeDb,
      bucket: fakeBucket,
      now: new Date('2026-10-17T12:00:00.000Z'),
    });

    assert.equal(count, 0);
    assert.equal(deletedFiles.length, 0);
    assert.equal(updatedDocs['b_disputed'], undefined);
  });

  it('missing objects are not an error', async () => {
    let updateCalled = false;

    const fakeBucket: any = {
      file: () => ({
        delete: async () => {
          throw new Error('Not found');
        },
      }),
    };

    const bookingDoc = {
      id: 'b1',
      data: () => ({
        status: 'completed',
        samplesPurged: false,
        escrowStatus: 'released',
      }),
      ref: {
        collection: () => ({
          get: async () => ({
            docs: [
              {
                id: '1',
                data: () => ({
                  samples: [{ path: 'missing.jpg', thumbPath: 'missing_thumb.jpg' }],
                }),
              },
            ],
          }),
        }),
        update: async () => {
          updateCalled = true;
        },
      },
    };

    const fakeDb: any = {
      collection: () => ({
        where: function () {
          return this;
        },
        limit: function () {
          return this;
        },
        get: async () => ({ docs: [bookingDoc] }),
      }),
    };

    const count = await purgeDeliverySamples({
      db: fakeDb,
      bucket: fakeBucket,
      now: new Date('2026-10-17T12:00:00.000Z'),
    });

    assert.equal(count, 1);
    assert.equal(updateCalled, true);
  });

  it('stops at the limit', async () => {
    let requestedLimit = 0;
    const fakeDb: any = {
      collection: () => ({
        where: function () {
          return this;
        },
        limit: function (n: number) {
          requestedLimit = n;
          return this;
        },
        get: async () => ({ docs: [] }),
      }),
    };

    await purgeDeliverySamples({
      db: fakeDb,
      bucket: {} as any,
      now: new Date('2026-10-17T12:00:00.000Z'),
      limit: 15,
    });

    assert.equal(requestedLimit, 15);
  });
});
