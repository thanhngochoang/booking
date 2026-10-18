import assert from 'node:assert/strict';
import test from 'node:test';

import { DomainError } from '../src/errors.js';
import {
  DEFAULT_MILESTONE_PERCENTS,
  MILESTONE_KINDS,
  milestoneAmounts,
  splitMilestones,
  aggregateEscrow,
  withMilestones,
  releaseDueMilestones,
} from '../src/milestones.js';
import { milestoneAmounts as milestoneAmountsFromIndex } from '../src/index.js';

test('default 50/50: 1_500_001 → shoot 750_000, delivery 750_001', () => {
  const result = milestoneAmounts(1_500_001);
  assert.deepEqual(result, { shoot: 750_000, delivery: 750_001 });
});

test('percents {shoot: 30, delivery: 70} on 1_000_001 → 300_000 / 700_001', () => {
  const result = milestoneAmounts(1_000_001, { shoot: 30, delivery: 70 });
  assert.deepEqual(result, { shoot: 300_000, delivery: 700_001 });
});

test('3_400_000 → 1_700_000 / 1_700_000', () => {
  const result = milestoneAmounts(3_400_000);
  assert.deepEqual(result, { shoot: 1_700_000, delivery: 1_700_000 });
});

test('0 → 0 / 0; {shoot: 0, delivery: 100} on 999 → 0 / 999; {shoot: 100, delivery: 0} on 999 → 999 / 0', () => {
  assert.deepEqual(milestoneAmounts(0), { shoot: 0, delivery: 0 });
  assert.deepEqual(milestoneAmounts(999, { shoot: 0, delivery: 100 }), {
    shoot: 0,
    delivery: 999,
  });
  assert.deepEqual(milestoneAmounts(999, { shoot: 100, delivery: 0 }), {
    shoot: 999,
    delivery: 0,
  });
});

test('shoot + delivery equals net for every net and percent pair', () => {
  const check = (net: number, p: number) => {
    const res = milestoneAmounts(net, { shoot: p, delivery: 100 - p });
    assert.equal(res.shoot + res.delivery, net);
    assert.equal(res.shoot, Math.floor((net * p) / 100));
  };

  for (let net = 0; net <= 1000; net += 25) {
    for (let p = 0; p <= 100; p += 5) {
      check(net, p);
    }
  }

  for (let net = 1_000_000; net <= 1_000_100; net += 10) {
    for (let p = 0; p <= 100; p += 10) {
      check(net, p);
    }
  }
});

test('exact at Number.MAX_SAFE_INTEGER', () => {
  const maxSafe = Number.MAX_SAFE_INTEGER; // 9_007_199_254_740_991
  const result = milestoneAmounts(maxSafe);
  assert.deepEqual(result, {
    shoot: 4_503_599_627_370_495,
    delivery: 4_503_599_627_370_496,
  });
  assert.equal(result.shoot + result.delivery, maxSafe);
});

test('invalid input is invalid_argument', () => {
  const invalidNets = [-1, 1.5, Number.NaN, Number.MAX_SAFE_INTEGER + 2];
  for (const net of invalidNets) {
    assert.throws(() => milestoneAmounts(net), (err: unknown) => {
      assert(err instanceof DomainError);
      assert.equal(err.code, 'invalid_argument');
      return true;
    });
  }

  const invalidPercents = [
    { shoot: 60, delivery: 60 },
    { shoot: 50.5, delivery: 49.5 },
    { shoot: -10, delivery: 110 },
  ];
  for (const percents of invalidPercents) {
    assert.throws(
      () =>
        milestoneAmounts(
          100_000,
          percents as unknown as Readonly<
            Record<(typeof MILESTONE_KINDS)[number], number>
          >,
        ),
      (err: unknown) => {
        assert(err instanceof DomainError);
        assert.equal(err.code, 'invalid_argument');
        return true;
      },
    );
  }
});

test('DEFAULT_MILESTONE_PERCENTS is 50/50 and MILESTONE_KINDS is [shoot, delivery]', () => {
  assert.deepEqual(DEFAULT_MILESTONE_PERCENTS, { shoot: 50, delivery: 50 });
  assert.deepEqual(MILESTONE_KINDS, ['shoot', 'delivery']);
});

test('milestoneAmounts is exported from the package index', () => {
  assert.equal(milestoneAmountsFromIndex, milestoneAmounts);
});

