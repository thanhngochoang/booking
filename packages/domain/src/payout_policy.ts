/**
 * What is withheld from a provider's money when it is paid out (payments spec §7, M4, M8).
 *
 * A versioned constant until staff get an editor (S23.02): changing it is a reviewed code change,
 * and each payout snapshots the rates it used (`feeRateBp`, `taxRateBp`), so history never moves.
 * The platform bears gateway and payout fees; they are never part of this policy.
 */

import { DomainError } from './errors.js';
import type { ProviderType } from './provider_type.js';

export interface PayoutPolicy {
  /** Platform commission per provider type, in basis points of the gross amount. */
  readonly feeBp: Readonly<Record<ProviderType, number>>;
  /** Tax withheld from natural persons (`individual`, `artist`): GTGT + TNCN, basis points. */
  readonly individualTaxBp: { readonly vat: number; readonly pit: number };
}

/** No commission; 5 % GTGT + 2 % TNCN for natural persons; studios 0 (spec §7 "mặc định không khấu trừ"). */
export const DEFAULT_PAYOUT_POLICY: PayoutPolicy = {
  feeBp: { individual: 0, artist: 0, studio: 0 },
  individualTaxBp: { vat: 500, pit: 200 },
};

export interface PayoutLine {
  readonly gross: number;
  readonly fee: number;
  readonly tax: number;
  readonly net: number;
  readonly feeRateBp: number;
  readonly taxRateBp: number;
}

const BP = 10_000;

/** The tax rate the policy applies to a payee type. */
export function taxRateBpOf(payee: ProviderType, policy: PayoutPolicy): number {
  return payee === 'studio' ? 0 : policy.individualTaxBp.vat + policy.individualTaxBp.pit;
}

/**
 * Integer VND; tax only for 'individual' and 'artist'; Math.round per line. Both fee and tax are
 * taken on the gross amount and net = gross − fee − tax, never below 0. A negative or non-integer
 * gross is `invalid_argument`.
 */
export function payoutLineOf(gross: number, payee: ProviderType, policy: PayoutPolicy): PayoutLine {
  if (!Number.isSafeInteger(gross) || gross < 0) throw new DomainError('invalid_argument');
  const amount = gross;
  const feeRateBp = policy.feeBp[payee];
  const taxRateBp = taxRateBpOf(payee, policy);
  const fee = Math.min(amount, Math.round((amount * feeRateBp) / BP));
  const tax = Math.min(amount - fee, Math.round((amount * taxRateBp) / BP));
  return { gross: amount, fee, tax, net: amount - fee - tax, feeRateBp, taxRateBp };
}
