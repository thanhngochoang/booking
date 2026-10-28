/**
 * Use case: a photographer, or an active organizer (plan #223 Decision 3), registers or changes their
 * payout account (S06.06, payments spec M6). The holder name comes from the bank and must match the
 * verified name (the identity's, or an organizer's verified business legal name); the first account is
 * active at once; a change needs an OTP for that exact account and takes effect after 72 hours. An
 * organizer's save also sets `organizers/{uid}.payoutAccountOk` in the same transaction.
 */

import type { NameLookupResult } from './account_lookup.js';
import { DomainError, type ErrorCode } from './errors.js';
import type { Payout } from './payout.js';
import {
  ACCOUNT_CHANGE_DELAY_HOURS,
  accountLast4,
  holderNameDecision,
  holderNameKey,
  parseAccountTarget,
  type HolderNameDecision,
  type NameStatus,
  type PayoutAccount,
} from './payout_account.js';
import { checkOtp, otpCodeHashInput, otpTargetHashInput } from './payout_otp.js';
import { chargeLookup, isSameAccount, payoutHolderOf, verifiedNameFor } from './payout_account_use_cases.js';
import type { PayoutAccountDeps } from './payout_ports.js';

export interface Caller {
  readonly uid: string;
}

export interface SavedPayoutAccount {
  readonly accountId: string;
  readonly accountLast4: string;
  readonly activeFrom: string;
  readonly nameStatus: NameStatus;
}

/** Decisions that refuse the save, and the code they refuse with. */
const REFUSAL: Readonly<Record<HolderNameDecision, ErrorCode | null>> = {
  matched: null,
  review: null,
  mismatch: 'name_mismatch',
  not_found: 'not_found',
  unverifiable: 'not_eligible',
};

/** The stored holder: the bank's name when it gave one, else the verified name (staff compare it). */
function holderOf(lookup: NameLookupResult, verifiedName: string | null): string {
  const found = lookup.status === 'found' ? holderNameKey(lookup.holderName) : '';
  return found !== '' ? found : holderNameKey(verifiedName);
}

/** Re-pointed to the new account: the first payout to it, so staff approve it again (Decision 7). */
function repointed(p: Payout, accountId: string, at: string): Payout {
  const { approvedBy, approvedAt, ...rest } = p;
  void approvedBy;
  void approvedAt;
  return {
    ...rest,
    accountId,
    firstPayout: true,
    status: p.status === 'pending' ? 'needs_approval' : p.status,
    updatedAt: at,
  };
}

type Outcome =
  | { readonly refused: 'otp_invalid' }
  | { readonly refused: null; readonly saved: SavedPayoutAccount; readonly changed: boolean; readonly bankCode: string };

