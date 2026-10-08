import { DomainError } from './errors.js';
import { decideDelivery, NOTIFICATION_TYPES, prefsFromRaw } from './notification.js';
import type { NotificationRow, NotifyDeps, NotifyRequest } from './notification_ports.js';
import { renderNotification, type NotificationContent } from './notification_render.js';

export type NotifyResult = 'created' | 'grouped' | 'duplicate' | 'suppressed';

const MARK_PAGE = 400;
const MAX_PAGES = 100;
const PRUNE_PAGE = 400;
const PRUNE_MAX_PAGES = 100;
export const NOTIFICATION_RETENTION_DAYS = 90;
/** How many recent event ids a grouped row remembers; a repeat inside the window is a duplicate (Ruling 8). */
export const GROUP_RECENT_EVENT_IDS = 20;

/** Dedupe/group key → Firestore-safe id part: `:` and `/` become `_` (keys without them keep their id). */
const idPart = (key: string): string => key.replace(/[:/]/g, '_');

/** Decides delivery from prefs, writes the inbox row (dedupe or group) and sends push after commit. */
export async function notify(deps: NotifyDeps, req: NotifyRequest): Promise<NotifyResult> {
  const meta = NOTIFICATION_TYPES[req.content.type];
  const prefs = prefsFromRaw(await deps.store.getPrefs(req.userId));
  const now = deps.clock.now();
  const delivery = decideDelivery(req.content.type, prefs, now, req.reminder);
  if (!delivery.inbox && delivery.push === 'none') return 'suppressed';

  const grouped = req.groupKey !== undefined;
  if (grouped && req.actor === undefined) throw new DomainError('invalid_argument');

  let result: NotifyResult = 'created';
  let row: NotificationRow | null = null;
  let text = renderNotification(req.content);

  if (delivery.inbox) {
    const base = {
      userId: req.userId,
      type: req.content.type,
      tab: meta.tab,
      category: meta.category,
      target: req.target,
      groupKey: req.groupKey ?? null,
      thumbUrl: req.thumbUrl ?? null,
    };
    const outcome = await deps.store.runTransaction(async (tx) => {
      if (req.groupKey !== undefined && req.actor !== undefined) {
        const id = `g_${idPart(req.groupKey)}`;
        const prev = await tx.getRow(req.userId, id);
        // A row the user already read restarts: count 1, a single actor and a fresh event-id list.
        const carried = prev && prev.readAt === null ? prev : null;
        // Duplicate: the row's last event (read or not, so a retried trigger never re-pushes), or any
        // event still remembered by the unread row (p1, p2, p1 counts two quotes, not three).
        if (
          prev && req.eventId
          && (prev.lastEventId === req.eventId || (carried?.recentEventIds ?? []).includes(req.eventId))
        ) {
          return { result: 'duplicate' as const, row: null };
        }
        const count = (carried?.count ?? 0) + 1;
        const actors = [req.actor, ...(carried?.actors ?? []).filter((a) => a.id !== req.actor?.id)].slice(0, 3);
        // Grouped copy may name the row's actors, newest first (S17 Decision 3); chat ignores `names`.
        const t = renderNotification({ ...req.content, count, names: actors.map((a) => a.name) } as NotificationContent);
        const next: NotificationRow = {
          ...base,
          id,
          count,
          actors,
          ...t,
          createdAt: now,
          readAt: null,
          lastEventId: req.eventId ?? null,
          recentEventIds: req.eventId
            ? [req.eventId, ...(carried?.recentEventIds ?? [])].slice(0, GROUP_RECENT_EVENT_IDS)
            : [...(carried?.recentEventIds ?? [])],
        };
        tx.putRow(next);
        return { result: carried ? ('grouped' as const) : ('created' as const), row: next };
      }
      const id = `n_${idPart(req.dedupeKey)}`;
      if (await tx.getRow(req.userId, id)) return { result: 'duplicate' as const, row: null };
      const next: NotificationRow = {
        ...base,
        id,
        count: 1,
        actors: req.actor ? [req.actor] : [],
        ...text,
        createdAt: now,
        readAt: null,
        lastEventId: null,
        recentEventIds: [],
      };
      tx.putRow(next);
      return { result: 'created' as const, row: next };
    });
    if (outcome.result === 'duplicate') return 'duplicate';
    result = outcome.result;
    row = outcome.row;
    if (row) text = { title: row.title, body: row.body };
  }

  if (delivery.push !== 'none') {
    try {
      await deps.push.send(req.userId, {
        title: text.title,
        body: text.body,
        channel: delivery.push,
        data: { type: req.content.type, target: req.target, ...(row ? { notificationId: row.id } : {}) },
      });
    } catch (e) {
      deps.onPushError?.(req.userId, e);
    }
  }
  return result;
}

/** Marks every unread row read (pages of 400) and reconciles the count. Returns rows marked. */
export async function markAllRead(deps: NotifyDeps, uid: string): Promise<number> {
  let total = 0;
  for (let page = 0; page < MAX_PAGES; page++) {
    const ids = await deps.store.listUnreadIds(uid, MARK_PAGE);
    if (ids.length === 0) break;
    await deps.store.markRead(uid, ids, deps.clock.now());
    total += ids.length;
  }
  await reconcileUnread(deps, uid);
  return total;
}

/**
 * Recounts unread rows and stores the count. The count time is taken before counting, so an out-of-order
 * run that started earlier can never overwrite a later one.
 */
export async function reconcileUnread(deps: NotifyDeps, uid: string): Promise<number> {
  const at = deps.clock.now();
  const count = await deps.store.countUnread(uid);
  await deps.store.setUnreadCount(uid, count, at);
  return count;
}

/** Nightly: deletes read rows older than 90 days (unread rows stay). Returns rows deleted. */
export async function pruneReadNotifications(deps: NotifyDeps): Promise<number> {
  const cutoff = new Date(deps.clock.now().getTime() - NOTIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000);
  let total = 0;
  for (let page = 0; page < PRUNE_MAX_PAGES; page++) {
    const n = await deps.store.deleteReadBefore(cutoff, PRUNE_PAGE);
    total += n;
    if (n < PRUNE_PAGE) break;
  }
  return total;
}
