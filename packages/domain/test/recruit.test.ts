import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { findContactLeak } from '../src/contact_filter.js';
import { DomainError } from '../src/errors.js';
import {
  EMPTY_COUNTERS,
  isValidFee,
  recruitFilterKey,
  recruitFilterKeys,
  recruitMatchKeys,
  takeDaily,
  validateRecruitPostInput,
} from '../src/recruit.js';
import { applyToRecruitPost } from '../src/recruit_use_cases.js';
import { createRecruitWorld, openPost, VALID_POST } from './support/recruit_world.js';

/** #139's contact_filter.test.ts table, plus the S27 rows (plan Task 2). */
const CONTACT_TABLE: ReadonlyArray<readonly [string, ReturnType<typeof findContactLeak>]> = [
  ['0903 123 456', 'phone'],
  ['+84 903.123.456', 'phone'],
  ['84912345678', 'phone'],
  ['0 9 0 3 1 2 3 4 5 6', 'phone'],
  ['liên hệ a@b.vn', 'email'],
  ['xem www.abc.com', 'link'],
  ['fb.com/abc', 'link'],
  ['studio.vn', 'link'],
  ['zalo.me/0912345678', 'link'],
  ['nhắn Zalo nhé', 'zalo'],
  ['42 bạn, 12A1, 2025', null],
  ['giá 3.000.000đ', null],
  ['ngân sách 1.000.000.000₫', null],
  ['từ 7:00 đến 11:00', null],
  ['70-200mm f2.8', null],
  ['Kỷ yếu lớp 12A1, 42 bạn', null],
  // S27 rows
  ['0912 345 678', 'phone'],
  ['+84 912345678', 'phone'],
  ['a@b.vn', 'email'],
  ['www.abc.com', 'link'],
  ['Zalo', 'zalo'],
];

function refusal(fn: () => unknown): { code: string; field: string | undefined } {
  try {
    fn();
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return { code: e.code, field: e.field };
  }
  assert.fail('expected a DomainError');
}

async function refusalOf(p: Promise<unknown>): Promise<{ code: string; field: string | undefined }> {
  try {
    await p;
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return { code: e.code, field: e.field };
  }
  assert.fail('expected a DomainError');
}

describe('recruit contact filter (#139 findContactLeak)', () => {
  for (const [text, want] of CONTACT_TABLE) {
    it(`${JSON.stringify(text)} -> ${want}`, () => assert.equal(findContactLeak(text), want));
  }

  it('ignores prices, years, lens sizes and times', () => {
    for (const text of ['800.000₫/buổi', '2026', '70-200mm', '15:30–19:30', 'f2.8']) assert.equal(findContactLeak(text), null, text);
  });

  it('an application message with any leak is invalid_argument with field message.contact', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    for (const message of ['gọi 0912 345 678', 'mail a@b.vn', 'xem studio.vn', 'nhắn zalo nhé']) {
      assert.deepEqual(
        await refusalOf(applyToRecruitPost(w.deps, 'p1', { postId, message, samplePostIds: [], acceptTerms: true })),
        { code: 'invalid_argument', field: 'message.contact' },
        message,
      );
    }
  });

  it('applying to a studio that blocked the applicant (either way) is blocked', async () => {
    const w = createRecruitWorld();
    const postId = await openPost(w, 's1');
    w.blocks.block('s1', 'p1');
    w.blocks.block('p2', 's1');
    for (const uid of ['p1', 'p2']) {
      assert.deepEqual(
        await refusalOf(applyToRecruitPost(w.deps, uid, { postId, message: '', samplePostIds: [], acceptTerms: true })),
        { code: 'blocked', field: undefined },
        uid,
      );
    }
    assert.equal(w.store.applications.size, 0);
  });
});

