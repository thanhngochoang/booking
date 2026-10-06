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
