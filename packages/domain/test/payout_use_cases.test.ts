import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { PLATFORM_PAYEE } from '../src/payout.js';
import {
  approvePayout,
  createPayout,
  executePayout,
  holdPayout,
  listDuePayees,
  resumePayout,
} from '../src/payout_use_cases.js';
import { HOLD_REASON_REPEATED_FAILURE } from '../src/payout.js';
import {
  ADMIN,
  addAccount,
  createPayoutWorld,
  paidBooking,
  payoutHistory,
  release,
  releasedFor,
  type PayoutWorld,
} from './support/payout_world.js';

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
/** p1 is an individual: 7 % withheld. */
const PAID_NET = PAID - Math.round((PAID * 700) / 10_000);

/** An account that has been paid before, so the next payout is `pending` (no staff approval). */
async function paidBeforeAccount(w: PayoutWorld, accountNumber?: string) {
  const a = await addAccount(w, accountNumber);
  payoutHistory(w, a);
  return a;
}

function ledgerOf(w: PayoutWorld, type: string) {
  return [...w.store.ledgerEntries.values()].filter((e) => e.type === type);
}

describe('payout use cases', () => {
  it('a non-admin is permission_denied', async () => {
    const w = createPayoutWorld();
    const user = { uid: 'p1', isAdmin: false };
    await refused(createPayout(w.payoutDeps, user, 'p1'), 'permission_denied');
    await refused(executePayout(w.payoutDeps, user, 'x'), 'permission_denied');
    await refused(holdPayout(w.payoutDeps, user, 'x', 'long enough'), 'permission_denied');
    await refused(resumePayout(w.payoutDeps, user, 'x'), 'permission_denied');
    await refused(approvePayout(w.payoutDeps, user, 'x'), 'permission_denied');
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
    await paidBeforeAccount(w);
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
    assert.equal(po.status, 'needs_approval');
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
    await paidBeforeAccount(w);
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
      assert.equal(e.amount, -PAID_NET);
      assert.equal(e.accountOwnerId, 'p1');
      assert.equal(e.payoutId, po.id);
    }
    assert.deepEqual(w.payGateway.calls, [po.id]);
  });

  it('executing a paid payout is a conflict', async () => {
    const w = createPayoutWorld();
    await paidBeforeAccount(w);
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
    await paidBeforeAccount(w);
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
    await paidBeforeAccount(w);
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
    await paidBeforeAccount(w, '0123450000');
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
    await paidBeforeAccount(w);
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
    await paidBeforeAccount(w);
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

  it('createPayout snapshots fee, tax and net per item and in total', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const small = await releasedFor(w, '2026-10-15', 'p1', 450_000);
    const big = await releasedFor(w, '2026-10-16', 'p1', 1_500_000);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(po.items.find((i) => i.paymentId === small), { paymentId: small, amount: 450_000, fee: 0, tax: 31_500, net: 418_500 });
    assert.deepEqual(po.items.find((i) => i.paymentId === big), { paymentId: big, amount: 1_500_000, fee: 0, tax: 105_000, net: 1_395_000 });
    assert.equal(po.amount, 1_950_000);
    assert.equal(po.taxWithheld, 136_500);
    assert.equal(po.platformFee, 0);
    assert.equal(po.amountNet, po.items.reduce((s, i) => s + i.net, 0));
    assert.equal(po.amountNet, 1_813_500);
    assert.equal(po.amount, po.amountNet + po.taxWithheld + po.platformFee);
    assert.equal(po.taxRateBp, 700);
    assert.equal(po.feeRateBp, 0);
  });

  it('a studio payout withholds no tax', async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedPayeeType('p1', 'studio');
    await addAccount(w);
    await releasedFor(w, '2026-10-15', 'p1', 450_000);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(po.taxWithheld, 0);
    assert.equal(po.taxRateBp, 0);
    assert.equal(po.amountNet, 450_000);
  });

  it('the first payout to an account is needs_approval; the next one is pending', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const first = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(first.status, 'needs_approval');
    assert.equal(first.firstPayout, true);
    await approvePayout(w.payoutDeps, ADMIN, first.id);
    assert.equal((await executePayout(w.payoutDeps, ADMIN, first.id)).status, 'paid');
    await releasedPayment(w, '2026-10-16');
    const next = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(next.status, 'pending');
    assert.equal(next.firstPayout, false);
  });

  it('a failed first payout keeps the next one waiting for approval', async () => {
    const w = createPayoutWorld();
    await addAccount(w, '0123450000');
    await releasedPayment(w, '2026-10-15');
    const first = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await approvePayout(w.payoutDeps, ADMIN, first.id);
    assert.equal((await executePayout(w.payoutDeps, ADMIN, first.id)).status, 'failed');
    assert.equal((await createPayout(w.payoutDeps, ADMIN, 'p1')).status, 'needs_approval');
  });

  it('a payout paid to an older account does not count for a new one', async () => {
    const w = createPayoutWorld();
    await paidBeforeAccount(w);
    await addAccount(w, '9988776655');
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(po.status, 'needs_approval');
    assert.equal(po.firstPayout, true);
  });

  it('a pending_review account always gets needs_approval', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w, '0123456789', { nameStatus: 'pending_review' });
    payoutHistory(w, a);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(po.status, 'needs_approval');
    assert.equal(po.firstPayout, false);
  });

  it('three failed payouts in a row to the account make the next one on_hold with repeated_failure', async () => {
    const w = createPayoutWorld();
    const a = await paidBeforeAccount(w);
    payoutHistory(w, a, 'failed');
    payoutHistory(w, a, 'failed');
    await releasedPayment(w, '2026-10-15');
    const two = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(two.status, 'pending', 'two failures are not enough');
    // Its money goes back (as a failed execute would) and a third failure is recorded.
    w.payoutStore.payouts.delete(two.id);
    for (const it of two.items) {
      const pay = w.store.payments.get(it.paymentId);
      assert.ok(pay);
      w.store.payments.set(pay.id, { ...pay, payoutId: null });
    }
    payoutHistory(w, a, 'failed');
    const held = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(held.status, 'on_hold');
    assert.equal(held.holdReason, HOLD_REASON_REPEATED_FAILURE);
    await refused(executePayout(w.payoutDeps, ADMIN, held.id), 'conflict');
  });

  it('a paid payout after failures resets the count', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w);
    payoutHistory(w, a, 'failed');
    payoutHistory(w, a, 'failed');
    payoutHistory(w, a, 'failed');
    payoutHistory(w, a, 'paid');
    await releasedPayment(w, '2026-10-15');
    assert.equal((await createPayout(w.payoutDeps, ADMIN, 'p1')).status, 'pending');
  });

  it("createPayout refuses before the account's activeFrom (not_eligible)", async () => {
    const w = createPayoutWorld();
    const activeFrom = new Date(w.clock.now().getTime() + 72 * 3600_000).toISOString();
    await addAccount(w, '0123456789', { activeFrom });
    await releasedPayment(w, '2026-10-15');
    const writes = w.payoutStore.writes;
    await refused(createPayout(w.payoutDeps, ADMIN, 'p1'), 'not_eligible');
    assert.equal(w.payoutStore.writes, writes);
    w.clock.advanceHours(72);
    assert.equal((await createPayout(w.payoutDeps, ADMIN, 'p1')).status, 'needs_approval');
  });

  it('approvePayout: needs_approval → pending with approvedBy/approvedAt; any other status is conflict; non-admin permission_denied', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await refused(approvePayout(w.payoutDeps, { uid: 'p1', isAdmin: false }, po.id), 'permission_denied');
    w.clock.advanceMinutes(3);
    const ok = await approvePayout(w.payoutDeps, { uid: 'staff9', isAdmin: true }, po.id);
    assert.equal(ok.status, 'pending');
    assert.equal(ok.approvedBy, 'staff9');
    assert.equal(ok.approvedAt, w.clock.now().toISOString());
    assert.equal(ok.updatedAt, w.clock.now().toISOString());
    assert.deepEqual(w.payoutStore.payouts.get(po.id), ok);
    await refused(approvePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    await holdPayout(w.payoutDeps, ADMIN, po.id, 'Kiểm tra thêm');
    await refused(approvePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    await refused(approvePayout(w.payoutDeps, ADMIN, 'missing'), 'not_found');
  });

  it('approvePayout confirms a pending_review account (staff_confirmed) and its owner view', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w, '0123456789', { nameStatus: 'pending_review' });
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await approvePayout(w.payoutDeps, ADMIN, po.id);
    const stored = w.payoutStore.accounts.get(`p1/${a.id}`);
    assert.equal(stored?.nameStatus, 'staff_confirmed');
    assert.equal(stored?.accountNumberEnc, a.accountNumberEnc);
    const view = w.payoutStore.accountViews.get('p1');
    assert.equal(view?.accountId, a.id);
    assert.equal(view?.nameStatus, 'staff_confirmed');
    assert.equal(view?.activeFrom, a.activeFrom);
  });

  it('approvePayout leaves a matched account as it is', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const writes = w.payoutStore.writes;
    await approvePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(w.payoutStore.writes, writes + 1);
    assert.equal(w.payoutStore.accounts.get(`p1/${a.id}`)?.nameStatus, 'matched');
  });

  it('executePayout refuses a needs_approval payout (conflict)', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'conflict');
    assert.equal(w.payoutStore.payouts.get(po.id)?.status, 'needs_approval');
    assert.deepEqual(w.payGateway.calls, []);
  });

  it("executePayout refuses before the account's activeFrom (not_eligible) and writes nothing", async () => {
    const w = createPayoutWorld();
    const a = await paidBeforeAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    // The account turns "not active yet" (an account change re-points the payout during the 72 hours).
    const later = new Date(w.clock.now().getTime() + 72 * 3600_000).toISOString();
    w.payoutStore.accounts.set(`p1/${a.id}`, { ...a, activeFrom: later });
    const writes = w.payoutStore.writes;
    const ledger = w.store.ledgerEntries.size;
    await refused(executePayout(w.payoutDeps, ADMIN, po.id), 'not_eligible');
    assert.equal(w.payoutStore.writes, writes);
    assert.equal(w.store.ledgerEntries.size, ledger);
    assert.equal(w.payoutStore.payouts.get(po.id)?.status, 'pending');
    assert.deepEqual(w.payGateway.calls, []);
    w.clock.advanceHours(72);
    assert.equal((await executePayout(w.payoutDeps, ADMIN, po.id)).status, 'paid');
  });

  it('transfer receives amountNet', async () => {
    const w = createPayoutWorld();
    await paidBeforeAccount(w);
    await releasedFor(w, '2026-10-15', 'p1', 450_000);
    await releasedFor(w, '2026-10-16', 'p1', 1_500_000);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    const amounts: number[] = [];
    const real = w.payGateway.transfer.bind(w.payGateway);
    (w.payoutDeps.gateway as { transfer: typeof real }).transfer = async (r) => {
      amounts.push(r.amount);
      return real(r);
    };
    await executePayout(w.payoutDeps, ADMIN, po.id);
    assert.deepEqual(amounts, [1_813_500]);
  });

  it('ledger nets each paid payment to −amount', async () => {
    const w = createPayoutWorld();
    await paidBeforeAccount(w);
    const small = await releasedFor(w, '2026-10-15', 'p1', 450_000);
    const big = await releasedFor(w, '2026-10-16', 'p1', 1_500_000);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await executePayout(w.payoutDeps, ADMIN, po.id);
    const amountOf = (type: string, paymentId: string) =>
      ledgerOf(w, type).filter((e) => e.paymentId === paymentId).map((e) => e.amount);
    assert.deepEqual(amountOf('payout_paid', small), [-418_500]);
    assert.deepEqual(amountOf('tax_withheld', small), [-31_500]);
    assert.deepEqual(amountOf('payout_paid', big), [-1_395_000]);
    assert.deepEqual(amountOf('tax_withheld', big), [-105_000]);
    assert.equal(ledgerOf(w, 'platform_fee').length, 0, 'no zero-amount platform_fee entry');
    for (const item of po.items) {
      const total = [...w.store.ledgerEntries.values()]
        .filter((e) => e.paymentId === item.paymentId && e.payoutId === po.id)
        .reduce((s, e) => s + e.amount, 0);
      assert.equal(total, -item.amount);
    }
    for (const e of ledgerOf(w, 'tax_withheld')) {
      assert.equal(e.accountOwnerId, 'p1');
      assert.equal(e.payoutId, po.id);
    }
  });

  it('a platform fee is written to the ledger when the policy has one; a studio has no tax entry', async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedPayeeType('p1', 'studio');
    const deps = { ...w.payoutDeps, policy: { ...w.payoutDeps.policy, feeBp: { individual: 0, artist: 0, studio: 1000 } } };
    const a = await addAccount(w);
    payoutHistory(w, a);
    const pay = await releasedFor(w, '2026-10-15', 'p1', 450_500);
    const po = await createPayout(deps, ADMIN, 'p1');
    assert.equal(po.feeRateBp, 1000);
    await executePayout(deps, ADMIN, po.id);
    assert.deepEqual(ledgerOf(w, 'platform_fee').map((e) => [e.paymentId, e.amount]), [[pay, -45_050]]);
    assert.deepEqual(ledgerOf(w, 'payout_paid').map((e) => e.amount), [-405_450]);
    assert.equal(ledgerOf(w, 'tax_withheld').length, 0);
  });

  it('resumePayout goes to needs_approval when the account has no paid payout', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedPayment(w, '2026-10-15');
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await approvePayout(w.payoutDeps, ADMIN, po.id);
    await holdPayout(w.payoutDeps, ADMIN, po.id, 'Kiểm tra tài khoản');
    const resumed = await resumePayout(w.payoutDeps, ADMIN, po.id);
    assert.equal(resumed.status, 'needs_approval');
    assert.equal(resumed.holdReason, undefined);
  });
});
