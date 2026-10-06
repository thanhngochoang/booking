import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { nextStatus, validateAwardInput, type AwardStatus, type ReviewAction } from '../src/award.js';
import { DomainError } from '../src/errors.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');
const base = {
  awardId: 'a1',
  competition: 'Vietnam Photo Awards',
  year: 2024,
  category: 'Chân dung',
  result: 'gold',
  workPostId: null,
  proofFiles: ['awardProofs/u1/a1/0.jpg'],
  proofLinks: [],
};
const bad = (over: Record<string, unknown>): void =>
  assert.throws(
    () => validateAwardInput({ ...base, ...over }, 'u1', NOW),
    (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
  );

describe('award input', () => {
  it('accepts a valid input and trims', () => {
    const i = validateAwardInput({ ...base, competition: '  Vietnam   Photo Awards ', category: '' }, 'u1', NOW);
    assert.equal(i.competition, 'Vietnam Photo Awards');
    assert.equal(i.category, null);
  });
  it('competition is trimmed and 2–120 characters', () => {
    bad({ competition: ' a ' });
    bad({ competition: 'x'.repeat(121) });
    assert.equal(validateAwardInput({ ...base, competition: ' ab ' }, 'u1', NOW).competition, 'ab');
    assert.equal(validateAwardInput({ ...base, competition: 'x'.repeat(120) }, 'u1', NOW).competition.length, 120);
  });
  it('the year bound uses Vietnam time', () => {
    const newYear = new Date('2026-12-31T17:30:00.000Z'); // 2027-01-01 00:30 +07
    assert.equal(validateAwardInput({ ...base, year: 2027 }, 'u1', newYear).year, 2027);
  });

  it('year before 1950 or after this year is invalid', () => {
    bad({ year: 1949 });
    bad({ year: 2027 });
    bad({ year: 2024.5 });
    assert.equal(validateAwardInput({ ...base, year: 1950 }, 'u1', NOW).year, 1950);
    assert.equal(validateAwardInput({ ...base, year: 2026 }, 'u1', NOW).year, 2026);
  });
  it('an unknown result is invalid', () => bad({ result: 'platinum' }));
  it('at least one proof is required', () => bad({ proofFiles: [], proofLinks: [] }));
  it('proof paths must be the caller\'s own folder', () => {
    bad({ proofFiles: ['awardProofs/u2/a1/0.jpg'] });
    bad({ proofFiles: ['awardProofs/u1/other/0.jpg'] });
    bad({ proofFiles: ['awardProofs/u1/a1/../x.jpg'] });
  });
  it('more than 3 files is invalid', () =>
    bad({ proofFiles: [0, 1, 2, 3].map((i) => `awardProofs/u1/a1/${i}.jpg`) }));
  it('more than 2 links is invalid', () =>
    bad({ proofFiles: [], proofLinks: ['https://a.vn/1', 'https://a.vn/2', 'https://a.vn/3'] }));
  it('http links are invalid', () => {
    bad({ proofLinks: ['http://a.vn/x'] });
    bad({ proofLinks: ['https://' + 'a'.repeat(300)] });
  });
  it('illegal review moves are conflicts', () => {
    const illegal: Array<[AwardStatus, ReviewAction]> = [
      ['approved', 'approve'],
      ['pending', 'revoke'],
      ['needs_info', 'approve'],
      ['rejected', 'approve'],
      ['revoked', 'revoke'],
      ['approved', 'reject'],
    ];
    for (const [s, a] of illegal) {
      assert.throws(() => nextStatus(s, a), (e: unknown) => e instanceof DomainError && e.code === 'conflict');
    }
    assert.equal(nextStatus('pending', 'approve'), 'approved');
    assert.equal(nextStatus('pending', 'needs_info'), 'needs_info');
    assert.equal(nextStatus('pending', 'reject'), 'rejected');
    assert.equal(nextStatus('approved', 'revoke'), 'revoked');
  });
});
