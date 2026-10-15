import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';
import {
  ACCOUNT_CHANGE_DELAY_HOURS,
  NAME_LOOKUPS_PER_DAY,
  accountLast4,
  holderNameDecision,
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

describe('holderNameDecision', () => {
  const found = (holderName: string) => ({ status: 'found' as const, holderName });

  it('the policy numbers: 72 hours, 20 lookups a day', () => {
    assert.equal(ACCOUNT_CHANGE_DELAY_HOURS, 72);
    assert.equal(NAME_LOOKUPS_PER_DAY, 20);
  });

  it('found "Nguyễn Văn An" vs verified "NGUYEN VAN AN" → matched', () => {
    assert.equal(holderNameDecision(found('Nguyễn Văn An'), 'NGUYEN VAN AN'), 'matched');
    assert.equal(holderNameDecision(found('NGUYEN VAN AN'), 'Nguyễn Văn An'), 'matched');
  });

  it('found "TRAN VAN B" vs "NGUYEN VAN AN" → mismatch', () => {
    assert.equal(holderNameDecision(found('TRAN VAN B'), 'NGUYEN VAN AN'), 'mismatch');
    assert.equal(holderNameDecision(found('NGUYEN VAN ANH'), 'Nguyễn Văn An'), 'mismatch');
  });

  it('not_found → not_found', () => {
    assert.equal(holderNameDecision({ status: 'not_found' }, 'NGUYEN VAN AN'), 'not_found');
    assert.equal(holderNameDecision({ status: 'not_found' }, null), 'not_found');
  });

  it('unsupported + verified → review', () => {
    assert.equal(holderNameDecision({ status: 'unsupported' }, 'Nguyễn Văn An'), 'review');
  });

  it('found + no verified → review', () => {
    assert.equal(holderNameDecision(found('TRAN VAN B'), null), 'review');
    assert.equal(holderNameDecision(found('TRAN VAN B'), '   '), 'review');
  });

  it('unsupported + no verified → unverifiable', () => {
    assert.equal(holderNameDecision({ status: 'unsupported' }, null), 'unverifiable');
    assert.equal(holderNameDecision({ status: 'unsupported' }, ''), 'unverifiable');
  });

  it('extra spaces and lower case still match', () => {
    assert.equal(holderNameDecision(found('  nguyen   van an '), 'Nguyễn Văn An'), 'matched');
    assert.equal(holderNameDecision(found('đỗ thị hồng'), 'DO  THI HONG'), 'matched');
  });

  it('a blank bank name counts as no name (unsupported)', () => {
    assert.equal(holderNameDecision(found('   '), 'NGUYEN VAN AN'), 'review');
    assert.equal(holderNameDecision(found(''), null), 'unverifiable');
  });
});
