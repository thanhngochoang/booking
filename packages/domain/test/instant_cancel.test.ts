import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import type { InstantRequest, InstantStatus } from '../src/instant.js';
import { quoteInstantCancel, quoteInstantNoShow, type InstantCancelQuote } from '../src/instant_cancel.js';
import { MIN, SEC, T0, aConfig, aRequest, at } from './support/instant_fixtures.js';

const isCode = (code: string) => (e: unknown): boolean => e instanceof DomainError && e.code === code;

/** Paid at T0 (#202's state; #140 never has `paidAt`). */
const paid = (overrides: Partial<InstantRequest> = {}): InstantRequest =>
  aRequest({ committedAt: T0, paidAt: T0, paymentId: 'pay_01', ...overrides });

/** Assigned at T0 with an initial ETA of 6 min: free cancel until T0 + 2:00, late after T0 + 21:00. */
const assignedFields = (status: InstantStatus): Partial<InstantRequest> => ({
  status,
  photographerId: 'p1',
  etaMinutes: 6,
  assignedAt: T0,
  freeCancelUntil: at(2 * MIN),
  lateDeadlineAt: at(21 * MIN),
  startedRouteAt: status === 'assigned' ? null : at(MIN),
  arrivedAt: status === 'arrived' ? at(15 * MIN) : null,
});

const quote = (rule: InstantCancelQuote['rule'], refundPercent: number, refundVnd: number, feeVnd: number, amountVnd = 690_000): InstantCancelQuote =>
  ({ rule, refundPercent, refundVnd, feeVnd, amountVnd });

describe('quoteInstantCancel (Decision 9)', () => {
  it('unpaid: a customer cancel before payment moves no money', () => {
    assert.deepEqual(quoteInstantCancel(aRequest(), 'customer', T0), quote('unpaid', 0, 0, 0, 0));
  });

  it('full_refund in choosing, pending_payment (paid), searching and no_match', () => {
    for (const status of ['choosing', 'pending_payment', 'searching', 'no_match'] as const) {
      assert.deepEqual(quoteInstantCancel(paid({ status }), 'customer', at(5 * MIN)), quote('full_refund', 100, 690_000, 0), status);
    }
  });

  it('free_window at assignedAt + 1:59', () => {
    for (const status of ['assigned', 'en_route'] as const) {
      assert.deepEqual(quoteInstantCancel(paid(assignedFields(status)), 'customer', at(MIN + 59 * SEC)), quote('free_window', 100, 690_000, 0));
    }
  });

  it('en_route at assignedAt + 2:01 → 80/20 of 690000 = 552000/138000', () => {
    for (const status of ['assigned', 'en_route'] as const) {
      assert.deepEqual(quoteInstantCancel(paid(assignedFields(status)), 'customer', at(2 * MIN + SEC)), quote('en_route', 80, 552_000, 138_000));
    }
    // The free window is open until, not at, freeCancelUntil.
    assert.equal(quoteInstantCancel(paid(assignedFields('en_route')), 'customer', at(2 * MIN)).rule, 'en_route');
  });

  it('photographer_late after lateDeadlineAt', () => {
    for (const status of ['assigned', 'en_route'] as const) {
      assert.deepEqual(quoteInstantCancel(paid(assignedFields(status)), 'customer', at(21 * MIN + SEC)), quote('photographer_late', 100, 690_000, 0));
    }
    assert.equal(quoteInstantCancel(paid(assignedFields('en_route')), 'customer', at(21 * MIN)).rule, 'en_route');
  });

  it('arrived with the request split 50 → 345000/345000 of 690000', () => {
    assert.deepEqual(quoteInstantCancel(paid(assignedFields('arrived')), 'customer', at(16 * MIN)), quote('arrived', 50, 345_000, 345_000));
    // Arrived counts even past the late deadline: the photographer is there.
    assert.equal(quoteInstantCancel(paid(assignedFields('arrived')), 'customer', at(40 * MIN)).rule, 'arrived');
  });

  it('arrived with the request split 30 → refund 483000 / fee 207000', () => {
    const r = paid({ ...assignedFields('arrived'), arrivedCancelPhotographerPercent: 30 });
    assert.deepEqual(quoteInstantCancel(r, 'customer', at(16 * MIN)), quote('arrived', 70, 483_000, 207_000));
  });

  it('the arrived split comes from the request snapshot, not the current config', () => {
    const current = aConfig({ instantArrivedCancelPhotographerPercent: 50 });
    const r = paid({ ...assignedFields('arrived'), arrivedCancelPhotographerPercent: 30 });
    assert.equal(current.instantArrivedCancelPhotographerPercent, 50);
    assert.equal(quoteInstantCancel(r, 'customer', at(16 * MIN)).refundPercent, 70);
    assert.equal(quoteInstantCancel({ ...r, arrivedCancelPhotographerPercent: 0 }, 'customer', at(16 * MIN)).refundPercent, 100);
    assert.equal(quoteInstantCancel({ ...r, arrivedCancelPhotographerPercent: 100 }, 'customer', at(16 * MIN)).refundVnd, 0);
  });

  it('photographer_cancel: the customer gets 100%', () => {
    for (const status of ['assigned', 'en_route', 'arrived'] as const) {
      assert.deepEqual(quoteInstantCancel(paid(assignedFields(status)), 'photographer', at(10 * MIN)), quote('photographer_cancel', 100, 690_000, 0), status);
    }
  });

  it('an unpaid request gives rule unpaid with zero refund, fee and amount in every status', () => {
    const statuses = ['choosing', 'pending_payment', 'searching', 'no_match', 'assigned', 'en_route', 'arrived'] as const;
    for (const status of statuses) {
      const r = aRequest({ committedAt: T0, ...(status === 'choosing' || status === 'pending_payment' || status === 'searching' || status === 'no_match' ? { status } : assignedFields(status)) });
      for (const now of [at(MIN), at(5 * MIN), at(30 * MIN)]) {
        assert.deepEqual(quoteInstantCancel(r, 'customer', now), quote('unpaid', 0, 0, 0, 0), `${status} customer`);
        if (status === 'assigned' || status === 'en_route' || status === 'arrived') {
          assert.deepEqual(quoteInstantCancel(r, 'photographer', now), quote('unpaid', 0, 0, 0, 0), `${status} photographer`);
        }
      }
    }
  });

  it('in_progress, finished and terminal refuse with conflict', () => {
    for (const status of ['in_progress', 'finished', 'completed', 'abandoned', 'cancelled_by_customer', 'no_show_customer'] as const) {
      for (const by of ['customer', 'photographer'] as const) {
        assert.throws(() => quoteInstantCancel(paid(assignedFields(status)), by, at(10 * MIN)), isCode('conflict'), `${status} ${by}`);
        assert.throws(() => quoteInstantCancel(aRequest(assignedFields(status)), by, at(10 * MIN)), isCode('conflict'), `${status} ${by} unpaid`);
      }
    }
  });

  it('photographer cannot cancel before assignment (conflict)', () => {
    for (const status of ['choosing', 'pending_payment', 'searching', 'no_match'] as const) {
      assert.throws(() => quoteInstantCancel(paid({ status }), 'photographer', T0), isCode('conflict'), status);
      assert.throws(() => quoteInstantCancel(aRequest({ status }), 'photographer', T0), isCode('conflict'), status);
    }
  });
});

