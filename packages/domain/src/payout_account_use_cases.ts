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
import type { PayoutAccountDeps } from './payout_ports.js';
import type { Caller } from './save_payout_account.js';

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

  await deps.store.runTransaction(async (tx) => {
    if ((await tx.getUserRole(caller.uid)) !== 'photographer') throw new DomainError('permission_denied');
    const day = formatVnDate(deps.clock.now());
    const quota = await tx.getLookupQuota(caller.uid);
    const count = quota !== null && quota.day === day ? quota.count : 0;
    if (count >= NAME_LOOKUPS_PER_DAY) throw new DomainError('limit_exceeded');
    tx.putLookupQuota(caller.uid, { day, count: count + 1 });
  });

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
 * Vietnam day. Stores salted hashes only; the code goes out after the commit.
 */
export async function requestPayoutOtp(
  deps: PayoutAccountDeps,
  caller: Caller,
  raw: unknown,
): Promise<{ phoneLast4: string; expiresInSeconds: number; resendInSeconds: number }> {
  const target = parseAccountTarget(raw, false);
  if (target === null) throw new DomainError('invalid_argument');

  const phone = (await deps.otp.phones.phoneOf(caller.uid))?.trim() ?? '';
  const phoneDigits = phone.replace(/[^0-9]/g, '');
  const code = otpCodeFrom(deps.otp.crypto.random(4));
  const salt = hexOf(deps.otp.crypto.random(OTP_SALT_BYTES));
  const codeHash = await deps.otp.crypto.sha256Hex(otpCodeHashInput(salt, code));
  const targetHash = await deps.otp.crypto.sha256Hex(otpTargetHashInput(salt, target.bank.code, target.number));

  await deps.store.runTransaction(async (tx) => {
    if ((await tx.getUserRole(caller.uid)) !== 'photographer') throw new DomainError('permission_denied');
    if ((await tx.getActiveAccount(caller.uid)) === null) throw new DomainError('not_eligible');
    if (phoneDigits === '') throw new DomainError('phone_required');
    const previous = await tx.getOtpChallenge(caller.uid);
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
    tx.putOtpChallenge({
      uid: caller.uid,
      purpose: 'payout_account',
      codeHash,
      salt,
      targetHash,
      expiresAt: new Date(now.getTime() + OTP_TTL_SECONDS * 1000).toISOString(),
      attempts: 0,
      sentAt: now.toISOString(),
      sendDay: day,
      sendsToday: previous !== null && previous.sendDay === day ? previous.sendsToday + 1 : 1,
      consumedAt: null,
    });
  });

  await deps.otp.sender.send({ phone, code, purpose: 'payout_account' });
  return { phoneLast4: phoneDigits.slice(-4), expiresInSeconds: OTP_TTL_SECONDS, resendInSeconds: OTP_RESEND_SECONDS };
}
