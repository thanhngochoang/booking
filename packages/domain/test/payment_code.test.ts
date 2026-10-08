import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { TRANSFER_CODE_ALPHABET, transferCodeFor, transferCodesIn } from '../src/payment_code.js';

describe('transferCodeFor', () => {
  it('is deterministic and uses only the alphabet', () => {
    assert.equal(transferCodeFor('pay_01'), transferCodeFor('pay_01'));
    assert.match(transferCodeFor('01JABCDEF'), /^PB [2-9A-HJKMNP-TV-Z]{6}$/);
    const seen = new Set<string>();
    for (let i = 0; i < 1000; i++) {
      const code = transferCodeFor(`pay_${i}`);
      assert.match(code, /^PB [2-9A-HJKMNP-TV-Z]{6}$/);
      for (const ch of code.slice(3)) assert.ok(TRANSFER_CODE_ALPHABET.includes(ch), ch);
      seen.add(code);
    }
    // 1 000 ids over 30^6 codes: a handful of collisions at most.
    assert.ok(seen.size > 990, `only ${seen.size} distinct codes`);
  });

  it('the alphabet has 30 characters and no 0, O, 1, I, L or U', () => {
    assert.equal(TRANSFER_CODE_ALPHABET.length, 30);
    assert.equal(new Set(TRANSFER_CODE_ALPHABET).size, 30);
    for (const ch of '01OILU') assert.ok(!TRANSFER_CODE_ALPHABET.includes(ch), ch);
  });
});

describe('transferCodesIn', () => {
  it('finds the code in mangled content', () => {
    assert.deepEqual(transferCodesIn('PB 7F3K2Q'), ['PB 7F3K2Q']);
    assert.deepEqual(transferCodesIn('pb7f3k2q chuyen tien'), ['PB 7F3K2Q']);
    assert.deepEqual(transferCodesIn('CK PB-7F3K2Q den Minh Tri'), ['PB 7F3K2Q']);
  });

  it('returns nothing when there is no code', () => {
    assert.deepEqual(transferCodesIn('CHUYEN TIEN'), []);
    assert.deepEqual(transferCodesIn(''), []);
    assert.deepEqual(transferCodesIn('PB 7F3K'), []);
    // 0, 1, I, L, O and U are not in the alphabet.
    assert.deepEqual(transferCodesIn('PB 0F3K2Q'), []);
  });

  it('returns two codes in order and ignores repeats', () => {
    assert.deepEqual(transferCodesIn('PB 7F3K2Q va PB 8H2M4N'), ['PB 7F3K2Q', 'PB 8H2M4N']);
    assert.deepEqual(transferCodesIn('PB 7F3K2Q PB7F3K2Q'), ['PB 7F3K2Q']);
  });

  it('round-trips a generated code through a mangled bank memo', () => {
    const code = transferCodeFor('01JXYZ');
    const memo = `ck ${code.toLowerCase().replace(' ', '')} Nguyen Van A`;
    assert.ok(transferCodesIn(memo).includes(code));
  });
});
