import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { pruneDataExports } from '../../src/scheduled/prune_data_exports.js';

describe('prune_data_exports', () => {
  it('deletes exports older than 7 days and keeps newer ones', async () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const oldDate = new Date('2026-10-10T10:00:00Z').toISOString(); // 11 days ago
    const newDate = new Date('2026-10-19T10:00:00Z').toISOString(); // 2 days ago

    const deletedFiles: string[] = [];

    const mockBucket: any = {
      getFiles: async () => [
        [
          {
            name: 'exports/u1/old.json',
            getMetadata: async () => [{ timeCreated: oldDate }],
            delete: async () => {
              deletedFiles.push('exports/u1/old.json');
            },
          },
          {
            name: 'exports/u1/new.json',
            getMetadata: async () => [{ timeCreated: newDate }],
            delete: async () => {
              deletedFiles.push('exports/u1/new.json');
            },
          },
        ],
      ],
    };

    const count = await pruneDataExports(mockBucket, now);
    assert.equal(count, 1);
    assert.deepEqual(deletedFiles, ['exports/u1/old.json']);
  });
});
