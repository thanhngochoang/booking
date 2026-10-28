import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import {
  ACCESS_FEES_MAX,
  GATE_INVITE_HOURS,
  canSell,
  inviteOpen,
  validateAccess,
  waiverFor,
  type GateStaff,
  type Resident,
} from '../src/organizer.js';

const rejects = (code: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === code && (field === undefined || e.field === field);

const NOW = new Date('2026-10-18T03:00:00.000Z');
const HOUR = 3_600_000;

const fee = (i: number) => ({ label: `Vé ${i}`, amountVnd: 70_000 });

describe('canSell', () => {
  test('canSell is true only when active, businessVerified and payoutAccountOk', () => {
    const ok = { status: 'active', businessVerified: true, payoutAccountOk: true } as const;
    assert.equal(canSell(ok), true);
    assert.equal(canSell({ ...ok, status: 'suspended' }), false);
    assert.equal(canSell({ ...ok, businessVerified: false }), false);
    assert.equal(canSell({ ...ok, payoutAccountOk: false }), false);
  });
});

describe('validateAccess', () => {
  test(`${ACCESS_FEES_MAX + 1} fees → field fees`, () => {
    const fees = Array.from({ length: ACCESS_FEES_MAX + 1 }, (_, i) => fee(i));
    assert.throws(() => validateAccess({ type: 'ticket', fees, note: '' }, 'organizer', NOW), rejects('invalid_argument', 'fees'));
  });

  test('a fee with amountVnd 0 or non-integer → field fees', () => {
    for (const amountVnd of [0, 1.5, -1000, '70000']) {
      assert.throws(
        () => validateAccess({ type: 'ticket', fees: [{ label: 'Người lớn', amountVnd }], note: '' }, 'staff', NOW),
        rejects('invalid_argument', 'fees'),
        String(amountVnd),
      );
    }
  });

  test('a fee without a label → field fees', () => {
    assert.throws(
      () => validateAccess({ type: 'ticket', fees: [{ label: '  ', amountVnd: 1000 }], note: '' }, 'staff', NOW),
      rejects('invalid_argument', 'fees'),
    );
  });

  test('note of 121 → field note; 120 is fine', () => {
    assert.throws(
      () => validateAccess({ type: 'ticket', fees: [], note: 'a'.repeat(121) }, 'staff', NOW),
      rejects('invalid_argument', 'note'),
    );
    assert.equal(validateAccess({ type: 'ticket', fees: [], note: 'a'.repeat(120) }, 'staff', NOW).note.length, 120);
  });

  test('an unknown type → field type', () => {
    assert.throws(() => validateAccess({ type: 'free', fees: [] }, 'staff', NOW), rejects('invalid_argument', 'type'));
    assert.throws(() => validateAccess(null, 'staff', NOW), rejects('invalid_argument'));
  });

  test('type open with fees → ok (fees kept as reference), stamped with now and the source', () => {
    const a = validateAccess(
      { type: 'open', fees: [{ label: ' Gửi xe máy ', amountVnd: 5000 }], note: ' Mở cả ngày ' },
      'organizer',
      NOW,
    );
    assert.deepEqual(a, {
      type: 'open',
      fees: [{ label: 'Gửi xe máy', amountVnd: 5000 }],
      note: 'Mở cả ngày',
      updatedAt: NOW.toISOString(),
      source: 'organizer',
    });
  });
});

describe('waiverFor', () => {
  const resident = (over: Partial<Resident> = {}): Resident => ({
    providerId: 'p1', waivesProvider: true, waivesGuests: true, maxGuests: 3, validUntil: null,
    addedAt: NOW.toISOString(), addedBy: 'org1', ...over,
  });

  test('null → no waiver', () => {
    assert.deepEqual(waiverFor(null, '2026-10-18'), { provider: false, guests: false, maxGuests: null });
  });

  test('validUntil yesterday → no waiver', () => {
    assert.deepEqual(waiverFor(resident({ validUntil: '2026-10-17' }), '2026-10-18'), {
      provider: false, guests: false, maxGuests: null,
    });
  });

  test('validUntil today → waiver; maxGuests copied', () => {
    assert.deepEqual(waiverFor(resident({ validUntil: '2026-10-18' }), '2026-10-18'), {
      provider: true, guests: true, maxGuests: 3,
    });
    assert.deepEqual(waiverFor(resident({ waivesGuests: false, maxGuests: null }), '2026-10-18'), {
      provider: true, guests: false, maxGuests: null,
    });
  });
});

describe('inviteOpen', () => {
  const invite = (hoursAgo: number, status: GateStaff['status'] = 'invited'): GateStaff => ({
    staffUid: 'g1', status, invitedAt: new Date(NOW.getTime() - hoursAgo * HOUR).toISOString(), respondedAt: null,
  });

  test(`invited 71 h ago true, 73 h ago false, active false (${GATE_INVITE_HOURS} h)`, () => {
    assert.equal(inviteOpen(invite(71), NOW), true);
    assert.equal(inviteOpen(invite(73), NOW), false);
    assert.equal(inviteOpen(invite(1, 'active'), NOW), false);
    assert.equal(inviteOpen(invite(1, 'removed'), NOW), false);
  });
});
