/**
 * S06.06 helpers around a payout account save: the bank's holder-name lookup (capped per day, so
 * it cannot be used to read strangers' names) and the OTP that a change of account needs.
 */

import { formatVnDate } from './booking_policy.js';
import { DomainError } from './errors.js';
import type { PayoutHolder } from './account_lookup.js';
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
 * Who is using S06.06 (plan #223 Decision 3): a provider (role `photographer`, as before) or an active
 * organizer; anyone else, a customer who is not an organizer or a suspended organizer, is `permission_denied`.
 */
export async function payoutHolderOf(tx: PayoutTx, uid: string): Promise<PayoutHolder> {
  return (await payoutStandingOf(tx, uid)).holder;
}

/**
 * `payoutHolderOf` plus whether the caller also has an `active` organizer document: a provider who is
 * one too keeps the identity-name check and, in addition, may set `organizers/{uid}.payoutAccountOk`.
 */
export async function payoutStandingOf(tx: PayoutTx, uid: string): Promise<{ holder: PayoutHolder; organizer: boolean }> {
  const isProvider = (await tx.getUserRole(uid)) === 'photographer';
  const organizer = (await tx.getOrganizerStatus(uid)) === 'active';
  if (isProvider) return { holder: 'provider', organizer };
  if (organizer) return { holder: 'organizer', organizer };
  throw new DomainError('permission_denied');
}

/** The name the account's holder must match: the identity's for a provider, the verified business's for an organizer. */
export async function verifiedNameFor(
  deps: Pick<PayoutAccountDeps, 'names' | 'businessNames'>,
  holder: PayoutHolder,
  uid: string,
): Promise<string | null> {
  if (holder === 'provider') return deps.names.legalName(uid);
  return deps.businessNames === undefined ? null : deps.businessNames.legalName(uid);
}

/**
 * One transaction before any bank lookup (`lookupPayoutAccountName` and `savePayoutAccount`): the
 * caller must be a provider or an active organizer, then `guard` (refusals that must not spend a
 * lookup), then one lookup is charged to the caller's Vietnam day; the 21st is `limit_exceeded` and
 * charges nothing. Returns who the caller is (`organizer`: also an active organizer) and what `guard` returned.
 */
export async function chargeLookup<T>(
  deps: Pick<PayoutAccountDeps, 'store' | 'clock'>,
  uid: string,
  guard: (tx: PayoutTx) => Promise<T>,
): Promise<{ holder: PayoutHolder; organizer: boolean; guarded: T }> {
  return deps.store.runTransaction(async (tx) => {
    const { holder, organizer } = await payoutStandingOf(tx, uid);
    const guarded = await guard(tx);
    const day = formatVnDate(deps.clock.now());
    const quota = await tx.getLookupQuota(uid);
    const count = quota !== null && quota.day === day ? quota.count : 0;
    if (count >= NAME_LOOKUPS_PER_DAY) throw new DomainError('limit_exceeded');
    tx.putLookupQuota(uid, { day, count: count + 1 });
    return { holder, organizer, guarded };
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

  const { holder } = await chargeLookup(deps, caller.uid, async () => undefined);

  const stored = await verifiedNameFor(deps, holder, caller.uid);
  const verifiedName = stored !== null && stored.trim() !== '' ? stored.trim() : null;
  const lookup = await deps.lookup.lookup({ bankCode: target.bank.code, accountNumber: target.number, holder });
  const found = lookup.status === 'found' ? holderNameKey(lookup.holderName) : '';
  return {
    decision: holderNameDecision(lookup, verifiedName),
    holderName: found === '' ? null : found,
    verifiedName,
  };
}

/**
 * raw: exactly {bankCode, accountNumber} (the account the code will be allowed to save). Only for
 * a change (a current account exists), to the caller's phone; resend after 60 s, 5 sends per
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
    // The caller's standing first: nothing is read or generated for anyone else.
    await payoutHolderOf(tx, caller.uid);
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
