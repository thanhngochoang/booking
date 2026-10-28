import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { InstantCandidate, InstantOfferRow, InstantRequest, InstantStatus } from '../src/instant.js';
import { nextDeadlineOf, settleInstant } from '../src/instant_settle.js';
import { HOUR, MIN, SEC, T0, aRequest, at } from './support/instant_fixtures.js';

function row(offerId: string, photographerId: string, expiresAt: Date, outcome: InstantOfferRow['outcome'] = 'pending'): InstantOfferRow {
  return { offerId, photographerId, name: photographerId, avatarUrl: null, tomatoPct: 0, reviewCount: 0, etaMinutes: 6, outcome, expiresAt };
}

const candidate = (photographerId: string): InstantCandidate => ({
  photographerId, name: photographerId, avatarUrl: null, verified: true, providerType: 'individual', tomatoPct: 0,
  reviewCount: 0, completedCount: 0, distanceKm: 1, etaMinutes: 5, photos: [], reasons: [], tier: 'priority', score: 0.5,
});

/** A committed request searching since T0: offers to p1 (60 s) and p2 (90 s). */
function searching(overrides: Partial<InstantRequest> = {}): InstantRequest {
  return aRequest({
    status: 'searching',
    committedAt: T0,
    searchDeadlineAt: at(10 * MIN),
    candidates: [candidate('p1'), candidate('p2'), candidate('p3')],
    offers: [row('o1', 'p1', at(60 * SEC)), row('o2', 'p2', at(90 * SEC))],
    invitedTotal: 2,
    roundsWithInvites: 1,
    ...overrides,
  });
}

