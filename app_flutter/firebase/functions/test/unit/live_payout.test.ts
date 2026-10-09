import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError, type NotifyDeps, type NotifyResult } from '@photobooking/domain';
import { livePayoutNotices } from '../../src/infra/live_payout.js';
import { captureLogs } from './support/payment_world.js';

const DEPS = { marker: 'notify-deps' } as unknown as NotifyDeps;
const SENT = { sent: true } as unknown as NotifyResult;

describe('livePayoutNotices', () => {
  it('livePayoutNotices forwards payee, amount and account id to the #138 hooks', async () => {
    const needed: unknown[] = [];
    const changed: unknown[] = [];
    const notices = livePayoutNotices(
      {
        needed: async (deps, e) => {
          needed.push({ deps, e });
          return SENT;
        },
        changed: async (deps, e) => {
          changed.push({ deps, e });
          return SENT;
        },
      },
      () => DEPS,
    );
    await notices.accountNeeded('p1', 418_500);
    await notices.accountChanged('p1', {
      accountId: 'a2', bankCode: 'VCB', accountLast4: '6789', activeFrom: '2026-10-13T12:00:00.000Z',
    });
    assert.deepEqual(needed, [{ deps: DEPS, e: { payeeId: 'p1', amount: 418_500 } }]);
    assert.deepEqual(changed, [
      { deps: DEPS, e: { uid: 'p1', accountId: 'a2', bankCode: 'VCB', accountLast4: '6789', activeFrom: '2026-10-13T12:00:00.000Z' } },
    ]);
  });

  it('a failing hook is logged by its code only and never thrown', async (t) => {
    const notices = livePayoutNotices(
      {
        needed: async () => {
          throw new DomainError('conflict');
        },
        changed: async () => {
          throw new Error('write failed for account 0123456789');
        },
      },
      () => DEPS,
    );
    const lines = await captureLogs(t, async () => {
      await notices.accountNeeded('p1', 1);
      await notices.accountChanged('p1', { accountId: 'a2', bankCode: 'VCB', accountLast4: '6789', activeFrom: '2026-10-13T12:00:00.000Z' });
    });
    const failed = lines.filter((l) => l.includes('payout notice failed'));
    assert.equal(failed.length, 2, lines.join(''));
    assert.match(failed[0] ?? '', /"code":"conflict"/);
    assert.match(failed[1] ?? '', /"code":"Error"/);
    for (const l of lines) assert.doesNotMatch(l, /0123456789|write failed/, l);
  });
});
