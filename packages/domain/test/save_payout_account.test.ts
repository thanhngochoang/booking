import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import type { Payout, PayoutStatus } from '../src/payout.js';
import { normalizeHolderName } from '../src/payout_account.js';
import { savePayoutAccount } from '../src/save_payout_account.js';
import { resumePayout } from '../src/payout_use_cases.js';
import { ADMIN, createPayoutWorld, otpFor, type PayoutWorld } from './support/payout_world.js';

const P1 = { uid: 'p1' } as const;
const HOUR = 3600_000;

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

const first = { bankCode: 'VCB', accountNumber: '0123 456 789' };
const second = { bankCode: 'TCB', accountNumber: '5555666677' };

/** p1 saves their first account (VCB 0123456789). */
async function withFirst(w: PayoutWorld) {
  return savePayoutAccount(w.accountDeps, P1, first);
}

function wrongCode(code: string): string {
  return code === '000000' ? '111111' : '000000';
}

describe('savePayoutAccount v2', () => {
  it('first account: no OTP, active at once, nameStatus matched, holder = looked-up name', async () => {
    const w = createPayoutWorld();
    const now = w.clock.now().toISOString();
    const res = await withFirst(w);
    assert.deepEqual(res, { accountId: res.accountId, accountLast4: '6789', activeFrom: now, nameStatus: 'matched' });
    const accounts = [...w.payoutStore.accounts.values()];
    assert.equal(accounts.length, 1);
    const a = accounts[0];
    assert.ok(a);
    assert.equal(a.id, res.accountId);
    assert.equal(a.active, true);
    assert.equal(a.holderName, normalizeHolderName('Nguyễn Văn An'));
    assert.equal(a.activeFrom, now);
    assert.equal(a.nameStatus, 'matched');
    assert.deepEqual(w.payoutStore.accountViews.get('p1'), {
      accountId: res.accountId,
      bankCode: 'VCB',
      accountLast4: '6789',
      holderName: 'NGUYEN VAN AN',
      updatedAt: now,
      nameStatus: 'matched',
      activeFrom: now,
    });
    assert.deepEqual(w.otpSender.sent, []);
    assert.deepEqual(w.notices.changed, []);
  });

  it('refuses holderName in the input (invalid_argument) and refuses unknown keys', async () => {
    const w = createPayoutWorld();
    const bad: unknown[] = [
      { ...first, holderName: 'Nguyễn Văn An' },
      { ...first, active: true },
      { bankCode: 'VCB' },
      { accountNumber: '0123456789' },
      { ...first, bankCode: 'XXX' },
      { ...first, accountNumber: '12' },
      { ...first, otpCode: '12345' },
      { ...first, otpCode: 123456 },
      { ...first, otpCode: '12345a' },
      null,
      [first],
      'VCB 0123456789',
    ];
    for (const raw of bad) await refused(savePayoutAccount(w.accountDeps, P1, raw), 'invalid_argument');
    assert.equal(w.payoutStore.writes, 0);
  });

  it('a customer is permission_denied', async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedRole('c1', 'customer');
    await refused(savePayoutAccount(w.accountDeps, { uid: 'c1' }, first), 'permission_denied');
    await refused(savePayoutAccount(w.accountDeps, { uid: 'ghost' }, first), 'permission_denied');
    // The role is checked before the lookup's refusal is reported.
    await refused(savePayoutAccount(w.accountDeps, { uid: 'c1' }, { ...first, accountNumber: '0123454321' }), 'permission_denied');
    assert.equal(w.payoutStore.writes, 0);
  });

  it('mismatch is name_mismatch and writes nothing; not_found is not_found; unverifiable is not_eligible', async () => {
    const w = createPayoutWorld();
    await refused(savePayoutAccount(w.accountDeps, P1, { ...first, accountNumber: '0123454321' }), 'name_mismatch');
    await refused(savePayoutAccount(w.accountDeps, P1, { ...first, accountNumber: '0123450404' }), 'not_found');
    w.names.delete('p1');
    await refused(savePayoutAccount(w.accountDeps, P1, { ...first, accountNumber: '0123459999' }), 'not_eligible');
    assert.equal(w.payoutStore.writes, 0);
    assert.equal(w.payoutStore.accounts.size, 0);
  });

  it('unsupported bank with a verified name saves pending_review with the verified name as holder', async () => {
    const w = createPayoutWorld();
    const res = await savePayoutAccount(w.accountDeps, P1, { ...first, accountNumber: '0123459999' });
    assert.equal(res.nameStatus, 'pending_review');
    const a = w.payoutStore.accounts.get(`p1/${res.accountId}`);
    assert.equal(a?.holderName, 'NGUYEN VAN AN');
    assert.equal(a?.nameStatus, 'pending_review');
    assert.equal(w.payoutStore.accountViews.get('p1')?.nameStatus, 'pending_review');
  });

  it('no verified name: the looked-up name is saved for staff review', async () => {
    const w = createPayoutWorld();
    w.names.delete('p1');
    const res = await savePayoutAccount(w.accountDeps, P1, { ...first, accountNumber: '0123454321' });
    assert.equal(res.nameStatus, 'pending_review');
    assert.equal(w.payoutStore.accounts.get(`p1/${res.accountId}`)?.holderName, 'TRAN VAN B');
  });

  it('a change without otpCode is otp_required', async () => {
    const w = createPayoutWorld();
    const one = await withFirst(w);
    const writes = w.payoutStore.writes;
    await refused(savePayoutAccount(w.accountDeps, P1, second), 'otp_required');
    assert.equal(w.payoutStore.writes, writes);
    assert.equal(w.payoutStore.accountViews.get('p1')?.accountId, one.accountId);
  });

  it('a change with the right code: old account inactive, new active from now + 72 h, view updated, notices.accountChanged called', async () => {
    const w = createPayoutWorld();
    const one = await withFirst(w);
    w.clock.advanceMinutes(10);
    const code = await otpFor(w, second);
    const now = w.clock.now();
    const activeFrom = new Date(now.getTime() + 72 * HOUR).toISOString();
    const two = await savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code });
    assert.deepEqual(two, { accountId: two.accountId, accountLast4: '6677', activeFrom, nameStatus: 'matched' });
    const old = w.payoutStore.accounts.get(`p1/${one.accountId}`);
    assert.equal(old?.active, false);
    assert.equal(old?.deactivatedAt, now.toISOString());
    const fresh = w.payoutStore.accounts.get(`p1/${two.accountId}`);
    assert.equal(fresh?.active, true);
    assert.equal(fresh?.activeFrom, activeFrom);
    assert.equal(fresh?.createdAt, now.toISOString());
    assert.equal(fresh?.bankCode, 'TCB');
    assert.equal([...w.payoutStore.accounts.values()].filter((a) => a.active).length, 1);
    assert.deepEqual(w.payoutStore.accountViews.get('p1'), {
      accountId: two.accountId,
      bankCode: 'TCB',
      accountLast4: '6677',
      holderName: 'NGUYEN VAN AN',
      updatedAt: now.toISOString(),
      nameStatus: 'matched',
      activeFrom,
    });
    assert.deepEqual(w.notices.changed, [
      { uid: 'p1', accountId: two.accountId, bankCode: 'TCB', accountLast4: '6677', activeFrom },
    ]);
    assert.ok(w.payoutStore.otpChallenges.get('p1')?.consumedAt, 'the code is used up');
  });

  it('a failing notice never fails the save', async () => {
    const w = createPayoutWorld();
    await withFirst(w);
    const code = await otpFor(w, second);
    const deps = {
      ...w.accountDeps,
      notices: { accountNeeded: async () => undefined, accountChanged: async () => { throw new Error('push down'); } },
    };
    const res = await savePayoutAccount(deps, P1, { ...second, otpCode: code });
    assert.equal(w.payoutStore.accountViews.get('p1')?.accountId, res.accountId);
  });

  it('wrong codes are counted across calls and the 6th try is limit_exceeded even with the right code', async () => {
    const w = createPayoutWorld();
    const one = await withFirst(w);
    const code = await otpFor(w, second);
    for (let i = 1; i <= 5; i += 1) {
      await refused(savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: wrongCode(code) }), 'otp_invalid');
      assert.equal(w.payoutStore.otpChallenges.get('p1')?.attempts, i, 'the attempt is persisted although the call fails');
    }
    await refused(savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code }), 'limit_exceeded');
    assert.equal(w.payoutStore.accountViews.get('p1')?.accountId, one.accountId);
    assert.equal([...w.payoutStore.accounts.values()].length, 1);
    assert.deepEqual(w.notices.changed, []);
  });

  it('a consumed code is otp_required', async () => {
    const w = createPayoutWorld();
    await withFirst(w);
    const code = await otpFor(w, second);
    const two = await savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code });
    await refused(savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code }), 'otp_required');
    assert.equal(w.payoutStore.accountViews.get('p1')?.accountId, two.accountId);
  });

  it('a code for another account is otp_required', async () => {
    const w = createPayoutWorld();
    await withFirst(w);
    const code = await otpFor(w, second); // requested for TCB 5555666677
    const writes = w.payoutStore.writes;
    await refused(savePayoutAccount(w.accountDeps, P1, { bankCode: 'TCB', accountNumber: '5555666688', otpCode: code }), 'otp_required');
    await refused(savePayoutAccount(w.accountDeps, P1, { bankCode: 'MB', accountNumber: '5555666677', otpCode: code }), 'otp_required');
    assert.equal(w.payoutStore.writes, writes);
    assert.equal(w.payoutStore.otpChallenges.get('p1')?.attempts, 0);
  });

  it('an expired code is otp_expired', async () => {
    const w = createPayoutWorld();
    await withFirst(w);
    const code = await otpFor(w, second);
    w.clock.advanceMinutes(5);
    await refused(savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code }), 'otp_expired');
  });

  it('a change re-points open payouts and sends them to needs_approval', async () => {
    const w = createPayoutWorld();
    const one = await withFirst(w);
    const at = w.clock.now().toISOString();
    const payout = (id: string, status: PayoutStatus, approved: boolean): Payout => ({
      id,
      payeeId: 'p1',
      accountId: one.accountId,
      amount: 100,
      status,
      items: [{ paymentId: `pay-${id}`, amount: 100, fee: 0, tax: 7, net: 93 }],
      platformFee: 0,
      taxWithheld: 7,
      amountNet: 93,
      feeRateBp: 0,
      taxRateBp: 700,
      firstPayout: true,
      ...(approved ? { approvedBy: 'staff9', approvedAt: at } : {}),
      createdBy: 'admin',
      createdAt: at,
      updatedAt: at,
    });
    w.payoutStore.seedPayout(payout('pend', 'pending', true));
    w.payoutStore.seedPayout(payout('wait', 'needs_approval', false));
    w.payoutStore.seedPayout(payout('held', 'on_hold', true));
    w.payoutStore.seedPayout(payout('paid', 'paid', true));
    w.payoutStore.seedPayout(payout('fail', 'failed', true));
    const code = await otpFor(w, second);
    const two = await savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code });
    const get = (id: string) => w.payoutStore.payouts.get(id);
    assert.deepEqual(
      ['pend', 'wait', 'held', 'paid', 'fail'].map((id) => [id, get(id)?.status, get(id)?.accountId === two.accountId]),
      [
        ['pend', 'needs_approval', true],
        ['wait', 'needs_approval', true],
        ['held', 'on_hold', true],
        ['paid', 'paid', false],
        ['fail', 'failed', false],
      ],
    );
    // An approval given for the old account does not carry over to the new one.
    for (const id of ['pend', 'wait', 'held']) {
      assert.equal(get(id)?.approvedBy, undefined, id);
      assert.equal(get(id)?.approvedAt, undefined, id);
      assert.equal(get(id)?.firstPayout, true, id);
    }
    assert.equal(get('paid')?.approvedBy, 'staff9');
    assert.equal((await resumePayout(w.payoutDeps, ADMIN, 'held')).status, 'needs_approval');
  });

  it('a change while a payout is processing is conflict', async () => {
    const w = createPayoutWorld();
    const one = await withFirst(w);
    const at = w.clock.now().toISOString();
    w.payoutStore.seedPayout({
      id: 'proc', payeeId: 'p1', accountId: one.accountId, amount: 100, status: 'processing',
      items: [{ paymentId: 'pay-proc', amount: 100, fee: 0, tax: 7, net: 93 }],
      platformFee: 0, taxWithheld: 7, amountNet: 93, feeRateBp: 0, taxRateBp: 700, firstPayout: false,
      createdBy: 'admin', createdAt: at, updatedAt: at,
    });
    const code = await otpFor(w, second);
    const writes = w.payoutStore.writes;
    await refused(savePayoutAccount(w.accountDeps, P1, { ...second, otpCode: code }), 'conflict');
    assert.equal(w.payoutStore.writes, writes);
    assert.equal(w.payoutStore.accounts.get(`p1/${one.accountId}`)?.active, true);
    assert.equal(w.payoutStore.otpChallenges.get('p1')?.consumedAt, null);
  });

  it('two first saves racing leave one active account', async () => {
    const w = createPayoutWorld();
    const results = await Promise.allSettled([
      savePayoutAccount(w.accountDeps, P1, first),
      savePayoutAccount(w.accountDeps, P1, second),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const failed = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    assert.ok(failed.reason instanceof DomainError && failed.reason.code === 'otp_required');
    assert.equal([...w.payoutStore.accounts.values()].filter((a) => a.active).length, 1);
  });

  it('the account number never appears in a thrown error or a stored field except accountNumberEnc', async () => {
    const w = createPayoutWorld();
    const numbers = ['0123456789', '5555666677', '0123454321', '0123450404', '7777888899'];
    const errors: unknown[] = [];
    const attempt = async (raw: unknown): Promise<void> => {
      try {
        await savePayoutAccount(w.accountDeps, P1, raw);
      } catch (e) {
        errors.push(e);
      }
    };
    await attempt(first);
    await attempt({ ...first, accountNumber: '0123454321' }); // name_mismatch
    await attempt({ ...first, accountNumber: '0123450404' }); // not_found
    await attempt({ ...first, accountNumber: '7777888899' }); // otp_required
    const code = await otpFor(w, second);
    await attempt({ ...second, otpCode: wrongCode(code) }); // otp_invalid
    await attempt({ ...second, otpCode: code });
    assert.equal(errors.length, 4);
    const errorText = errors.map((e) => `${String(e)} ${(e as Error).stack ?? ''} ${JSON.stringify(e)}`).join('\n');
    const stored = JSON.stringify(
      {
        accounts: [...w.payoutStore.accounts.values()],
        views: [...w.payoutStore.accountViews.values()],
        payouts: [...w.payoutStore.payouts.values()],
        otp: [...w.payoutStore.otpChallenges.values()],
        quotas: [...w.payoutStore.lookupQuotas.values()],
        notices: w.notices.changed,
      },
      (key, value: unknown) => (key === 'accountNumberEnc' ? undefined : value),
    );
    for (const n of numbers) {
      for (const text of [errorText, stored]) {
        assert.equal(text.includes(n), false, `${n} leaked`);
        assert.equal(text.includes(n.slice(0, 6)), false, `${n.slice(0, 6)} leaked`);
      }
    }
  });
});
