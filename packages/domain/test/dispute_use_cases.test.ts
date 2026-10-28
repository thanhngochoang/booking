import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { dispatchDisputeRefund, openDispute, resolveDispute } from '../src/dispute_use_cases.js';
import { DomainError } from '../src/errors.js';
import { verifyPaymentLedgerInvariant, type Payment, type Refund } from '../src/escrow.js';
import { releaseMilestone } from '../src/milestones.js';
import {
  createDisputeWorld,
  hoursFrom,
  NOW,
  openInput,
  paidPayment,
  seedApprovedBooking,
  seedLegacyBooking,
  seedShotBooking,
  seedTicket,
  type DisputeWorld,
} from './support/dispute_world.js';

const rejectsWith = (p: Promise<unknown>, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);

const payment = (w: DisputeWorld, id = 'pay_b1'): Payment => {
  const p = w.store.payments.get(id);
  assert.ok(p);
  return p;
};
const milestone = (w: DisputeWorld, kind: 'shoot' | 'delivery') => payment(w).milestones?.find((m) => m.kind === kind);
const ledgerOf = (w: DisputeWorld, id = 'pay_b1') => w.store.ledger.filter((e) => e.paymentId === id);
const refundsOf = (w: DisputeWorld, id = 'pay_b1') => [...w.store.refunds.values()].filter((r) => r.paymentId === id);
const invariantHolds = (w: DisputeWorld, id = 'pay_b1') =>
  verifyPaymentLedgerInvariant(payment(w, id), refundsOf(w, id), ledgerOf(w, id));

const NOTE = 'Đã xem bằng chứng hai bên';

