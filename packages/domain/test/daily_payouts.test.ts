import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { runDailyPayouts, type DailyPayoutReport } from '../src/daily_payouts.js';
import type { PayoutStore, PayoutTx } from '../src/payout_ports.js';
import { SYSTEM_PAYOUT_ACTOR, approvePayout } from '../src/payout_use_cases.js';
import { ADMIN, addAccount, createPayoutWorld, payoutHistory, releasedFor } from './support/payout_world.js';

const ZERO: DailyPayoutReport = {
  created: 0, needsApproval: 0, onHold: 0, executed: 0, paid: 0, failed: 0, noAccount: 0, notActive: 0, errors: 0,
};

describe('runDailyPayouts', () => {
  it('the system actor is an admin with its own uid', () => {
    assert.deepEqual(SYSTEM_PAYOUT_ACTOR, { uid: 'system:createPayouts', isAdmin: true });
  });

  it('creates one payout per due payee and executes it the same run', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w);
    payoutHistory(w, a);
    const pay = await releasedFor(w, '2026-10-15', 'p1', 450_000);
    const report = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(report, { ...ZERO, created: 1, executed: 1, paid: 1 });
    const created = [...w.payoutStore.payouts.values()].find((p) => p.items.some((i) => i.paymentId === pay));
    assert.equal(created?.status, 'paid');
    assert.equal(created?.createdBy, SYSTEM_PAYOUT_ACTOR.uid);
    assert.equal(w.store.payments.get(pay)?.escrowStatus, 'paid_out');
    assert.deepEqual(w.payGateway.calls, [created?.id]);
  });

  it('a first payout waits for approval and is not executed', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedFor(w, '2026-10-15');
    const report = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(report, { ...ZERO, created: 1, needsApproval: 1 });
    assert.deepEqual(w.payGateway.calls, []);
    // Once staff approve it, the next run sends it.
    const [po] = [...w.payoutStore.payouts.values()];
    assert.ok(po);
    await approvePayout(w.payoutDeps, ADMIN, po.id);
    assert.deepEqual(await runDailyPayouts(w.payoutDeps), { ...ZERO, executed: 1, paid: 1 });
  });

  it('a payee without an account calls notices.accountNeeded with the payee and the amount and creates no payout', async () => {
    const w = createPayoutWorld();
    await releasedFor(w, '2026-10-15', 'p1', 450_000);
    const report = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(report, { ...ZERO, noAccount: 1 });
    assert.deepEqual(w.notices.needed, [{ payeeId: 'p1', amount: 450_000 }]);
    assert.equal(w.payoutStore.payouts.size, 0);
  });

  it('a failing notice is reported to onError and the run goes on', async () => {
    const w = createPayoutWorld();
    await releasedFor(w, '2026-10-15', 'p2', 450_000);
    const a = await addAccount(w);
    payoutHistory(w, a);
    await releasedFor(w, '2026-10-16', 'p1', 450_000);
    const notices = {
      accountNeeded: async () => { throw new Error('push down'); },
      accountChanged: async () => undefined,
    };
    const deps = { ...w.payoutDeps, notices };
    const errors: [string, string][] = [];
    const report = await runDailyPayouts(deps, (id, step) => errors.push([id, step]));
    assert.deepEqual(report, { ...ZERO, noAccount: 1, created: 1, executed: 1, paid: 1 });
    assert.deepEqual(errors, [['p2', 'create']]);
  });

  it('a payee inside the 72 hours is skipped', async () => {
    const w = createPayoutWorld();
    const activeFrom = new Date(w.clock.now().getTime() + 72 * 3600_000).toISOString();
    const a = await addAccount(w, '0123456789', { activeFrom });
    payoutHistory(w, a);
    await releasedFor(w, '2026-10-15');
    const report = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(report, { ...ZERO, notActive: 1 });
    assert.equal(w.notices.needed.length, 0);
    assert.deepEqual(w.payGateway.calls, []);
  });

  it('running twice creates nothing new', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w);
    payoutHistory(w, a);
    await releasedFor(w, '2026-10-15');
    await runDailyPayouts(w.payoutDeps);
    const calls = [...w.payGateway.calls];
    const payouts = w.payoutStore.payouts.size;
    const second = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(second, ZERO);
    assert.deepEqual(w.payGateway.calls, calls);
    assert.equal(w.payoutStore.payouts.size, payouts);
  });

  it("one payee's failure does not stop the others", async () => {
    const w = createPayoutWorld();
    const a1 = await addAccount(w);
    payoutHistory(w, a1);
    const a2 = await addAccount(w, '1111222233', { uid: 'p2' });
    payoutHistory(w, a2);
    const p1Pay = await releasedFor(w, '2026-10-15', 'p1');
    await releasedFor(w, '2026-10-16', 'p2');
    const real = w.payoutStore;
    const store: PayoutStore = {
      listDuePayees: () => real.listDuePayees(),
      listPayoutIdsByStatus: (s, n) => real.listPayoutIdsByStatus(s, n),
      runTransaction: (fn) =>
        real.runTransaction((tx) => {
          const broken: PayoutTx = {
            ...tx,
            getPayeeType: async (uid) => {
              if (uid === 'p2') throw new Error('store down');
              return tx.getPayeeType(uid);
            },
          };
          return fn(broken);
        }),
    };
    const errors: [string, string, unknown][] = [];
    const report = await runDailyPayouts({ ...w.payoutDeps, store }, (id, step, e) => errors.push([id, step, e]));
    assert.deepEqual(report, { ...ZERO, created: 1, executed: 1, paid: 1, errors: 1 });
    assert.equal(w.store.payments.get(p1Pay)?.escrowStatus, 'paid_out');
    assert.equal(errors.length, 1);
    assert.equal(errors[0]?.[0], 'p2');
    assert.equal(errors[0]?.[1], 'create');
    assert.match(String(errors[0]?.[2]), /store down/);
  });

  it('an execute error is reported with the payout id and step execute', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w);
    payoutHistory(w, a);
    await releasedFor(w, '2026-10-15');
    const deps = { ...w.payoutDeps, cipher: { ...w.payoutDeps.cipher, decrypt: async () => { throw new Error('bad key'); } } };
    const errors: [string, string][] = [];
    const report = await runDailyPayouts(deps, (id, step) => errors.push([id, step]));
    assert.deepEqual(report, { ...ZERO, created: 1, errors: 1 });
    const pending = [...w.payoutStore.payouts.values()].find((p) => p.status === 'pending');
    assert.ok(pending);
    assert.deepEqual(errors, [[pending.id, 'execute']]);
  });

  it('a failed transfer is counted and the money is payable again next run', async () => {
    const w = createPayoutWorld();
    const a = await addAccount(w, '0123450000');
    payoutHistory(w, a);
    const pay = await releasedFor(w, '2026-10-15', 'p1', 450_000);
    assert.deepEqual(await runDailyPayouts(w.payoutDeps), { ...ZERO, created: 1, executed: 1, failed: 1 });
    assert.equal(w.store.payments.get(pay)?.payoutId, null);
    assert.equal(w.store.payments.get(pay)?.escrowStatus, 'released');
    assert.deepEqual(await w.payoutStore.listDuePayees(), [{ payeeId: 'p1', amount: 450_000, hasAccount: true }]);
    w.clock.advanceHours(24);
    assert.deepEqual(await runDailyPayouts(w.payoutDeps), { ...ZERO, created: 1, executed: 1, failed: 1 });
    assert.equal(w.payGateway.calls.length, 2);
  });

  it('an approved first payout lets the next day\'s payout go without a second approval', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await releasedFor(w, '2026-10-15');
    // Day 1: A is created and waits for staff.
    assert.deepEqual(await runDailyPayouts(w.payoutDeps), { ...ZERO, created: 1, needsApproval: 1 });
    const [a] = [...w.payoutStore.payouts.values()];
    assert.ok(a);
    await approvePayout(w.payoutDeps, ADMIN, a.id);
    // Day 2: new money arrives before A is sent; B is created pending, then both are sent.
    w.clock.advanceHours(24);
    const later = await releasedFor(w, '2026-10-16');
    const report = await runDailyPayouts(w.payoutDeps);
    assert.deepEqual(report, { ...ZERO, created: 1, executed: 2, paid: 2 });
    const b = [...w.payoutStore.payouts.values()].find((p) => p.items.some((i) => i.paymentId === later));
    assert.ok(b);
    assert.equal(b.firstPayout, false);
    assert.equal(b.approvedBy, undefined);
    assert.equal(b.status, 'paid');
  });
});
