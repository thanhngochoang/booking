/**
 * Payer bank account parsing, normalization and encryption for refund destination.
 */

import type { PayerBankAccount, TransferNotification } from './booking_ports.js';
import type { StoredBankAccount } from './escrow.js';
import { normalizeAccountNumber, normalizeHolderName } from './payout_account.js';
import type { AccountCipher } from './payout_ports.js';
import { bankByCode } from './vn_banks.js';

/** Decision 2: a complete payer → encrypted StoredBankAccount; anything less → null. */
export async function payerAccountOf(
  cipher: AccountCipher,
  payer: TransferNotification['payer'],
): Promise<StoredBankAccount | null> {
  if (!payer || !payer.bankCode) return null;

  const accountNumber = normalizeAccountNumber(payer.accountNumber);
  if (!accountNumber) return null;

  const holderName = normalizeHolderName(payer.name);
  if (!holderName) return null;

  const bank = bankByCode(payer.bankCode);
  const bankName = bank?.shortName ?? payer.bankCode;

  const accountNumberEnc = await cipher.encrypt(accountNumber);
  const accountLast4 = accountNumber.slice(-4);

  return {
    bankCode: payer.bankCode,
    bankName,
    accountNumberEnc,
    accountLast4,
    holderName,
  };
}

/** The plain account for the one gateway call. */
export async function revealDestination(
  cipher: AccountCipher,
  d: StoredBankAccount,
): Promise<PayerBankAccount> {
  const accountNumber = await cipher.decrypt(d.accountNumberEnc);
  return {
    bankCode: d.bankCode,
    accountNumber,
    holderName: d.holderName,
  };
}
