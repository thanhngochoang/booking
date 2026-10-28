import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  checkoutActive,
  cityKeyOf,
  cityOf,
  deadlinePassed,
  validateJobInput,
} from '../src/job.js';
import { DomainError } from '../src/errors.js';
import { milestoneAmounts } from '../src/milestones.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

describe('job model & validation', () => {
  const now = new Date('2026-10-05T02:00:00.000Z');

  const validFixedInput = {
    specialtyId: 'portrait',
    title: 'Kỷ yếu lớp 12A1, 42 bạn',
    description: 'Chụp ảnh kỷ yếu tại trường và công viên',
    references: [{ url: 'https://storage.googleapis.com/test/jobRefs/c1/d1/1.jpg', path: 'jobRefs/c1/d1/1.jpg' }],
    schedule: {
      kind: 'fixed',
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
    },
    area: {
      areaId: 'q1',
      name: 'Quận 1, TP.HCM',
      lat: 10.7769,
      lng: 106.7009,
    },
    budget: {
      min: 3000000,
      max: 5000000,
    },
    wants: {
      editedCount: 40,
      deliveryDays: 7,
    },
    allowedProviders: 'all',
    deadlineDays: 3,
  };

  it('title is trimmed and 10–60 characters', () => {
    const res = validateJobInput({ ...validFixedInput, title: '   Kỷ yếu lớp 12A1, 42 bạn   ' }, now);
    assert.equal(res.title, 'Kỷ yếu lớp 12A1, 42 bạn');

    assert.throws(
      () => validateJobInput({ ...validFixedInput, title: 'Quá ngắn' }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'title',
    );
    assert.throws(
      () => validateJobInput({ ...validFixedInput, title: 'a'.repeat(61) }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'title',
    );
  });

  it('a phone number in the description is invalid_argument with field description.contact', () => {
    assert.throws(
      () => validateJobInput({ ...validFixedInput, description: 'Liên hệ mình số 0903123456 nhé' }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'description.contact',
    );
  });

  it('a link in the title is invalid_argument with field title.contact', () => {
    assert.throws(
      () => validateJobInput({ ...validFixedInput, title: 'Xem tại fb.com/myjob nhé mn' }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'title.contact',
    );
  });

  it('specialty must be in the catalogue or other', () => {
    const otherRes = validateJobInput({ ...validFixedInput, specialtyId: 'other' }, now);
    assert.equal(otherRes.specialtyId, 'other');

    assert.throws(
      () => validateJobInput({ ...validFixedInput, specialtyId: 'unknown_specialty_xyz' }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'specialtyId',
    );
  });

  it('at most 5 references, each the caller\'s own upload', () => {
    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            references: Array.from({ length: 6 }, (_, i) => ({
              url: `https://storage.googleapis.com/test/jobRefs/c1/d1/${i}.jpg`,
              path: `jobRefs/c1/d1/${i}.jpg`,
            })),
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'references',
    );
  });

  it('fixed schedule needs day, start and end with end after start', () => {
    const res = validateJobInput(validFixedInput, now);
    assert.equal(res.schedule.kind, 'fixed');
    assert.equal(res.schedule.durationMinutes, 240);
    assert.equal(res.dayFrom, '2026-10-20');
    assert.equal(res.dayTo, '2026-10-20');

    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            schedule: { kind: 'fixed', day: '2026-10-20', start: '11:00', end: '07:00' },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'schedule',
    );
  });

  it('flexible needs from ≤ to within 30 days and a duration from the list', () => {
    const flexRes = validateJobInput(
      {
        ...validFixedInput,
        schedule: { kind: 'flexible', from: '2026-10-20', to: '2026-10-30', durationMinutes: 120 },
      },
      now,
    );
    assert.equal(flexRes.schedule.kind, 'flexible');
    assert.equal(flexRes.schedule.durationMinutes, 120);
    assert.equal(flexRes.dayFrom, '2026-10-20');
    assert.equal(flexRes.dayTo, '2026-10-30');

    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            schedule: { kind: 'flexible', from: '2026-10-20', to: '2026-11-25', durationMinutes: 120 },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'schedule',
    );

    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            schedule: { kind: 'flexible', from: '2026-10-20', to: '2026-10-25', durationMinutes: 100 },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'schedule',
    );
  });

  it('the shoot day must be after the quote deadline', () => {
    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            deadlineDays: 7,
            schedule: { kind: 'fixed', day: '2026-10-10', start: '07:00', end: '11:00' },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'schedule',
    );
  });

  it('the shoot day is at most 365 days ahead', () => {
    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            schedule: { kind: 'fixed', day: '2028-10-20', start: '07:00', end: '11:00' },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'schedule',
    );
  });

  it('budget needs 0 < min ≤ max', () => {
    assert.throws(
      () => validateJobInput({ ...validFixedInput, budget: { min: 5000000, max: 3000000 } }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'budget',
    );
    assert.throws(
      () => validateJobInput({ ...validFixedInput, budget: { min: -100, max: 3000000 } }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'budget',
    );
  });

  it('budget null is allowed', () => {
    const res = validateJobInput({ ...validFixedInput, budget: null }, now);
    assert.equal(res.budget, null);
  });

  it('deadline days outside 1–7 are invalid', () => {
    assert.throws(
      () => validateJobInput({ ...validFixedInput, deadlineDays: 0 }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'deadlineDays',
    );
    assert.throws(
      () => validateJobInput({ ...validFixedInput, deadlineDays: 8 }, now),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'deadlineDays',
    );
  });

  it('area outside Vietnam is invalid', () => {
    assert.throws(
      () =>
        validateJobInput(
          {
            ...validFixedInput,
            area: { areaId: 'tokyo', name: 'Tokyo', lat: 35.6762, lng: 139.6503 },
          },
          now,
        ),
      (e: any) => e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'area',
    );
  });

  it('cityOf and cityKeyOf follow the fixture table', () => {
    const raw = readFileSync(join(__dirname, 'fixtures', 'city_keys.json'), 'utf-8');
    const table: [string, string][] = JSON.parse(raw);
    for (const [name, expectedKey] of table) {
      assert.equal(cityKeyOf(cityOf(name)), expectedKey);
    }
  });

  it('#199\'s milestoneAmounts at 50/50 gives the remainder to delivery', () => {
    assert.deepEqual(milestoneAmounts(4_200_000, { shoot: 50, delivery: 50 }), {
      shoot: 2_100_000,
      delivery: 2_100_000,
    });
    assert.deepEqual(milestoneAmounts(1_500_001, { shoot: 50, delivery: 50 }), {
      shoot: 750_000,
      delivery: 750_001,
    });
    assert.deepEqual(milestoneAmounts(1, { shoot: 50, delivery: 50 }), {
      shoot: 0,
      delivery: 1,
    });
  });

  it('deadlinePassed at the exact instant', () => {
    const deadline = new Date('2026-10-08T02:00:00.000Z');
    assert.equal(deadlinePassed({ quoteDeadline: deadline }, new Date('2026-10-08T01:59:59.999Z')), false);
    assert.equal(deadlinePassed({ quoteDeadline: deadline }, new Date('2026-10-08T02:00:00.000Z')), true);
    assert.equal(deadlinePassed({ quoteDeadline: deadline }, new Date('2026-10-08T02:00:01.000Z')), true);
  });

  it('checkoutActive until expiresAt', () => {
    const expiresAt = new Date('2026-10-05T02:30:00.000Z');
    const checkout = { quoteId: 'q1', bookingId: 'b1', expiresAt };
    assert.equal(checkoutActive({ checkout }, new Date('2026-10-05T02:29:59.999Z')), true);
    assert.equal(checkoutActive({ checkout }, new Date('2026-10-05T02:30:00.000Z')), false);
    assert.equal(checkoutActive({ checkout: null }, new Date('2026-10-05T02:20:00.000Z')), false);
  });
});
