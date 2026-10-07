import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { MemoryPayoutStore } from '../src/memory_payout_store.js';
import type { Payout, PayoutStatus } from '../src/payout.js';
import type { AccountCipher, PayoutAccountDeps } from '../src/payout_ports.js';
import { savePayoutAccount, type Caller } from '../src/save_payout_account.js';
import { ControllableClock, SequentialIdGen } from './support/booking_world.js';

const NOW = new Date('2026-10-06T10:00:00.000Z');

const cipher: AccountCipher = {
  encrypt: async (p) => `enc:${[...p].reverse().join('')}`,
  decrypt: async (e) => [...e.slice(4)].reverse().join(''),
};

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

describe('savePayoutAccount', () => {
  let store: MemoryPayoutStore;
  let deps: PayoutAccountDeps;
  const fresh: Caller = { uid: 'p1', authTime: new Date(NOW.getTime() - 60_000) };
  const stale: Caller = { uid: 'p1', authTime: new Date(NOW.getTime() - 301_000) };
  const input = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
    bankCode: 'VCB',
    accountNumber: '0123 456 789',
    holderName: 'Nguyễn Văn An',
    ...over,
  });
  const payout = (id: string, status: PayoutStatus): Payout => ({
    id,
    payeeId: 'p1',
    accountId: 'old',
    amount: 100,
    status,
    items: [{ paymentId: `pay-${id}`, amount: 100 }],
    createdBy: 'admin',
    createdAt: NOW.toISOString(),
    updatedAt: NOW.toISOString(),
  });

  beforeEach(() => {
    store = new MemoryPayoutStore();
    store.seedRole('p1', 'photographer');
    store.seedRole('c1', 'customer');
    deps = { store, cipher, clock: new ControllableClock(NOW), ids: new SequentialIdGen('acc') };
  });

  it('first save creates one active account and the view', async () => {
    const res = await savePayoutAccount(deps, stale, input());
    assert.equal(res.accountLast4, '6789');
    const accounts = [...store.accounts.values()];
    assert.equal(accounts.length, 1);
    assert.equal(accounts[0]?.active, true);
    assert.equal(accounts[0]?.id, res.accountId);
    const view = store.accountViews.get('p1');
    assert.deepEqual(view, {
      accountId: res.accountId,
      bankCode: 'VCB',
      accountLast4: '6789',
      holderName: 'NGUYEN VAN AN',
      updatedAt: NOW.toISOString(),
    });
  });

  it('the stored account holds no plain digits beyond the last four', async () => {
    await savePayoutAccount(deps, fresh, input());
    const dump = JSON.stringify([...store.accounts.values(), ...store.accountViews.values()]);
    assert.equal(dump.includes('0123456789'), false);
    assert.equal(dump.includes('012345'), false);
    assert.equal(dump.includes('987654321'.slice(0, 6)), true); // reversed ciphertext only
  });

  it('a customer is permission_denied', async () => {
    await refused(savePayoutAccount(deps, { uid: 'c1', authTime: NOW }, input()), 'permission_denied');
    await refused(savePayoutAccount(deps, { uid: 'ghost', authTime: NOW }, input()), 'permission_denied');
    assert.equal(store.writes, 0);
  });

  it('extra keys are invalid_argument', async () => {
    await refused(savePayoutAccount(deps, fresh, input({ active: true })), 'invalid_argument');
    await refused(savePayoutAccount(deps, fresh, { bankCode: 'VCB', accountNumber: '123456' }), 'invalid_argument');
    await refused(savePayoutAccount(deps, fresh, input({ bankCode: 'XXX' })), 'invalid_argument');
    await refused(savePayoutAccount(deps, fresh, input({ accountNumber: '12' })), 'invalid_argument');
    await refused(savePayoutAccount(deps, fresh, input({ holderName: 'A1' })), 'invalid_argument');
    await refused(savePayoutAccount(deps, fresh, null), 'invalid_argument');
    assert.equal(store.writes, 0);
  });

  it('a change without a recent sign-in is reauth_required', async () => {
    await savePayoutAccount(deps, stale, input());
    const writes = store.writes;
    await refused(savePayoutAccount(deps, stale, input({ accountNumber: '999999' })), 'reauth_required');
    await refused(savePayoutAccount(deps, { uid: 'p1', authTime: null }, input({ accountNumber: '999999' })), 'reauth_required');
    assert.equal(store.writes, writes);
  });

  it('a change within five minutes deactivates the old account', async () => {
    const first = await savePayoutAccount(deps, stale, input());
    const second = await savePayoutAccount(deps, fresh, input({ bankCode: 'TCB', accountNumber: '555566' }));
    const old = store.accounts.get(`p1/${first.accountId}`);
    assert.equal(old?.active, false);
    assert.equal(old?.deactivatedAt, NOW.toISOString());
    assert.equal(store.accounts.get(`p1/${second.accountId}`)?.active, true);
    assert.equal([...store.accounts.values()].filter((a) => a.active).length, 1);
    assert.equal(store.accountViews.get('p1')?.accountId, second.accountId);
    assert.equal(store.accountViews.get('p1')?.accountLast4, '5566');
  });

  it('a change re-points pending payouts and keeps paid ones', async () => {
    await savePayoutAccount(deps, stale, input());
    store.seedPayout(payout('a', 'pending'));
    store.seedPayout(payout('b', 'on_hold'));
    store.seedPayout(payout('c', 'paid'));
    store.seedPayout(payout('d', 'failed'));
    const next = await savePayoutAccount(deps, fresh, input({ accountNumber: '777788' }));
    assert.equal(store.payouts.get('a')?.accountId, next.accountId);
    assert.equal(store.payouts.get('b')?.accountId, next.accountId);
    assert.equal(store.payouts.get('c')?.accountId, 'old');
    assert.equal(store.payouts.get('d')?.accountId, 'old');
  });

  it('a change during processing is a conflict and writes nothing', async () => {
    const first = await savePayoutAccount(deps, stale, input());
    store.seedPayout(payout('a', 'processing'));
    const writes = store.writes;
    await refused(savePayoutAccount(deps, fresh, input({ accountNumber: '777788' })), 'conflict');
    assert.equal(store.writes, writes);
    assert.equal(store.accounts.get(`p1/${first.accountId}`)?.active, true);
  });

  it('two first saves racing leave one active account', async () => {
    const results = await Promise.allSettled([
      savePayoutAccount(deps, stale, input()),
      savePayoutAccount(deps, stale, input({ accountNumber: '999999' })),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const failed = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    assert.ok(failed.reason instanceof DomainError && failed.reason.code === 'reauth_required');
    assert.equal([...store.accounts.values()].filter((a) => a.active).length, 1);
  });
});
