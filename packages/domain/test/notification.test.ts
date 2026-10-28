import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  decideDelivery,
  DEFAULT_NOTIFICATION_PREFS,
  isQuietAt,
  NOTIFICATION_CATEGORIES,
  NOTIFICATION_TABS,
  NOTIFICATION_TYPES,
  prefsFromRaw,
  type NotificationPrefs,
} from '../src/notification.js';

const withChannel = (
  p: NotificationPrefs,
  c: (typeof NOTIFICATION_CATEGORIES)[number],
  v: { push?: boolean; inApp?: boolean },
): NotificationPrefs => ({ ...p, channels: { ...p.channels, [c]: { ...p.channels[c], ...v } } });

// 2026-10-10 15:00 UTC = 22:00 in Vietnam.
const NIGHT = new Date('2026-10-10T15:00:00.000Z');
const NOON = new Date('2026-10-10T05:00:00.000Z');

describe('notification types and prefs', () => {
  it('every type has a category, tab and critical flag', () => {
    for (const [type, m] of Object.entries(NOTIFICATION_TYPES)) {
      assert.ok((NOTIFICATION_CATEGORIES as readonly string[]).includes(m.category), type);
      assert.ok((NOTIFICATION_TABS as readonly string[]).includes(m.tab), type);
      assert.equal(typeof m.critical, 'boolean', type);
    }
    assert.equal(NOTIFICATION_TYPES.booking_cancelled.critical, true);
    assert.equal(NOTIFICATION_TYPES.refund_done.critical, true);
    assert.equal(NOTIFICATION_TYPES.chat_message.tab, 'system');
    assert.equal(NOTIFICATION_TYPES.event_soon.tab, 'events');
  });

  it('defaults: all on, promo off, quiet 22:00–07:00 on, reminders on', () => {
    const d = DEFAULT_NOTIFICATION_PREFS;
    for (const c of NOTIFICATION_CATEGORIES) {
      assert.deepEqual(d.channels[c], c === 'promo' ? { push: false, inApp: false } : { push: true, inApp: true }, c);
    }
    assert.deepEqual(d.quietHours, { enabled: true, from: '22:00', to: '07:00' });
    assert.deepEqual(d.reminders, { h24: true, h2: true });
  });

  it('prefsFromRaw keeps valid parts and forces booking.inApp true', () => {
    const p = prefsFromRaw({
      channels: { chat: { push: false, inApp: true }, booking: { push: false, inApp: false }, bogus: { push: false } },
      quietHours: { enabled: false, from: '23:00', to: 'x' },
      reminders: { h24: false },
      extra: 1,
    });
    assert.deepEqual(p.channels.chat, { push: false, inApp: true });
    assert.deepEqual(p.channels.booking, { push: false, inApp: true });
    assert.deepEqual(p.quietHours, { enabled: false, from: '23:00', to: '07:00' });
    assert.deepEqual(p.reminders, { h24: false, h2: true });
    assert.deepEqual(p.channels.badges, DEFAULT_NOTIFICATION_PREFS.channels.badges);
  });

  it('garbage prefs give defaults', () => {
    for (const raw of [null, undefined, 'x', 5, [], { channels: 3, quietHours: [], reminders: 'a' }]) {
      assert.deepEqual(prefsFromRaw(raw), DEFAULT_NOTIFICATION_PREFS);
    }
  });
});

describe('quiet hours', () => {
  it('quiet window wraps midnight in Vietnam time', () => {
    const p = DEFAULT_NOTIFICATION_PREFS;
    assert.equal(isQuietAt(p, new Date('2026-10-10T16:30:00.000Z')), true); // 23:30 VN
    assert.equal(isQuietAt(p, new Date('2026-10-10T00:30:00.000Z')), false); // 07:30 VN
    assert.equal(isQuietAt(p, NIGHT), true); // 22:00 VN
    assert.equal(isQuietAt(p, new Date('2026-10-10T23:59:00.000Z')), true); // 06:59 VN
    assert.equal(isQuietAt(p, new Date('2026-10-11T00:00:00.000Z')), false); // 07:00 VN
    assert.equal(isQuietAt(p, NOON), false);
  });

  it('disabled quiet hours are never quiet', () => {
    const p = { ...DEFAULT_NOTIFICATION_PREFS, quietHours: { enabled: false, from: '22:00', to: '07:00' } };
    assert.equal(isQuietAt(p, NIGHT), false);
  });
});

describe('decideDelivery', () => {
  const p = DEFAULT_NOTIFICATION_PREFS;

  it('everything on by day → inbox and default push', () => {
    assert.deepEqual(decideDelivery('review_new', p, NOON), { inbox: true, push: 'default' });
  });

  it('in-app off and not critical → no inbox', () => {
    const d = decideDelivery('review_new', withChannel(p, 'badges', { inApp: false }), NOON);
    assert.deepEqual(d, { inbox: false, push: 'default' });
  });

  it('critical keeps the inbox and the default channel at night', () => {
    assert.deepEqual(decideDelivery('booking_cancelled', p, NIGHT), { inbox: true, push: 'default' });
    assert.deepEqual(decideDelivery('refund_done', withChannel(p, 'booking', { inApp: false }), NIGHT), {
      inbox: true,
      push: 'default',
    });
  });

  it('push off → none', () => {
    assert.deepEqual(decideDelivery('chat_message', withChannel(p, 'chat', { push: false }), NOON), {
      inbox: true,
      push: 'none',
    });
  });

  it('quiet hours → quiet channel', () => {
    assert.deepEqual(decideDelivery('chat_message', p, NIGHT), { inbox: true, push: 'quiet' });
  });

  it('reminder variant off drops the reminder', () => {
    const off = { ...p, reminders: { h24: false, h2: true } };
    assert.deepEqual(decideDelivery('shoot_reminder', off, NOON, 'h24'), { inbox: false, push: 'none' });
    assert.deepEqual(decideDelivery('shoot_reminder', off, NOON, 'h2'), { inbox: true, push: 'default' });
  });

  it('promo is off by default', () => {
    assert.deepEqual(decideDelivery('promo', p, NOON), { inbox: false, push: 'none' });
  });
});

