import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
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
      writer: { write: async () => assert.fail('nothing may be written') },
    };
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: { skills: {} }, after: undefined }, deps), 'deleted');
    assert.equal(await handlePhotographerWrite({ uid: 'p1', before: undefined, after: { skills: 'portrait' } }, deps), 'malformed');
  });
});
