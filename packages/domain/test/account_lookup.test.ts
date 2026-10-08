import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { FakeAccountNameLookup } from '../src/account_lookup.js';

const at = (accountNumber: string) => ({ bankCode: 'VCB', accountNumber });

describe('FakeAccountNameLookup', () => {
  it('FakeAccountNameLookup echoes its name', async () => {
    const lookup = new FakeAccountNameLookup('Nguyễn Văn An');
    assert.deepEqual(await lookup.lookup(at('0123456789')), { status: 'found', holderName: 'Nguyễn Văn An' });
  });

  it('4321 → found TRAN VAN B; 9999 → unsupported; 0404 → not_found', async () => {
    const lookup = new FakeAccountNameLookup('Nguyễn Văn An');
    assert.deepEqual(await lookup.lookup(at('0123454321')), { status: 'found', holderName: 'TRAN VAN B' });
    assert.deepEqual(await lookup.lookup(at('0123459999')), { status: 'unsupported' });
    assert.deepEqual(await lookup.lookup(at('0123450404')), { status: 'not_found' });
    // 0000 is the payout gateway's failure number, never a lookup rule.
    assert.deepEqual(await lookup.lookup(at('0123450000')), { status: 'found', holderName: 'Nguyễn Văn An' });
  });

  it('a null echo name → unsupported', async () => {
    const lookup = new FakeAccountNameLookup(null);
    assert.deepEqual(await lookup.lookup(at('0123456789')), { status: 'unsupported' });
    assert.deepEqual(await lookup.lookup(at('0123454321')), { status: 'found', holderName: 'TRAN VAN B' });
  });
});
