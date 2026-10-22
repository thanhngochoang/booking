/**
 * Plain readers of the Chụp ngay ports (plan #140 Task 4): the server config (cached 60 s), the
 * photographer's phone, the profile snapshot stored on presence, and today's availability day.
 */
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import {
  isVnE164,
  parseInstantConfig,
  providerTypeOf,
  type InstantConfig,
  type InstantConfigReader,
  type InstantDayReader,
  type InstantDayState,
  type InstantProfile,
  type InstantProfileReader,
  type PhotographerPhoneReader,
} from '@photobooking/domain';

export const INSTANT_CONFIG_PATH = 'instant_config/current';
export const INSTANT_CONFIG_TTL_MS = 60_000;

/**
 * `instant_config/current`, parsed by the domain (anything missing or out of range is `not_eligible`)
 * and kept in memory for 60 s per instance; a refused document is not cached.
 */
export class FirestoreInstantConfigReader implements InstantConfigReader {
  private cached: { readonly config: InstantConfig; readonly at: number } | null = null;

  constructor(
    private readonly firestore: Firestore,
    private readonly nowMs: () => number = Date.now,
    private readonly ttlMs = INSTANT_CONFIG_TTL_MS,
  ) {}

  async get(): Promise<InstantConfig> {
    const now = this.nowMs();
    if (this.cached !== null && now - this.cached.at < this.ttlMs) return this.cached.config;
    const snap = await this.firestore.doc(INSTANT_CONFIG_PATH).get();
    const config = parseInstantConfig(snap.exists ? snap.data() : undefined);
    this.cached = { config, at: now };
    return config;
  }
}

/** `photographers/{uid}/private/contact.phone` is a VN E.164 number. */
export class FirestorePhotographerPhoneReader implements PhotographerPhoneReader {
  constructor(private readonly firestore: Firestore) {}

  async hasPhone(uid: string): Promise<boolean> {
    const snap = await this.firestore.doc(`photographers/${uid}/private/contact`).get();
    return isVnE164(snap.data()?.phone);
  }
}

const PROFILE_POSTS = 6;
const PROFILE_PHOTOS = 3;

const num = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
const text = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

/** The first image of a post: `imageUrls[0]`, else `images[0]` (a URL or `{url}`). */
export function firstPostImage(d: DocumentData): string | null {
  if (Array.isArray(d.imageUrls)) return text(d.imageUrls[0]);
  if (Array.isArray(d.images)) {
    const first: unknown = d.images[0];
    return typeof first === 'string' ? text(first) : text((first as { url?: unknown } | undefined)?.url);
  }
  return null;
}

/**
 * The profile snapshot shown on candidate cards and offers: `users/{uid}` (`displayName`, `avatarUrl`),
 * `photographers/{uid}` (`verified`, `providerType`, `stats`, `specialties`) and the first image of the
 * first three `work` posts among the 6 latest. Null without a photographer profile.
 */
export function instantProfileOf(
  user: DocumentData | undefined,
  photographer: DocumentData | undefined,
  posts: readonly DocumentData[],
): InstantProfile | null {
  if (photographer === undefined) return null;
  const stats = (photographer.stats ?? {}) as Record<string, unknown>;
  const photos = posts
    .filter((p) => p.kind === 'work')
    .map(firstPostImage)
    .filter((u): u is string => u !== null)
    .slice(0, PROFILE_PHOTOS);
  return {
    name: text(user?.displayName) ?? text(photographer.displayName) ?? 'Nhiếp ảnh gia',
    avatarUrl: text(user?.avatarUrl),
    verified: photographer.verified === true,
    providerType: providerTypeOf(photographer.providerType),
    tomatoPct: num(stats.tomatoPct),
    score: num(stats.score),
    reviewCount: num(stats.reviewCount),
    completedCount: num(stats.completedCount),
    specialties: Array.isArray(photographer.specialties)
      ? photographer.specialties.filter((s: unknown): s is string => typeof s === 'string')
      : [],
    photos,
  };
}

export class FirestoreInstantProfileReader implements InstantProfileReader {
  constructor(private readonly firestore: Firestore) {}

  async snapshot(uid: string): Promise<InstantProfile | null> {
    const [docs, posts] = await Promise.all([
      this.firestore.getAll(this.firestore.doc(`users/${uid}`), this.firestore.doc(`photographers/${uid}`)),
      this.firestore.collection('posts').where('photographerId', '==', uid).orderBy('createdAt', 'desc').limit(PROFILE_POSTS).get(),
    ]);
    const [user, photographer] = docs;
    return instantProfileOf(
      user?.exists === true ? user.data() : undefined,
      photographer?.exists === true ? photographer.data() : undefined,
      posts.docs.map((p) => p.data()),
    );
  }
}

const DAY_STATES: readonly InstantDayState[] = ['off', 'booked', 'pending', 'spot', 'full'];
/** `getAll` takes many references; keep one call well inside request limits. */
const DAY_BATCH = 100;

/**
 * `availability/{uid}/days/{day}.state`. Calls made in the same tick (the domain asks for every
 * candidate at once with Promise.all) are read together with one `getAll` per day and 100 references.
 * An unknown state reads as no record.
 */
export class FirestoreInstantDayReader implements InstantDayReader {
  private pending = new Map<string, Array<{ uid: string; resolve: (s: InstantDayState | null) => void; reject: (e: unknown) => void }>>();
  private scheduled = false;

  constructor(private readonly firestore: Firestore) {}

  stateOf(uid: string, day: string): Promise<InstantDayState | null> {
    return new Promise((resolve, reject) => {
      const waiting = this.pending.get(day) ?? [];
      waiting.push({ uid, resolve, reject });
      this.pending.set(day, waiting);
      if (!this.scheduled) {
        this.scheduled = true;
        queueMicrotask(() => void this.flush());
      }
    });
  }

  private async flush(): Promise<void> {
    const batches = this.pending;
    this.pending = new Map();
    this.scheduled = false;
    for (const [day, waiting] of batches) {
      for (let i = 0; i < waiting.length; i += DAY_BATCH) {
        const part = waiting.slice(i, i + DAY_BATCH);
        try {
          const snaps = await this.firestore.getAll(...part.map((w) => this.firestore.doc(`availability/${w.uid}/days/${day}`)));
          part.forEach((w, j) => {
            const state: unknown = snaps[j]?.exists === true ? snaps[j]?.data()?.state : null;
            w.resolve(typeof state === 'string' && (DAY_STATES as readonly string[]).includes(state) ? (state as InstantDayState) : null);
          });
        } catch (e) {
          for (const w of part) w.reject(e);
        }
      }
    }
  }
}
