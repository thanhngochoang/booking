/**
 * S17 `event_soon`: one reminder per paid ticket when its event starts within 48 hours (plan
 * 2026-10-07 Decision 4). Run by the event clock every 5 minutes. After each run the event records the
 * registrations whose send settled (`soonNotifiedRegIds`, Ruling 7), so a retry after a partial
 * failure sends only to the others: a user with the inbox off but push on has no dedupe row and would
 * otherwise get a push on every tick. The event-level marker `soonNoticeAt` is set (and the list
 * cleared) once every paid registration is in the list. Tickets bought after the marker is set get no
 * reminder (they just bought it).
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

/** Entry events (S30) span many days and are never "about to start": no `event_soon`. */
const remindable = (ev: EventRecord): boolean => ev.type !== 'entry'
  && (ev.status === 'open' || ev.status === 'full' || ev.status === 'closed') && (ev.soonNoticeAt ?? null) === null;

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
      const already = new Set(ev.soonNotifiedRegIds ?? []);
      const pending = regs.filter((r) => !already.has(r.id));
      const content = eventSoonContent(ev, deps.clock.now());
      const results = await Promise.allSettled(pending.map((r) => notify(notifyDeps, {
        userId: r.userId,
        content,
        target: `/e/${ev.id}`,
        dedupeKey: `event_soon_${ev.id}_${r.id}`,
        thumbUrl: ev.coverUrl,
      })));
      sent += results.filter((x) => x.status === 'fulfilled' && x.value === 'created').length;
      const settled = pending.filter((_, i) => results[i]?.status === 'fulfilled').map((r) => r.id);
      const marked = await deps.events.runTransaction(async (tx) => {
        const fresh = await tx.getEvent(ev.id);
        if (fresh === null || (fresh.soonNoticeAt ?? null) !== null) return false;
        const notified = new Set([...(fresh.soonNotifiedRegIds ?? []), ...settled]);
        const paid = (await tx.activeRegistrations(ev.id)).filter((r) => r.status === 'paid');
        const done = paid.every((r) => notified.has(r.id));
        if (!done && settled.length === 0) return false;
        // Version unchanged: a server marker, not an edit of the event.
        tx.putEvent(done
          ? { ...fresh, soonNoticeAt: deps.clock.now(), soonNotifiedRegIds: [] }
          : { ...fresh, soonNotifiedRegIds: [...notified] });
        return done;
      });
      if (results.some((x) => x.status === 'rejected')) throw new Error('event_soon send failed');
      if (!marked) continue;
      events += 1;
    } catch (e) {
      onError(due.id, e);
    }
  }
  return { events, sent };
}
