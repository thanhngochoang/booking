import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  isOwnEvidencePost,
  scorePhotographerSkills,
  type EvidencePostRecord,
  type ScoreSkillsDeps,
  type SkillsScoreUpdate,
  type SkillsWriteEvent,
} from '../src/index.js';

const P = 'p1';

type WriteResult = 'written' | 'stale';

/** `writeResult`: one result for every write, or one per write in order. `current`: what each reread returns. */
function fakes(
  posts: Record<string, EvidencePostRecord> = {},
  writeResult: WriteResult | readonly WriteResult[] = 'written',
  current: readonly ({ skills: unknown } | null)[] = [],
) {
  const reads: string[][] = [];
  const writes: SkillsScoreUpdate[] = [];
  let rereads = 0;
  const deps: ScoreSkillsDeps = {
    posts: {
      async owned(uid, ids) {
        reads.push([...ids]);
        return new Set(ids.filter((id) => isOwnEvidencePost(uid, posts[id])));
      },
    },
    writer: {
      async write(update) {
        writes.push(update);
        return typeof writeResult === 'string' ? writeResult : (writeResult[writes.length - 1] ?? 'written');
      },
      async reread() {
        const doc = current[rereads];
        rereads += 1;
        if (doc === undefined) return assert.fail('unexpected reread');
        return doc;
      },
    },
  };
  return { deps, reads, writes, rereads: () => rereads };
}

const ev = (before: unknown, after: unknown, deleted = false): SkillsWriteEvent => ({ uid: P, before, after, deleted });
const saved = (over: Record<string, unknown> = {}) => ({
  schemaVersion: 1,
  specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }],
  languages: ['vi'],
  ...over,
});