describe('validateRecruitPostInput', () => {
  const ok = (over: Record<string, unknown>) => validateRecruitPostInput({ ...VALID_POST, ...over }, 'create');
  const bad = (over: Record<string, unknown>) => refusal(() => ok(over));

  it('accepts a valid post and trims text', () => {
    const f = ok({ title: '  Tuyển CTV chụp cưới  ' });
    assert.equal(f.title, 'Tuyển CTV chụp cưới');
    assert.equal(f.kind, 'collaborator');
    assert.deepEqual(f.feeHint, { type: 'per_shoot', amount: 800_000 });
  });

  it('title is 8–80 characters', () => {
    assert.deepEqual(bad({ title: 'a'.repeat(7) }), { code: 'invalid_argument', field: 'title' });
    assert.equal(ok({ title: 'a'.repeat(8) }).title.length, 8);
    assert.equal(ok({ title: 'a'.repeat(80) }).title.length, 80);
    assert.deepEqual(bad({ title: 'a'.repeat(81) }), { code: 'invalid_argument', field: 'title' });
  });

  it('specialties: 1–4 known ids, no duplicates', () => {
    assert.deepEqual(bad({ specialties: [] }), { code: 'invalid_argument', field: 'specialties' });
    assert.deepEqual(bad({ specialties: ['wedding', 'family', 'portrait', 'couple', 'event'] }),
      { code: 'invalid_argument', field: 'specialties' });
    assert.deepEqual(bad({ specialties: ['karaoke'] }), { code: 'invalid_argument', field: 'specialties' });
    assert.deepEqual(bad({ specialties: ['wedding', 'wedding'] }), { code: 'invalid_argument', field: 'specialties' });
    assert.equal(ok({ specialties: ['wedding', 'family', 'portrait', 'couple'] }).specialties.length, 4);
  });

  it('areas: 1–5 known ids, no duplicates', () => {
    assert.deepEqual(bad({ areas: [] }), { code: 'invalid_argument', field: 'areas' });
    assert.deepEqual(bad({ areas: ['hcm-q1', 'hcm-q3', 'hcm-q7', 'hcm-binh-thanh', 'hcm-thu-duc', 'hue'] }),
      { code: 'invalid_argument', field: 'areas' });
    assert.deepEqual(bad({ areas: ['paris'] }), { code: 'invalid_argument', field: 'areas' });
    assert.deepEqual(bad({ areas: ['hue', 'hue'] }), { code: 'invalid_argument', field: 'areas' });
  });

  it('kind and frequency are known codes', () => {
    assert.deepEqual(bad({ kind: 'employee' }), { code: 'invalid_argument', field: 'kind' });
    assert.deepEqual(bad({ kind: undefined }), { code: 'invalid_argument', field: 'kind' });
    assert.deepEqual(bad({ frequency: 'daily' }), { code: 'invalid_argument', field: 'frequency' });
  });

  it('per_shoot fee is 1.000–100.000.000 in steps of 1.000; negotiable ok', () => {
    for (const amount of [999, 1_500, 100_001_000, 800_000.5, '800000']) {
      assert.deepEqual(bad({ feeHint: { type: 'per_shoot', amount } }), { code: 'invalid_argument', field: 'feeHint' }, String(amount));
    }
    assert.deepEqual(ok({ feeHint: { type: 'per_shoot', amount: 800_000 } }).feeHint, { type: 'per_shoot', amount: 800_000 });
    assert.deepEqual(ok({ feeHint: { type: 'negotiable', amount: 5 } }).feeHint, { type: 'negotiable' });
    assert.deepEqual(bad({ feeHint: { type: 'hourly' } }), { code: 'invalid_argument', field: 'feeHint' });
    assert.equal(isValidFee(1_000), true);
    assert.equal(isValidFee(100_000_000), true);
  });

  it('requirements: at most 600 characters', () => {
    assert.equal(ok({ requirements: 'a'.repeat(600) }).requirements.length, 600);
    assert.equal(ok({ requirements: undefined }).requirements, '');
    assert.deepEqual(bad({ requirements: 'a'.repeat(601) }), { code: 'invalid_argument', field: 'requirements' });
  });

  it('contact info in title or requirements is refused with a .contact field', () => {
    assert.deepEqual(bad({ title: 'Tuyển CTV gọi 0912 345 678' }), { code: 'invalid_argument', field: 'title.contact' });
    assert.deepEqual(bad({ requirements: 'Gửi portfolio qua 0912345678' }), { code: 'invalid_argument', field: 'requirements.contact' });
    assert.deepEqual(bad({ requirements: 'liên hệ zalo nhé' }), { code: 'invalid_argument', field: 'requirements.contact' });
    assert.equal(ok({ requirements: 'Thù lao 800.000₫/buổi, 70-200mm f2.8, 15:30–19:30' }).requirements.length > 0, true);
  });

  it('update mode may leave kind out', () => {
    assert.equal(validateRecruitPostInput({ ...VALID_POST, kind: undefined }, 'update').kind, null);
    assert.equal(validateRecruitPostInput({ ...VALID_POST, kind: 'member' }, 'update').kind, 'member');
  });

  it('a non-object is invalid', () => {
    assert.deepEqual(refusal(() => validateRecruitPostInput(null, 'create')).code, 'invalid_argument');
  });
});

