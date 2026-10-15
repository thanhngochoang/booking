import { DomainError } from './errors.js';

export const MILESTONE_KINDS = ['shoot', 'delivery'] as const;
export type MilestoneKind = (typeof MILESTONE_KINDS)[number];

export const DEFAULT_MILESTONE_PERCENTS: Readonly<Record<MilestoneKind, number>> =
  Object.freeze({
    shoot: 50,
    delivery: 50,
  });

/**
 * Exact integer split of a net amount into shoot and delivery milestones.
 * shoot = ⌊net × percents.shoot / 100⌋, delivery = net − shoot.
 * Throws DomainError('invalid_argument') on invalid inputs.
 */
export function milestoneAmounts(
  net: number,
  percents: Readonly<Record<MilestoneKind, number>> = DEFAULT_MILESTONE_PERCENTS,
): { shoot: number; delivery: number } {
  if (!Number.isSafeInteger(net) || net < 0) {
    throw new DomainError('invalid_argument');
  }

  const { shoot: pShoot, delivery: pDelivery } = percents;
  if (
    !Number.isSafeInteger(pShoot) ||
    !Number.isSafeInteger(pDelivery) ||
    pShoot < 0 ||
    pShoot > 100 ||
    pDelivery < 0 ||
    pDelivery > 100 ||
    pShoot + pDelivery !== 100
  ) {
    throw new DomainError('invalid_argument');
  }

  const q = Math.floor(net / 100);
  const r = net % 100;
  const shoot = q * pShoot + Math.floor((r * pShoot) / 100);
  return { shoot, delivery: net - shoot };
}
