import type { EventRecord } from './event.js';
import type {
  SharedPost,
  TimelinePost,
  TimelineRow,
  TimelineStore,
  TimelineTx,
} from './event_timeline_ports.js';

export class MemoryEventTimelineStore implements TimelineStore {
  readonly events = new Map<string, EventRecord>();
  readonly hashtags = new Map<string, string>();
  readonly posts = new Map<string, TimelinePost>();
  readonly sharedPosts = new Map<string, SharedPost>();
  readonly rows = new Map<string, TimelineRow>(); // `${eventId}/${postId}`
  /** `${eventId}/${uid}` of the users holding a paid registration. */
  readonly paid = new Set<string>();
  /** Committed write count. */
  writes = 0;

  private lock: Promise<void> = Promise.resolve();

  seedEvent(e: EventRecord): void {
    this.events.set(e.id, e);
    if (e.hashtagKey !== '') this.hashtags.set(e.hashtagKey, e.id);
  }

  seedPost(p: TimelinePost): void {
    this.posts.set(p.id, p);
  }

  seedPaid(eventId: string, uid: string): void {
    this.paid.add(`${eventId}/${uid}`);
  }

  rowsOf(eventId: string): TimelineRow[] {
    return [...this.rows.entries()].filter(([k]) => k.startsWith(`${eventId}/`)).map(([, v]) => v);
  }

  async getPost(postId: string): Promise<TimelinePost | null> {
    return this.postById(postId);
  }

  private postById(postId: string): TimelinePost | null {
    const seeded = this.posts.get(postId);
    if (seeded !== undefined) return seeded;
    const s = this.sharedPosts.get(postId);
    if (s === undefined) return null;
    return {
      id: s.id,
      authorId: s.authorId,
      kind: 'event_share',
      hashtags: s.hashtags,
      eventId: s.eventId,
      imageUrls: s.imageUrls,
      imageW: s.imageMeta[0]?.w ?? null,
      imageH: s.imageMeta[0]?.h ?? null,
    };
  }

  async runTransaction<T>(fn: (tx: TimelineTx) => Promise<T>): Promise<T> {
    const run = this.lock.then(async () => {
      const staged: Array<() => void> = [];
      let hasWritten = false;
      const read = (name: string): void => {
        if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
      };
      const write = (apply: () => void): void => {
        hasWritten = true;
        staged.push(() => {
          apply();
          this.writes += 1;
        });
      };
      const tx: TimelineTx = {
        getEvent: async (id) => {
          read('getEvent');
          return this.events.get(id) ?? null;
        },
        hashtagOwner: async (key) => {
          read('hashtagOwner');
          return this.hashtags.get(key) ?? null;
        },
        getRow: async (eventId, postId) => {
          read('getRow');
          return this.rows.get(`${eventId}/${postId}`) ?? null;
        },
        hasPaidTicket: async (eventId, uid) => {
          read('hasPaidTicket');
          return this.paid.has(`${eventId}/${uid}`);
        },
        getPost: async (postId) => {
          read('getPost');
          return this.postById(postId);
        },
        putRow: (eventId, row) => write(() => { this.rows.set(`${eventId}/${row.postId}`, row); }),
        setPostCount: (eventId, count) =>
          write(() => {
            const ev = this.events.get(eventId);
            if (ev !== undefined) this.events.set(eventId, { ...ev, postCount: count });
          }),
        createPost: (post) => write(() => { this.sharedPosts.set(post.id, post); }),
      };
      const result = await fn(tx);
      for (const apply of staged) apply();
      return result;
    });
    this.lock = run.then(() => undefined, () => undefined);
    return run;
  }
}
