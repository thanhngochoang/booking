import { Timestamp, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  type BadgeDefinition,
  type BadgeMetric,
  type BadgeMetricsReader,
  type BadgeStore,
  type BadgeTx,
  type EarnedBadge,
  type Metrics,
} from '@photobooking/domain';

const DAY_MS = 86_400_000;

/** `badges/{id}` fields: the catalogue minus the rule internals. */
export function catalogDoc(d: BadgeDefinition): Record<string, unknown> {
  return {
    name: d.name,
    shortName: d.shortName,
    description: d.description,
    icon: d.icon,
    source: d.source,
    audience: d.audience,
    order: d.order,
    hiddenWhenLocked: d.hiddenWhenLocked,
    progress: d.progress,
  };
}

const sameDoc = (a: Record<string, unknown> | undefined, b: Record<string, unknown>): boolean =>
  a !== undefined && Object.keys(b).every((k) => a[k] === b[k]) && Object.keys(a).length === Object.keys(b).length;

const asDate = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null);

export class FirestoreBadgeStore implements BadgeStore {
  constructor(private readonly db: Firestore) {}

  async runTransaction<T>(fn: (tx: BadgeTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx: Transaction) => {
      const earned = (uid: string) => this.db.collection('users').doc(uid).collection('badges');
      const tx: BadgeTx = {
        listEarned: async (uid) => {
          const snap = await fTx.get(earned(uid));
          const out: EarnedBadge[] = [];
          for (const d of snap.docs) {
            const data = d.data();
            const text: unknown = data.snapshot?.text;
            out.push({ badgeId: d.id, awardedAt: asDate(data.awardedAt) ?? new Date(0), snapshotText: typeof text === 'string' ? text : '' });
          }
          return out;
        },
        putEarned: (uid, b) => {
          fTx.set(earned(uid).doc(b.badgeId), {
            badgeId: b.badgeId,
            uid,
            awardedAt: Timestamp.fromDate(b.awardedAt),
            snapshot: { text: b.snapshotText },
          });
        },
        deleteEarned: (uid, badgeId) => {
          fTx.delete(earned(uid).doc(badgeId));
        },
        setProgress: (uid, p, at) => {
          fTx.set(this.db.collection('users').doc(uid).collection('private').doc('badgeProgress'), {
            entries: p,
            updatedAt: Timestamp.fromDate(at),
          });
        },
      };
      return fn(tx);
    });
  }

  /**
   * Holders ordered by uid after the cursor. The collection-group query orders by `uid` (index
   * `badges (badgeId, uid)`); the age filter runs in memory, so a page may hold fewer matches and
   * the scan continues until `limit` matches or the end.
   */
  async holdersOlderThan(badgeId: string, cutoff: Date, limit: number, after: string | null = null): Promise<string[]> {
    const out: string[] = [];
    let cursor = after;
    const page = Math.max(limit, 50);
    for (let guard = 0; guard < 200 && out.length < limit; guard++) {
      let q = this.db.collectionGroup('badges').where('badgeId', '==', badgeId).orderBy('uid');
      if (cursor !== null) q = q.startAfter(cursor);
      const snap = await q.limit(page).get();
      for (const d of snap.docs) {
        cursor = String(d.data().uid ?? '');
        const at = asDate(d.data().awardedAt);
        if (at !== null && at.getTime() < cutoff.getTime() && cursor !== '' && out.length < limit) out.push(cursor);
      }
      if (snap.size < page) break;
    }
    return out;
  }

  async syncCatalog(defs: readonly BadgeDefinition[]): Promise<number> {
    if (defs.length === 0) return 0;
    const refs = defs.map((d) => this.db.collection('badges').doc(d.id));
    const snaps = await this.db.getAll(...refs);
    const batch = this.db.batch();
    let n = 0;
    defs.forEach((d, i) => {
      const want = catalogDoc(d);
      if (!sameDoc(snaps[i]?.data(), want)) {
        batch.set(refs[i] as (typeof refs)[number], want);
        n += 1;
      }
    });
    if (n > 0) await batch.commit();
    return n;
  }
}

