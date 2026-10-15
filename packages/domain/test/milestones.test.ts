import assert from 'node:assert/strict';
import test from 'node:test';

import { DomainError } from '../src/errors.js';
import {
  DEFAULT_MILESTONE_PERCENTS,
  MILESTONE_KINDS,
  milestoneAmounts,
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
