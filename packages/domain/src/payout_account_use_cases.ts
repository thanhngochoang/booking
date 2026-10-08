/**
 * S06.06 helpers around a payout account save: the bank's holder-name lookup (capped per day, so
 * it cannot be used to read strangers' names) and the OTP that a change of account needs.
 */

import { formatVnDate } from './booking_policy.js';
import { DomainError } from './errors.js';
import {
  NAME_LOOKUPS_PER_DAY,
  holderNameDecision,
  holderNameKey,
  parseAccountTarget,
  type HolderNameDecision,
} from './payout_account.js';
import {
  OTP_MAX_SENDS_PER_DAY,
  OTP_RESEND_SECONDS,
  OTP_SALT_BYTES,
  OTP_TTL_SECONDS,
  hexOf,
  otpCodeFrom,
  otpCodeHashInput,
  otpTargetHashInput,
} from './payout_otp.js';
import type { PayoutAccount } from './payout_account.js';
import type { AccountCipher, PayoutAccountDeps, PayoutTx } from './payout_ports.js';
import type { Caller } from './save_payout_account.js';

/** The target is the account already active (same bank, same number): nothing to change. */
export async function isSameAccount(
  cipher: AccountCipher,
  current: PayoutAccount | null,
  bankCode: string,
  number: string,
): Promise<boolean> {
  if (current === null || current.bankCode !== bankCode || current.accountLast4 !== number.slice(-4)) return false;
  return (await cipher.decrypt(current.accountNumberEnc)) === number;
}

/**
 * One transaction before any bank lookup (`lookupPayoutAccountName` and `savePayoutAccount`): the
 * caller must be a photographer, then `guard` (refusals that must not spend a lookup), then one
 * lookup is charged to the caller's Vietnam day; the 21st is `limit_exceeded` and charges nothing.
 * Returns what `guard` returned.
 */
export async function chargeLookup<T>(
  deps: Pick<PayoutAccountDeps, 'store' | 'clock'>,
  uid: string,
  guard: (tx: PayoutTx) => Promise<T>,
): Promise<T> {
  return deps.store.runTransaction(async (tx) => {
    if ((await tx.getUserRole(uid)) !== 'photographer') throw new DomainError('permission_denied');
    const guarded = await guard(tx);
    const day = formatVnDate(deps.clock.now());
    const quota = await tx.getLookupQuota(uid);
    const count = quota !== null && quota.day === day ? quota.count : 0;
    if (count >= NAME_LOOKUPS_PER_DAY) throw new DomainError('limit_exceeded');
    tx.putLookupQuota(uid, { day, count: count + 1 });
    return guarded;
  });
}

/**
 * raw: exactly {bankCode, accountNumber}. Counts one lookup for the caller's Vietnam day (the 21st
 * is `limit_exceeded` and never reaches the bank), then asks the bank and compares with the
 * verified name. `holderName` is the bank's name (normalised) or null; `verifiedName` as stored.
 */
export async function lookupPayoutAccountName(
  deps: PayoutAccountDeps,
  caller: Caller,
  raw: unknown,
): Promise<{ decision: HolderNameDecision; holderName: string | null; verifiedName: string | null }> {
  const target = parseAccountTarget(raw, false);
  if (target === null) throw new DomainError('invalid_argument');

  await chargeLookup(deps, caller.uid, async () => undefined);

  const stored = await deps.names.legalName(caller.uid);
  const verifiedName = stored !== null && stored.trim() !== '' ? stored.trim() : null;
  const lookup = await deps.lookup.lookup({ bankCode: target.bank.code, accountNumber: target.number });
  const found = lookup.status === 'found' ? holderNameKey(lookup.holderName) : '';
  return {
    decision: holderNameDecision(lookup, verifiedName),
    holderName: found === '' ? null : found,
    verifiedName,
  };
}

/**
 * raw: exactly {bankCode, accountNumber} (the account the code will be allowed to save). Only for
 * a change (a current account exists), to the photographer's phone; resend after 60 s, 5 sends per
 * Vietnam day; never for the account already active (`conflict`). Stores salted hashes only; the
 * code goes out after the commit.
 */
export async function requestPayoutOtp(
  deps: PayoutAccountDeps,
  caller: Caller,
  raw: unknown,
): Promise<{ phoneLast4: string; expiresInSeconds: number; resendInSeconds: number }> {
  const target = parseAccountTarget(raw, false);
  if (target === null) throw new DomainError('invalid_argument');

  const sent = await deps.store.runTransaction(async (tx) => {
    // The role first: nothing is read or generated for anyone else.
    if ((await tx.getUserRole(caller.uid)) !== 'photographer') throw new DomainError('permission_denied');
    const current = await tx.getActiveAccount(caller.uid);
    if (current === null) throw new DomainError('not_eligible');
    // No code for the account already active: saving it would be refused anyway.
    if (await isSameAccount(deps.cipher, current, target.bank.code, target.number)) throw new DomainError('conflict');
    const previous = await tx.getOtpChallenge(caller.uid);
    const phone = (await deps.otp.phones.phoneOf(caller.uid))?.trim() ?? '';
    const phoneDigits = phone.replace(/[^0-9]/g, '');
    if (phoneDigits === '') throw new DomainError('phone_required');
    const now = deps.clock.now();
    const day = formatVnDate(now);
    if (previous !== null) {
      if (now.getTime() - Date.parse(previous.sentAt) < OTP_RESEND_SECONDS * 1000) {
        throw new DomainError('limit_exceeded');
      }
      if (previous.sendDay === day && previous.sendsToday >= OTP_MAX_SENDS_PER_DAY) {
        throw new DomainError('limit_exceeded');
      }
    }
    // A new code and a new salt replace the previous challenge (Ruling 6): the old code is then
    // checked against the new hash, so it is a counted wrong try (`otp_invalid`), not `otp_required`.
    const code = otpCodeFrom(deps.otp.crypto.random(4));
    const salt = hexOf(deps.otp.crypto.random(OTP_SALT_BYTES));
    tx.putOtpChallenge({
      uid: caller.uid,
      purpose: 'payout_account',
      codeHash: await deps.otp.crypto.sha256Hex(otpCodeHashInput(salt, code)),
      salt,
      targetHash: await deps.otp.crypto.sha256Hex(otpTargetHashInput(salt, target.bank.code, target.number)),
      expiresAt: new Date(now.getTime() + OTP_TTL_SECONDS * 1000).toISOString(),
      attempts: 0,
      sentAt: now.toISOString(),
      sendDay: day,
      sendsToday: previous !== null && previous.sendDay === day ? previous.sendsToday + 1 : 1,
      consumedAt: null,
    });
    return { phone, phoneDigits, code };
  });

  await deps.otp.sender.send({ phone: sent.phone, code: sent.code, purpose: 'payout_account' });
  return { phoneLast4: sent.phoneDigits.slice(-4), expiresInSeconds: OTP_TTL_SECONDS, resendInSeconds: OTP_RESEND_SECONDS };
}
