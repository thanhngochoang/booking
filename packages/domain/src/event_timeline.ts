import { DomainError } from './errors.js';
import { TIMELINE_OPEN_DAYS, isEventManager, type EventCaller, type EventRecord } from './event.js';
import { hashtagKeyOf } from './event_hashtag.js';
import type {
  SharedPost,
  TimelineDeps,
  TimelineRow,
  TimelineSource,
  TimelineStatus,
  TimelineTx,
} from './event_timeline_ports.js';
import { isId } from './ids.js';

export type { TimelineStatus } from './event_timeline_ports.js';

const DAY_MS = 86_400_000;
export const SHARE_IMAGES_MAX = 10;
export const SHARE_CAPTION_MAX = 2000;
const TAG = /(?<![\p{L}\p{N}_/&#])#([\p{L}\p{N}_]+)/gu;

export interface TimelineAuthor {
  readonly isPhotographer: boolean;
  readonly hasPaidTicket: boolean;
  readonly isManager: boolean;
}

/** Photographers, managers and paid attendees post visible; everyone else waits for approval. */
export function timelineStatusFor(a: TimelineAuthor): TimelineStatus {
  return a.isPhotographer || a.hasPaidTicket || a.isManager ? 'visible' : 'pending';
}

/** Not a draft or a cancelled event (M4), and not later than 30 days after the event completed. */
export function timelineOpen(e: Pick<EventRecord, 'status' | 'completedAt'>, now: Date): boolean {
  if (e.status === 'draft' || e.status === 'cancelled') return false;
  if (e.completedAt === null) return true;
  return now.getTime() <= e.completedAt.getTime() + TIMELINE_OPEN_DAYS * DAY_MS;
}

/** Lower case, unique, in order, 2–40 characters, at most 30 (same rule as the app). */
export function extractHashtags(caption: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const m of caption.matchAll(TAG)) {
    const tag = (m[1] ?? '').toLowerCase();
    if (tag.length < 2 || tag.length > 40 || seen.has(tag)) continue;
    seen.add(tag);
    out.push(tag);
    if (out.length === 30) break;
  }
  return out;
}

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

const isHostOf = (e: EventRecord, uid: string): boolean => e.host.id === uid || e.createdBy === uid;

/**
 * Links a new post to the timelines it names: each hashtag → `event_hashtags` → event, plus the event
 * the post names itself (`eventId`). Idempotent: a post that already has its row there is skipped.
 */
export async function linkEventPosts(deps: TimelineDeps, postId: string): Promise<{ linked: string[] }> {
  const post = await deps.timeline.getPost(postId);
  if (post === null) return { linked: [] };
  const keys = [...new Set(post.hashtags.map(hashtagKeyOf))];
  if (keys.length === 0 && post.eventId === null) return { linked: [] };
  const author = await deps.people.author(post.authorId);

  return deps.timeline.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const targets = new Map<string, TimelineSource>();
    for (const key of keys) {
      const owner = await tx.hashtagOwner(key);
      if (owner !== null) targets.set(owner, 'hashtag');
    }
    if (post.eventId !== null) targets.set(post.eventId, 'explicit');

    const plans: Array<{ ev: EventRecord; row: TimelineRow }> = [];
    for (const [eventId, source] of targets) {
      const ev = await tx.getEvent(eventId);
      if (ev === null || !timelineOpen(ev, now)) continue;
      if ((await tx.getRow(eventId, postId)) !== null) continue;
      const host = isHostOf(ev, post.authorId);
      const isPhotographer = author?.isPhotographer === true;
      const paid = isPhotographer || host ? false : await tx.hasPaidTicket(eventId, post.authorId);
      const status = timelineStatusFor({ isPhotographer, hasPaidTicket: paid, isManager: host });
      plans.push({
        ev,
        row: {
          postId,
          source,
          status,
          authorId: post.authorId,
          authorName: author?.name ?? 'Người dùng',
          isHost: host,
          imageUrl: post.imageUrls[0] ?? '',
          imageW: post.imageW,
          imageH: post.imageH,
          imageCount: post.imageUrls.length,
          addedAt: now,
          moderatedBy: null,
        },
      });
    }

    for (const { ev, row } of plans) {
      tx.putRow(ev.id, row);
      if (row.status === 'visible') tx.setPostCount(ev.id, ev.postCount + 1);
    }
    return { linked: plans.map((p) => p.ev.id) };
  });
}

interface ShareImage {
  readonly url: string;
  readonly path: string;
  readonly w: number | null;
  readonly h: number | null;
  readonly blurHash: string | null;
}

