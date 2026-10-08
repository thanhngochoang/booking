import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createHash } from 'node:crypto';
import type { AccountNameLookup } from '../src/account_lookup.js';
import { DomainError } from '../src/errors.js';
import { lookupPayoutAccountName, requestPayoutOtp } from '../src/payout_account_use_cases.js';
import { savePayoutAccount } from '../src/save_payout_account.js';
import { addAccount, createPayoutWorld } from './support/payout_world.js';

const P1 = { uid: 'p1' } as const;
const target = { bankCode: 'TCB', accountNumber: '5555 6666 77' };

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

const sha = (s: string): string => createHash('sha256').update(s, 'utf8').digest('hex');

describe('lookupPayoutAccountName', () => {
  it('lookupPayoutAccountName returns decision, holder and verified name', async () => {
    const w = createPayoutWorld();
    assert.deepEqual(await lookupPayoutAccountName(w.accountDeps, P1, { bankCode: 'VCB', accountNumber: '0123456789' }), {
      decision: 'matched',
      holderName: 'NGUYEN VAN AN',
      verifiedName: 'Nguyễn Văn An',
    });
    assert.deepEqual(await lookupPayoutAccountName(w.accountDeps, P1, { bankCode: 'VCB', accountNumber: '0123454321' }), {
      decision: 'mismatch',
      holderName: 'TRAN VAN B',
      verifiedName: 'Nguyễn Văn An',
    });
    assert.deepEqual(await lookupPayoutAccountName(w.accountDeps, P1, { bankCode: 'VCB', accountNumber: '0123459999' }), {
      decision: 'review',
      holderName: null,
      verifiedName: 'Nguyễn Văn An',
    });
    assert.deepEqual(await lookupPayoutAccountName(w.accountDeps, P1, { bankCode: 'VCB', accountNumber: '0123450404' }), {
      decision: 'not_found',
      holderName: null,
      verifiedName: 'Nguyễn Văn An',
    });
    w.names.delete('p1');
    assert.deepEqual(await lookupPayoutAccountName(w.accountDeps, P1, { bankCode: 'VCB', accountNumber: '0123459999' }), {
      decision: 'unverifiable',
      holderName: null,
      verifiedName: null,
    });
  });

  it('bad input is invalid_argument and is not counted', async () => {
    const w = createPayoutWorld();
    for (const raw of [null, { bankCode: 'VCB' }, { bankCode: 'XXX', accountNumber: '0123456789' }, { ...target, otpCode: '123456' }]) {
      await refused(lookupPayoutAccountName(w.accountDeps, P1, raw), 'invalid_argument');
    }
    assert.equal(w.payoutStore.writes, 0);
  });

  it('lookupPayoutAccountName: the 21st lookup of the day is limit_exceeded; the count resets the next Vietnam day', async () => {
    const w = createPayoutWorld(new Date('2026-10-10T16:59:00.000Z')); // 23:59 on 10/10 in Vietnam
    let calls = 0;
    const counting: AccountNameLookup = {
      lookup: (r) => {
        calls += 1;
        return w.accountDeps.lookup.lookup(r);
      },
    };
    const deps = { ...w.accountDeps, lookup: counting };
    for (let i = 0; i < 20; i += 1) {
      assert.equal((await lookupPayoutAccountName(deps, P1, target)).decision, 'matched');
    }
    await refused(lookupPayoutAccountName(deps, P1, target), 'limit_exceeded');
    assert.equal(calls, 20, 'a refused lookup never reaches the bank');
    assert.deepEqual(w.payoutStore.lookupQuotas.get('p1'), { day: '2026-10-10', count: 20 });
    w.clock.advanceMinutes(2); // 00:01 on 11/10 in Vietnam
    assert.equal((await lookupPayoutAccountName(deps, P1, target)).decision, 'matched');
    assert.deepEqual(w.payoutStore.lookupQuotas.get('p1'), { day: '2026-10-11', count: 1 });
  });

  it('lookup by a customer is permission_denied', async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedRole('c1', 'customer');
    await refused(lookupPayoutAccountName(w.accountDeps, { uid: 'c1' }, target), 'permission_denied');
    await refused(lookupPayoutAccountName(w.accountDeps, { uid: 'ghost' }, target), 'permission_denied');
    assert.equal(w.payoutStore.writes, 0);
  });
});

