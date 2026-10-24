import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { Booking } from '../src/booking.js';
import {
  addUnpaidFlag,
  collaboratorContactOpen,
  confirmCollabPay,
  confirmedAssigneeId,
  isShootMilestoneReleased,
  offerExpiry,
  poachingSignal,
  reportCollabPaid,
  syncCollabJobOnBooking,
  type CollabJob,
} from '../src/collab_jobs.js';
import type { Payment } from '../src/escrow.js';
import { DomainError } from '../src/errors.js';
import { EMPTY_COUNTERS, isRecruitBlocked } from '../src/recruit.js';
import { createCollabWorld, type CollabWorld } from './support/collab_world.js';

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

async function code(p: Promise<unknown>): Promise<{ code: string; field: string | undefined }> {
  try {
    await p;
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return { code: e.code, field: e.field };
  }
  assert.fail('expected a DomainError');
}

/** An accepted job of `p1` for studio `s1` on booking `b1`, shot on 2026-10-15. */
function job(over: Partial<CollabJob> = {}): CollabJob {
  const at = new Date('2026-10-10T10:00:00.000Z');
  return {
    id: 'b1_p1',
    bookingId: 'b1',
    studioId: 's1',
    collaboratorId: 'p1',
    customerId: 'c1',
    studioName: 'Studio Mây',
    collaboratorName: 'Minh Trí',
    shoot: { day: '2026-10-15', start: '14:00', end: '16:00', serviceName: 'Gói Studio', placeName: 'Nhà thờ Lớn' },
    shootEndsAt: new Date('2026-10-15T09:00:00.000Z'),
    agreedFee: 800_000,
    offerStatus: 'accepted',
    offerAt: at,
    offerExpiresAt: new Date(at.getTime() + 6 * HOUR),
    acceptedAt: new Date(at.getTime() + HOUR),
    declinedAt: null,
    closedAt: null,
    payStatus: 'none',
    pay: {
      amount: 800_000,
      dueAt: null,
      paidOn: null,
      method: null,
      reportedAt: null,
      receivedAt: null,
      disputedAt: null,
      overdueFlaggedAt: null,
      disputeFlaggedAt: null,
    },
    createdAt: at,
    updatedAt: at,
    ...over,
  };
}

describe('offerExpiry (Decision 13)', () => {
  const deadline = new Date('2026-10-14T07:00:00.000Z');
  const start = new Date('2026-10-15T07:00:00.000Z');
  const cases: Array<[string, string, string | null]> = [
    ['now + 6 h before the deadline', '2026-10-10T10:00:00.000Z', '2026-10-10T16:00:00.000Z'],
    ['capped at assignDeadline', '2026-10-14T03:00:00.000Z', '2026-10-14T07:00:00.000Z'],
    ['exactly 15 minutes left is enough', '2026-10-14T06:45:00.000Z', '2026-10-14T07:00:00.000Z'],
    ['null when less than 15 minutes remain before the deadline', '2026-10-14T06:46:00.000Z', null],
    ['after the deadline: now + 6 h', '2026-10-14T08:00:00.000Z', '2026-10-14T14:00:00.000Z'],
    ['after the deadline: capped at startAt', '2026-10-15T03:00:00.000Z', '2026-10-15T07:00:00.000Z'],
    ['after the deadline: null when less than 15 minutes remain before the start', '2026-10-15T06:50:00.000Z', null],
  ];
  for (const [name, now, expected] of cases) {
    it(name, () => {
      const got = offerExpiry(new Date(now), deadline, start);
      assert.equal(got?.toISOString() ?? null, expected);
    });
  }
});

describe('confirmedAssigneeId', () => {
  it('a member counts as soon as assigned; a collaborator only once accepted', () => {
    assert.equal(confirmedAssigneeId({ assigneeId: 'm1', assigneeKind: 'member' }), 'm1');
    assert.equal(confirmedAssigneeId({ assigneeId: 'm1' }), 'm1');
    assert.equal(confirmedAssigneeId({ assigneeId: 'p1', assigneeKind: 'collaborator', assigneeAccepted: false }), null);
    assert.equal(confirmedAssigneeId({ assigneeId: 'p1', assigneeKind: 'collaborator' }), null);
    assert.equal(confirmedAssigneeId({ assigneeId: 'p1', assigneeKind: 'collaborator', assigneeAccepted: true }), 'p1');
    assert.equal(confirmedAssigneeId({ assigneeId: null }), null);
  });
});