test('splitMilestones(1_500_001, shotAt) gives 750,000 (releaseAfter = shotAt + 24h) and 750,001 (releaseAfter null)', () => {
  const shotAt = new Date('2026-10-15T14:00:00.000Z');
  const ms = splitMilestones(1_500_001, shotAt);
  assert.equal(ms.length, 2);
  const shoot = ms.find((m) => m.kind === 'shoot');
  const delivery = ms.find((m) => m.kind === 'delivery');
  assert.ok(shoot);
  assert.ok(delivery);
  assert.equal(shoot.amount, 750_000);
  assert.equal(shoot.status, 'held');
  assert.equal(shoot.releaseAfter, new Date(shotAt.getTime() + 24 * 3600 * 1000).toISOString());
  assert.equal(delivery.amount, 750_001);
  assert.equal(delivery.status, 'held');
  assert.equal(delivery.releaseAfter, null);
  assert.equal(shoot.amount + delivery.amount, 1_500_001);
});

test('splitMilestones with percents {shoot: 30, delivery: 70} on 1_000_001 → 300,000 / 700,001', () => {
  const shotAt = new Date('2026-10-15T14:00:00.000Z');
  const ms = splitMilestones(1_000_001, shotAt, { shoot: 30, delivery: 70 });
  const shoot = ms.find((m) => m.kind === 'shoot');
  const delivery = ms.find((m) => m.kind === 'delivery');
  assert.ok(shoot);
  assert.ok(delivery);
  assert.equal(shoot.amount, 300_000);
  assert.equal(delivery.amount, 700_001);
  const amounts = milestoneAmounts(1_000_001, { shoot: 30, delivery: 70 });
  assert.equal(shoot.amount, amounts.shoot);
  assert.equal(delivery.amount, amounts.delivery);
});

test('aggregateEscrow precedence: disputed > held > released > paid_out; all refunded -> refunded', () => {
  const m = (kind: 'shoot' | 'delivery', status: 'held' | 'released' | 'paid_out' | 'disputed' | 'refunded') =>
    ({ kind, amount: 500_000, status, releaseAfter: null, releasedAt: null, payoutId: null, paidOutAt: null });

  assert.equal(aggregateEscrow([m('shoot', 'disputed'), m('delivery', 'held')]), 'disputed');
  assert.equal(aggregateEscrow([m('shoot', 'disputed'), m('delivery', 'released')]), 'disputed');
  assert.equal(aggregateEscrow([m('shoot', 'disputed'), m('delivery', 'paid_out')]), 'disputed');
  assert.equal(aggregateEscrow([m('shoot', 'held'), m('delivery', 'released')]), 'held');
  assert.equal(aggregateEscrow([m('shoot', 'released'), m('delivery', 'released')]), 'released');
  assert.equal(aggregateEscrow([m('shoot', 'paid_out'), m('delivery', 'released')]), 'released');
  assert.equal(aggregateEscrow([m('shoot', 'paid_out'), m('delivery', 'paid_out')]), 'paid_out');
  assert.equal(aggregateEscrow([m('shoot', 'refunded'), m('delivery', 'refunded')]), 'refunded');
});

test('releaseDueMilestones is idempotent', () => {
  const shotAt = new Date('2026-10-15T14:00:00.000Z');
  const ms = splitMilestones(1_000_000, shotAt);
  const payment = withMilestones(
    {
      id: 'pay_1',
      subjectType: 'booking',
      subjectId: 'bk_1',
      payerId: 'c1',
      payeeId: 'p1',
      amount: 1_000_000,
      receivedAmount: 1_000_000,
      status: 'paid',
      escrowStatus: 'held',
      method: 'bank_qr',
      provider: 'fake',
      idempotencyKey: 'k',
      createdAt: shotAt.toISOString(),
      updatedAt: shotAt.toISOString(),
    },
    ms,
    shotAt.toISOString(),
  );

  const nowPastShoot = new Date(shotAt.getTime() + 25 * 3600 * 1000);
  let idCounter = 1;
  const rel1 = releaseDueMilestones(payment, nowPastShoot, () => `led_${idCounter++}`);
  const firstEntry = rel1.ledgerEntries[0];
  assert.ok(firstEntry);
  assert.equal(firstEntry.amount, 500_000);
  assert.equal(rel1.payment.payableAmount, 500_000);

  const rel2 = releaseDueMilestones(rel1.payment, nowPastShoot, () => `led_${idCounter++}`);
  assert.equal(rel2.ledgerEntries.length, 0);
  assert.equal(rel2.payment, rel1.payment);
});

