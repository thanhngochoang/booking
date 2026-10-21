import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  canJoinAsMember,
  foldNameKey,
  inCooldown,
  isOpenBookingStatus,
  maxMembers,
  quotaLeft,
  relationId,
  spendQuota,
} from '../src/studio_membership.js';
import { studioProfile } from './support/studio_world.js';

describe('studio membership rules', () => {
  it('maxMembers is 3, 30 when businessVerified', () => {
    assert.equal(maxMembers({ businessVerified: false }), 3);
    assert.equal(maxMembers({ businessVerified: true }), 30);
  });

  it('artist and individual can join, studio and unfinished cannot', () => {
    assert.equal(canJoinAsMember(studioProfile('m1')), true);
    assert.equal(canJoinAsMember(studioProfile('a1', { providerType: 'artist' })), true);
    assert.equal(canJoinAsMember(studioProfile('s1', { providerType: 'studio' })), false);
    assert.equal(canJoinAsMember(studioProfile('u1', { onboardingComplete: false })), false);
  });

  it('cooldown ends exactly 7 days after endedAt', () => {
    const until = '2026-10-17T10:00:00.000Z';
    assert.equal(inCooldown({ studioCooldownUntil: until }, new Date('2026-10-17T09:59:59.999Z')), true);
    assert.equal(inCooldown({ studioCooldownUntil: until }, new Date(until)), false);
    assert.equal(inCooldown({ studioCooldownUntil: null }, new Date(until)), false);
  });

  it('quotaLeft resets at 00:00 VN (17:00 UTC)', () => {
    const q = { dayKey: '2026-10-10', studioActions: 5, memberActions: 1 };
    const before = new Date('2026-10-10T16:59:59.999Z');
    const after = new Date('2026-10-10T17:00:00.000Z');
    assert.equal(quotaLeft(q, 'studio', before), 0);
    assert.equal(quotaLeft(q, 'member', before), 2);
    assert.equal(quotaLeft(q, 'studio', after), 5);
    assert.equal(quotaLeft(q, 'member', after), 3);
    assert.equal(quotaLeft(null, 'studio', before), 5);
    assert.equal(quotaLeft(null, 'member', before), 3);
  });

  it('spendQuota counts one action and starts a new VN day from zero', () => {
    const q = { dayKey: '2026-10-10', studioActions: 4, memberActions: 1 };
    assert.deepEqual(spendQuota(q, 'studio', new Date('2026-10-10T16:00:00.000Z')),
      { dayKey: '2026-10-10', studioActions: 5, memberActions: 1 });
    assert.deepEqual(spendQuota(q, 'member', new Date('2026-10-10T17:00:00.000Z')),
      { dayKey: '2026-10-11', studioActions: 0, memberActions: 1 });
    assert.deepEqual(spendQuota(null, 'studio', new Date('2026-10-10T10:00:00.000Z')),
      { dayKey: '2026-10-10', studioActions: 1, memberActions: 0 });
  });

  it('isOpenBookingStatus is false only for declined, expired, cancelled, completed, reviewed', () => {
    for (const s of ['declined', 'expired', 'cancelled', 'completed', 'reviewed']) {
      assert.equal(isOpenBookingStatus(s), false, s);
    }
    for (const s of ['draft', 'requested', 'accepted', 'upcoming', 'shot', 'delivered', 'revision_requested',
      'approved', 'disputed']) {
      assert.equal(isOpenBookingStatus(s), true, s);
    }
  });

  it('foldNameKey folds marks and lower-cases (Hồng Nhung → hong nhung)', () => {
    assert.equal(foldNameKey('Hồng Nhung'), 'hong nhung');
    assert.equal(foldNameKey('  Đặng Quốc Bảo '), 'dang quoc bao');
  });

  it('relationId is studio, member and creation time in ms', () => {
    assert.equal(relationId('s1', 'm1', new Date('2026-10-10T10:00:00.000Z')), 's1_m1_1791626400000');
  });
});