describe('collaboratorContactOpen (R8)', () => {
  const now = new Date('2026-10-20T10:00:00.000Z');
  const base = { completedAt: null, cancelledAt: null };
  const ago = (ms: number) => new Date(now.getTime() - ms);
  const cases: Array<[string, Parameters<typeof collaboratorContactOpen>[0], boolean]> = [
    ['member: as S26 (accepted)', { ...base, assigneeKind: 'member', status: 'accepted' }, true],
    ['member: as S26 (completed 20 d ago, 30-day window)', { ...base, assigneeKind: 'member', status: 'completed', completedAt: ago(20 * DAY) }, true],
    ['collaborator not accepted', { ...base, assigneeKind: 'collaborator', assigneeAccepted: false, status: 'accepted' }, false],
    ['collaborator accepted, booking requested', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'requested' }, true],
    ['collaborator accepted, booking accepted', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'accepted' }, true],
    ['collaborator accepted, booking upcoming', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'upcoming' }, true],
    ['collaborator accepted, booking shot', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'shot' }, true],
    ['collaborator accepted, booking approved', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'approved' }, true],
    ['completed 6 d 23 h ago', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'completed', completedAt: ago(7 * DAY - HOUR) }, true],
    ['completed 7 d ago', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'completed', completedAt: ago(7 * DAY) }, false],
    ['reviewed 7 d ago', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'reviewed', completedAt: ago(8 * DAY) }, false],
    ['completed without a completion time', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'completed' }, false],
    ['cancelled 6 d ago', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'cancelled', cancelledAt: ago(6 * DAY) }, true],
    ['cancelled 7 d ago', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'cancelled', cancelledAt: ago(7 * DAY) }, false],
    ['draft', { ...base, assigneeKind: 'collaborator', assigneeAccepted: true, status: 'draft' }, false],
  ];
  for (const [name, b, expected] of cases) {
    it(name, () => assert.equal(collaboratorContactOpen(b, now), expected));
  }
});

describe('unpaid flags (Decision 15)', () => {
  const now = new Date('2026-10-20T10:00:00.000Z');

  it('addUnpaidFlag prunes flags older than 90 d and blocks for 30 d at the third', () => {
    const old = new Date(now.getTime() - 91 * DAY);
    const recent = new Date(now.getTime() - 10 * DAY);
    const one = addUnpaidFlag({ ...EMPTY_COUNTERS, unpaidFlags: [old, recent] }, now);
    assert.deepEqual(one.unpaidFlags, [recent, now]);
    assert.equal(one.recruitBlockedUntil, null);
    const later = new Date(now.getTime() + HOUR);
    const three = addUnpaidFlag(one, later);
    assert.deepEqual(three.unpaidFlags, [recent, now, later]);
    assert.deepEqual(three.recruitBlockedUntil, new Date(later.getTime() + 30 * DAY));
  });

  it('a later block never shortens an earlier one', () => {
    const until = new Date(now.getTime() + 40 * DAY);
    const flags = [new Date(now.getTime() - DAY), new Date(now.getTime() - HOUR)];
    const c = addUnpaidFlag({ ...EMPTY_COUNTERS, unpaidFlags: flags, recruitBlockedUntil: until }, now);
    assert.deepEqual(c.recruitBlockedUntil, until);
  });

  it('isRecruitBlocked: until recruitBlockedUntil, exclusive', () => {
    const until = new Date(now.getTime() + DAY);
    assert.equal(isRecruitBlocked({ ...EMPTY_COUNTERS, recruitBlockedUntil: until }, now), true);
    assert.equal(isRecruitBlocked({ ...EMPTY_COUNTERS, recruitBlockedUntil: until }, until), false);
    assert.equal(isRecruitBlocked(EMPTY_COUNTERS, now), false);
  });
});