describe('openDispute', () => {
  it('openDispute on an approved booking freezes only the delivery milestone (shoot stays released) and opens the thread', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    const d = await openDispute(w.deps, 'c1', openInput({ reason: 'link_broken' }));

    assert.equal(milestone(w, 'shoot')?.status, 'released');
    assert.equal(milestone(w, 'delivery')?.status, 'disputed');
    assert.equal(payment(w).escrowStatus, 'disputed');
    assert.deepEqual(payment(w).dispute, { reason: 'link_broken', openedAt: NOW.toISOString(), disputeId: 'd1', milestone: 'delivery' });

    assert.equal(d.status, 'open');
    assert.equal(d.amountHeld, 500_000);
    assert.equal(d.paymentId, 'pay_b1');
    assert.deepEqual(d.parties, ['c1', 'p1']);
    assert.equal(d.openedBy, 'customer');
    assert.equal(d.description, 'Thợ đến muộn hai tiếng và thiếu ảnh');
    assert.deepEqual(d.evidencePaths, ['disputeEvidence/c1/d1/f1.jpg']);
    assert.equal(d.threadId, 'dispute_d1');
    assert.equal(d.outcome, null);
    assert.deepEqual(w.store.disputes.get('d1'), d);
    assert.deepEqual(w.store.mirrors.get('booking::b1'), { disputeId: 'd1', escrowStatus: 'disputed' });

    const thread = w.store.threads.get('dispute_d1');
    assert.ok(thread);
    assert.equal(thread.kind, 'dispute');
    assert.equal(thread.disputeId, 'd1');
    assert.deepEqual(thread.participants, ['c1', 'p1']);
    assert.equal(thread.status, 'open');
    assert.equal(thread.awaitingStaff, true);
    assert.equal(thread.lastSenderRole, 'customer');
    const msgs = [...(await w.store.listMessages('dispute_d1', 10))].reverse();
    assert.deepEqual(msgs.map((m) => [m.senderRole, m.senderId]), [['system', null], ['customer', 'c1']]);
    assert.equal(msgs[0]?.body, 'Đã mở khiếu nại · 17:00 20/10');
    assert.equal(msgs[1]?.senderName, 'An');
    assert.equal(msgs[1]?.body, 'Thợ đến muộn hai tiếng và thiếu ảnh');
  });

  it('openDispute on a shot booking freezes the shoot milestone', async () => {
    const w = createDisputeWorld();
    seedShotBooking(w);
    const d = await openDispute(w.deps, 'c1', openInput({ reason: 'no_show' }));
    assert.equal(milestone(w, 'shoot')?.status, 'disputed');
    assert.equal(milestone(w, 'delivery')?.status, 'held');
    assert.equal(payment(w).dispute?.milestone, 'shoot');
    assert.equal(d.amountHeld, 500_000);
  });

  it('a legacy payment without milestones is frozen whole and stores prevEscrowStatus partially_refunded', async () => {
    const w = createDisputeWorld();
    seedLegacyBooking(w, { escrowRefund: 200_000, overpaid: 50_000 });
    const d = await openDispute(w.deps, 'c1', openInput());
    assert.equal(payment(w).escrowStatus, 'disputed');
    assert.deepEqual(payment(w).dispute, {
      reason: 'not_as_agreed', openedAt: NOW.toISOString(), disputeId: 'd1', milestone: null, prevEscrowStatus: 'partially_refunded',
    });
    assert.equal(d.amountHeld, 800_000);
  });

  it('openDispute is idempotent for the same id', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    const first = await openDispute(w.deps, 'c1', openInput());
    w.clock.advanceMinutes(1);
    const again = await openDispute(w.deps, 'c1', openInput({ description: 'Một mô tả khác hẳn lần đầu' }));
    assert.deepEqual(again, first);
    assert.equal(w.store.threads.size, 1);
    assert.equal((await w.store.listMessages('dispute_d1', 10)).length, 2);
    await rejectsWith(openDispute(w.deps, 'c2', openInput({ evidencePaths: [] })), 'permission_denied');
  });

  it('a second dispute on the same booking → conflict', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    await rejectsWith(openDispute(w.deps, 'c1', openInput({ disputeId: 'd2', evidencePaths: [] })), 'conflict');
  });

  it('after a resolved shoot dispute the delivery milestone can be disputed in its window; the shoot one not again', async () => {
    const w = createDisputeWorld();
    seedShotBooking(w);
    await openDispute(w.deps, 'c1', openInput({ reason: 'no_show' }));
    // The same id again is still answered with the first dispute (idempotent path first).
    assert.equal((await openDispute(w.deps, 'c1', openInput({ reason: 'no_show' }))).id, 'd1');
    await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: NOTE });

    // Still `shot`: the shoot milestone is no longer held → refused.
    await rejectsWith(openDispute(w.deps, 'c1', openInput({ disputeId: 'd2', evidencePaths: [] })), 'not_eligible');

    // The photographer delivers and the customer approves: delivery held, its window open.
    const view = w.store.subjects.get('booking::b1');
    assert.ok(view);
    w.store.putSubject({ ...view, state: 'approved', checkUntil: hoursFrom(24) });
    const d3 = await openDispute(w.deps, 'c1', openInput({ disputeId: 'd3', reason: 'link_broken', evidencePaths: [] }));
    assert.equal(d3.status, 'open');
    assert.equal(milestone(w, 'delivery')?.status, 'disputed');
    assert.equal(payment(w).dispute?.milestone, 'delivery');
    assert.equal(w.store.subjects.get('booking::b1')?.disputeId, 'd3');
    assert.deepEqual(w.store.mirrors.get('booking::b1'), { disputeId: 'd3', escrowStatus: 'disputed' });
    // While d3 is open, another one → conflict.
    await rejectsWith(openDispute(w.deps, 'c1', openInput({ disputeId: 'd4', evidencePaths: [] })), 'conflict');
  });

  it('a booking with a stray settled payment freezes the one still holding money (pickSubjectPayment, like Firestore)', async () => {
    const w = createDisputeWorld();
    // Settled (paid) but holding nothing: before pickSubjectPayment the memory store took the first settled one.
    const stray = paidPayment({ id: 'pay_b1_old', escrowStatus: 'released', idempotencyKey: 'key_b1_old' });
    w.store.payments.set(stray.id, stray);
    seedApprovedBooking(w);
    const d = await openDispute(w.deps, 'c1', openInput());
    assert.equal(d.paymentId, 'pay_b1');
    assert.equal(payment(w).escrowStatus, 'disputed');
    assert.equal(payment(w, 'pay_b1_old').escrowStatus, 'released');
  });

  it('another customer → permission_denied', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await rejectsWith(openDispute(w.deps, 'c2', openInput({ evidencePaths: [] })), 'permission_denied');
    assert.equal(w.store.disputes.size, 0);
  });

  it('a booking whose payment was already released → not_eligible', async () => {
    const w = createDisputeWorld();
    seedLegacyBooking(w, { escrowStatus: 'released' });
    await rejectsWith(openDispute(w.deps, 'c1', openInput()), 'not_eligible');
    assert.equal(payment(w).escrowStatus, 'released');
  });

  it('ticket dispute freezes the ticket payment and sets registration.disputeId; platform event → parties is the customer only', async () => {
    const w = createDisputeWorld();
    seedTicket(w, { platform: true });
    const d = await openDispute(
      w.deps,
      'c1',
      openInput({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', reason: 'event_not_held' }),
    );
    assert.equal(payment(w, 'pay_r1').escrowStatus, 'disputed');
    assert.equal(payment(w, 'pay_r1').dispute?.prevEscrowStatus, 'held');
    assert.equal(w.store.mirrors.get('ticket:e1:r1')?.disputeId, 'd1');
    assert.deepEqual(d.parties, ['c1']);
    assert.equal(d.providerId, 'platform');
    assert.equal(d.eventId, 'e1');
    assert.equal(d.amountHeld, 300_000);
    assert.deepEqual(w.store.threads.get('dispute_d1')?.participants, ['c1']);
  });
});

