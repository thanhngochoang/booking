import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { PLATFORM_PAYEE } from '../src/payout.js';
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

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

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

  /** A released ticket payment of the same shape the event flow writes (payee = host or platform). */
  async function releasedTicket(w: ReturnType<typeof createPayoutWorld>, day: string, payeeId: string, amount = 250_000): Promise<string> {
    const id = await releasedPayment(w, day);
    const p = w.store.payments.get(id);
    assert.ok(p);
    w.store.payments.set(id, {
      ...p, subjectType: 'event_registration', subjectId: `reg_${day}`, eventId: 'ev1', payeeId, amount,
      idempotencyKey: `tkt_reg_${day}_momo`,
    });
    return id;
  }

  it('a released ticket payment is batched in the host\'s payout exactly once', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const booking = await releasedPayment(w, '2026-10-15');
    const bookingAmount = w.store.payments.get(booking)?.amount ?? 0;
    const ticket = await releasedTicket(w, '2026-10-16', 'p1');
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), [{ payeeId: 'p1', amount: bookingAmount + 250_000, hasAccount: true }]);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(po.items.map((i) => i.paymentId).sort(), [booking, ticket].sort());
    assert.equal(po.items.find((i) => i.paymentId === ticket)?.amount, 250_000);
    assert.equal(w.store.payments.get(ticket)?.payoutId, po.id);
    // Batched once: nothing is due any more and a second payout has nothing to take.
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), []);
    await refused(createPayout(w.payoutDeps, ADMIN, 'p1'), 'not_eligible');
  });

  it('a platform-event ticket payment never enters a payout', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const platform = await releasedTicket(w, '2026-10-15', PLATFORM_PAYEE);
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), []);
    await refused(createPayout(w.payoutDeps, ADMIN, PLATFORM_PAYEE), 'not_eligible');
    const ok = await releasedPayment(w, '2026-10-16');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(po.items.map((i) => i.paymentId), [ok]);
    assert.equal(w.store.payments.get(platform)?.payoutId, undefined);
  });

  it('a cipher failure fails execute before the payout turns processing', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const deps = { ...w.payoutDeps, cipher: { ...w.payoutDeps.cipher, decrypt: async () => { throw new Error('bad key'); } } };
    await assert.rejects(executePayout(deps, ADMIN, po.id), /bad key/);
    assert.equal(w.payoutStore.payouts.get(po.id)?.status, 'pending');
    assert.deepEqual(w.payGateway.calls, []);
  });

  it('the payout amount equals the sum of its items', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const a = await releasedPayment(w, '2026-10-15');
    const b = await releasedPayment(w, '2026-10-16');
    w.store.refunds.set('r1', {
      id: 'r1', paymentId: b, amount: 100_000, percent: 33, status: 'done', manual: false, fromEscrow: true,
      createdAt: 'x', updatedAt: 'x',
    });
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(po.status, 'pending');
    assert.equal(po.createdBy, ADMIN.uid);
    assert.equal(po.amount, po.items.reduce((s, i) => s + i.amount, 0));
    assert.equal(po.amount, PAID + (PAID - 100_000));
    assert.equal(po.items.find((i) => i.paymentId === a)?.amount, PAID);
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
      assert.equal(e.amount, -PAID);
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

  it('a payment that left the batch during the transfer is a conflict and writes nothing', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const a = await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const real = w.payGateway.transfer.bind(w.payGateway);
    (w.payoutDeps.gateway as { transfer: typeof real }).transfer = async (r) => {
      const pay = w.store.payments.get(a);
      assert.ok(pay);
      w.store.payments.set(a, { ...pay, escrowStatus: 'disputed' });
      return real(r);
    };
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    assert.equal(w.payoutStore.payouts.get(po.id)?.status, 'processing');
    assert.equal(w.store.payments.get(a)?.escrowStatus, 'disputed');
    assert.equal([...w.store.ledgerEntries.values()].filter((e) => e.type === 'payout_paid').length, 0);
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
      { payeeId: 'p1', amount: PAID, hasAccount: false },
    ]);
    await addAccount(w);
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), [
      { payeeId: 'p1', amount: PAID, hasAccount: true },
    ]);
    await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(await listDuePayees(w.payoutDeps, ADMIN), []);
  });
});