describe('settleInstant', () => {
  it('a pending offer past expiresAt becomes expired and its photographer is excluded', () => {
    const out = settleInstant(searching(), at(61 * SEC));
    assert.equal(out.changed, true);
    assert.equal(out.request.status, 'searching');
    assert.deepEqual(out.request.offers.map((o) => o.outcome), ['expired', 'pending']);
    assert.deepEqual(out.request.excludedIds, ['p1']);
    assert.deepEqual(out.expired.map((o) => o.offerId), ['o1']);
    assert.deepEqual(out.withdrawn, []);
    assert.equal(out.ended, false);
    assert.equal(out.request.version, 2);
    assert.deepEqual(out.request.updatedAt, at(61 * SEC));
    assert.deepEqual(out.request.nextDeadlineAt, at(90 * SEC));
  });

  it('the last pending offer expiring ends the round: choosing, roundEnded, no candidates', () => {
    const out = settleInstant(searching({ excludedIds: ['p1'] }), at(91 * SEC));
    assert.equal(out.request.status, 'choosing');
    assert.equal(out.request.roundEnded, true);
    assert.deepEqual(out.request.candidates, []);
    assert.deepEqual(out.request.offers.map((o) => o.outcome), ['expired', 'expired']);
    assert.deepEqual(out.request.excludedIds, ['p1', 'p2']);
    assert.deepEqual(out.expired.map((o) => o.offerId), ['o1', 'o2']);
    assert.equal(out.ended, false);
    // The search window keeps running for the next round.
    assert.deepEqual(out.request.nextDeadlineAt, at(10 * MIN));
  });

  it('a searching request with offers but none pending is rebuilt as an ended round (self-healing), once', () => {
    const stuck = searching({ offers: [row('o1', 'p1', at(60 * SEC), 'declined'), row('o2', 'p2', at(90 * SEC), 'withdrawn')] });
    const out = settleInstant(stuck, at(10 * SEC));
    assert.equal(out.changed, true);
    assert.deepEqual([out.request.status, out.request.roundEnded, out.request.candidates], ['choosing', true, []]);
    assert.deepEqual(out.expired, []);
    assert.deepEqual(out.request.nextDeadlineAt, at(10 * MIN));
    const again = settleInstant(out.request, at(10 * SEC));
    assert.equal(again.changed, false);
    assert.equal(again.request, out.request);
  });

  it('an offer still pending keeps searching', () => {
    const r = searching();
    const out = settleInstant(r, at(30 * SEC));
    assert.equal(out.changed, false);
    assert.equal(out.request, r);
    assert.deepEqual(out.expired, []);
  });

  it('committed request past searchDeadlineAt becomes no_match and pending offers are withdrawn', () => {
    const late = at(10 * MIN + 30 * SEC);
    const r = searching({ offers: [row('o1', 'p1', late), row('o2', 'p2', at(90 * SEC), 'declined')] });
    const out = settleInstant(r, at(10 * MIN));
    assert.equal(out.request.status, 'no_match');
    assert.equal(out.request.roundEnded, false);
    assert.deepEqual(out.request.candidates, []);
    assert.deepEqual(out.request.offers.map((o) => o.outcome), ['withdrawn', 'declined']);
    assert.deepEqual(out.withdrawn.map((o) => o.offerId), ['o1']);
    assert.deepEqual(out.expired, []);

    const choosing = settleInstant(aRequest({ committedAt: T0, searchDeadlineAt: at(10 * MIN), roundEnded: true }), at(10 * MIN));
    assert.equal(choosing.request.status, 'no_match');
  });

  it('no_match is not ended and has no refund fields', () => {
    const out = settleInstant(searching(), at(11 * MIN));
    assert.equal(out.request.status, 'no_match');
    assert.equal(out.ended, false);
    assert.equal(out.request.active, true);
    assert.equal(out.request.refundId, null);
    assert.equal(out.request.refundStatus, null);
    assert.equal(out.request.refundPercent, null);
    assert.equal(out.request.feeVnd, null);
    assert.equal(out.request.cancelRule, null);
    assert.equal(out.request.nextDeadlineAt, null);
  });

  it('pending_payment past paymentDeadlineAt returns to choosing and clears pendingInviteIds', () => {
    const r = aRequest({
      status: 'pending_payment',
      pendingInviteIds: ['p1', 'p2'],
      paymentDeadlineAt: at(15 * MIN),
      lastActivityAt: at(10 * MIN),
    });
    const out = settleInstant(r, at(15 * MIN));
    assert.equal(out.request.status, 'choosing');
    assert.deepEqual(out.request.pendingInviteIds, []);
    assert.equal(out.ended, false);
    assert.deepEqual(out.request.nextDeadlineAt, at(40 * MIN));
  });

  it('uncommitted choosing idle for 30 minutes becomes abandoned (inactive)', () => {
    const r = aRequest({ candidates: [candidate('p1')], lastActivityAt: T0 });
    assert.equal(settleInstant(r, at(30 * MIN - 1)).changed, false);
    const out = settleInstant(r, at(30 * MIN));
    assert.equal(out.request.status, 'abandoned');
    assert.equal(out.request.active, false);
    assert.equal(out.ended, true);
    assert.deepEqual(out.request.candidates, []);
    assert.deepEqual(out.request.offers, []);
    assert.equal(out.request.nextDeadlineAt, null);
  });

  it('committed choosing idle for 30 minutes is not abandoned', () => {
    const r = aRequest({ committedAt: T0, searchDeadlineAt: at(40 * MIN), roundEnded: true, lastActivityAt: T0 });
    const out = settleInstant(r, at(30 * MIN));
    assert.equal(out.changed, false);
    assert.equal(out.request.status, 'choosing');
  });

  it('in_progress past shootEndsAt becomes finished at shootEndsAt', () => {
    const r = aRequest({ status: 'in_progress', committedAt: T0, photographerId: 'p1', startedAt: T0, shootEndsAt: at(60 * MIN) });
    assert.equal(settleInstant(r, at(59 * MIN)).changed, false);
    const out = settleInstant(r, at(65 * MIN));
    assert.equal(out.request.status, 'finished');
    assert.deepEqual(out.request.finishedAt, at(60 * MIN));
    assert.equal(out.ended, false);
    assert.deepEqual(out.request.nextDeadlineAt, at(3 * HOUR));
  });

  it('finished 2 h later becomes completed (ended) with completedAt = finishedAt + 2 h', () => {
    const r = aRequest({ status: 'finished', committedAt: T0, photographerId: 'p1', finishedAt: T0 });
    assert.equal(settleInstant(r, at(2 * HOUR - 1)).changed, false);
    const out = settleInstant(r, at(5 * HOUR));
    assert.equal(out.request.status, 'completed');
    assert.equal(out.request.active, false);
    assert.equal(out.ended, true);
    assert.deepEqual(out.request.completedAt, at(2 * HOUR));
    // A shoot whose time ran out long ago finishes and completes in one call.
    const both = settleInstant({ ...r, status: 'in_progress', finishedAt: null, shootEndsAt: T0 }, at(5 * HOUR));
    assert.equal(both.request.status, 'completed');
    assert.deepEqual(both.request.completedAt, at(2 * HOUR));
  });

  it('settling twice changes nothing the second time', () => {
    const cases: readonly [InstantRequest, Date][] = [
      [searching(), at(61 * SEC)],
      [searching(), at(91 * SEC)],
      [searching(), at(11 * MIN)],
      [aRequest(), at(31 * MIN)],
      [aRequest({ status: 'finished', committedAt: T0, finishedAt: T0 }), at(3 * HOUR)],
    ];
    for (const [r, now] of cases) {
      const first = settleInstant(r, now);
      assert.equal(first.changed, true);
      const second = settleInstant(first.request, now);
      assert.equal(second.changed, false);
      assert.equal(second.request, first.request);
      assert.deepEqual(second.expired, []);
      assert.deepEqual(second.withdrawn, []);
    }
  });

  it('a terminal request is returned as is', () => {
    const r = aRequest({ status: 'completed', active: false });
    const out = settleInstant(r, at(10 * HOUR));
    assert.equal(out.request, r);
    assert.equal(out.changed, false);
    assert.equal(out.ended, false);
  });
});