function parseImages(raw: unknown, uid: string, postId: string, deps: TimelineDeps): ShareImage[] {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > SHARE_IMAGES_MAX) throw new DomainError('invalid_argument');
  const dim = (v: unknown): number | null => (typeof v === 'number' && Number.isInteger(v) && v > 0 && v <= 20000 ? v : null);
  return raw.map((item): ShareImage => {
    const r = obj(item);
    if (typeof r.url !== 'string' || typeof r.path !== 'string') throw new DomainError('invalid_argument');
    if (!deps.media.isOwnPostImage(r.url, r.path, uid, postId)) throw new DomainError('invalid_argument');
    return {
      url: r.url,
      path: r.path,
      w: dim(r.w),
      h: dim(r.h),
      blurHash: typeof r.blurHash === 'string' && r.blurHash.length <= 64 ? r.blurHash : null,
    };
  });
}

/**
 * A paid attendee (or a manager) shares photos to an event: the post (`event_share`) and its timeline
 * row are written together. The caption gets the event hashtag when it lacks it.
 */
export async function shareEventPost(
  deps: TimelineDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ postId: string }> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const postId = idOf(r.postId);
  const images = parseImages(r.images, caller.uid, postId, deps);
  if (r.caption !== undefined && typeof r.caption !== 'string') throw new DomainError('invalid_argument');
  const typed = (typeof r.caption === 'string' ? r.caption : '').normalize('NFC').trim();
  if (typed.length > SHARE_CAPTION_MAX) throw new DomainError('invalid_argument');
  const author = await deps.people.author(caller.uid);

  return deps.timeline.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const ev = await tx.getEvent(eventId);
    if (ev === null || ev.status === 'draft') throw new DomainError('not_found');
    const manager = isEventManager(ev, caller);
    const paid = manager ? false : await tx.hasPaidTicket(eventId, caller.uid);
    if (!manager && !paid) throw new DomainError('permission_denied');
    const existing = await tx.getPost(postId);
    if (existing !== null) {
      if (existing.authorId !== caller.uid || existing.eventId !== eventId) throw new DomainError('conflict');
      return { postId }; // a retried call
    }
    if (!timelineOpen(ev, now)) throw new DomainError('not_eligible');

    const hasTag = extractHashtags(typed).includes(ev.hashtagKey);
    const caption = hasTag ? typed : `${typed}${typed === '' ? '' : ' '}#${ev.hashtag}`;
    if (caption.length > SHARE_CAPTION_MAX) throw new DomainError('invalid_argument');
    const post: SharedPost = {
      id: postId,
      authorId: caller.uid,
      eventId,
      imageUrls: images.map((i) => i.url),
      imageMeta: images.map((i) => ({ w: i.w, h: i.h, blurHash: i.blurHash })),
      caption,
      hashtags: extractHashtags(caption),
      createdAt: now,
    };
    const status = timelineStatusFor({
      isPhotographer: false, hasPaidTicket: paid, isManager: manager,
    });
    tx.createPost(post);
    tx.putRow(eventId, {
      postId,
      source: 'explicit',
      status,
      authorId: caller.uid,
      authorName: author?.name ?? 'Người dùng',
      isHost: manager,
      imageUrl: images[0]?.url ?? '',
      imageW: images[0]?.w ?? null,
      imageH: images[0]?.h ?? null,
      imageCount: images.length,
      addedAt: now,
      moderatedBy: null,
    });
    if (status === 'visible') tx.setPostCount(eventId, ev.postCount + 1);
    return { postId };
  });
}

const ACTIONS = ['hide', 'show', 'approve'] as const;
type ModerateAction = (typeof ACTIONS)[number];

/** Managers hide, show or approve a row; `postCount` follows the visible rows. Repeating an action is a no-op. */
export async function moderateEventTimeline(deps: TimelineDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const r = obj(raw);
  const eventId = idOf(r.eventId);
  const postId = idOf(r.postId);
  const action = ACTIONS.find((a) => a === r.action);
  if (action === undefined) throw new DomainError('invalid_argument');

  await deps.timeline.runTransaction(async (tx: TimelineTx) => {
    const ev = await tx.getEvent(eventId);
    if (ev === null || ev.status === 'draft') throw new DomainError('not_found');
    if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
    const row = await tx.getRow(eventId, postId);
    if (row === null) throw new DomainError('not_found');
    const next = nextStatus(action, row.status);
    if (next === row.status) return;
    tx.putRow(eventId, { ...row, status: next, moderatedBy: caller.uid });
    const delta = (next === 'visible' ? 1 : 0) - (row.status === 'visible' ? 1 : 0);
    tx.setPostCount(eventId, Math.max(0, ev.postCount + delta));
  });
}

function nextStatus(action: ModerateAction, current: TimelineStatus): TimelineStatus {
  if (action === 'hide') return 'hidden';
  if (action === 'approve') {
    if (current === 'hidden') throw new DomainError('conflict');
    return 'visible';
  }
  if (current === 'pending') throw new DomainError('conflict'); // a pending post is approved, not shown
  return 'visible';
}
