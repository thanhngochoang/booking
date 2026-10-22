/**
 * Cancellation and no-show money of Chụp ngay (spec §4, mock S13.08, plan Decision 9). A quote is
 * what S13.08 shows (dry run) and what the real cancel records. While a request is unpaid
 * (`paidAt === null`, every #140 request) no money moves: the amounts are 0.
 */
import { computeRefund } from './booking_policy.js';
import { DomainError } from './errors.js';
import { INSTANT, type InstantRequest } from './instant.js';

export type InstantCancelRule =
  | 'unpaid' | 'full_refund' | 'free_window' | 'photographer_late' | 'en_route' | 'arrived' | 'photographer_cancel' | 'no_show';

export interface InstantCancelQuote {
  readonly rule: InstantCancelRule;
  /** 0..100: the customer's share. */
  readonly refundPercent: number;
  readonly refundVnd: number;
  /** What the photographer keeps (`amountVnd − refundVnd`). */
  readonly feeVnd: number;
  /** The money collected: `amountVnd` once paid, 0 before. */
  readonly amountVnd: number;
}

function quote(r: InstantRequest, rule: InstantCancelRule, refundPercent: number): InstantCancelQuote {
  const amountVnd = r.paidAt === null ? 0 : r.amountVnd;
  const refundVnd = computeRefund(amountVnd, refundPercent);
  return { rule, refundPercent, refundVnd, feeVnd: amountVnd - refundVnd, amountVnd };
}

const UNPAID: InstantCancelQuote = { rule: 'unpaid', refundPercent: 0, refundVnd: 0, feeVnd: 0, amountVnd: 0 };

const before = (now: Date, d: Date | null): boolean => d !== null && now.getTime() < d.getTime();
const after = (now: Date, d: Date | null): boolean => d !== null && now.getTime() > d.getTime();

/**
 * The cancel the caller may make now. Customer: until `in_progress`. Photographer: only once
 * assigned and before the shoot starts. Anything else is `conflict` (a dispute is S18).
 * `arrived`: refundPercent = 100 − r.arrivedCancelPhotographerPercent (the request's snapshot of the config).
 */
export function quoteInstantCancel(r: InstantRequest, by: 'customer' | 'photographer', now: Date): InstantCancelQuote {
  const s = r.status;
  if (by === 'photographer') {
    if (s !== 'assigned' && s !== 'en_route' && s !== 'arrived') throw new DomainError('conflict');
    return r.paidAt === null ? UNPAID : quote(r, 'photographer_cancel', 100);
  }
  switch (s) {
    case 'choosing':
    case 'pending_payment':
    case 'searching':
    case 'no_match':
      return r.paidAt === null ? UNPAID : quote(r, 'full_refund', 100);
    case 'assigned':
    case 'en_route':
      if (r.paidAt === null) return UNPAID;
      if (before(now, r.freeCancelUntil)) return quote(r, 'free_window', 100);
      if (after(now, r.lateDeadlineAt)) return quote(r, 'photographer_late', 100);
      return quote(r, 'en_route', 80);
    case 'arrived':
      return r.paidAt === null ? UNPAID : quote(r, 'arrived', 100 - r.arrivedCancelPhotographerPercent);
    default:
      throw new DomainError('conflict');
  }
}

/**
 * The photographer reports the customer absent: only `arrived`, after waiting 15 minutes
 * (`deadline_passed` before), 50/50. Unpaid: the rule is recorded with no money.
 */
export function quoteInstantNoShow(r: InstantRequest, now: Date): InstantCancelQuote {
  if (r.status !== 'arrived' || r.arrivedAt === null) throw new DomainError('conflict');
  if (now.getTime() < r.arrivedAt.getTime() + INSTANT.NO_SHOW_WAIT_MIN * 60_000) throw new DomainError('deadline_passed');
  return quote(r, 'no_show', 50);
}
