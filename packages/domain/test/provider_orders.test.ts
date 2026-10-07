import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { acceptsOrders, acceptingOrdersPatch } from '../src/provider_orders.js';

describe('provider_orders', () => {
  it('acceptsOrders: true only when verified and onboardingComplete are both true', () => {
    const cases: Array<[Parameters<typeof acceptsOrders>[0], boolean]> = [
      [{ verified: true, onboardingComplete: true }, true],
      [{ verified: true, onboardingComplete: false }, false],
      [{ verified: false, onboardingComplete: true }, false],
      [{}, false],
      [null, false],
      [undefined, false],
      [{ verified: 'true', onboardingComplete: true }, false],
    ];
    for (const [fields, expected] of cases) {
      assert.equal(acceptsOrders(fields), expected, JSON.stringify(fields));
    }
  });

  it('acceptingOrdersPatch: writes when the stored flag differs or is missing', () => {
    assert.deepEqual(acceptingOrdersPatch({ verified: true, onboardingComplete: true }), {
      acceptingOrders: true,
    });
    assert.deepEqual(
      acceptingOrdersPatch({ verified: false, onboardingComplete: true, acceptingOrders: true }),
      { acceptingOrders: false },
    );
  });

  it('acceptingOrdersPatch: null when the stored flag already matches', () => {
    assert.equal(
      acceptingOrdersPatch({ verified: true, onboardingComplete: true, acceptingOrders: true }),
      null,
    );
    assert.equal(
      acceptingOrdersPatch({ verified: false, onboardingComplete: true, acceptingOrders: false }),
      null,
    );
  });

  it('acceptingOrdersPatch: null for a deleted document', () => {
    assert.equal(acceptingOrdersPatch(undefined), null);
    assert.equal(acceptingOrdersPatch(null), null);
  });
});
