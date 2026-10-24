import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { disputeWindow, outcomeAmounts, parseOpenDisputeInput } from '../src/dispute.js';
import { DomainError } from '../src/errors.js';
import { bookingView, hoursFrom, NOW, openInput, ticketView } from './support/dispute_world.js';

const fails = (fn: () => unknown, code: string): void =>
  assert.throws(fn, (e: unknown) => e instanceof DomainError && e.code === code);

const paths = (n: number): string[] => Array.from({ length: n }, (_, i) => `disputeEvidence/c1/d1/f${i}.jpg`);

describe('parseOpenDisputeInput', () => {
  it('parseOpenDisputeInput accepts a booking dispute with 0–5 evidence paths', () => {
    const none = parseOpenDisputeInput(openInput({ evidencePaths: [] }), 'c1');
    assert.deepEqual(none, {
      disputeId: 'd1',
      subjectType: 'booking',
      subjectId: 'b1',
      eventId: null,
      reason: 'not_as_agreed',
      description: 'Thợ đến muộn hai tiếng và thiếu ảnh',
      evidencePaths: [],
    });
    assert.deepEqual(parseOpenDisputeInput(openInput({ evidencePaths: undefined }), 'c1').evidencePaths, []);
    assert.deepEqual(parseOpenDisputeInput(openInput({ evidencePaths: paths(5) }), 'c1').evidencePaths, paths(5));
    const ticket = parseOpenDisputeInput(
      openInput({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', reason: 'event_not_held' }),
      'c1',
    );
    assert.equal(ticket.eventId, 'e1');
  });

  it('refuses a reason that does not belong to the subject', () => {
    fails(() => parseOpenDisputeInput(openInput({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', reason: 'no_show' }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ reason: 'event_not_held' }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ reason: 'bad' }), 'c1'), 'invalid_argument');
  });

  it('refuses a description under 10 or over 1000 graphemes after trim', () => {
    fails(() => parseOpenDisputeInput(openInput({ description: '   123456789   ' }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ description: 'ả'.repeat(1001) }), 'c1'), 'invalid_argument');
    assert.equal(parseOpenDisputeInput(openInput({ description: ' 1234567890 ' }), 'c1').description, '1234567890');
    assert.equal(parseOpenDisputeInput(openInput({ description: 'ả'.repeat(1000) }), 'c1').description.length, 1000);
  });

  it('refuses 6 evidence paths and a path under another uid or another dispute id', () => {
    fails(() => parseOpenDisputeInput(openInput({ evidencePaths: paths(6) }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ evidencePaths: ['disputeEvidence/c2/d1/f1.jpg'] }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ evidencePaths: ['disputeEvidence/c1/d2/f1.jpg'] }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ evidencePaths: ['disputeEvidence/c1/d1/f1.png'] }), 'c1'), 'invalid_argument');
    fails(() => parseOpenDisputeInput(openInput({ evidencePaths: ['disputeEvidence/c1/d1/../f1.jpg'] }), 'c1'), 'invalid_argument');
  });
});

describe('disputeWindow', () => {
  it('disputeWindow: shot booking closes 24 h after shotAt with milestone shoot', () => {
    const w = disputeWindow(bookingView({ state: 'shot', shotAt: hoursFrom(-2) }), NOW, true);
    assert.deepEqual(w, { closesAt: hoursFrom(22), milestone: 'shoot' });
  });

  it('approved booking closes at checkUntil with milestone delivery', () => {
    const w = disputeWindow(bookingView({ state: 'approved', shotAt: hoursFrom(-72), checkUntil: hoursFrom(5) }), NOW, true);
    assert.deepEqual(w, { closesAt: hoursFrom(5), milestone: 'delivery' });
  });

  it('completed booking with milestones → not_eligible (nothing held)', () => {
    fails(() => disputeWindow(bookingView({ state: 'completed', windowStart: hoursFrom(-1) }), NOW, true), 'not_eligible');
  });

  it('legacy completed booking (no milestones) closes 24 h after completedAt', () => {
    const w = disputeWindow(bookingView({ state: 'completed', windowStart: hoursFrom(-2) }), NOW, false);
    assert.deepEqual(w, { closesAt: hoursFrom(22), milestone: null });
    const reviewed = disputeWindow(bookingView({ state: 'reviewed', windowStart: hoursFrom(-2) }), NOW, false);
    assert.deepEqual(reviewed, { closesAt: hoursFrom(22), milestone: null });
    fails(() => disputeWindow(bookingView({ state: 'completed', windowStart: hoursFrom(-25) }), NOW, false), 'deadline_passed');
  });

  it('upcoming booking is not_eligible', () => {
    fails(() => disputeWindow(bookingView({ state: 'upcoming' }), NOW, false), 'not_eligible');
    fails(() => disputeWindow(bookingView({ state: 'shot', shotAt: null }), NOW, true), 'not_eligible');
  });

  it('at the closing instant exactly → deadline_passed', () => {
    fails(() => disputeWindow(bookingView({ state: 'shot', shotAt: hoursFrom(-24) }), NOW, true), 'deadline_passed');
    fails(() => disputeWindow(bookingView({ state: 'approved', checkUntil: NOW }), NOW, true), 'deadline_passed');
    fails(() => disputeWindow(ticketView({ windowStart: hoursFrom(-24) }), NOW, false), 'deadline_passed');
  });

  it('paid ticket opens at endAt and closes 24 h later; before endAt → not_eligible', () => {
    assert.deepEqual(disputeWindow(ticketView({ windowStart: NOW }), NOW, false), { closesAt: hoursFrom(24), milestone: null });
    fails(() => disputeWindow(ticketView({ windowStart: hoursFrom(1) }), NOW, false), 'not_eligible');
    fails(() => disputeWindow(ticketView({ state: 'cancelled' }), NOW, false), 'not_eligible');
  });

  it('free ticket → not_eligible', () => {
    fails(() => disputeWindow(ticketView({ amount: 0, paymentId: null }), NOW, false), 'not_eligible');
  });
});

describe('outcomeAmounts', () => {
  it('outcomeAmounts: release 0/held, refund held/0, split 40% of 1 500 000 → 600 000 / 900 000, split 33% of 1 000 001 floors the refund', () => {
    assert.deepEqual(outcomeAmounts(500_000, 'release'), { refundPercent: 0, refundAmount: 0, releaseAmount: 500_000 });
    assert.deepEqual(outcomeAmounts(500_000, 'refund'), { refundPercent: 100, refundAmount: 500_000, releaseAmount: 0 });
    assert.deepEqual(outcomeAmounts(1_500_000, 'split', 40), { refundPercent: 40, refundAmount: 600_000, releaseAmount: 900_000 });
    assert.deepEqual(outcomeAmounts(1_000_001, 'split', 33), { refundPercent: 33, refundAmount: 330_000, releaseAmount: 670_001 });
  });

  it('split 0 or 100 or 12.5 → invalid_argument', () => {
    fails(() => outcomeAmounts(1_000_000, 'split', 0), 'invalid_argument');
    fails(() => outcomeAmounts(1_000_000, 'split', 100), 'invalid_argument');
    fails(() => outcomeAmounts(1_000_000, 'split', 12.5), 'invalid_argument');
    fails(() => outcomeAmounts(1_000_000, 'split'), 'invalid_argument');
    fails(() => outcomeAmounts(1_000_000, 'release', 10), 'invalid_argument');
    fails(() => outcomeAmounts(1_000_000, 'refund', 50), 'invalid_argument');
  });
});