describe('recruit keys', () => {
  it('recruitFilterKeys has every non-empty combination and no duplicates', () => {
    const keys = recruitFilterKeys({ kind: 'collaborator', areas: ['hcm-q1', 'hcm-q3'], specialties: ['wedding', 'family'] });
    assert.equal(keys.length, 17);
    assert.equal(new Set(keys).size, 17);
    for (const k of ['k=collaborator', 'a=hcm-q1', 's=family', 'k=collaborator|a=hcm-q3', 'a=hcm-q1|s=wedding',
      'k=collaborator|s=family', 'k=collaborator|a=hcm-q3|s=wedding']) {
      assert.ok(keys.includes(k), k);
    }
    assert.equal(recruitFilterKeys({ kind: 'member', areas: ['a1', 'a2', 'a3', 'a4', 'a5'], specialties: ['s1', 's2', 's3', 's4'] }).length, 59);
  });

  it('recruitFilterKey orders kind, area, specialty', () => {
    assert.equal(recruitFilterKey({ specialty: 'wedding', kind: 'member', area: 'hue' }), 'k=member|a=hue|s=wedding');
    assert.equal(recruitFilterKey({ area: 'hue' }), 'a=hue');
    assert.equal(recruitFilterKey({}), '');
  });

  it('recruitMatchKeys is areas × specialties', () => {
    assert.deepEqual(recruitMatchKeys(['hue', 'da-lat'], ['wedding']), ['a=hue|s=wedding', 'a=da-lat|s=wedding']);
  });
});

describe('takeDaily', () => {
  it('takeDaily resets at VN midnight', () => {
    const before = new Date('2026-10-10T16:59:59.000Z');
    const after = new Date('2026-10-10T17:00:00.000Z');
    const d = takeDaily(takeDaily(null, before, 3), before, 3);
    assert.deepEqual(d, { day: '2026-10-10', count: 2 });
    assert.deepEqual(takeDaily(d, after, 3), { day: '2026-10-11', count: 1 });
  });

  it('throws rate_limited when full', () => {
    const at = new Date('2026-10-10T10:00:00.000Z');
    const full = { day: '2026-10-10', count: 3 };
    assert.deepEqual(refusal(() => takeDaily(full, at, 3)), { code: 'rate_limited', field: undefined });
  });

  it('EMPTY_COUNTERS starts at zero', () => {
    assert.equal(EMPTY_COUNTERS.openPostCount, 0);
    assert.equal(EMPTY_COUNTERS.openApplicationCount, 0);
    assert.equal(EMPTY_COUNTERS.recruitBlockedUntil, null);
  });
});
