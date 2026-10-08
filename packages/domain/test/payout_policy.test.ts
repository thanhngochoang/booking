import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DEFAULT_PAYOUT_POLICY, payoutLineOf, type PayoutPolicy } from '../src/payout_policy.js';

describe('payout policy', () => {
  it('individual: 1,500,000 → tax 105,000, net 1,395,000, taxRateBp 700', () => {
    assert.deepEqual(payoutLineOf(1_500_000, 'individual', DEFAULT_PAYOUT_POLICY), {
      gross: 1_500_000,
      fee: 0,
      tax: 105_000,
      net: 1_395_000,
      feeRateBp: 0,
      taxRateBp: 700,
    });
  });

  it('artist pays the individual tax; studio pays none', () => {
    const artist = payoutLineOf(450_000, 'artist', DEFAULT_PAYOUT_POLICY);
    assert.equal(artist.taxRateBp, 700);
    assert.equal(artist.tax, 31_500);
    assert.equal(artist.net, 418_500);
    const studio = payoutLineOf(450_000, 'studio', DEFAULT_PAYOUT_POLICY);
    assert.deepEqual(studio, { gross: 450_000, fee: 0, tax: 0, net: 450_000, feeRateBp: 0, taxRateBp: 0 });
  });

  it('fee bp applies before tax and both round per line', () => {
    const policy: PayoutPolicy = { ...DEFAULT_PAYOUT_POLICY, feeBp: { individual: 1000, artist: 1000, studio: 1000 } };
    const line = payoutLineOf(450_500, 'individual', policy);
    assert.deepEqual(line, { gross: 450_500, fee: 45_050, tax: 31_535, net: 373_915, feeRateBp: 1000, taxRateBp: 700 });
    assert.equal(line.fee + line.tax + line.net, line.gross);
  });

  it('zero and one đồng stay integers', () => {
    for (const gross of [0, 1]) {
      for (const payee of ['individual', 'artist', 'studio'] as const) {
        const line = payoutLineOf(gross, payee, DEFAULT_PAYOUT_POLICY);
        for (const v of [line.fee, line.tax, line.net]) {
          assert.ok(Number.isInteger(v), `${payee} ${gross}`);
          assert.ok(v >= 0, `${payee} ${gross}`);
        }
        assert.equal(line.fee + line.tax + line.net, gross);
      }
    }
    assert.equal(payoutLineOf(1, 'individual', DEFAULT_PAYOUT_POLICY).net, 1);
  });

  it('the default policy is 0 fee and 5% + 2% individual tax', () => {
    assert.deepEqual(DEFAULT_PAYOUT_POLICY.feeBp, { individual: 0, artist: 0, studio: 0 });
    assert.deepEqual(DEFAULT_PAYOUT_POLICY.individualTaxBp, { vat: 500, pit: 200 });
  });
});
