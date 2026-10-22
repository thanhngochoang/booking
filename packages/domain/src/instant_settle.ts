/**
 * Lazy timers of a Chụp ngay request (plan Decision 3): offer expiry (60 s), the payment window
 * (15 min, #202), the search window (10 min), abandon (30 min), the end of the shoot and
 * auto-complete (2 h). Every use case settles the request first, inside its transaction; apps
 * nudge with `tickInstantRequest`; the 15-minute clock step catches the rest through
 * `nextDeadlineAt`. No timer moves money here (refund re-sends are V2's).
 */
import { INSTANT, isInstantActive, type InstantOfferRow, type InstantRequest } from './instant.js';

export interface SettleOutcome {
  readonly request: InstantRequest;
  /** Offer rows that expired in this call (their offer docs and presences follow). */
  readonly expired: readonly InstantOfferRow[];
  /** Offer rows withdrawn by `no_match` in this call. */
  readonly withdrawn: readonly InstantOfferRow[];
  /** false → `request` is the input object itself; nothing to write. */
  readonly changed: boolean;
  /** The request left the active statuses in this call. */
  readonly ended: boolean;
}

const MINUTE = 60_000;
const HOUR = 3_600_000;

const union = (a: readonly string[], b: readonly string[]): string[] => [...new Set([...a, ...b])];

/** Applies every timer due at `now`, in an order that converges in one call. Idempotent. */
export function settleInstant(r: InstantRequest, now: Date): SettleOutcome {
  if (!isInstantActive(r.status)) return { request: r, expired: [], withdrawn: [], changed: false, ended: false };
  const t = now.getTime();
  let next = r;
  const expired: InstantOfferRow[] = [];
  let withdrawn: InstantOfferRow[] = [];
  if (next.status === 'searching') {
    const offers = next.offers.map((o) => {
      if (o.outcome !== 'pending' || o.expiresAt === null || o.expiresAt.getTime() > t) return o;
      expired.push(o);
      return { ...o, outcome: 'expired' as const };
    });
    if (expired.length > 0) {
      next = { ...next, offers, excludedIds: union(next.excludedIds, expired.map((o) => o.photographerId)) };
    }
    // Self-healing (Task 2 ruling): a searching round whose rows are all resolved ends here even when
    // nothing expired in this call (a write that resolved the last row without ending the round).
    if (next.offers.length > 0 && !next.offers.some((o) => o.outcome === 'pending')) {
      next = { ...next, status: 'choosing', roundEnded: true, candidates: [] };
    }
  }
  const committed = next.committedAt !== null; // offers sent at least once; from #202 on this implies paid
  if (committed && (next.status === 'choosing' || next.status === 'searching')
      && next.searchDeadlineAt !== null && next.searchDeadlineAt.getTime() <= t) {
    withdrawn = next.offers.filter((o) => o.outcome === 'pending');
    next = {
      ...next, status: 'no_match', roundEnded: false, candidates: [],
      offers: next.offers.map((o) => (o.outcome === 'pending' ? { ...o, outcome: 'withdrawn' as const } : o)),
    };
  }
  if (next.status === 'pending_payment' && next.paymentDeadlineAt !== null && next.paymentDeadlineAt.getTime() <= t) {
    next = { ...next, status: 'choosing', pendingInviteIds: [] };
  }
  if (!committed && (next.status === 'choosing' || next.status === 'pending_payment')
      && next.lastActivityAt.getTime() + INSTANT.ABANDON_AFTER_MIN * MINUTE <= t) {
    next = { ...next, status: 'abandoned', active: false, candidates: [], offers: [], pendingInviteIds: [] };
  }
  if (next.status === 'in_progress' && next.shootEndsAt !== null && next.shootEndsAt.getTime() <= t) {
    next = { ...next, status: 'finished', finishedAt: next.shootEndsAt };
  }
  if (next.status === 'finished' && next.finishedAt !== null
      && next.finishedAt.getTime() + INSTANT.AUTO_COMPLETE_H * HOUR <= t) {
    next = {
      ...next, status: 'completed', active: false,
      completedAt: new Date(next.finishedAt.getTime() + INSTANT.AUTO_COMPLETE_H * HOUR),
    };
  }
  const changed = next !== r;
  next = changed ? { ...next, nextDeadlineAt: nextDeadlineOf(next), updatedAt: now, version: r.version + 1 } : r;
  return { request: next, expired, withdrawn, changed, ended: changed && !next.active };
}

const earliest = (...ds: readonly (Date | null)[]): Date | null =>
  ds.reduce<Date | null>((min, d) => (d !== null && (min === null || d.getTime() < min.getTime()) ? d : min), null);

/**
 * The earliest moment `settleInstant` would change this request, or null. Only timers that
 * settle count, so the clock step never picks a request it cannot move: `assigned`, `en_route`,
 * `arrived` (late and no-show are checked when someone asks) and `no_match` (money stays held)
 * have none.
 */
export function nextDeadlineOf(r: InstantRequest): Date | null {
  if (!isInstantActive(r.status)) return null;
  const committed = r.committedAt !== null;
  const abandonAt = committed ? null : new Date(r.lastActivityAt.getTime() + INSTANT.ABANDON_AFTER_MIN * MINUTE);
  switch (r.status) {
    case 'choosing':
      return committed ? r.searchDeadlineAt : abandonAt;
    case 'pending_payment':
      return earliest(r.paymentDeadlineAt, abandonAt);
    case 'searching':
      return earliest(
        ...r.offers.filter((o) => o.outcome === 'pending').map((o) => o.expiresAt),
        committed ? r.searchDeadlineAt : null,
      );
    case 'in_progress':
      return r.shootEndsAt;
    case 'finished':
      return r.finishedAt === null ? null : new Date(r.finishedAt.getTime() + INSTANT.AUTO_COMPLETE_H * HOUR);
    default:
      return null;
  }
}
