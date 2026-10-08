/**
 * S17 `event_soon`: one reminder per paid ticket when its event starts within 48 hours (plan
 * 2026-10-07 Decision 4). Run by the event clock every 5 minutes; the event-level marker
 * `soonNoticeAt` is set only after every send succeeded, so a failure retries on the next tick and
 * the per-ticket dedupe key (`event_soon_{eventId}_{regId}`) keeps the retry from sending twice.
 * Tickets bought after the marker is set get no reminder (they just bought it).
 */

import { formatVnDate, formatVnTime } from './booking_policy.js';
import type { EventRecord } from './event.js';
import type { EventDeps } from './event_ports.js';
import type { NotifyDeps } from './notification_ports.js';
import type { NotificationContent } from './notification_render.js';
import { notify } from './notification_use_cases.js';

export const EVENT_SOON_HOURS = 48;

const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;
const BATCH = 200;

/** Days since the epoch of the Vietnam calendar day of `d`. */
function vnDayNumber(d: Date): number {
  const [y, m, day] = formatVnDate(d).split('-').map(Number);
  return Date.UTC(y ?? 1970, (m ?? 1) - 1, day ?? 1) / DAY_MS;
}

/** Copy fields of the reminder: whole Vietnam calendar days left, start time, meeting place. */
export function eventSoonContent(ev: EventRecord, now: Date): Extract<NotificationContent, { type: 'event_soon' }> {
  if (ev.startAt === null) throw new Error(`event ${ev.id} has no start`);
  return {
    type: 'event_soon',
    title: ev.title,
    daysLeft: Math.max(0, vnDayNumber(ev.startAt) - vnDayNumber(now)),
    start: formatVnTime(ev.startAt),
    place: ev.location?.meetingPoint ?? ev.location?.name ?? '',
  };
}

const remindable = (ev: EventRecord): boolean =>
  (ev.status === 'open' || ev.status === 'full' || ev.status === 'closed') && (ev.soonNoticeAt ?? null) === null;

/**
 * Sends `event_soon` to every paid ticket of each event starting within `EVENT_SOON_HOURS`. One bad
 * event never blocks the others: `onError` gets its id and the loop goes on. Returns how many events
 * were completed (marker set) and how many rows were created.
 */
export async function sendEventSoonNotices(
  deps: EventDeps,
  notifyDeps: NotifyDeps,
  onError: (eventId: string, e: unknown) => void = () => undefined,
): Promise<{ events: number; sent: number }> {
  const now = deps.clock.now();
  let events = 0;
  let sent = 0;
  for (const due of await deps.events.dueForSoonNotice(now, new Date(now.getTime() + EVENT_SOON_HOURS * HOUR_MS), BATCH)) {
    try {
      // Re-read: the event may have been cancelled or reminded since the query.
      const found = await deps.events.runTransaction(async (tx) => {
        const ev = await tx.getEvent(due.id);
        if (ev === null || !remindable(ev)) return null;
        return { ev, regs: (await tx.activeRegistrations(ev.id)).filter((r) => r.status === 'paid') };
      });
      if (found === null) continue;
      const { ev, regs } = found;
      const content = eventSoonContent(ev, deps.clock.now());
      const results = await Promise.allSettled(regs.map((r) => notify(notifyDeps, {
        userId: r.userId,
        content,
        target: `/e/${ev.id}`,
        dedupeKey: `event_soon_${ev.id}_${r.id}`,
        thumbUrl: ev.coverUrl,
      })));
      sent += results.filter((x) => x.status === 'fulfilled' && x.value === 'created').length;
      if (results.some((x) => x.status === 'rejected')) throw new Error('event_soon send failed');
      await deps.events.runTransaction(async (tx) => {
        const fresh = await tx.getEvent(ev.id);
        if (fresh === null || (fresh.soonNoticeAt ?? null) !== null) return;
        // Version unchanged: a server marker, not an edit of the event.
        tx.putEvent({ ...fresh, soonNoticeAt: deps.clock.now() });
      });
      events += 1;
    } catch (e) {
      onError(due.id, e);
    }
  }
  return { events, sent };
}
