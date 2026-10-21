import { describe, expect, it } from 'vitest';

import { ERROR_CODES, contactUnlocked, contactUrl } from '../src/domain/index.js';

type Status = Parameters<typeof contactUnlocked>[0]['status'];
const now = new Date('2026-10-01T12:00:00Z');
const ago = (ms: number) => new Date(now.getTime() - ms);
const DAY = 86_400_000;

describe('phase 1 domain module, as reused by the API', () => {
  it('lists the ErrorCode catalogue of domain-model.md §4', () => {
    expect([...ERROR_CODES].sort()).toEqual([
      'addon_changed', 'addon_limit', 'addon_not_applicable', 'blocked', 'conflict', 'contact_leak',
      'contact_locked', 'cooldown', 'day_conflict', 'day_taken', 'deadline_passed', 'identity_in_use', 'invalid_argument',
      'limit_exceeded', 'member_busy', 'membership_conflict', 'name_mismatch', 'not_accepting_orders',
      'not_eligible', 'not_found', 'not_ready', 'otp_expired', 'otp_invalid', 'otp_required',
      'outside_schedule',
      'payment_attempts_exceeded', 'permission_denied', 'phone_required', 'pickup_required',
      'price_changed', 'rate_limited', 'reauth_required', 'schedule_has_bookings', 'schedule_limit', 'slot_taken', 'sold_out',
      'spot_archived', 'studio_full', 'underage',
    ]);
  });

  it.each<[Status, boolean]>([
    ['requested', true], ['accepted', true], ['upcoming', true],
    ['draft', false], ['declined', false], ['expired', false], ['cancelled', false],
  ])('booking %s → unlocked %s', (status, expected) => {
    expect(contactUnlocked({ status, completedAt: null }, now)).toBe(expected);
  });

  it('completed and reviewed stay unlocked for 30 days after completion', () => {
    for (const status of ['completed', 'reviewed'] as Status[]) {
      expect(contactUnlocked({ status, completedAt: ago(29 * DAY) }, now)).toBe(true);
      expect(contactUnlocked({ status, completedAt: ago(30 * DAY) }, now)).toBe(true);
      expect(contactUnlocked({ status, completedAt: ago(30 * DAY + 1000) }, now)).toBe(false);
      expect(contactUnlocked({ status, completedAt: null }, now)).toBe(false);
    }
  });

  it('builds the URL shapes of plan 2b', () => {
    const vn = { phone: '+84903123456' };
    expect(contactUrl('call', vn)).toBe('tel:+84903123456');
    expect(contactUrl('zalo', vn)).toBe('https://zalo.me/84903123456');
    expect(contactUrl('whatsapp', vn)).toBe('https://wa.me/84903123456');
    const own = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
    expect(contactUrl('call', own)).toBe('tel:+84903123456');
    expect(contactUrl('zalo', own)).toBe('https://zalo.me/84912345678');
    expect(contactUrl('whatsapp', own)).toBe('https://wa.me/14155552671');
  });
});