describe('nextDeadlineOf', () => {
  const committed = { committedAt: T0, searchDeadlineAt: at(10 * MIN) };
  const cases: readonly [string, Partial<InstantRequest>, Date | null][] = [
    ['choosing uncommitted: abandon after 30 min idle', { lastActivityAt: at(5 * MIN) }, at(35 * MIN)],
    ['choosing committed: the search window', { ...committed, roundEnded: true }, at(10 * MIN)],
    ['pending_payment: the payment window when earlier', { status: 'pending_payment', paymentDeadlineAt: at(15 * MIN), lastActivityAt: at(10 * MIN) }, at(15 * MIN)],
    // #202 (ledger of #140): never abandoned while the payment window is open; its end settles first.
    ['pending_payment: the payment window even when the abandon time is earlier', { status: 'pending_payment', paymentDeadlineAt: at(15 * MIN), lastActivityAt: at(-20 * MIN) }, at(15 * MIN)],
    ['searching: the first pending offer expiry', { ...committed, status: 'searching', offers: [row('o1', 'p1', at(60 * SEC), 'declined'), row('o2', 'p2', at(90 * SEC)), row('o3', 'p3', at(75 * SEC))] }, at(75 * SEC)],
    ['searching: the search window when earlier', { ...committed, status: 'searching', offers: [row('o1', 'p1', at(11 * MIN))] }, at(10 * MIN)],
    ['assigned: no timer', { ...committed, status: 'assigned', photographerId: 'p1', freeCancelUntil: at(2 * MIN), lateDeadlineAt: at(25 * MIN) }, null],
    ['en_route: no timer', { ...committed, status: 'en_route', photographerId: 'p1', lateDeadlineAt: at(25 * MIN) }, null],
    ['arrived: no timer (the no-show wait is checked on demand)', { ...committed, status: 'arrived', arrivedAt: T0 }, null],
    ['in_progress: the end of the shoot', { ...committed, status: 'in_progress', shootEndsAt: at(HOUR) }, at(HOUR)],
    ['finished: auto-complete 2 h later', { ...committed, status: 'finished', finishedAt: at(HOUR) }, at(3 * HOUR)],
    ['no_match: none (money stays held, no refund timer)', { ...committed, status: 'no_match' }, null],
  ];
  for (const [name, overrides, expected] of cases) {
    it(name, () => assert.deepEqual(nextDeadlineOf(aRequest(overrides)), expected));
  }

  it('null for every terminal status', () => {
    for (const status of ['completed', 'abandoned', 'cancelled_by_customer', 'no_show_customer'] as InstantStatus[]) {
      assert.equal(nextDeadlineOf(aRequest({ status, active: false, committedAt: T0, searchDeadlineAt: at(MIN) })), null);
    }
  });

  it('refund fields never set a deadline', () => {
    const r = aRequest({ ...committed, status: 'no_match', refundId: 'rf1', refundStatus: 'pending' });
    assert.equal(nextDeadlineOf(r), null);
  });
});

describe('pending_payment and the abandon timer (#202)', () => {
  it('pending_payment is not abandoned while the payment window is open', () => {
    const r = aRequest({
      status: 'pending_payment', lastActivityAt: at(-20 * MIN), paymentDeadlineAt: at(15 * MIN), paymentId: 'pay_1',
      pendingInviteIds: ['p1'],
    });
    assert.deepEqual(nextDeadlineOf(r), at(15 * MIN));
    const open = settleInstant(r, at(10 * MIN));
    assert.equal(open.changed, false);
    assert.equal(open.request.status, 'pending_payment');
    // Once the window closes the request is back to choosing, idle for 35 minutes: abandoned.
    const closed = settleInstant(r, at(15 * MIN));
    assert.equal(closed.request.status, 'abandoned');
  });
});
