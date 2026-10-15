import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { decideTransfer } from '../src/transfer_rules.js';
import type { PaymentStatus } from '../src/escrow.js';

const EXPIRES = '2026-10-10T10:15:00.000Z';
const base = {
  status: 'created' as PaymentStatus,
  amount: 1_500_000,
  receivedBefore: 0,
  expiresAt: EXPIRES,
  transferAmount: 1_500_000,
  receivedAt: '2026-10-10T10:05:00.000Z',
};

describe('decideTransfer', () => {
  it('exact amount within validity: paid, excess 0', () => {
    assert.deepEqual(decideTransfer(base), { kind: 'paid', excess: 0 });
  });

  it('over: paid, excess is the over-payment', () => {
    assert.deepEqual(decideTransfer({ ...base, transferAmount: 1_600_000 }), { kind: 'paid', excess: 100_000 });
  });

  it('under: partial with the amount received so far', () => {
    assert.deepEqual(decideTransfer({ ...base, transferAmount: 500_000 }), { kind: 'partial', received: 500_000 });
  });

  it('a second under-payment keeps adding up', () => {
    assert.deepEqual(
      decideTransfer({ ...base, receivedBefore: 500_000, transferAmount: 400_000 }),
      { kind: 'partial', received: 900_000 },
    );
  });

  it('top-up reaching the amount: paid, no excess', () => {
    assert.deepEqual(
      decideTransfer({ ...base, receivedBefore: 500_000, transferAmount: 1_000_000 }),
      { kind: 'paid', excess: 0 },
    );
  });

  it('top-up passing the amount: paid with only the extra as excess', () => {
    assert.deepEqual(
      decideTransfer({ ...base, receivedBefore: 1_000_000, transferAmount: 600_000 }),
      { kind: 'paid', excess: 100_000 },
    );
  });

  it('receivedAt at or after expiresAt: refund late_transfer even when the status is still created', () => {
    assert.deepEqual(decideTransfer({ ...base, receivedAt: EXPIRES }), {
      kind: 'refund',
      amount: 1_500_000,
      reason: 'late_transfer',
    });
    assert.deepEqual(decideTransfer({ ...base, receivedAt: '2026-10-10T10:15:00.001Z', transferAmount: 200_000 }), {
      kind: 'refund',
      amount: 200_000,
      reason: 'late_transfer',
    });
  });

  it('compares instants, not strings', () => {
    // 17:10 in +07:00 is 10:10Z: still valid; the lexical order would say it is late.
    assert.deepEqual(decideTransfer({ ...base, receivedAt: '2026-10-10T17:10:00.000+07:00' }), {
      kind: 'paid',
      excess: 0,
    });
    // Same instant as EXPIRES written in another offset: late.
    assert.deepEqual(decideTransfer({ ...base, receivedAt: '2026-10-10T17:15:00.000+07:00' }), {
      kind: 'refund',
      amount: 1_500_000,
      reason: 'late_transfer',
    });
  });

  it('status expired: refund late_transfer', () => {
    assert.deepEqual(decideTransfer({ ...base, status: 'expired' }), {
      kind: 'refund',
      amount: 1_500_000,
      reason: 'late_transfer',
    });
  });

  for (const status of ['paid', 'refunded', 'partially_refunded'] as const) {
    it(`status ${status}: refund extra_transfer`, () => {
      assert.deepEqual(decideTransfer({ ...base, status, receivedBefore: 1_500_000, transferAmount: 300_000 }), {
        kind: 'refund',
        amount: 300_000,
        reason: 'extra_transfer',
      });
    });
  }

  it('a paid payment stays extra_transfer even when the transfer is also past expiresAt', () => {
    assert.deepEqual(decideTransfer({ ...base, status: 'paid', receivedAt: '2026-10-10T11:00:00.000Z' }), {
      kind: 'refund',
      amount: 1_500_000,
      reason: 'extra_transfer',
    });
  });
});
