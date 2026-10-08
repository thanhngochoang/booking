/**
 * Badge catalogue and the pure rules over metrics (plan 10a Decisions 14, 15; spec §3d.2).
 * The catalogue is a constant here and is synced to `badges/{id}`; the evaluator never reads it from storage.
 */

export const BADGE_METRICS = [
  'tomatoPct',
  'reviewCount',
  'punctualMentions',
  'detailedReviews',
  'accountAgeDays',
  'workPosts',
  'activeServices',
  'responseMinutes',
  'completedShoots',
  'hostedEvents',
  'customerShoots',
  'realShootPosts',
] as const;
export type BadgeMetric = (typeof BADGE_METRICS)[number];

export interface BadgeRule {
  readonly metric: BadgeMetric;
  readonly op: '>=' | '<=';
  readonly threshold: number;
  /** Anti-inflation guard: this must hold as well (always `>=`). */
  readonly minSample?: { readonly metric: BadgeMetric; readonly threshold: number };
}

export interface BadgeDefinition {
  readonly id: string;
  readonly name: string;
  readonly shortName: string | null;
  /** The locked condition; also the earned text unless a snapshot says more. */
  readonly description: string;
  readonly icon: string;
  readonly source: 'review' | 'system';
  readonly audience: 'photographer' | 'customer' | 'both';
  readonly order: number;
  readonly rule: BadgeRule;
  readonly progress: 'none' | 'metric' | 'minSample';
  readonly revocable: boolean;
  readonly hiddenWhenLocked: boolean;
}

const def = (
  id: string,
  order: number,
  d: Omit<BadgeDefinition, 'id' | 'order' | 'shortName' | 'hiddenWhenLocked'> &
    Partial<Pick<BadgeDefinition, 'shortName' | 'hiddenWhenLocked'>>,
): BadgeDefinition => ({ id, order, shortName: null, hiddenWhenLocked: false, ...d });

const shoots = (n: number, order: number, shortName: string): BadgeDefinition =>
  def(`shoots_${n}`, order, {
    name: `${shortName.replace(' buổi', '')} buổi chụp`,
    shortName,
    description: `Hoàn thành ${n} buổi chụp`,
    icon: 'photo_camera',
    source: 'system',
    audience: 'photographer',
    rule: { metric: 'completedShoots', op: '>=', threshold: n },
    progress: 'metric',
    revocable: false,
  });

export const BADGE_CATALOG: readonly BadgeDefinition[] = [
  def('top_rated', 10, {
    name: 'Được đánh giá cao',
    description: 'Từ 95% cà chua với ít nhất 20 đánh giá',
    icon: 'favorite',
    source: 'review',
    audience: 'photographer',
    rule: { metric: 'tomatoPct', op: '>=', threshold: 95, minSample: { metric: 'reviewCount', threshold: 20 } },
    progress: 'minSample',
    revocable: true,
  }),
  def('punctual', 20, {
    name: 'Khen đúng giờ',
    description: '5 đánh giá khen đúng giờ',
    icon: 'schedule',
    source: 'review',
    audience: 'photographer',
    rule: { metric: 'punctualMentions', op: '>=', threshold: 5 },
    progress: 'metric',
    revocable: false,
  }),
  def('detailed_reviewer', 30, {
    name: 'Nhận xét chi tiết',
    description: 'Viết 5 nhận xét dài',
    icon: 'check',
    source: 'review',
    audience: 'customer',
    rule: { metric: 'detailedReviews', op: '>=', threshold: 5 },
    progress: 'metric',
    revocable: false,
  }),
  def('new_member', 40, {
    name: 'Thành viên mới',
    description: '30 ngày đầu trên app',
    icon: 'celebration',
    source: 'system',
    audience: 'both',
    rule: { metric: 'accountAgeDays', op: '<=', threshold: 30 },
    progress: 'none',
    revocable: true,
    hiddenWhenLocked: true,
  }),
  def('complete_profile', 50, {
    name: 'Hồ sơ đầy đủ',
    description: 'Đủ ảnh và gói',
    icon: 'person',
    source: 'system',
    audience: 'photographer',
    rule: { metric: 'workPosts', op: '>=', threshold: 6, minSample: { metric: 'activeServices', threshold: 1 } },
    progress: 'metric',
    revocable: false,
  }),
  def('fast_reply', 60, {
    name: 'Phản hồi nhanh',
    description: 'Trả lời trong 1 giờ',
    icon: 'chat_bubble',
    source: 'system',
    audience: 'photographer',
    rule: { metric: 'responseMinutes', op: '<=', threshold: 60 },
    progress: 'none',
    revocable: true,
  }),
  shoots(10, 70, '10 buổi'),
  shoots(50, 80, '50 buổi'),
  shoots(100, 90, '100+ buổi'),
  def('event_host', 100, {
    name: 'Chủ sự kiện',
    description: 'Tổ chức 1 sự kiện',
    icon: 'calendar_today',
    source: 'system',
    audience: 'photographer',
    rule: { metric: 'hostedEvents', op: '>=', threshold: 1 },
    progress: 'metric',
    revocable: false,
  }),
  def('loyal_customer', 110, {
    name: 'Khách thân thiết',
    description: 'Hoàn thành 3 buổi chụp',
    icon: 'favorite',
    source: 'system',
    audience: 'customer',
    rule: { metric: 'customerShoots', op: '>=', threshold: 3 },
    progress: 'metric',
    revocable: false,
  }),
  def('sharer', 120, {
    name: 'Người chia sẻ',
    description: 'Chia sẻ 5 bài Buổi chụp thật',
    icon: 'ios_share',
    source: 'system',
    audience: 'customer',
    rule: { metric: 'realShootPosts', op: '>=', threshold: 5 },
    progress: 'metric',
    revocable: false,
  }),
];

