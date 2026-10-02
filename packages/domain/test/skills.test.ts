import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  COMPLETENESS_POINTS,
  COMPLETENESS_STEPS,
  MAX_EVIDENCE_READS,
  cleanEvidence,
  evidenceIds,
  isOwnEvidencePost,
  parseSkills,
  sameClientSkills,
  skillsCompleteness,
  toStoredSpecialties,
  type SkillLevel,
  type Skills,
  type SpecialtySkill,
} from '../src/index.js';

const genre = (id: string, level: SkillLevel = 2, evidencePostIds: string[] = [], years: number | null = null): SpecialtySkill =>
  ({ id, level, years, evidencePostIds });
const skills = (over: Partial<Skills> = {}): Skills =>
  ({ specialties: [], styles: [], extras: [], languages: [], audiences: [], yearsExperience: null, ...over });

describe('parseSkills', () => {
  test("reads the stored shape (the app's skillsToMap) and ignores server fields", () => {
    assert.deepEqual(
      parseSkills({
        schemaVersion: 1,
        specialties: [
          { id: 'portrait', level: 3, years: 6, evidencePostIds: ['p1', 'p2'] },
          { id: 'couple', level: 1, evidencePostIds: [] },
        ],
        styles: ['film'],
        extras: ['retouch'],
        languages: ['vi', 'en'],
        audiences: ['couple'],
        yearsExperience: 6,
        completeness: 72,
        completenessNext: 'audiences',
      }),
      skills({
        specialties: [genre('portrait', 3, ['p1', 'p2'], 6), genre('couple', 1)],
        styles: ['film'],
        extras: ['retouch'],
        languages: ['vi', 'en'],
        audiences: ['couple'],
        yearsExperience: 6,
      }),
    );
  });

  test('anything but a schema-1 map is malformed', () => {
    for (const raw of [undefined, null, 'portrait', 5, [], ['portrait'], {}, { schemaVersion: 2 }, { schemaVersion: '1' }]) {
      assert.equal(parseSkills(raw), null, JSON.stringify(raw) ?? 'undefined');
    }
  });

  test('tolerant like skillsFromMap: bad entries dropped, bad level is 2, duplicates once', () => {
    assert.deepEqual(
      parseSkills({
        schemaVersion: 1,
        specialties: [
          'portrait',
          null,
          { level: 3 },
          { id: 7 },
          { id: 'wedding', level: 9, years: 'six', evidencePostIds: ['a', 5, 'a', 'b'] },
          { id: 'wedding', level: 3, evidencePostIds: ['z'] },
          { id: 'family', level: '3' },
        ],
        styles: 'film',
        extras: ['retouch', 'retouch', 1],
        languages: ['vi'],
        yearsExperience: 6.5,
      }),
      skills({ specialties: [genre('wedding', 2, ['a', 'b']), genre('family', 2)], extras: ['retouch'], languages: ['vi'] }),
    );
  });
});