describe('scorePhotographerSkills', () => {
  test('a deleted profile is skipped without reading or writing', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(saved(), undefined, true), f.deps), 'deleted');
    assert.deepEqual([f.reads, f.writes], [[], []]);
  });

  test('a profile without skills is skipped', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, undefined), f.deps), 'no_skills');
    assert.deepEqual(f.writes, []);
  });

  test("a change of server fields only (the Function's own write) stops before any read", async () => {
    const f = fakes({ own: { authorId: P } });
    const before = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own'] }] });
    const after = { ...before, completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, updatedAt: new Date() };
    assert.equal(await scorePhotographerSkills(ev(before, after), f.deps), 'unchanged');
    assert.deepEqual([f.reads, f.writes], [[], []]);
  });

  test('a malformed skills value is not scored and nothing is written', async () => {
    for (const after of ['portrait', [], { specialties: [] }, { schemaVersion: 2 }]) {
      const f = fakes();
      assert.equal(await scorePhotographerSkills(ev(undefined, after), f.deps), 'malformed', JSON.stringify(after));
      assert.deepEqual(f.writes, []);
    }
  });

  test('evidence of another photographer, of a deleted post or with a bad id is removed; Chuyên sâu drops', async () => {
    const f = fakes({
      own: { authorId: P, photographerId: P },
      theirs: { authorId: 'p2', photographerId: 'p2' },
      trashed: { authorId: P, deletedAt: new Date() },
    });
    const after = saved({
      specialties: [
        { id: 'portrait', level: 3, evidencePostIds: ['theirs', 'trashed', 'a/b'] },
        { id: 'couple', level: 2, years: 4, evidencePostIds: ['own', 'missing'] },
      ],
      styles: ['film'],
    });
    assert.equal(await scorePhotographerSkills(ev(undefined, after), f.deps), 'written');
    assert.deepEqual(f.reads, [['theirs', 'trashed', 'own', 'missing']], 'one read, bad id never read');
    assert.deepEqual(f.writes, [
      {
        completeness: 85,
        completenessNext: 'audiences',
        completenessNextAfter: 95,
        specialties: [
          { id: 'portrait', level: 2, evidencePostIds: [] },
          { id: 'couple', level: 2, years: 4, evidencePostIds: ['own'] },
        ],
      },
    ]);
  });

  test('no evidence: no read; score and next step written, specialties left alone', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), f.deps), 'written');
    assert.deepEqual(f.reads, []);
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null }]);
  });

  test('the re-run after the Function removed evidence finds the score current and writes nothing', async () => {
    const f = fakes({ own: { authorId: P } });
    const before = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own', 'theirs'] }] });
    const after = saved({
      specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own'] }],
      completeness: 75,
      completenessNext: 'styles',
      completenessNextAfter: 85,
      updatedAt: new Date(),
      evidenceRemovedAt: new Date(),
    });
    assert.equal(await scorePhotographerSkills(ev(before, after), f.deps), 'up_to_date');
    assert.deepEqual(f.writes, []);
  });

  test('a photographer with no genre yet scores 10 and is told to choose one', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, { schemaVersion: 1, specialties: [], languages: ['vi'] }), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 10, completenessNext: 'specialties', completenessNextAfter: 75, specialties: null }]);
  });

  test('a stored score without completenessNext (an older run) is written again', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(undefined, saved({ completeness: 75 })), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null }]);
  });

  test('a stored score without completenessNextAfter (a run before it existed) is written again', async () => {
    const f = fakes();
    const after = saved({ completeness: 75, completenessNext: 'styles' });
    assert.equal(await scorePhotographerSkills(ev(undefined, after), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null }]);
  });

  test('a stale write re-reads the document once and scores what is stored now', async () => {
    const f = fakes({}, ['stale', 'written'], [{ skills: saved({ styles: ['film'] }) }]);
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), f.deps), 'written');
    assert.equal(f.rereads(), 1);
    assert.deepEqual(f.writes, [
      { completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null },
      { completeness: 85, completenessNext: 'audiences', completenessNextAfter: 95, specialties: null },
    ]);
  });

  test('a second stale write gives up after one reread (the newer save is unscored, so its trigger scores it)', async () => {
    const f = fakes({}, 'stale', [{ skills: saved({ styles: ['film'] }) }]);
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), f.deps), 'stale');
    assert.deepEqual([f.rereads(), f.writes.length], [1, 2]);
  });

  test('a stale write whose reread finds the document deleted, or already scored, writes nothing more', async () => {
    const gone = fakes({}, 'stale', [null]);
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), gone.deps), 'stale');
    assert.equal(gone.writes.length, 1);
    const scored = saved({ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85 });
    const done = fakes({}, 'stale', [{ skills: scored }]);
    assert.equal(await scorePhotographerSkills(ev(undefined, saved()), done.deps), 'up_to_date');
    assert.equal(done.writes.length, 1);
  });

  test('a non-skills write of a profile never scored (an earlier run went stale or was dropped) scores it', async () => {
    const f = fakes();
    assert.equal(await scorePhotographerSkills(ev(saved(), saved()), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, specialties: null }]);
  });

  test('a non-skills write whose stored score does not match the skills scores them again', async () => {
    const f = fakes();
    const stored = saved({ styles: ['film'], completeness: 75, completenessNext: 'styles', completenessNextAfter: 85 });
    assert.equal(await scorePhotographerSkills(ev(stored, stored), f.deps), 'written');
    assert.deepEqual(f.writes, [{ completeness: 85, completenessNext: 'audiences', completenessNextAfter: 95, specialties: null }]);
  });

  test('a non-skills write of a scored profile stops before any read', async () => {
    const f = fakes();
    const stored = saved({
      specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['own'] }],
      completeness: 75,
      completenessNext: 'styles',
      completenessNextAfter: 85,
    });
    assert.equal(await scorePhotographerSkills(ev(stored, stored), f.deps), 'unchanged');
    assert.deepEqual([f.reads, f.writes], [[], []]);
  });

  test('a failed post read rejects (so Functions retries) and writes nothing', async () => {
    const writes: SkillsScoreUpdate[] = [];
    const deps: ScoreSkillsDeps = {
      posts: { owned: () => Promise.reject(new Error('unavailable')) },
      writer: {
        async write(update) {
          writes.push(update);
          return 'written';
        },
        reread: () => assert.fail('no reread'),
      },
    };
    const after = saved({ specialties: [{ id: 'portrait', level: 3, evidencePostIds: ['a'] }] });
    await assert.rejects(scorePhotographerSkills(ev(undefined, after), deps), /unavailable/);
    assert.deepEqual(writes, []);
  });
});
