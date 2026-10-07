import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';
import {
  accountLast4,
  normalizeAccountNumber,
  normalizeHolderName,
} from '../src/payout_account.js';
import { VN_BANKS, bankByCode } from '../src/vn_banks.js';

interface Case { raw: string; normalized: string | null }
const fixture = JSON.parse(
  readFileSync(new URL('./fixtures/payout_account.json', import.meta.url), 'utf8'),
) as { accountNumbers: Case[]; holderNames: Case[]; last4: Array<{ number: string; last4: string }> };

describe('payout account input rules', () => {
  it('account number keeps 6–20 digits after removing spaces, dots and dashes', () => {
    for (const c of fixture.accountNumbers.filter((x) => x.normalized !== null)) {
      assert.equal(normalizeAccountNumber(c.raw), c.normalized, c.raw);
    }
  });

  it('letters in the account number are invalid', () => {
    assert.equal(normalizeAccountNumber('12345678a'), null);
    assert.equal(normalizeAccountNumber(123456789), null);
    for (const c of fixture.accountNumbers.filter((x) => x.normalized === null)) {
      assert.equal(normalizeAccountNumber(c.raw), null, c.raw);
    }
  });

  it('holder name is upper-case ASCII without diacritics', () => {
    assert.equal(normalizeHolderName('Nguyễn Văn An'), 'NGUYEN VAN AN');
    assert.equal(normalizeHolderName('Nguyễn Văn An'.normalize('NFD')), 'NGUYEN VAN AN');
  });

  it('Đ becomes D and spaces collapse', () => {
    assert.equal(normalizeHolderName('  đỗ  thị   hồng '), 'DO THI HONG');
    assert.equal(normalizeHolderName('Đặng Lê'), 'DANG LE');
  });

  it('holder name with digits or over 50 characters is invalid', () => {
    for (const c of fixture.holderNames) {
      assert.equal(normalizeHolderName(c.raw), c.normalized, c.raw);
    }
    assert.equal(normalizeHolderName('A'.repeat(51)), null);
    assert.equal(normalizeHolderName('A'.repeat(50)), 'A'.repeat(50));
    assert.equal(normalizeHolderName(null), null);
  });

  it('last four of 0123456789 is 6789', () => {
    for (const c of fixture.last4) assert.equal(accountLast4(c.number), c.last4);
  });

  it('every bank code is unique and has a 6-digit bin', () => {
    const codes = VN_BANKS.map((b) => b.code);
    assert.equal(new Set(codes).size, codes.length);
    assert.equal(new Set(VN_BANKS.map((b) => b.bin)).size, codes.length);
    for (const b of VN_BANKS) assert.match(b.bin, /^[0-9]{6}$/);
    assert.equal(VN_BANKS[0]?.code, 'VCB');
    assert.equal(VN_BANKS.length, 20);
  });

  it('bankByCode ignores unknown codes', () => {
    assert.equal(bankByCode('VCB')?.shortName, 'Vietcombank');
    assert.equal(bankByCode('vcb'), null);
    assert.equal(bankByCode('XXX'), null);
    assert.equal(bankByCode(5), null);
  });
});
