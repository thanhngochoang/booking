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
  instant_round_ended: meta('instant', 'activity'),
  instant_no_match: meta('instant', 'activity'),
  instant_arrived: meta('instant', 'activity'),
  instant_finished: meta('instant', 'activity'),
  instant_cancelled: meta('instant', 'activity', true),
  event_soon: meta('events', 'events'),
  event_host_invited: meta('events', 'events', true),
  review_new: meta('badges', 'system'),
  review_tomato: meta('badges', 'system'),
  review_brick: meta('badges', 'system'),
  badge_new: meta('badges', 'system'),
  award_reviewed: meta('badges', 'system'),
  artist_granted: meta('badges', 'system'),
  artist_revoked: meta('badges', 'system'),
  // S17 Decision 6: delivery and studio assignment → booking/activity; studio membership,
  // payout account and verification → booking/system; disputes, support, refund account → booking/activity.
  delivery_submitted: meta('booking', 'activity'),
  delivery_revision_requested: meta('booking', 'activity'),
  delivery_approved: meta('booking', 'activity'),
  delivery_auto_approve_soon: meta('booking', 'activity'),
  delivery_extra_round: meta('booking', 'activity'),
  studio_invite: meta('booking', 'system'),
  studio_join_request: meta('booking', 'system'),
  studio_invite_accepted: meta('booking', 'system'),
  studio_join_approved: meta('booking', 'system'),
  studio_removed: meta('booking', 'system'),
  studio_invite_expiring: meta('booking', 'system'),
  booking_assigned: meta('booking', 'activity'),
  booking_reassigned: meta('booking', 'activity'),
  assign_reminder: meta('booking', 'activity'),
  assign_overdue: meta('booking', 'activity', true),
  change_requested: meta('booking', 'activity'),
  change_answered: meta('booking', 'activity'),
  assignment_returned: meta('booking', 'activity'),
  payout_account_needed: meta('booking', 'system'),
  payout_account_changed: meta('booking', 'system', true),
  verification_approved: meta('booking', 'system', true),
  verification_rejected: meta('booking', 'system', true),
  verification_revoked: meta('booking', 'system', true),
  verification_reminder: meta('booking', 'system'),
  business_verified: meta('booking', 'system', true),
  business_rejected: meta('booking', 'system', true),
  dispute_opened: meta('booking', 'activity', true),
  dispute_resolved: meta('booking', 'activity', true),
  dispute_message: meta('booking', 'activity'),
  support_reply: meta('booking', 'activity', true),
  refund_account_needed: meta('booking', 'activity', true),
  // Recruiting and collaborators: the "Việc đăng tuyển" channel.
  recruit_post_new: meta('jobs', 'activity'),
  recruit_application_new: meta('jobs', 'activity'),
  recruit_application_result: meta('jobs', 'activity'),
  collab_invite: meta('jobs', 'activity'),
  collab_invite_result: meta('jobs', 'activity'),
  collab_assignment_offer: meta('jobs', 'activity', true),
  collab_assignment_result: meta('jobs', 'activity'),
  collab_pay_due: meta('jobs', 'activity'),
  collab_pay_reported: meta('jobs', 'activity'),
  collab_pay_disputed: meta('jobs', 'activity'),
  // S30 organizers (#223): spot claims, residents and gate staff → the events channel.
  spot_claim_approved: meta('events', 'system'),
  spot_claim_rejected: meta('events', 'system'),
  spot_resident_added: meta('events', 'system'),
  gate_staff_invited: meta('events', 'events'),
  // S30 entry tickets: the organizer closed a visit day; the ticket is refunded 100%.
  entry_day_closed: meta('events', 'events'),
  // S30 passes and the shoot question (Decision 10): booking/activity; the question decides held money.
  shoot_question: meta('booking', 'activity', true),
  pass_ready: meta('booking', 'activity'),
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
