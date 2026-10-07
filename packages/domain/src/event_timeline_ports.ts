import type { EventRecord } from './event.js';
import type { Clock } from './ports.js';

export type TimelineStatus = 'visible' | 'pending' | 'hidden';
export type TimelineSource = 'hashtag' | 'explicit';

/** The parts of `posts/{id}` the timeline reads. */
export interface TimelinePost {
  readonly id: string;
  readonly authorId: string;
  readonly kind: string;
  /** Lower case, no `#`. */
  readonly hashtags: readonly string[];
  readonly eventId: string | null;
  readonly imageUrls: readonly string[];
  readonly imageW: number | null;
  readonly imageH: number | null;
}

/** `events/{id}/timeline/{postId}` (the relational `event_posts`). */
export interface TimelineRow {
  readonly postId: string;
  readonly source: TimelineSource;
  readonly status: TimelineStatus;
  readonly authorId: string;
  readonly authorName: string;
  readonly isHost: boolean;
  readonly imageUrl: string;
  readonly imageW: number | null;
  readonly imageH: number | null;
  readonly imageCount: number;
  readonly addedAt: Date;
  readonly moderatedBy: string | null;
}

/** A post a customer shares to an event (`kind: 'event_share'`). */
export interface SharedPost {
  readonly id: string;
  readonly authorId: string;
  /** The host photographer, or '' for a platform event. */
  readonly photographerId: string;
  readonly eventId: string;
  readonly imageUrls: readonly string[];
  readonly imageMeta: ReadonlyArray<{ readonly w: number | null; readonly h: number | null; readonly blurHash: string | null }>;
  readonly caption: string;
  readonly hashtags: readonly string[];
  readonly createdAt: Date;
}

/** Every read must come before the first write (Firestore transactions; the memory store enforces it). */
export interface TimelineTx {
  getEvent(id: string): Promise<EventRecord | null>;
  /** `event_hashtags/{key}.eventId`. */
  hashtagOwner(key: string): Promise<string | null>;
  getRow(eventId: string, postId: string): Promise<TimelineRow | null>;
  /** A `paid` registration of the user for the event. */
  hasPaidTicket(eventId: string, uid: string): Promise<boolean>;
  getPost(postId: string): Promise<TimelinePost | null>;
  putRow(eventId: string, row: TimelineRow): void;
  /** `events/{id}.postCount` (visible rows). */
  setPostCount(eventId: string, count: number): void;
  createPost(post: SharedPost): void;
}

export interface TimelineStore {
  runTransaction<T>(fn: (tx: TimelineTx) => Promise<T>): Promise<T>;
  /** One document, outside a transaction. */
  getPost(postId: string): Promise<TimelinePost | null>;
}

export interface TimelinePeople {
  author(uid: string): Promise<{ name: string; isPhotographer: boolean } | null>;
}

export interface TimelineDeps {
  readonly timeline: TimelineStore;
  readonly people: TimelinePeople;
  readonly media: { isOwnPostImage(url: string, path: string, uid: string, postId: string): boolean };
  readonly clock: Clock;
}
