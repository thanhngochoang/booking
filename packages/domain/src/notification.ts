/**
 * Notification types, per-user preferences and the delivery decision
 * (plan 10a Decisions 1, 6, 7; spec §3h). Pure: no storage, no clock.
 */

export const NOTIFICATION_CATEGORIES = ['booking', 'jobs', 'instant', 'events', 'chat', 'badges', 'promo'] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];

export const NOTIFICATION_TABS = ['activity', 'events', 'system'] as const;
export type NotificationTab = (typeof NOTIFICATION_TABS)[number];

interface TypeMeta {
  readonly category: NotificationCategory;
  readonly tab: NotificationTab;
  readonly critical: boolean;
}

const meta = (category: NotificationCategory, tab: NotificationTab, critical = false): TypeMeta => ({
  category,
  tab,
  critical,
});

/** Single source for the S17.02 row, the S17.01 filter bucket and "critical" (always in the inbox, never quiet). */
export const NOTIFICATION_TYPES = {
  booking_request: meta('booking', 'activity'),
  booking_accepted: meta('booking', 'activity'),
  booking_declined: meta('booking', 'activity'),
  booking_cancelled: meta('booking', 'activity', true),
  refund_done: meta('booking', 'activity', true),
  shoot_reminder: meta('booking', 'activity'),
  payout_released: meta('booking', 'system', true),
  quote_new: meta('jobs', 'activity'),
  quote_withdrawn: meta('jobs', 'activity'),
  job_expiring: meta('jobs', 'activity'),
  job_expired: meta('jobs', 'activity'),
  job_match: meta('jobs', 'activity'),
  job_invited: meta('jobs', 'activity'),
  quote_accepted: meta('jobs', 'activity'),
  quote_not_selected: meta('jobs', 'activity'),
  job_selected: meta('jobs', 'activity'),
  instant_assigned: meta('instant', 'activity'),
  instant_missed: meta('instant', 'activity'),
  event_soon: meta('events', 'events'),
  review_new: meta('badges', 'system'),
  badge_new: meta('badges', 'system'),
  award_reviewed: meta('badges', 'system'),
  artist_granted: meta('badges', 'system'),
  artist_revoked: meta('badges', 'system'),
  chat_message: meta('chat', 'system'),
  promo: meta('promo', 'system'),
} as const satisfies Record<string, TypeMeta>;

export type NotificationType = keyof typeof NOTIFICATION_TYPES;

export interface ChannelPrefs {
  readonly push: boolean;
  readonly inApp: boolean;
}

export interface NotificationPrefs {
  readonly channels: Readonly<Record<NotificationCategory, ChannelPrefs>>;
  readonly quietHours: { readonly enabled: boolean; readonly from: string; readonly to: string };
  readonly reminders: { readonly h24: boolean; readonly h2: boolean };
}

const defaultChannels = (): Record<NotificationCategory, ChannelPrefs> =>
  Object.fromEntries(
    NOTIFICATION_CATEGORIES.map((c) => [c, c === 'promo' ? { push: false, inApp: false } : { push: true, inApp: true }]),
  ) as Record<NotificationCategory, ChannelPrefs>;

export const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs = {
  channels: defaultChannels(),
  quietHours: { enabled: true, from: '22:00', to: '07:00' },
  reminders: { h24: true, h2: true },
};

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const bool = (v: unknown, fallback: boolean): boolean => (typeof v === 'boolean' ? v : fallback);

/** Lenient: unknown keys ignored, missing/invalid parts fall back to defaults, booking.inApp forced true. */
export function prefsFromRaw(raw: unknown): NotificationPrefs {
  const d = DEFAULT_NOTIFICATION_PREFS;
  if (!isRecord(raw)) return d;

  const rawChannels = isRecord(raw.channels) ? raw.channels : {};
  const channels = {} as Record<NotificationCategory, ChannelPrefs>;
  for (const c of NOTIFICATION_CATEGORIES) {
    const r = rawChannels[c];
    const fb = d.channels[c];
    channels[c] = isRecord(r) ? { push: bool(r.push, fb.push), inApp: bool(r.inApp, fb.inApp) } : fb;
  }
  channels.booking = { ...channels.booking, inApp: true };

  const q = isRecord(raw.quietHours) ? raw.quietHours : {};
  const quietHours = {
    enabled: bool(q.enabled, d.quietHours.enabled),
    from: typeof q.from === 'string' && HHMM.test(q.from) ? q.from : d.quietHours.from,
    to: typeof q.to === 'string' && HHMM.test(q.to) ? q.to : d.quietHours.to,
  };

  const r = isRecord(raw.reminders) ? raw.reminders : {};
  const reminders = { h24: bool(r.h24, d.reminders.h24), h2: bool(r.h2, d.reminders.h2) };

  return { channels, quietHours, reminders };
}

const VN_OFFSET_MIN = 7 * 60;

const minutesOf = (hhmm: string): number => {
  const [h, m] = hhmm.split(':');
  return Number(h) * 60 + Number(m);
};

/** True inside the quiet window (Asia/Ho_Chi_Minh, UTC+7); a window with from > to wraps midnight. */
export function isQuietAt(prefs: NotificationPrefs, now: Date): boolean {
  const q = prefs.quietHours;
  if (!q.enabled) return false;
  const from = minutesOf(q.from);
  const to = minutesOf(q.to);
  if (from === to) return false;
  const local = (Math.floor(now.getTime() / 60_000) + VN_OFFSET_MIN) % 1440;
  return from < to ? local >= from && local < to : local >= from || local < to;
}

export interface Delivery {
  readonly inbox: boolean;
  readonly push: 'none' | 'default' | 'quiet';
}

export function decideDelivery(
  type: NotificationType,
  prefs: NotificationPrefs,
  now: Date,
  reminder?: 'h24' | 'h2',
): Delivery {
  const { category, critical } = NOTIFICATION_TYPES[type];
  if (type === 'shoot_reminder' && reminder !== undefined && !prefs.reminders[reminder]) {
    return { inbox: false, push: 'none' };
  }
  const ch = prefs.channels[category];
  const inbox = critical || ch.inApp;
  const push = ch.push ? (isQuietAt(prefs, now) && !critical ? 'quiet' : 'default') : 'none';
  return { inbox, push };
}
