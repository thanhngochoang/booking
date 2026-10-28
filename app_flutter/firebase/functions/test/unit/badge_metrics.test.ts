import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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
    const { db, log } = fakeDb({ 'photographers/u1': { stats: { tomatoPct: 97, reviewCount: 58, score: 0.942 } } }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['reviewCount'] as const));
    assert.deepEqual(log, ['get photographers/u1']);
    assert.deepEqual(m, { reviewCount: 58 });
  });

  it('tomatoPct and reviewCount come from stats', async () => {
    const { db } = fakeDb({ 'photographers/u1': { stats: { tomatoPct: 97, reviewCount: 58, rating: 4.9 } } }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['tomatoPct', 'reviewCount'] as const));
    assert.deepEqual(m, { tomatoPct: 97, reviewCount: 58 });
  });

  it('a photographer without stats has tomatoPct null', async () => {
    const { db } = fakeDb({ 'photographers/u1': {} }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read('u1', new Set(['tomatoPct'] as const));
    assert.deepEqual(m, { tomatoPct: null });
    // Legacy star stats (rating only) give no percentage either.
    const legacy = fakeDb({ 'photographers/u2': { stats: { rating: 4.9, ratingSum: 284, reviewCount: 58 } } }, {});
    const m2 = await new FirestoreBadgeMetricsReader(legacy.db, () => NOW).read('u2', new Set(['tomatoPct'] as const));
    assert.deepEqual(m2, { tomatoPct: null });
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
    assert.equal(log.length, 4);
    assert.ok(log.every((l) => l.startsWith('count ')));
  });

  it('shoot counts subtract late-cancelled bookings and keep bookings written before deliveryCancel existed (#207)', async () => {
    // `deliveryCancel == null` would match only documents that have the field, dropping every older booking.
    const { db, log } = fakeDb({}, {
      'bookings|photographerId == "u1" & status in ["completed","reviewed"]': 12,
      'bookings|photographerId == "u1" & deliveryCancel != null': 2,
      'bookings|customerId == "u1" & status in ["completed","reviewed"]': 5,
      'bookings|customerId == "u1" & deliveryCancel != null': 1,
    });
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read(
      'u1',
      new Set(['completedShoots', 'customerShoots'] as const),
    );
    assert.deepEqual(m, { completedShoots: 10, customerShoots: 4 });
    assert.ok(log.every((l) => !l.includes('deliveryCancel == null')));
  });

  it('the late-cancel counts have their composite indexes (#207)', () => {
    const json = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; queryScope: string; fields: { fieldPath: string; order: string }[] }[];
    };
    const shapes = json.indexes
      .filter((i) => i.collectionGroup === 'bookings' && i.queryScope === 'COLLECTION')
      .map((i) => i.fields.map((f) => `${f.fieldPath} ${f.order}`).join(', '));
    // completedShoots / completedBookings: photographerId ==, deliveryCancel != null; customerShoots: customerId ==, deliveryCancel != null.
    assert.ok(shapes.includes('photographerId ASCENDING, deliveryCancel ASCENDING'), shapes.join(' | '));
    assert.ok(shapes.includes('customerId ASCENDING, deliveryCancel ASCENDING'), shapes.join(' | '));
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

  it('absent stats give null for tomatoPct and 0 for counts', async () => {
    const { db } = fakeDb({ 'photographers/u1': {} }, {});
    const m = await new FirestoreBadgeMetricsReader(db, () => NOW).read(
      'u1',
      new Set(['tomatoPct', 'reviewCount', 'responseMinutes', 'punctualMentions'] as const),
    );
    assert.deepEqual(m, { tomatoPct: null, reviewCount: 0, responseMinutes: null, punctualMentions: 0 });
  });
});