/** raw: exactly {bankCode, accountNumber} or {bankCode, accountNumber, otpCode}. */
export async function savePayoutAccount(
  deps: PayoutAccountDeps,
  caller: Caller,
  raw: unknown,
): Promise<SavedPayoutAccount> {
  const target = parseAccountTarget(raw, true);
  if (target === null) throw new DomainError('invalid_argument');
  const { bank, number, otpCode } = target;

  // Before any external call: a provider or an active organizer only, not the account already active,
  // a change carries a code; then one lookup is charged to the 20 a day (the save must not be an
  // uncapped oracle).
  const { holder, guarded: seenId } = await chargeLookup(deps, caller.uid, async (tx) => {
    const current = await tx.getActiveAccount(caller.uid);
    if (await isSameAccount(deps.cipher, current, bank.code, number)) throw new DomainError('conflict');
    if (current !== null && otpCode === undefined) throw new DomainError('otp_required');
    return current?.id ?? null;
  });

  // Outside the transaction: the verified name and the bank lookup (a slow external call).
  const verifiedName = await verifiedNameFor(deps, holder, caller.uid);
  const lookup = await deps.lookup.lookup({ bankCode: bank.code, accountNumber: number, holder });
  const decision = holderNameDecision(lookup, verifiedName);
  const refusal = REFUSAL[decision];
  const last4 = accountLast4(number);
  const enc = refusal === null ? await deps.cipher.encrypt(number) : '';
  const accountId = refusal === null ? deps.ids.newId() : '';
  const sha = (s: string): Promise<string> => deps.otp.crypto.sha256Hex(s);

  const outcome = await deps.store.runTransaction(async (tx): Promise<Outcome> => {
    // Changed since the checks above (a suspension, a role): refuse, the client retries.
    if ((await payoutHolderOf(tx, caller.uid)) !== holder) throw new DomainError('conflict');
    if (refusal !== null) throw new DomainError(refusal);
    const now = deps.clock.now();
    const at = now.toISOString();
    const current = await tx.getActiveAccount(caller.uid);
    // Changed since the checks above (a concurrent save): refuse, the client retries.
    if ((current?.id ?? null) !== seenId) throw new DomainError('conflict');
    const processing = current ? await tx.listPayouts(caller.uid, ['processing']) : [];
    const open = current ? await tx.listPayouts(caller.uid, ['pending', 'needs_approval', 'on_hold']) : [];
    const challenge = current ? await tx.getOtpChallenge(caller.uid) : null;

    if (current !== null) {
      if (otpCode === undefined) throw new DomainError('otp_required');
      if (processing.length > 0) throw new DomainError('conflict');
      const given = {
        codeHash: challenge ? await sha(otpCodeHashInput(challenge.salt, otpCode)) : '',
        targetHash: challenge ? await sha(otpTargetHashInput(challenge.salt, bank.code, number)) : '',
      };
      const verdict = checkOtp(challenge, given, now);
      if (verdict === 'wrong' && challenge !== null) {
        // Committed with the transaction, then refused: a wrong try always counts.
        tx.putOtpChallenge({ ...challenge, attempts: challenge.attempts + 1 });
        return { refused: 'otp_invalid' };
      }
      if (verdict === 'required') throw new DomainError('otp_required');
      if (verdict === 'expired') throw new DomainError('otp_expired');
      if (verdict === 'too_many') throw new DomainError('limit_exceeded');
      if (challenge === null || verdict !== 'ok') throw new DomainError('otp_required');
      tx.putOtpChallenge({ ...challenge, consumedAt: at });
      tx.putAccount({ ...current, active: false, deactivatedAt: at });
    }

    const activeFrom = current
      ? new Date(now.getTime() + ACCOUNT_CHANGE_DELAY_HOURS * 3600_000).toISOString()
      : at;
    const account: PayoutAccount = {
      id: accountId,
      userId: caller.uid,
      bankCode: bank.code,
      accountNumberEnc: enc,
      accountLast4: last4,
      holderName: holderOf(lookup, verifiedName),
      active: true,
      createdAt: at,
      nameStatus: decision === 'matched' ? 'matched' : 'pending_review',
      activeFrom,
    };
    tx.putAccount(account);
    for (const p of open) tx.putPayout(repointed(p, accountId, at));
    tx.putAccountView(caller.uid, {
      accountId,
      bankCode: account.bankCode,
      accountLast4: last4,
      holderName: account.holderName,
      updatedAt: at,
      nameStatus: account.nameStatus,
      activeFrom,
    });
    // Decision 3: a saved account (the bank's name matched the business, or staff compare it before the
    // first payout) is what lets an organizer sell; a refusal above never reaches this line.
    if (holder === 'organizer') tx.setOrganizerPayoutOk(caller.uid, true);
    return {
      refused: null,
      saved: { accountId, accountLast4: last4, activeFrom, nameStatus: account.nameStatus },
      changed: current !== null,
      bankCode: bank.code,
    };
  });

  if (outcome.refused !== null) throw new DomainError(outcome.refused);
  if (outcome.changed) {
    const { accountId: id, accountLast4: l4, activeFrom } = outcome.saved;
    try {
      await deps.notices.accountChanged(caller.uid, { accountId: id, bankCode: outcome.bankCode, accountLast4: l4, activeFrom });
    } catch {
      // The notice never fails the save: the change is committed (the adapter logs by code).
    }
  }
  return outcome.saved;
}
