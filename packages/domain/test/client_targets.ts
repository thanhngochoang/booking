// Test-only TypeScript port of the app's `safeTarget` (lib/features/notifications/notification_targets.dart;
// S17 plan, Decision 8 and the App contract): every target a hook writes must be one the app opens.
// The app's `switch (segments)` must accept exactly these patterns (S17 Task 4 mirrors this list).
//
// Pattern syntax: `:id` is one id-safe segment; a pattern with `?key=:id` (or `?key=value`) accepts
// exactly that one query parameter, and the same path without a query only when listed separately.

/** Every target pattern the app accepts. Keep it the one list both sides are compared with. */
export const CLIENT_TARGET_PATTERNS = [
  // Before S17 (plan 10a)
  '/bookings',
  '/notifications',
  '/me/awards',
  '/b/:id',
  '/chat/:id',
  '/u/:id/badges',
  '/u/:id',
  '/u/:id?tab=reviews',
  // Exist today (events)
  '/e/:id',
  '/events/:id/manage',
  // #134 earnings
  '/work/earnings',
  '/work/earnings/account',
  // #139 jobs
  '/jobs/:id',
  '/jobs/:id/applications',
  // #140 Chụp ngay
  '/instant/:id',
  '/work/instant',
  '/work/instant/:id',
  '/work/instant/offer/:id',
  // #130 / #152 delivery
  '/b/:id/delivery',
  // #136 studio
  '/studio/members',
  '/me/studio',
  // #135 verification
  '/verify/start',
  '/verify/business',
  // #142 disputes and support
  '/disputes/:id',
  '/help/chat',
  // #141 payments
  '/me/payments',
  // #151 recruiting and collaborators (the only id queries)
  '/recruit/:id',
  '/studio/recruit?post=:id',
  '/collab',
  '/collab?offer=:id',
  // #223 S30 organizers: S30.02, S30.03, S30.06 and the spot page S29.02
  '/organizer/spots/claim',
  '/organizer/spots/:id',
  '/organizer/gate-staff',
  '/spots/:id',
  // Final fix A-I3: a ticket's pass_ready and entry_day_closed open the buyer's tickets (S11.04)
  '/bookings?tab=events',
] as const;

const ID = /^[A-Za-z0-9_-]{1,128}$/;

function segmentsOf(path: string): string[] | null {
  try {
    return path.slice(1).split('/').map(decodeURIComponent);
  } catch {
    return null;
  }
}

const matchPart = (pattern: string, value: string): boolean => (pattern === ':id' ? ID.test(value) : pattern === value);

function matches(pattern: string, segments: readonly string[], query: readonly (readonly [string, string])[]): boolean {
  const [path = '', q] = pattern.split('?');
  const want = path.slice(1).split('/');
  if (want.length !== segments.length || !want.every((p, i) => matchPart(p, segments[i] ?? ''))) return false;
  if (q === undefined) return query.length === 0;
  const [key, value = ''] = q.split('=');
  const only = query.length === 1 ? query[0] : undefined;
  return only !== undefined && only[0] === key && matchPart(value, only[1]);
}

/** True when the app would open `raw` (same checks as `safeTarget`). */
export function isAllowedTarget(raw: string): boolean {
  const value = raw.trim();
  if (value.length === 0 || value.length > 200 || !value.startsWith('/') || value.startsWith('//')) return false;
  if (value.includes('#')) return false;
  const qIndex = value.indexOf('?');
  const path = qIndex < 0 ? value : value.slice(0, qIndex);
  const segments = segmentsOf(path);
  if (segments === null) return false;
  const query = qIndex < 0 ? [] : [...new URLSearchParams(value.slice(qIndex + 1)).entries()];
  return CLIENT_TARGET_PATTERNS.some((p) => matches(p, segments, query));
}
