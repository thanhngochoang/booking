import type { NotificationCategory, NotificationTab, NotificationType } from './notification.js';
import type { NotificationContent } from './notification_render.js';
import type { Clock } from './ports.js';

export interface NotificationActor {
  readonly id: string;
  readonly name: string;
  readonly avatarUrl: string | null;
}

/** `users/{uid}/notifications/{id}`. Only the server writes it; the client sets `readAt`. */
export interface NotificationRow {
  readonly id: string;
  readonly userId: string;
  readonly type: NotificationType;
  readonly tab: NotificationTab;
  readonly category: NotificationCategory;
  readonly title: string;
  readonly body: string;
  readonly target: string;
  readonly groupKey: string | null;
  readonly actors: readonly NotificationActor[];
  readonly count: number;
  readonly thumbUrl: string | null;
  readonly lastEventId: string | null;
  readonly createdAt: Date;
  readonly readAt: Date | null;
}

export interface NotificationTx {
  getRow(uid: string, id: string): Promise<NotificationRow | null>;
  putRow(r: NotificationRow): void;
}

export interface NotificationStore {
  runTransaction<T>(fn: (tx: NotificationTx) => Promise<T>): Promise<T>;
  /** Raw prefs document (`users/{uid}/private/notificationPrefs`) or null. */
  getPrefs(uid: string): Promise<unknown>;
  listUnreadIds(uid: string, limit: number): Promise<string[]>;
  markRead(uid: string, ids: readonly string[], at: Date): Promise<void>;
  countUnread(uid: string): Promise<number>;
  /**
   * Writes the private inbox doc `users/{uid}/private/inbox` (`unreadCount`, `unreadCountAt`; ruling R1,
   * never the public user doc) only when `at` is not older than the stored `unreadCountAt`. True when written.
   */
  setUnreadCount(uid: string, count: number, at: Date): Promise<boolean>;
  /**
   * Deletes up to `limit` read rows created before `cutoff` (all users) and returns how many went (ruling R2).
   * Unread rows are never touched.
   */
  deleteReadBefore(cutoff: Date, limit: number): Promise<number>;
}

export interface PushMessage {
  readonly title: string;
  readonly body: string;
  readonly channel: 'default' | 'quiet';
  readonly data: { readonly type: string; readonly target: string; readonly notificationId?: string };
}

/** The adapter finds the user's devices and prunes dead tokens. */
export interface PushSender {
  send(uid: string, msg: PushMessage): Promise<void>;
}

export interface UserDirectory {
  get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>;
}

export interface NotifyDeps {
  readonly store: NotificationStore;
  readonly push: PushSender;
  readonly users: UserDirectory;
  readonly clock: Clock;
  /** Push failures are swallowed (the row stays); this reports them. */
  readonly onPushError?: (uid: string, error: unknown) => void;
}

export interface NotifyRequest {
  readonly userId: string;
  readonly content: NotificationContent;
  readonly target: string;
  /** Ignored for grouped requests. */
  readonly dedupeKey: string;
  readonly groupKey?: string;
  readonly eventId?: string;
  readonly actor?: NotificationActor;
  readonly thumbUrl?: string | null;
  readonly reminder?: 'h24' | 'h2';
}
