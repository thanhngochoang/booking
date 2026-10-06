import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import {
  createPayout,
  executePayout,
  holdPayout,
  listDuePayees,
  resumePayout,
} from '../src/payout_use_cases.js';
import { ADMIN, addAccount, createPayoutWorld, paidBooking, release } from './support/payout_world.js';

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

async function releasedPayment(w: ReturnType<typeof createPayoutWorld>, day: string): Promise<string> {
  const b = await paidBooking(w, day);
  release(w, b.paymentId);
  return b.paymentId;
}

describe('payout use cases', () => {
  it('a non-admin is permission_denied', async () => {
    const w = createPayoutWorld();
    const user = { uid: 'p1', isAdmin: false };
    await refused(createPayout(w.payoutDeps, user, 'p1'), 'permission_denied');
    await refused(executePayout(w.payoutDeps, user, 'x'), 'permission_denied');
    await refused(holdPayout(w.payoutDeps, user, 'x', 'long enough'), 'permission_denied');
    await refused(resumePayout(w.payoutDeps, user, 'x'), 'permission_denied');
    await refused(listDuePayees(w.payoutDeps, user), 'permission_denied');
  });

  it('no active account is not_eligible', async () => {
    const w = createPayoutWorld();
    await releasedPayment(w, '2026-10-15');
    await refused(createPayout(w.payoutDeps, ADMIN, 'p1'), 'not_eligible');
    await addAccount(w);
    const none = createPayoutWorld();
    await addAccount(none);
    await refused(createPayout(none.payoutDeps, ADMIN, 'p1'), 'not_eligible');
  });

  it('held and disputed payments are never batched', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await paidBooking(w, '2026-10-15'); // held
    const dis = await paidBooking(w, '2026-10-16');
    const disPayment = w.store.payments.get(dis.paymentId);
    assert.ok(disPayment);
    w.store.payments.set(dis.paymentId, { ...disPayment, escrowStatus: 'disputed' });
    await refused(createPayout(w.payoutDeps, ADMIN, 'p1'), 'not_eligible');
    const ok = await releasedPayment(w, '2026-10-17');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(po.items.map((i) => i.paymentId), [ok]);
  });

  it('the payout amount equals the sum of its items', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const a = await releasedPayment(w, '2026-10-15');
    const b = await releasedPayment(w, '2026-10-16');
    w.store.refunds.set('r1', {
      id: 'r1', paymentId: b, amount: 100_000, percent: 33, status: 'done', manual: false,
      createdAt: 'x', updatedAt: 'x',
    });
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(po.status, 'pending');
    assert.equal(po.createdBy, ADMIN.uid);
    assert.equal(po.amount, po.items.reduce((s, i) => s + i.amount, 0));
    assert.equal(po.amount, 500_000);
    assert.equal(po.items.find((i) => i.paymentId === a)?.amount, 300_000);
    assert.equal(w.store.payments.get(a)?.payoutId, po.id);
  });

  it('a payment already in an open payout is not batched twice', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    await createPayout(w.payoutDeps, ADMIN, 'p1');
    await refused(createPayout(w.payoutDeps, ADMIN, 'p1'), 'not_eligible');
    assert.equal(w.payoutStore.payouts.size, 1);
  });

  it('execute pays, marks payments paid_out and writes one payout_paid per item', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const a = await releasedPayment(w, '2026-10-15');
    const b = await releasedPayment(w, '2026-10-16');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const done = await executePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(done.status, 'paid');
    assert.equal(done.reference, `FAKE-${po.id}`);
    assert.ok(done.paidAt);
    assert.equal(w.store.payments.get(a)?.escrowStatus, 'paid_out');
    assert.equal(w.store.payments.get(b)?.escrowStatus, 'paid_out');
    const entries = [...w.store.ledgerEntries.values()].filter((e) => e.type === 'payout_paid');
    assert.equal(entries.length, 2);
    for (const e of entries) {
      assert.equal(e.amount, -300_000);
      assert.equal(e.accountOwnerId, 'p1');
      assert.equal(e.payoutId, po.id);
    }
    assert.deepEqual(w.payGateway.calls, [po.id]);
  });

  it('executing a paid payout is a conflict', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await executePayout(w.payoutDeps, ADMIN, po.id);
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    assert.equal(w.payGateway.calls.length, 1);
    assert.equal([...w.store.ledgerEntries.values()].filter((e) => e.type === 'payout_paid').length, 1);
    await refused(executePayout(w.payoutDeps, ADMIN, 'missing'), 'not_found');
  });

  it('a retried execute uses the same gateway call', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    // The first attempt reaches the bank but the process dies before the result is stored.
    const real = w.payGateway.transfer.bind(w.payGateway);
    let crash = true;
    (w.payoutDeps.gateway as { transfer: typeof real }).transfer = async (r) => {
      const out = await real(r);
      if (crash) {
        crash = false;
        throw new Error('crash');
      }
      return out;
    };
    await assert.rejects(executePayout(w.payoutDeps, ADMIN, po.id), /crash/);
    assert.equal(w.payoutStore.payouts.get(po.id)?.status, 'processing');
    const done = await executePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(done.status, 'paid');
    assert.equal(w.payGateway.outcomes.size, 1);
    assert.deepEqual(w.payGateway.calls, [po.id, po.id]);
    assert.equal([...w.store.ledgerEntries.values()].filter((e) => e.type === 'payout_paid').length, 1);
  });

  it('a failed payout returns its payments', async () => {
    const w = createPayoutWorld();
    await addAccount(w, '0123450000');
    const a = await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const failed = await executePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(failed.status, 'failed');
    assert.equal(failed.failureReason, 'account_rejected');
    assert.equal(w.store.payments.get(a)?.escrowStatus, 'released');
    assert.equal(w.store.payments.get(a)?.payoutId, null);
    assert.equal([...w.store.ledgerEntries.values()].filter((e) => e.type === 'payout_paid').length, 0);
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    const again = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(again.items[0]?.paymentId, a);
  });

  it('an on_hold payout cannot execute until resumed', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const held = await holdPayout(w.payoutDeps, ADMIN, po.id, '  Kiểm tra tài khoản  ');
    assert.equal(held.status, 'on_hold');
    assert.equal(held.holdReason, 'Kiểm tra tài khoản');
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    await refused(holdPayout(w.payoutDeps, ADMIN, po.id, 'again please'), 'conflict');
    const resumed = await resumePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(resumed.status, 'pending');
    assert.equal(resumed.holdReason, undefined);
    await refused(resumePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    assert.equal((await executePayout(w.payoutDeps, ADMIN, po.id)).status, 'paid');
  });

  it('hold needs a 5–200 character reason', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await refused(holdPayout(w.payoutDeps, ADMIN, po.id, '1234'), 'invalid_argument');
    await refused(holdPayout(w.payoutDeps, ADMIN, po.id, '   ab   '), 'invalid_argument');
    await refused(holdPayout(w.payoutDeps, ADMIN, po.id, 'x'.repeat(201)), 'invalid_argument');
    assert.equal((await holdPayout(w.payoutDeps, ADMIN, po.id, 'x'.repeat(200))).status, 'on_hold');
  });

  it('due payees list released money and whether they have an account', async () => {
    const w = createPayoutWorld();
    await releasedPayment(w, '2026-10-15');
    await paidBooking(w, '2026-10-16'); // held: not due
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), [
      { payeeId: 'p1', amount: 300_000, hasAccount: false },
    ]);
    await addAccount(w);
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), [
      { payeeId: 'p1', amount: 300_000, hasAccount: true },
    ]);
    await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), []);
  });
});