describe('syncCollabJobOnBooking', () => {
  const booking = (over: Partial<Booking>): Pick<Booking, 'status' | 'cancel' | 'completedAt' | 'updatedAt'> => ({
    status: 'accepted',
    updatedAt: '2026-10-12T00:00:00.000Z',
    ...over,
  });

  it('a cancelled booking cancels a pending or accepted job, with no pay record', () => {
    for (const offerStatus of ['pending', 'accepted'] as const) {
      const next = syncCollabJobOnBooking(job({ offerStatus }), booking({
        status: 'cancelled',
        cancel: { by: 'customer', at: '2026-10-12T08:00:00.000Z', refundPercent: 100 },
      }));
      assert.equal(next?.offerStatus, 'cancelled', offerStatus);
      assert.deepEqual(next?.closedAt, new Date('2026-10-12T08:00:00.000Z'));
      assert.equal(next?.payStatus, 'none');
    }
  });

  it('a completed or reviewed booking closes the accepted job', () => {
    for (const status of ['completed', 'reviewed'] as const) {
      const next = syncCollabJobOnBooking(job(), booking({ status, completedAt: '2026-10-17T09:00:00.000Z' }));
      assert.equal(next?.offerStatus, 'accepted');
      assert.deepEqual(next?.closedAt, new Date('2026-10-17T09:00:00.000Z'));
    }
  });

  it('nothing changes for an open booking, a closed job or a job that is no longer live', () => {
    assert.equal(syncCollabJobOnBooking(job(), booking({ status: 'upcoming' })), null);
    const closed = job({ closedAt: new Date('2026-10-17T09:00:00.000Z') });
    assert.equal(syncCollabJobOnBooking(closed, booking({ status: 'reviewed', completedAt: '2026-10-17T09:00:00.000Z' })), null);
    assert.equal(syncCollabJobOnBooking(job({ offerStatus: 'declined' }), booking({ status: 'cancelled' })), null);
    assert.equal(syncCollabJobOnBooking(job({ offerStatus: 'replaced' }), booking({ status: 'completed' })), null);
  });
});

describe('isShootMilestoneReleased', () => {
  const pay = (status: string | null): Payment =>
    ({
      id: 'pay1',
      ...(status === null ? {} : { milestones: [{ kind: 'shoot', amount: 1, status, releaseAfter: null, releasedAt: null, payoutId: null }] }),
    }) as unknown as Payment;
  it('released or paid out → true; held, refunded or no milestones → false', () => {
    assert.equal(isShootMilestoneReleased([pay('released')]), true);
    assert.equal(isShootMilestoneReleased([pay('held'), pay('paid_out')]), true);
    assert.equal(isShootMilestoneReleased([pay('held')]), false);
    assert.equal(isShootMilestoneReleased([pay('refunded')]), false);
    assert.equal(isShootMilestoneReleased([pay(null)]), false);
    assert.equal(isShootMilestoneReleased([]), false);
  });
});

describe('poachingSignal (Decision 18)', () => {
  const now = new Date('2026-12-01T00:00:00.000Z');
  const accepted = job({ acceptedAt: new Date(now.getTime() - 60 * DAY) });

  it('two personal bookings with the same customer within 183 d of an accepted job → the jobs', () => {
    const since: Date[] = [];
    const got = poachingSignal({ jobs: [accepted], personalBookingsSince: (d) => { since.push(d); return 2; }, now });
    assert.deepEqual(got, [accepted]);
    assert.deepEqual(since, [accepted.acceptedAt]);
  });

  it('one booking → null', () => {
    assert.equal(poachingSignal({ jobs: [accepted], personalBookingsSince: () => 1, now }), null);
  });

  it('a job older than 183 d → null', () => {
    const old = job({ acceptedAt: new Date(now.getTime() - 184 * DAY) });
    assert.equal(poachingSignal({ jobs: [old], personalBookingsSince: () => 5, now }), null);
  });

  it('only accepted jobs count (declined, replaced, returned offers do not)', () => {
    for (const offerStatus of ['declined', 'replaced', 'returned', 'pending'] as const) {
      assert.equal(poachingSignal({ jobs: [job({ offerStatus, acceptedAt: offerStatus === 'returned' ? accepted.acceptedAt : null })], personalBookingsSince: () => 5, now }), null, offerStatus);
    }
  });
});

