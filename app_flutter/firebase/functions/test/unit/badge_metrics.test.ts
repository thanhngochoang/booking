import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { FirestoreBadgeMetricsReader } from '../../src/infra/badge_firestore.js';

/** Records every read; answers `get` with `docs[path]` and `count()` with `counts[description]`. */
function fakeDb(docs: Record<string, unknown>, counts: Record<string, number>, lists: Record<string, unknown[]> = {}) {
  const log: string[] = [];
  const query = (name: string, filters: string[]) => ({
    where: (f: string, op: string, v: unknown) => query(name, [...filters, `${f} ${op} ${JSON.stringify(v)}`]),
    limit: () => query(name, filters),
    count: () => ({
      get: async () => {
        const key = `${name}|${filters.join(' & ')}`;
        log.push(`count ${key}`);
        return { data: () => ({ count: counts[key] ?? 0 }) };
      },
    }),
    get: async () => {
      const key = `${name}|${filters.join(' & ')}`;
      log.push(`list ${key}`);
      return { docs: (lists[key] ?? []).map((d) => ({ data: () => d })) };
    },
  });
  const collection = (name: string) => ({
    ...query(name, []),
    doc: (id: string) => ({
      get: async () => {
        log.push(`get ${name}/${id}`);
        const data = docs[`${name}/${id}`];
        return { exists: data !== undefined, data: () => data };
      },
      collection: (sub: string) => collection(`${name}/${id}/${sub}`),
    }),
  });
  return { db: { collection } as unknown as Firestore, log };
}

const NOW = new Date('2026-10-10T00:00:00.000Z');

describe('FirestoreBadgeMetricsReader', () => {
  it('asks only the requested metrics', async () => {
    const { db, log } = fakeDb({ 'photographers/u1': { stats: { rating: 4.85, reviewCount: 30 } } }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['rating', 'reviewCount'] as const));
    assert.deepEqual(log, ['get photographers/u1']);
    assert.deepEqual(m, { rating: 4.9, reviewCount: 30 });
  });

  it('counts through aggregation queries, one per metric', async () => {
    const { db, log } = fakeDb({}, {
      'bookings|photographerId == "u1" & status in ["completed","reviewed"]': 12,
      'posts|photographerId == "u1" & kind == "work"': 6,
      'photographers/u1/services|active == true': 1,
    });
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read(
      'u1',
      new Set(['completedShoots', 'workPosts', 'activeServices'] as const),
    );
    assert.deepEqual(m, { completedShoots: 12, workPosts: 6, activeServices: 1 });
    assert.equal(log.length, 3);
    assert.ok(log.every((l) => l.startsWith('count ')));
  });

  it('reads account age from users/{uid}.createdAt', async () => {
    const { db } = fakeDb({ 'users/u1': { createdAt: Timestamp.fromDate(new Date('2026-09-20T00:00:00.000Z')) } }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['accountAgeDays'] as const));
    assert.equal(m.accountAgeDays, 20);
  });

  it('detailedReviews counts texts of 50+ graphemes', async () => {
    const long = 'Ảnh đẹp, nhiếp ảnh gia rất nhiệt tình và đúng giờ, mình rất hài lòng.';
    const { db } = fakeDb({}, {}, {
      'reviews|customerId == "u1"': [{ text: long }, { text: 'Tốt' }, { text: 'a'.repeat(49) }, { text: 'b'.repeat(50) }, {}],
    });
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['detailedReviews'] as const));
    assert.equal(m.detailedReviews, 2);
  });

  it('absent stats give null for rating and 0 for counts', async () => {
    const { db } = fakeDb({ 'photographers/u1': {} }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read(
      'u1',
      new Set(['rating', 'reviewCount', 'responseMinutes', 'punctualMentions'] as const),
    );
    assert.deepEqual(m, { rating: null, reviewCount: 0, responseMinutes: null, punctualMentions: 0 });
  });
});
