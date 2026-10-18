import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { FirestoreDiscoveryStatsStore } from '../../src/infra/discovery_firestore.js';
import type { Firestore } from 'firebase-admin/firestore';

describe('discovery firestore adapter mapping', () => {
  test('the patch maps to dotted stats paths and startingPrice', async () => {
    let updatedPath: string | null = null;
    let updatePayload: Record<string, unknown> | null = null;

    const fakeDb = {
      collection(col: string) {
        assert.equal(col, 'photographers');
        return {
          doc(id: string) {
            updatedPath = `${col}/${id}`;
            return {
              update: async (data: Record<string, unknown>) => {
                updatePayload = data;
              },
            };
          },
        };
      },
    } as unknown as Firestore;

    const store = new FirestoreDiscoveryStatsStore(fakeDb);
    await store.apply('p1', {
      nextFreeDate: '2026-10-15',
      completedCount: 5,
      startingPrice: 1_200_000,
    });

    assert.equal(updatedPath, 'photographers/p1');
    assert.ok(updatePayload);
    assert.equal(updatePayload['stats.nextFreeDate'], '2026-10-15');
    assert.equal(updatePayload['stats.completedCount'], 5);
    assert.equal(updatePayload['startingPrice'], 1_200_000);
    assert.ok('stats.discoveryAt' in updatePayload);
  });

  test('ensureScore writes stats.score 0 and leaves stats.reviewCount alone', async () => {
    let updatePayload: Record<string, unknown> | null = null;

    const fakeDb = {
      collection() {
        return {
          doc() {
            return {
              update: async (data: Record<string, unknown>) => {
                updatePayload = data;
              },
            };
          },
        };
      },
    } as unknown as Firestore;

    const store = new FirestoreDiscoveryStatsStore(fakeDb);
    await store.apply('p1', { ensureScore: true });

    assert.ok(updatePayload);
    assert.equal(updatePayload['stats.score'], 0);
    assert.equal('stats.reviewCount' in updatePayload, false);
  });

  test('NOT_FOUND on apply is a no-op', async () => {
    const fakeDb = {
      collection() {
        return {
          doc() {
            return {
              update: async () => {
                const err = new Error('Document not found');
                (err as unknown as { code: number }).code = 5; // NOT_FOUND
                throw err;
              },
            };
          },
        };
      },
    } as unknown as Firestore;

    const store = new FirestoreDiscoveryStatsStore(fakeDb);
    // Should not throw
    await store.apply('missing_p', { nextFreeDate: '2026-10-15' });
  });
});