describe('resolveDispute', () => {
  it('resolveDispute release on a milestone dispute releases that milestone only (releaseMilestone), outcome stored with decidedBy, thread closed', async () => {
    const w = createDisputeWorld();
    seedShotBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    w.clock.advanceMinutes(30);
    const { dispute, refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: NOTE });

    assert.equal(refund, null);
    assert.equal(milestone(w, 'shoot')?.status, 'released');
    assert.equal(milestone(w, 'delivery')?.status, 'held');
    assert.equal(payment(w).escrowStatus, 'held');
    const released = ledgerOf(w).filter((e) => e.type === 'escrow_released');
    assert.deepEqual(released.map((e) => [e.amount, e.accountOwnerId]), [[500_000, 'p1']]);

    const at = w.clock.now().toISOString();
    assert.equal(dispute.status, 'resolved');
    assert.equal(dispute.resolvedAt, at);
    assert.deepEqual(dispute.outcome, {
      kind: 'release', refundPercent: 0, refundAmount: 0, releaseAmount: 500_000, note: NOTE, decidedBy: 'staff1', decidedAt: at, refundId: null,
    });
    assert.deepEqual(w.store.disputes.get('d1'), dispute);
    assert.deepEqual(w.store.mirrors.get('booking::b1'), { disputeId: 'd1', escrowStatus: 'held' });

    const thread = w.store.threads.get('dispute_d1');
    assert.equal(thread?.status, 'closed');
    assert.equal(thread?.awaitingStaff, false);
    assert.equal(thread?.lastSenderRole, 'system');
    const msgs = await w.store.listMessages('dispute_d1', 10);
    assert.equal(msgs.length, 3);
    assert.equal(msgs[0]?.senderRole, 'system');
  });

  it('refund on a delivery-milestone dispute refunds the delivery amount (`fromEscrow: true`), never the released shoot milestone', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    const releasedBefore = ledgerOf(w).filter((e) => e.type === 'escrow_released').length;
    const { dispute, refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE });

    assert.ok(refund);
    assert.equal(refund.amount, 500_000);
    assert.equal(refund.fromEscrow, true);
    assert.equal(refund.percent, 100);
    assert.equal(refund.reason, 'dispute:d1');
    assert.equal(refund.status, 'pending');
    assert.deepEqual(w.store.refunds.get(refund.id), refund);
    assert.equal(dispute.outcome?.refundId, refund.id);
    assert.equal(milestone(w, 'shoot')?.status, 'released');
    assert.equal(milestone(w, 'delivery')?.status, 'refunded');
    assert.equal(payment(w).status, 'partially_refunded');
    assert.equal(payment(w).refundedAmount, 500_000);
    assert.equal(ledgerOf(w).filter((e) => e.type === 'escrow_released').length, releasedBefore);
  });

  it('split 40% of a frozen milestone refunds 40% of that milestone', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    const { dispute, refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'split', refundPercent: 40, note: NOTE });

    assert.equal(refund?.amount, 200_000);
    assert.equal(refund?.percent, 40);
    assert.equal(dispute.outcome?.refundAmount, 200_000);
    assert.equal(dispute.outcome?.releaseAmount, 300_000);
    const delivery = milestone(w, 'delivery');
    assert.equal(delivery?.status, 'released');
    assert.equal(delivery?.amount, 300_000);
    const released = ledgerOf(w).filter((e) => e.type === 'escrow_released').map((e) => e.amount);
    assert.deepEqual(released, [500_000, 300_000]);
    assert.equal(payment(w).escrowStatus, 'released');
    assert.equal(payment(w).payableAmount, 800_000);
  });

  it('split on a legacy payment uses amount − escrowRefundedTotal (a refund with fromEscrow false is not subtracted)', async () => {
    const w = createDisputeWorld();
    seedLegacyBooking(w, { escrowRefund: 200_000, overpaid: 50_000 });
    await openDispute(w.deps, 'c1', openInput());
    const { dispute, refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'split', refundPercent: 40, note: NOTE });

    assert.equal(refund?.amount, 320_000);
    assert.equal(dispute.outcome?.releaseAmount, 480_000);
    const released = ledgerOf(w).filter((e) => e.type === 'escrow_released').map((e) => e.amount);
    assert.deepEqual(released, [480_000]);
    assert.equal(payment(w).escrowStatus, 'released');
    assert.equal(payment(w).refundedAmount, 570_000);
  });

  it('verifyPaymentLedgerInvariant holds after release, refund and split', async () => {
    const outcomes = [
      { outcome: 'release' },
      { outcome: 'refund' },
      { outcome: 'split', refundPercent: 25 },
    ] as const;
    const seeds = [
      seedShotBooking,
      seedApprovedBooking,
      (w: DisputeWorld) => seedLegacyBooking(w, { escrowRefund: 200_000, overpaid: 50_000 }),
      (w: DisputeWorld) => seedLegacyBooking(w),
    ];
    for (const s of seeds) {
      for (const o of outcomes) {
        const w = createDisputeWorld();
        s(w);
        await openDispute(w.deps, 'c1', openInput());
        await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', note: NOTE, ...o });
        assert.equal(invariantHolds(w), true, `${s.name} ${o.outcome}`);
        const p = payment(w);
        const escrowRefunded = refundsOf(w).filter((r) => r.fromEscrow).reduce((sum, r) => sum + r.amount, 0);
        assert.ok(escrowRefunded <= p.amount, `${s.name} ${o.outcome}: refunds stay within what was paid`);
      }
    }
    const t = createDisputeWorld();
    seedTicket(t);
    await openDispute(t.deps, 'c1', openInput({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', reason: 'other' }));
    await resolveDispute(t.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE });
    assert.equal(invariantHolds(t, 'pay_r1'), true);
    assert.equal(payment(t, 'pay_r1').escrowStatus, 'refunded');
  });

  describe('shoot dispute open → booking completes → resolve', () => {
    /** b1's shoot milestone is disputed, then the booking completes; `deliveryReleased`: completion released delivery (today's rule), else the older order where it is still held. */
    async function completedWhileDisputed(w: DisputeWorld, deliveryReleased: boolean): Promise<void> {
      seedShotBooking(w);
      await openDispute(w.deps, 'c1', openInput({ reason: 'no_show' }));
      if (deliveryReleased) {
        const r = releaseMilestone(payment(w), 'delivery', 'le_rel_delivery', hoursFrom(1));
        w.store.payments.set('pay_b1', r.payment);
        w.store.ledger.push(r.ledgerEntry);
      }
      const view = w.store.subjects.get('booking::b1');
      assert.ok(view);
      w.store.putSubject({ ...view, state: 'completed', windowStart: hoursFrom(1) });
      w.clock.setTime(hoursFrom(2));
    }

    for (const deliveryReleased of [true, false]) {
      for (const o of [{ outcome: 'release' }, { outcome: 'refund' }, { outcome: 'split', refundPercent: 40 }] as const) {
        it(`${o.outcome} with delivery ${deliveryReleased ? 'released at completion' : 'still held'}: delivery ends released once, ledger balances`, async () => {
          const w = createDisputeWorld();
          await completedWhileDisputed(w, deliveryReleased);
          const { dispute } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', note: NOTE, ...o });
          assert.equal(milestone(w, 'delivery')?.status, 'released');
          const shoot = milestone(w, 'shoot');
          assert.equal(shoot?.status, o.outcome === 'refund' ? 'refunded' : 'released');
          const released = ledgerOf(w).filter((e) => e.type === 'escrow_released').map((e) => e.amount).sort();
          const shootRelease = dispute.outcome?.releaseAmount ?? 0;
          assert.deepEqual(released, (shootRelease > 0 ? [shootRelease, 500_000] : [500_000]).sort());
          assert.equal(payment(w).escrowStatus, 'released');
          assert.equal(invariantHolds(w), true);
          const refunded = refundsOf(w).reduce((sum, r) => sum + r.amount, 0);
          assert.equal(refunded + released.reduce((a, b) => a + b, 0), 1_000_000);
        });
      }
    }
  });

  it('a milestone payment without dispute.milestone resolves its single disputed milestone, and conflicts when there is none', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    const p = payment(w);
    w.store.payments.set('pay_b1', { ...p, dispute: { reason: 'link_broken', openedAt: NOW.toISOString(), disputeId: 'd1' } });
    const { refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE });
    assert.equal(refund?.amount, 500_000);
    assert.equal(milestone(w, 'shoot')?.status, 'released');
    assert.equal(milestone(w, 'delivery')?.status, 'refunded');
    assert.equal(invariantHolds(w), true);

    const none = createDisputeWorld();
    seedApprovedBooking(none);
    await openDispute(none.deps, 'c1', openInput());
    const q = payment(none);
    none.store.payments.set('pay_b1', {
      ...q,
      milestones: q.milestones?.map((m) => ({ ...m, status: m.kind === 'delivery' ? 'held' : m.status })),
      escrowStatus: 'disputed',
      dispute: { reason: 'link_broken', openedAt: NOW.toISOString(), disputeId: 'd1' },
    });
    await rejectsWith(resolveDispute(none.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE }), 'conflict');
    assert.equal(refundsOf(none).length, 0);
  });

  it('resolving twice with another decision → conflict', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: NOTE });
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE }), 'conflict');
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: 'Đổi ý lần nữa' }), 'conflict');
    await rejectsWith(resolveDispute(w.deps, 'staff2', { disputeId: 'd1', outcome: 'release', note: NOTE }), 'conflict');
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'nope', outcome: 'refund', note: NOTE }), 'not_found');
  });

  it('the same staff retrying the same decision (lost response) gets the stored outcome and refund, nothing written twice', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    const first = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'split', refundPercent: 40, note: NOTE });
    const ledgerBefore = ledgerOf(w).length;
    const messagesBefore = (await w.store.listMessages('dispute_d1', 10)).length;
    w.clock.advanceMinutes(1);
    const again = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'split', refundPercent: 40, note: NOTE });
    assert.deepEqual(again, first);
    assert.equal(refundsOf(w).length, 1);
    assert.equal(ledgerOf(w).length, ledgerBefore);
    assert.equal((await w.store.listMessages('dispute_d1', 10)).length, messagesBefore);
    // Another split percent is another decision.
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'split', refundPercent: 50, note: NOTE }), 'conflict');
  });

  it('note under 5 characters → invalid_argument', async () => {
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: ' ok  ' }), 'invalid_argument');
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'release', note: 'x'.repeat(501) }), 'invalid_argument');
    await rejectsWith(resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'keep', note: NOTE }), 'invalid_argument');
    assert.equal(w.store.disputes.get('d1')?.status, 'open');
  });
});

