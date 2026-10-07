/** Use case: a photographer registers or changes their payout account (S06.06). */

import { DomainError } from './errors.js';
import {
  REAUTH_MAX_AGE_SECONDS,
  accountLast4,
  normalizeAccountNumber,
  normalizeHolderName,
  type PayoutAccount,
} from './payout_account.js';
import type { PayoutAccountDeps } from './payout_ports.js';
import { bankByCode } from './vn_banks.js';

export interface Caller {
  readonly uid: string;
  /** When the ID token's sign-in happened (`auth_time`); null when unknown. */
  readonly authTime: Date | null;
}

const KEYS = ['accountNumber', 'bankCode', 'holderName'];

export async function savePayoutAccount(
  deps: PayoutAccountDeps,
  caller: Caller,
  raw: unknown,
): Promise<{ accountId: string; accountLast4: string }> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const keys = Object.keys(raw).sort();
  if (keys.length !== KEYS.length || keys.some((k, i) => k !== KEYS[i])) {
    throw new DomainError('invalid_argument');
  }
  const input = raw as Record<string, unknown>;
  const bank = bankByCode(input.bankCode);
  const number = normalizeAccountNumber(input.accountNumber);
  const holderName = normalizeHolderName(input.holderName);
  if (bank === null || number === null || holderName === null) {
    throw new DomainError('invalid_argument');
  }

  const last4 = accountLast4(number);
  const enc = await deps.cipher.encrypt(number);
  const accountId = deps.ids.newId();

  return deps.store.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const at = now.toISOString();
    if ((await tx.getUserRole(caller.uid)) !== 'photographer') {
      throw new DomainError('permission_denied');
    }
    const current = await tx.getActiveAccount(caller.uid);
    let open: Awaited<ReturnType<typeof tx.listPayouts>> = [];
    if (current !== null) {
      const age = caller.authTime === null ? Infinity : (now.getTime() - caller.authTime.getTime()) / 1000;
      if (age > REAUTH_MAX_AGE_SECONDS) throw new DomainError('reauth_required');
      if ((await tx.listPayouts(caller.uid, ['processing'])).length > 0) {
        throw new DomainError('conflict');
      }
      open = await tx.listPayouts(caller.uid, ['pending', 'on_hold']);
    }

    if (current !== null) {
      tx.putAccount({ ...current, active: false, deactivatedAt: at });
    }
    const account: PayoutAccount = {
      id: accountId,
      userId: caller.uid,
      bankCode: bank.code,
      accountNumberEnc: enc,
      accountLast4: last4,
      holderName,
      active: true,
      createdAt: at,
    };
    tx.putAccount(account);
    for (const p of open) tx.putPayout({ ...p, accountId, updatedAt: at });
    tx.putAccountView(caller.uid, {
      accountId,
      bankCode: bank.code,
      accountLast4: last4,
      holderName,
      updatedAt: at,
    });
    return { accountId, accountLast4: last4 };
  });
}