describe('off-app pay record (Decision 15)', () => {
  const dueJob = (w: CollabWorld, over: Partial<CollabJob> = {}): CollabJob => {
    const j = job({ payStatus: 'due', pay: { ...job().pay, dueAt: w.bw.clock.now() }, ...over });
    w.recruit.seedCollabJob(j);
    return j;
  };
  const report = (w: CollabWorld, caller: string, over: Record<string, unknown> = {}) =>
    reportCollabPaid(w.deps, caller, { bookingId: 'b1', collaboratorId: 'p1', paidOn: '2026-10-10', method: 'bank', ...over });
  const stored = (w: CollabWorld) => w.recruit.collabJobs.get('b1_p1');

  it('reportCollabPaid by the studio on a due job → paid_reported with paidOn and method, collab_pay_reported sent', async () => {
    const w = createCollabWorld();
    dueJob(w);
    await report(w, 's1', { paidOn: '2026-10-09', method: 'cash' });
    const j = stored(w);
    assert.equal(j?.payStatus, 'paid_reported');
    assert.equal(j?.pay.paidOn, '2026-10-09');
    assert.equal(j?.pay.method, 'cash');
    assert.deepEqual(j?.pay.reportedAt, w.bw.clock.now());
    const rows = w.rowsOf('p1').filter((r) => r.type === 'collab_pay_reported');
    assert.equal(rows.length, 1);
    assert.match(rows[0]?.body ?? '', /tiền mặt/);
  });

  it('paidOn in the future (VN day) or malformed, or an unknown method → invalid_argument', async () => {
    const w = createCollabWorld(); // 2026-10-10 17:00 in Vietnam
    dueJob(w);
    assert.deepEqual(await code(report(w, 's1', { paidOn: '2026-10-11' })), { code: 'invalid_argument', field: 'paidOn' });
    assert.deepEqual(await code(report(w, 's1', { paidOn: '2026-02-30' })), { code: 'invalid_argument', field: 'paidOn' });
    assert.deepEqual(await code(report(w, 's1', { paidOn: '10/10/2026' })), { code: 'invalid_argument', field: 'paidOn' });
    assert.deepEqual(await code(report(w, 's1', { method: 'momo' })), { code: 'invalid_argument', field: 'method' });
    assert.equal(stored(w)?.payStatus, 'due');
  });

  it('by the collaborator or another studio → permission_denied; an unknown job → not_found', async () => {
    const w = createCollabWorld();
    dueJob(w);
    assert.equal((await code(report(w, 'p1'))).code, 'permission_denied');
    assert.equal((await code(report(w, 's2'))).code, 'permission_denied');
    assert.equal((await code(report(w, 's1', { collaboratorId: 'p2' }))).code, 'not_found');
  });

  it('on a none, already reported or received job → conflict', async () => {
    for (const payStatus of ['none', 'paid_reported', 'received'] as const) {
      const w = createCollabWorld();
      dueJob(w, { payStatus });
      assert.equal((await code(report(w, 's1'))).code, 'conflict', payStatus);
    }
  });

  it('confirmCollabPay received → received', async () => {
    const w = createCollabWorld();
    dueJob(w);
    await report(w, 's1');
    w.bw.clock.advanceHours(2);
    assert.deepEqual(await confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: true }), { payStatus: 'received' });
    assert.equal(stored(w)?.payStatus, 'received');
    assert.deepEqual(stored(w)?.pay.receivedAt, w.bw.clock.now());
    assert.equal(w.rowsOf('s1').filter((r) => r.type === 'collab_pay_disputed').length, 0);
  });

  it('not received → disputed, collab_pay_disputed to the studio', async () => {
    const w = createCollabWorld();
    dueJob(w);
    await report(w, 's1');
    assert.deepEqual(await confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: false }), { payStatus: 'disputed' });
    assert.equal(stored(w)?.payStatus, 'disputed');
    assert.deepEqual(stored(w)?.pay.disputedAt, w.bw.clock.now());
    assert.equal(w.rowsOf('s1').filter((r) => r.type === 'collab_pay_disputed').length, 1);
  });

  it('confirm only by the collaborator, only after a report', async () => {
    const w = createCollabWorld();
    dueJob(w);
    assert.equal((await code(confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: true }))).code, 'conflict');
    await report(w, 's1');
    assert.equal((await code(confirmCollabPay(w.deps, 's1', { bookingId: 'b1', received: true }))).code, 'not_found');
    assert.equal((await code(confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: 'yes' }))).code, 'invalid_argument');
  });

  it('a disputed job can be reported paid again (back to paid_reported)', async () => {
    const w = createCollabWorld();
    dueJob(w);
    await report(w, 's1');
    await confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: false });
    w.bw.clock.advanceHours(1);
    await report(w, 's1', { method: 'other' });
    assert.equal(stored(w)?.payStatus, 'paid_reported');
    assert.equal(stored(w)?.pay.method, 'other');
    assert.deepEqual(stored(w)?.pay.reportedAt, w.bw.clock.now());
  });

  it('no payment, refund or ledger write anywhere (R5)', async () => {
    const w = createCollabWorld();
    dueJob(w);
    await report(w, 's1');
    await confirmCollabPay(w.deps, 'p1', { bookingId: 'b1', received: true });
    assert.equal(w.bw.store.payments.size, 0);
    assert.equal(w.bw.store.refunds.size, 0);
    assert.equal(w.bw.store.ledgerEntries.size, 0);
  });
});