describe('requestPayoutOtp', () => {
  it("requestPayoutOtp sends a 6-digit code to the photographer's phone and stores only its hash", async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const now = w.clock.now();
    const res = await requestPayoutOtp(w.accountDeps, P1, target);
    assert.deepEqual(res, { phoneLast4: '5678', expiresInSeconds: 300, resendInSeconds: 60 });
    assert.equal(w.otpSender.sent.length, 1);
    const sent = w.otpSender.sent[0];
    assert.ok(sent);
    assert.equal(sent.phone, '0912345678');
    assert.match(sent.code, /^[0-9]{6}$/);
    const c = w.payoutStore.otpChallenges.get('p1');
    assert.ok(c);
    assert.equal(JSON.stringify(c).includes(sent.code), false, 'no plain code is stored');
    assert.equal(JSON.stringify(c).includes('5555666677'), false, 'no plain number is stored');
    assert.match(c.salt, /^[0-9a-f]{32}$/);
    assert.deepEqual(c, {
      uid: 'p1',
      purpose: 'payout_account',
      codeHash: sha(`${c.salt}:${sent.code}`),
      salt: c.salt,
      targetHash: sha(`${c.salt}:TCB:5555666677`),
      expiresAt: new Date(now.getTime() + 300_000).toISOString(),
      attempts: 0,
      sentAt: now.toISOString(),
      sendDay: '2026-10-10',
      sendsToday: 1,
      consumedAt: null,
    });
  });

  it('requestPayoutOtp without a current account is not_eligible; without a phone is phone_required', async () => {
    const w = createPayoutWorld();
    await refused(requestPayoutOtp(w.accountDeps, P1, target), 'not_eligible');
    await addAccount(w);
    w.phones.delete('p1');
    await refused(requestPayoutOtp(w.accountDeps, P1, target), 'phone_required');
    w.phones.set('p1', '   ');
    await refused(requestPayoutOtp(w.accountDeps, P1, target), 'phone_required');
    assert.deepEqual(w.otpSender.sent, []);
    assert.equal(w.payoutStore.otpChallenges.size, 0);
  });

  it('a customer is permission_denied and bad input is invalid_argument', async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedRole('c1', 'customer');
    w.phones.set('c1', '0900000000');
    let phoneReads = 0;
    let randomCalls = 0;
    const deps = {
      ...w.accountDeps,
      otp: {
        ...w.accountDeps.otp,
        phones: { phoneOf: (uid: string) => ((phoneReads += 1), w.accountDeps.otp.phones.phoneOf(uid)) },
        crypto: {
          sha256Hex: (x: string) => w.accountDeps.otp.crypto.sha256Hex(x),
          random: (n: number) => ((randomCalls += 1), w.accountDeps.otp.crypto.random(n)),
        },
      },
    };
    await refused(requestPayoutOtp(deps, { uid: 'c1' }, target), 'permission_denied');
    assert.deepEqual([phoneReads, randomCalls], [0, 0], 'the role is checked before the phone or the code');
    await refused(requestPayoutOtp(deps, P1, { ...target, holderName: 'X' }), 'invalid_argument');
    assert.deepEqual(w.otpSender.sent, []);
  });

  it('a resend within 60 s is limit_exceeded; the 6th send of the day is limit_exceeded', async () => {
    const w = createPayoutWorld(new Date('2026-10-10T10:00:00.000Z'));
    await addAccount(w);
    await requestPayoutOtp(w.accountDeps, P1, target);
    w.clock.setTime(new Date(w.clock.now().getTime() + 59_000));
    await refused(requestPayoutOtp(w.accountDeps, P1, target), 'limit_exceeded');
    w.clock.setTime(new Date(w.clock.now().getTime() + 1_000));
    await requestPayoutOtp(w.accountDeps, P1, target); // 2nd
    for (let i = 3; i <= 5; i += 1) {
      w.clock.advanceMinutes(1);
      await requestPayoutOtp(w.accountDeps, P1, target);
    }
    assert.equal(w.payoutStore.otpChallenges.get('p1')?.sendsToday, 5);
    w.clock.advanceMinutes(1);
    await refused(requestPayoutOtp(w.accountDeps, P1, target), 'limit_exceeded');
    assert.equal(w.otpSender.sent.length, 5);
    // The next Vietnam day (00:00 on 11/10 = 17:00 UTC) starts a new count.
    w.clock.setTime(new Date('2026-10-10T17:00:00.000Z'));
    await requestPayoutOtp(w.accountDeps, P1, target);
    assert.deepEqual(
      [w.payoutStore.otpChallenges.get('p1')?.sendDay, w.payoutStore.otpChallenges.get('p1')?.sendsToday],
      ['2026-10-11', 1],
    );
  });

  it('a resend replaces the code (the old code no longer saves; the new one does)', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    await requestPayoutOtp(w.accountDeps, P1, target);
    const oldCode = w.otpSender.sent.at(-1)?.code ?? '';
    w.clock.advanceMinutes(1);
    await requestPayoutOtp(w.accountDeps, P1, target);
    const newCode = w.otpSender.sent.at(-1)?.code ?? '';
    assert.notEqual(oldCode, newCode);
    // The old code is checked against the new code's hash: a wrong try, counted.
    await refused(savePayoutAccount(w.accountDeps, P1, { ...target, otpCode: oldCode }), 'otp_invalid');
    const res = await savePayoutAccount(w.accountDeps, P1, { ...target, otpCode: newCode });
    assert.equal(res.accountLast4, '6677');
  });
});