describe('quoteInstantNoShow', () => {
  it('no_show 50 once the photographer waited 15 minutes', () => {
    const r = paid(assignedFields('arrived')); // arrived at T0 + 15:00
    assert.deepEqual(quoteInstantNoShow(r, at(30 * MIN)), quote('no_show', 50, 345_000, 345_000));
    // Unpaid (#140): the rule is recorded, no money moves.
    assert.deepEqual(quoteInstantNoShow(aRequest(assignedFields('arrived')), at(30 * MIN)), quote('no_show', 50, 0, 0, 0));
  });

  it('quoteInstantNoShow refuses before arrivedAt + 15 min with deadline_passed', () => {
    const r = paid(assignedFields('arrived'));
    assert.throws(() => quoteInstantNoShow(r, at(30 * MIN - 1)), isCode('deadline_passed'));
    for (const status of ['assigned', 'en_route', 'in_progress', 'choosing'] as const) {
      assert.throws(() => quoteInstantNoShow(paid(assignedFields(status)), at(40 * MIN)), isCode('conflict'), status);
    }
  });
});

/** mulberry32: a small seeded PRNG so the property run is the same every time. */
function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

describe('cancellation money', () => {
  it('refundVnd + feeVnd == amountVnd for 1.000 random amounts (1.000–20.000.000) and every rule', () => {
    const next = prng(140);
    const seen = new Set<string>();
    for (let i = 0; i < 1000; i++) {
      const amountVnd = 1000 + Math.floor(next() * (20_000_000 - 1000 + 1));
      const split = Math.floor(next() * 101);
      const base = { amountVnd, arrivedCancelPhotographerPercent: split };
      const quotes: InstantCancelQuote[] = [
        quoteInstantCancel(aRequest(base), 'customer', T0),
        quoteInstantCancel(paid({ ...base, status: 'searching' }), 'customer', T0),
        quoteInstantCancel(paid({ ...base, ...assignedFields('assigned') }), 'customer', at(MIN)),
        quoteInstantCancel(paid({ ...base, ...assignedFields('en_route') }), 'customer', at(5 * MIN)),
        quoteInstantCancel(paid({ ...base, ...assignedFields('en_route') }), 'customer', at(25 * MIN)),
        quoteInstantCancel(paid({ ...base, ...assignedFields('arrived') }), 'customer', at(20 * MIN)),
        quoteInstantCancel(paid({ ...base, ...assignedFields('en_route') }), 'photographer', at(5 * MIN)),
        quoteInstantNoShow(paid({ ...base, ...assignedFields('arrived') }), at(30 * MIN)),
      ];
      for (const q of quotes) {
        seen.add(q.rule);
        assert.equal(q.refundVnd + q.feeVnd, q.amountVnd, `${q.rule} ${amountVnd}`);
        assert.ok(Number.isInteger(q.refundVnd) && q.refundVnd >= 0 && q.feeVnd >= 0);
        assert.equal(q.refundVnd, Math.floor((q.amountVnd * q.refundPercent) / 100));
        assert.equal(q.amountVnd, q.rule === 'unpaid' ? 0 : amountVnd);
      }
    }
    assert.deepEqual([...seen].sort(), ['arrived', 'en_route', 'free_window', 'full_refund', 'no_show', 'photographer_cancel', 'photographer_late', 'unpaid']);
  });
});