describe('dispatchDisputeRefund marks the refund done, failed+manual when the gateway fails or throws (#129 Ruling 7), and never overwrites a refund that is no longer pending', () => {
  async function refunded(w: DisputeWorld): Promise<{ payment: Payment; refund: Refund }> {
    seedApprovedBooking(w);
    await openDispute(w.deps, 'c1', openInput());
    const { refund } = await resolveDispute(w.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: NOTE });
    assert.ok(refund);
    return { payment: payment(w), refund };
  }

  it('marks the refund done', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    const out = await dispatchDisputeRefund(w.deps, p, refund);
    assert.equal(out.status, 'done');
    assert.equal(w.store.refunds.get(refund.id)?.status, 'done');
    assert.deepEqual(w.gateway.refundCalls, [refund.id]);
    assert.equal(w.gateway.issuedRefunds.get(refund.id), 500_000);
  });

  it('failed + manual when the gateway refuses', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    w.gateway.refundFailureId = refund.id;
    await dispatchDisputeRefund(w.deps, p, refund);
    const stored = w.store.refunds.get(refund.id);
    assert.equal(stored?.status, 'failed');
    assert.equal(stored?.manual, true);
  });

  it('with V2 a throw keeps it pending (re-sent later under the same id)', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    w.gateway.refundThrowCount = 1;
    await dispatchDisputeRefund(w.deps, p, refund);
    const stored = w.store.refunds.get(refund.id);
    assert.equal(stored?.status, 'pending');
    assert.equal(stored?.attempts, 1);
  });

  it('a refund settled before the send is not sent again', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    const done: Refund = { ...refund, status: 'done', manual: false, providerRef: 'by_event' };
    w.store.refunds.set(refund.id, done);
    const out = await dispatchDisputeRefund(w.deps, p, refund);
    assert.deepEqual(out, done);
    assert.deepEqual(w.gateway.refundCalls, []);
  });

  it('never overwrites a refund that is no longer pending', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    const done: Refund = { ...refund, status: 'done', manual: false, providerRef: 'by_staff' };
    // Settled (a refund event, or staff) while the gateway call is in flight; the gateway then refuses.
    const issue = w.gateway.issueRefund.bind(w.gateway);
    w.gateway.issueRefund = async (params) => {
      w.store.refunds.set(refund.id, done);
      return issue(params);
    };
    w.gateway.refundFailureId = refund.id;
    await dispatchDisputeRefund(w.deps, p, refund);
    assert.deepEqual(w.gateway.refundCalls, [refund.id]);
    assert.deepEqual(w.store.refunds.get(refund.id), done);
  });

  it('an awaiting_account refund is not sent', async () => {
    const w = createDisputeWorld();
    const { payment: p, refund } = await refunded(w);
    const awaiting: Refund = { ...refund, status: 'awaiting_account', method: 'bank_transfer', destination: null };
    w.store.refunds.set(refund.id, awaiting);
    const out = await dispatchDisputeRefund(w.deps, p, awaiting);
    assert.equal(out.status, 'awaiting_account');
    assert.deepEqual(w.gateway.refundCalls, []);
    assert.deepEqual(w.store.refunds.get(refund.id), awaiting);
  });
});