/** The plan's catalogue (Contract table): type → [category, tab, critical]. */
const PLAN_META: Record<string, readonly [string, string, boolean]> = {
  payout_released: ['booking', 'system', true],
  quote_new: ['jobs', 'activity', false],
  quote_withdrawn: ['jobs', 'activity', false],
  job_expiring: ['jobs', 'activity', false],
  job_expired: ['jobs', 'activity', false],
  job_match: ['jobs', 'activity', false],
  job_invited: ['jobs', 'activity', false],
  quote_accepted: ['jobs', 'activity', false],
  quote_not_selected: ['jobs', 'activity', false],
  job_selected: ['jobs', 'activity', false],
  instant_assigned: ['instant', 'activity', false],
  instant_missed: ['instant', 'activity', false],
  instant_round_ended: ['instant', 'activity', false],
  instant_no_match: ['instant', 'activity', false],
  instant_arrived: ['instant', 'activity', false],
  instant_finished: ['instant', 'activity', false],
  instant_cancelled: ['instant', 'activity', true],
  event_soon: ['events', 'events', false],
  review_tomato: ['badges', 'system', false],
  review_brick: ['badges', 'system', false],
  delivery_submitted: ['booking', 'activity', false],
  delivery_revision_requested: ['booking', 'activity', false],
  delivery_approved: ['booking', 'activity', false],
  delivery_auto_approve_soon: ['booking', 'activity', false],
  delivery_extra_round: ['booking', 'activity', false],
  studio_invite: ['booking', 'system', false],
  studio_join_request: ['booking', 'system', false],
  studio_invite_accepted: ['booking', 'system', false],
  studio_join_approved: ['booking', 'system', false],
  studio_removed: ['booking', 'system', false],
  studio_invite_expiring: ['booking', 'system', false],
  booking_assigned: ['booking', 'activity', false],
  booking_reassigned: ['booking', 'activity', false],
  assign_reminder: ['booking', 'activity', false],
  assign_overdue: ['booking', 'activity', true],
  change_requested: ['booking', 'activity', false],
  change_answered: ['booking', 'activity', false],
  assignment_returned: ['booking', 'activity', false],
  payout_account_needed: ['booking', 'system', false],
  payout_account_changed: ['booking', 'system', true],
  verification_approved: ['booking', 'system', true],
  verification_rejected: ['booking', 'system', true],
  verification_revoked: ['booking', 'system', true],
  verification_reminder: ['booking', 'system', false],
  business_verified: ['booking', 'system', true],
  business_rejected: ['booking', 'system', true],
  dispute_opened: ['booking', 'activity', true],
  dispute_resolved: ['booking', 'activity', true],
  dispute_message: ['booking', 'activity', false],
  support_reply: ['booking', 'activity', true],
  refund_account_needed: ['booking', 'activity', true],
  recruit_post_new: ['jobs', 'activity', false],
  recruit_application_new: ['jobs', 'activity', false],
  recruit_application_result: ['jobs', 'activity', false],
  collab_invite: ['jobs', 'activity', false],
  collab_invite_result: ['jobs', 'activity', false],
  collab_assignment_offer: ['jobs', 'activity', true],
  collab_assignment_result: ['jobs', 'activity', false],
  collab_pay_due: ['jobs', 'activity', false],
  collab_pay_reported: ['jobs', 'activity', false],
  collab_pay_disputed: ['jobs', 'activity', false],
};

/** Critical rows that existed before S17 and keep their meta. */
const EARLIER_CRITICAL = ['booking_cancelled', 'refund_done', 'event_host_invited'];
/** Critical rows added after S17: S30's shoot question decides held money (plan #223 Contract). */
const LATER_CRITICAL = ['shoot_question'];

describe('S17 catalogue', () => {
  it('every new type has meta (category, tab, critical) as in the plan table', () => {
    const types = NOTIFICATION_TYPES as Record<string, { category: string; tab: string; critical: boolean }>;
    for (const [type, [category, tab, critical]] of Object.entries(PLAN_META)) {
      assert.deepEqual(types[type], { category, tab, critical }, type);
    }
  });

  it('the critical set is exactly the ✓ rows of the table', () => {
    const critical = Object.entries(NOTIFICATION_TYPES)
      .filter(([, m]) => m.critical)
      .map(([t]) => t)
      .sort();
    const expected = [
      ...EARLIER_CRITICAL,
      ...LATER_CRITICAL,
      ...Object.entries(PLAN_META)
        .filter(([, m]) => m[2])
        .map(([t]) => t),
    ].sort();
    assert.deepEqual(critical, expected);
  });

  it('review_tomato and review_brick are badges/system', () => {
    for (const t of ['review_tomato', 'review_brick'] as const) {
      assert.equal(NOTIFICATION_TYPES[t].category, 'badges');
      assert.equal(NOTIFICATION_TYPES[t].tab, 'system');
      assert.equal(NOTIFICATION_TYPES[t].critical, false);
    }
  });
});
