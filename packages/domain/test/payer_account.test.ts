import assert from 'node:assert/strict';
import test, { describe } from 'node:test';
import { payerAccountOf, revealDestination } from '../src/payer_account.js';
import { TEST_CIPHER } from './support/test_cipher.js';

describe('payerAccountOf and revealDestination', () => {
  test('a complete payer becomes a StoredBankAccount', async () => {
    const raw = {
      bankCode: 'VCB',
      accountNumber: '0071 000 123 456',
      name: 'Nguyễn Thanh Hà',
    };
    const stored = await payerAccountOf(TEST_CIPHER, raw);
    assert.ok(stored);
    assert.equal(stored.bankCode, 'VCB');
    assert.equal(stored.bankName, 'Vietcombank');
    assert.equal(stored.accountLast4, '3456');
    assert.equal(stored.holderName, 'NGUYEN THANH HA');
    assert.ok(!stored.accountNumberEnc.includes('0071000123456'));
    const decrypted = await TEST_CIPHER.decrypt(stored.accountNumberEnc);
    assert.equal(decrypted, '0071000123456');
  });

  test('an unknown bank code keeps the code as bank name', async () => {
    const raw = {
      bankCode: 'UNKNOWN_BANK',
      accountNumber: '0071000123456',
      name: 'Nguyễn Thanh Hà',
    };
    const stored = await payerAccountOf(TEST_CIPHER, raw);
    assert.ok(stored);
    assert.equal(stored.bankCode, 'UNKNOWN_BANK');
    assert.equal(stored.bankName, 'UNKNOWN_BANK');
  });

  test('no number, a bad number, no name, a bad name or no bank code → null', async () => {
    assert.equal(await payerAccountOf(TEST_CIPHER, { bankCode: 'VCB', name: 'HA' }), null);
    assert.equal(await payerAccountOf(TEST_CIPHER, { bankCode: 'VCB', accountNumber: '123', name: 'HA' }), null);
    assert.equal(await payerAccountOf(TEST_CIPHER, { bankCode: 'VCB', accountNumber: '0071000123456' }), null);
    assert.equal(await payerAccountOf(TEST_CIPHER, { bankCode: 'VCB', accountNumber: '0071000123456', name: '123' }), null);
    assert.equal(await payerAccountOf(TEST_CIPHER, { bankCode: '', accountNumber: '0071000123456', name: 'HA' }), null);
  });

  test('undefined payer → null', async () => {
    assert.equal(await payerAccountOf(TEST_CIPHER, undefined), null);
  });

  test('revealDestination returns bankCode, the plain number and holderName', async () => {
    const raw = {
      bankCode: 'VCB',
      accountNumber: '0071000123456',
      name: 'Nguyễn Thanh Hà',
    };
    const stored = await payerAccountOf(TEST_CIPHER, raw);
    assert.ok(stored);
    const revealed = await revealDestination(TEST_CIPHER, stored);
    assert.deepEqual(revealed, {
      bankCode: 'VCB',
      accountNumber: '0071000123456',
      holderName: 'NGUYEN THANH HA',
    });
  });
});
