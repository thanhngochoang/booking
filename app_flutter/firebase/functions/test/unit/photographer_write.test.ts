import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import type { ScoreSkillsDeps, SkillsScoreUpdate } from '@photobooking/domain';
import { REGION, TRIGGER_OPTIONS } from '../../src/config.js';
import { firestoreSkillsScoreWriter, isStaleWriteError, skillsUpdateFields } from '../../src/infra/skills_firestore.js';
import { handlePhotographerWrite } from '../../src/triggers/photographer_write.js';

const serverTime = (v: unknown) => v instanceof FieldValue && v.isEqual(FieldValue.serverTimestamp());

describe('onPhotographerWrite plumbing', () => {
  test('trigger options: Singapore, small, bounded, retried', () => {
    assert.deepEqual(TRIGGER_OPTIONS, {
      region: REGION,
      memory: '256MiB',
      timeoutSeconds: 30,
      maxInstances: 10,
      minInstances: 0,
      retry: true,
    });
  });

  test('update fields: score with server time; specialties and evidenceRemovedAt only after a removal', () => {
    const plain = skillsUpdateFields({ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null });
    assert.deepEqual(Object.keys(plain).sort(), [
      'skills.completeness',
      'skills.completenessNext',
      'skills.completenessNextAfter',
      'skills.updatedAt',
    ]);
    assert.equal(plain['skills.completeness'], 75);
    assert.equal(plain['skills.completenessNext'], 'styles');
    assert.equal(plain['skills.completenessNextAfter'], 85);
    assert.ok(serverTime(plain['skills.updatedAt']));
    const cleaned = skillsUpdateFields({
      completeness: 100,
      completenessNext: null,
      completenessNextAfter: null,
      specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }],
    });
    assert.equal(cleaned['skills.completenessNext'], null);
    assert.equal(cleaned['skills.completenessNextAfter'], null);
    assert.deepEqual(cleaned['skills.specialties'], [{ id: 'portrait', level: 2, evidencePostIds: [] }]);
    assert.ok(serverTime(cleaned['skills.evidenceRemovedAt']));
  });

  test('stale writes are FAILED_PRECONDITION and NOT_FOUND; anything else is rethrown', () => {
    assert.equal(isStaleWriteError({ code: 9 }), true);
    assert.equal(isStaleWriteError({ code: 5 }), true);
    assert.equal(isStaleWriteError({ code: 14 }), false);
    assert.equal(isStaleWriteError(new Error('boom')), false);
    assert.equal(isStaleWriteError(null), false);
  });

  test('after a stale write the writer re-reads the document and conditions the next write on it', async () => {
    const t1 = Timestamp.fromMillis(1_000);
    const t2 = Timestamp.fromMillis(2_000);
    const preconditions: unknown[] = [];
    let gets = 0;
    const doc = {
      async update(_fields: unknown, precondition: { lastUpdateTime: Timestamp }) {
        preconditions.push(precondition.lastUpdateTime);
        if (preconditions.length === 1) throw Object.assign(new Error('changed'), { code: 9 });
      },
      async get() {
        gets += 1;
        return { exists: true, updateTime: t2, get: (field: string) => (field === 'skills' ? { schemaVersion: 1 } : undefined) };
      },
    };
    const db = { collection: () => ({ doc: () => doc }) } as unknown as Firestore;
    const writer = firestoreSkillsScoreWriter(db, 'p1', t1);
    const update = { completeness: 10, completenessNext: 'specialties', completenessNextAfter: 35, specialties: null } as const;
    assert.equal(await writer.write(update), 'stale');
    assert.deepEqual(await writer.reread(), { skills: { schemaVersion: 1 } });
    assert.equal(await writer.write(update), 'written');
    assert.equal(gets, 1);
    assert.deepEqual(preconditions, [t1, t2]);
  });

  test('a reread of a deleted document returns null and the next write is stale without a request', async () => {
    const doc = {
      update: () => assert.fail('no write after the document is gone'),
      get: async () => ({ exists: false, updateTime: undefined, get: () => undefined }),
    };
    const db = { collection: () => ({ doc: () => doc }) } as unknown as Firestore;
    const writer = firestoreSkillsScoreWriter(db, 'p1', Timestamp.fromMillis(1_000));
    assert.equal(await writer.reread(), null);
    assert.equal(
      await writer.write({ completeness: 10, completenessNext: 'specialties', completenessNextAfter: 35, specialties: null }),
      'stale',
    );
  });

  test('a write for a deleted document (no update time) touches nothing', async () => {
    const writer = firestoreSkillsScoreWriter({} as Firestore, 'p1', undefined);
    assert.equal(
      await writer.write({ completeness: 10, completenessNext: 'specialties', completenessNextAfter: 35, specialties: null }),
      'stale',
    );
  });

  test('the handler passes the skills maps of both snapshots to the use case', async () => {
    const writes: SkillsScoreUpdate[] = [];
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: {
        write: async (u) => {
          writes.push(u);
          return 'written';
        },
        reread: () => assert.fail('no reread'),
      },
    };
    const outcome = await handlePhotographerWrite(
      {
        uid: 'p1',
        before: { bio: 'x' },
        after: {
          bio: 'x',
          skills: { schemaVersion: 1, specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }], languages: ['vi'] },
        },
      },
      deps,
    );
    assert.equal(outcome, 'written');
    assert.deepEqual(writes, [{ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null }]);
  });

  test('the handler skips a deleted document and a malformed skills value (warning logged)', async () => {
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: { write: async () => assert.fail('nothing may be written'), reread: () => assert.fail('no reread') },
    };
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: { skills: {} }, after: undefined }, deps), 'deleted');
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: undefined, after: { skills: 'portrait' } }, deps), 'malformed');
  });
});