describe('evidence', () => {
  test('evidenceIds: every opaque id once, at most 18; other ids are never read', () => {
    assert.deepEqual(
      evidenceIds(skills({ specialties: [genre('portrait', 3, ['a', 'b', 'a/b']), genre('couple', 2, ['b', 'c', ''])] })),
      ['a', 'b', 'c'],
    );
    const many = Array.from({ length: 7 }, (_, i) => genre(`g${i}`, 2, [`x${i}a`, `x${i}b`, `x${i}c`]));
    assert.equal(MAX_EVIDENCE_READS, 18);
    assert.equal(evidenceIds(skills({ specialties: many })).length, MAX_EVIDENCE_READS);
  });

  test('isOwnEvidencePost: a live post of this photographer only', () => {
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', photographerId: 'u1' }), true);
    assert.equal(isOwnEvidencePost('u1', { photographerId: 'u1' }), true, 'older posts without authorId');
    assert.equal(isOwnEvidencePost('u1', { authorId: 'c9', photographerId: 'u1' }), false, "a customer's real-shoot post");
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u2', photographerId: 'u2' }), false);
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', deletedAt: new Date() }), false, 'soft-deleted');
    assert.equal(isOwnEvidencePost('u1', { authorId: 'u1', deletedAt: null }), true);
    assert.equal(isOwnEvidencePost('u1', undefined), false, 'missing document');
  });

  test('cleanEvidence removes posts of other photographers and posts that are gone', () => {
    const s = skills({
      specialties: [genre('couple', 2, ['own1', 'other', 'gone']), genre('family', 1, ['own2'])],
      languages: ['vi'],
    });
    assert.deepEqual(cleanEvidence(s, new Set(['own1', 'own2'])), {
      skills: skills({ specialties: [genre('couple', 2, ['own1']), genre('family', 1, ['own2'])], languages: ['vi'] }),
      removed: true,
    });
  });

  test('a Chuyên sâu genre left without evidence drops to Thành thạo; one post left keeps it', () => {
    const s = skills({ specialties: [genre('portrait', 3, ['other']), genre('wedding', 3, ['own', 'gone'])] });
    assert.deepEqual(cleanEvidence(s, new Set(['own'])).skills.specialties, [genre('portrait', 2, []), genre('wedding', 3, ['own'])]);
  });

  test('nothing to remove: the same skills object and removed false', () => {
    const s = skills({ specialties: [genre('portrait', 3, ['a'])] });
    const result = cleanEvidence(s, new Set(['a', 'unrelated']));
    assert.equal(result.removed, false);
    assert.equal(result.skills, s);
  });
});

describe('skillsCompleteness', () => {
  test('weights of spec 3e.2, highest first, 100 in total', () => {
    assert.deepEqual([...COMPLETENESS_STEPS], ['specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras']);
    assert.deepEqual(COMPLETENESS_STEPS.map((s) => COMPLETENESS_POINTS[s]), [25, 20, 20, 10, 10, 10, 5]);
  });

  const table = JSON.parse(readFileSync(new URL('./fixtures/skills_completeness.json', import.meta.url), 'utf8')) as {
    cases: { name: string; skills: unknown; percent: number; next: string | null; nextAfter: number | null }[];
  };
  for (const c of table.cases) {
    test(c.name, () => {
      const s = parseSkills(c.skills);
      assert.ok(s !== null, 'fixture skills must parse');
      assert.deepEqual(skillsCompleteness(s), { percent: c.percent, next: c.next, nextAfter: c.nextAfter });
    });
  }
});

describe('sameClientSkills', () => {
  const base = { schemaVersion: 1, specialties: [{ id: 'portrait', level: 2, evidencePostIds: ['a'] }], languages: ['vi'] };

  test("server fields are ignored (the Function's own write)", () => {
    const after = { ...base, completeness: 75, completenessNext: 'styles', completenessNextAfter: 85, updatedAt: new Date(), evidenceRemovedAt: new Date() };
    assert.equal(sameClientSkills(base, after), true);
  });

  test('key order does not matter; any client change does', () => {
    assert.equal(
      sameClientSkills(base, { languages: ['vi'], specialties: [{ evidencePostIds: ['a'], level: 2, id: 'portrait' }], schemaVersion: 1 }),
      true,
    );
    assert.equal(sameClientSkills(base, { ...base, languages: ['vi', 'en'] }), false);
    assert.equal(sameClientSkills(base, { ...base, specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }] }), false);
    assert.equal(sameClientSkills(base, { ...base, styles: [] }), false);
  });

  test('no skills before is never the same as skills after', () => {
    assert.equal(sameClientSkills(undefined, base), false);
    assert.equal(sameClientSkills(undefined, undefined), true);
  });
});

test("toStoredSpecialties writes the app's shape: years only when known", () => {
  assert.deepEqual(toStoredSpecialties([genre('portrait', 3, ['a'], 6), genre('couple')]), [
    { id: 'portrait', level: 3, years: 6, evidencePostIds: ['a'] },
    { id: 'couple', level: 2, evidencePostIds: [] },
  ]);
});