const GROUP_STATS: readonly BadgeMetric[] = ['tomatoPct', 'reviewCount', 'responseMinutes', 'punctualMentions'];
const DETAILED_MIN_GRAPHEMES = 50;
const countGraphemes = (s: string): number =>
  Array.from(new Intl.Segmenter('vi', { granularity: 'grapheme' }).segment(s.trim())).length;

/** Reads only the metrics asked for (plan 10a Decision 15). */
export class FirestoreBadgeMetricsReader implements BadgeMetricsReader {
  constructor(
    private readonly db: Firestore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async isPhotographer(uid: string): Promise<boolean> {
    const user = await this.db.collection('users').doc(uid).get();
    if (user.data()?.role === 'photographer') return true;
    return (await this.db.collection('photographers').doc(uid).get()).exists;
  }

  async read(uid: string, metrics: ReadonlySet<BadgeMetric>): Promise<Metrics> {
    const m: Record<string, number | null> = {};
    const db = this.db;
    const jobs: Promise<void>[] = [];
    const count = (metric: BadgeMetric, q: { count(): { get(): Promise<{ data(): { count: number } }> } }) =>
      jobs.push(q.count().get().then((s) => { m[metric] = s.data().count; }));

    if (GROUP_STATS.some((k) => metrics.has(k))) {
      jobs.push(
        db.collection('photographers').doc(uid).get().then((snap) => {
          const raw: unknown = snap.data()?.stats;
          const s = typeof raw === 'object' && raw !== null ? (raw as Record<string, unknown>) : {};
          const num = (k: string): number | null => (typeof s[k] === 'number' && Number.isFinite(s[k]) ? (s[k] as number) : null);
          // A legacy star `rating` is ignored: no tomatoPct until the first verdict is counted.
          if (metrics.has('tomatoPct')) m.tomatoPct = num('tomatoPct');
          if (metrics.has('reviewCount')) m.reviewCount = num('reviewCount') ?? 0;
          if (metrics.has('responseMinutes')) m.responseMinutes = num('responseMinutes');
          if (metrics.has('punctualMentions')) m.punctualMentions = num('punctualMentions') ?? 0;
        }),
      );
    }
    if (metrics.has('detailedReviews')) {
      jobs.push(
        db.collection('reviews').where('customerId', '==', uid).limit(100).get().then((snap) => {
          m.detailedReviews = snap.docs.filter((d) => {
            const t: unknown = d.data().text;
            return typeof t === 'string' && countGraphemes(t) >= DETAILED_MIN_GRAPHEMES;
          }).length;
        }),
      );
    }
    if (metrics.has('accountAgeDays')) {
      jobs.push(
        db.collection('users').doc(uid).get().then((snap) => {
          const created = asDate(snap.data()?.createdAt);
          m.accountAgeDays = created === null ? null : Math.max(0, Math.floor((this.now().getTime() - created.getTime()) / DAY_MS));
        }),
      );
    }
    if (metrics.has('completedShoots')) {
      count('completedShoots', db.collection('bookings').where('photographerId', '==', uid).where('status', 'in', ['completed', 'reviewed']));
    }
    if (metrics.has('customerShoots')) {
      count('customerShoots', db.collection('bookings').where('customerId', '==', uid).where('status', 'in', ['completed', 'reviewed']));
    }
    if (metrics.has('workPosts')) {
      count('workPosts', db.collection('posts').where('photographerId', '==', uid).where('kind', '==', 'work'));
    }
    if (metrics.has('realShootPosts')) {
      count('realShootPosts', db.collection('posts').where('authorId', '==', uid).where('kind', '==', 'real_shoot'));
    }
    if (metrics.has('activeServices')) {
      count('activeServices', db.collection('photographers').doc(uid).collection('services').where('active', '==', true));
    }
    if (metrics.has('hostedEvents')) {
      count('hostedEvents', db.collection('events').where('host.id', '==', uid).where('status', '==', 'completed'));
    }
    await Promise.all(jobs);
    return m;
  }
}