/** Unknown (null or absent) metric = rule not met. */
export type Metrics = Partial<Record<BadgeMetric, number | null>>;

const value = (m: Metrics, metric: BadgeMetric): number | null => {
  const v = m[metric];
  return typeof v === 'number' && Number.isFinite(v) ? v : null;
};

export function meets(rule: BadgeRule, m: Metrics): boolean {
  const v = value(m, rule.metric);
  if (v === null) return false;
  if (!(rule.op === '>=' ? v >= rule.threshold : v <= rule.threshold)) return false;
  if (rule.minSample) {
    const s = value(m, rule.minSample.metric);
    if (s === null || s < rule.minSample.threshold) return false;
  }
  return true;
}

/** Progress toward a locked badge; `current` is capped at `target`. */
export function progressOf(b: BadgeDefinition, m: Metrics): { current: number; target: number } | null {
  if (b.progress === 'none') return null;
  const [metric, target] =
    b.progress === 'minSample' && b.rule.minSample
      ? [b.rule.minSample.metric, b.rule.minSample.threshold]
      : [b.rule.metric, b.rule.threshold];
  const raw = value(m, metric) ?? 0;
  return { current: Math.max(0, Math.min(raw, target)), target };
}

/** Text frozen on the earned badge at award time ("97% cà chua từ 58 đánh giá", "Hoàn thành 112 buổi"). */
export function snapshotText(b: BadgeDefinition, m: Metrics): string {
  if (b.id === 'top_rated') {
    const pct = value(m, 'tomatoPct');
    const count = value(m, 'reviewCount');
    if (pct !== null && count !== null) return `${Math.round(pct)}% cà chua từ ${count} đánh giá`;
  }
  if (b.id.startsWith('shoots_')) {
    const n = value(m, 'completedShoots');
    if (n !== null) return `Hoàn thành ${n} buổi`;
  }
  return b.description;
}

/** Customers see customer and shared badges; photographers also the photographer ones. */
export function eligibleBadges(isPhotographer: boolean): readonly BadgeDefinition[] {
  return BADGE_CATALOG.filter((b) => b.audience !== 'photographer' || isPhotographer);
}

export interface BadgePlan {
  readonly award: readonly BadgeDefinition[];
  readonly revoke: readonly string[];
  readonly progress: Readonly<Record<string, { current: number; target: number }>>;
}

export function planBadges(
  eligible: readonly BadgeDefinition[],
  m: Metrics,
  earned: ReadonlySet<string>,
): BadgePlan {
  const award: BadgeDefinition[] = [];
  const revoke: string[] = [];
  const progress: Record<string, { current: number; target: number }> = {};
  for (const b of eligible) {
    const met = meets(b.rule, m);
    let isEarned = earned.has(b.id);
    if (!isEarned && met) {
      award.push(b);
      isEarned = true;
    } else if (isEarned && !met && b.revocable) {
      revoke.push(b.id);
      isEarned = false;
    }
    if (!isEarned) {
      const p = progressOf(b, m);
      if (p) progress[b.id] = p;
    }
  }
  return { award, revoke, progress };
}
