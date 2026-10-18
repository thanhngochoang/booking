import { DomainError } from './errors.js';
import type { EscrowStatus } from './booking.js';
import type { LedgerEntry, Payment } from './escrow.js';

export const MILESTONE_KINDS = ['shoot', 'delivery'] as const;
export type MilestoneKind = (typeof MILESTONE_KINDS)[number];

export const DEFAULT_MILESTONE_PERCENTS: Readonly<Record<MilestoneKind, number>> =
  Object.freeze({
    shoot: 50,
    delivery: 50,
  });

export const MILESTONE_STATUSES = ['held', 'released', 'paid_out', 'refunded', 'disputed'] as const;
export type MilestoneStatus = (typeof MILESTONE_STATUSES)[number];

export interface PaymentMilestone {
  readonly kind: MilestoneKind;
  readonly amount: number;
  readonly status: MilestoneStatus;
  readonly releaseAfter: string | null;
  readonly releasedAt: string | null;
  readonly payoutId: string | null;
}

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

/**
 * Splits a net amount into two milestones at shot time:
 * shoot: releaseAfter = shotAt + 24 h
 * delivery: releaseAfter = null
 */
export function splitMilestones(
  net: number,
  shotAt: Date,
  percents: Readonly<Record<MilestoneKind, number>> = DEFAULT_MILESTONE_PERCENTS,
): PaymentMilestone[] {
  const amounts = milestoneAmounts(net, percents);
  const shootReleaseAfter = new Date(shotAt.getTime() + 24 * 60 * 60 * 1000).toISOString();
  return [
    {
      kind: 'shoot',
      amount: amounts.shoot,
      status: 'held',
      releaseAfter: shootReleaseAfter,
      releasedAt: null,
      payoutId: null,
    },
    {
      kind: 'delivery',
      amount: amounts.delivery,
      status: 'held',
      releaseAfter: null,
      releasedAt: null,
      payoutId: null,
    },
  ];
}

/**
 * Aggregate escrow status precedence:
 * disputed > held > released > paid_out; all refunded → refunded.
 */
export function aggregateEscrow(ms: readonly PaymentMilestone[]): EscrowStatus {
  if (ms.length === 0) return 'held';
  if (ms.some((m) => m.status === 'disputed')) return 'disputed';
  if (ms.some((m) => m.status === 'held')) return 'held';
  if (ms.some((m) => m.status === 'released')) return 'released';
  if (ms.every((m) => m.status === 'refunded')) return 'refunded';
  return 'paid_out';
}

export function payableAmountOf(p: Payment): number {
  if (!p.milestones) {
    return p.escrowStatus === 'released' && !p.payoutId ? (p.payableAmount ?? p.amount) : 0;
  }
  return p.milestones
    .filter((m) => m.status === 'released' && !m.payoutId)
    .reduce((s, m) => s + m.amount, 0);
}

export function withMilestones(p: Payment, ms: readonly PaymentMilestone[], at: string): Payment {
  const heldWithRelease = ms
    .filter((m) => m.status === 'held' && m.releaseAfter)
    .map((m) => m.releaseAfter as string)
    .sort();
  const nextReleaseAfter = heldWithRelease[0] ?? undefined;
  const payable = ms
    .filter((m) => m.status === 'released' && !m.payoutId)
    .reduce((s, m) => s + m.amount, 0);

  return {
    ...p,
    milestones: ms,
    escrowStatus: aggregateEscrow(ms),
    payableAmount: payable,
    releaseAfter: nextReleaseAfter,
    releasedAt: ms.some((m) => m.status === 'released' || m.status === 'paid_out')
      ? (p.releasedAt ?? at)
      : p.releasedAt,
    updatedAt: at,
  };
}

/**
 * Releases a single milestone of the payment and generates an escrow_released ledger entry.
 */
export function releaseMilestone(
  p: Payment,
  kind: MilestoneKind,
  ledgerEntryId: string,
  now: Date,
): { payment: Payment; ledgerEntry: LedgerEntry } {
  if (!p.milestones) {
    throw new DomainError('conflict');
  }
  const target = p.milestones.find((m) => m.kind === kind);
  if (!target || target.status !== 'held') {
    throw new DomainError('conflict');
  }

  const at = now.toISOString();
  const updatedMilestones: PaymentMilestone[] = p.milestones.map((m) =>
    m.kind === kind
      ? { ...m, status: 'released' as const, releasedAt: at }
      : m,
  );

  const updatedPayment = withMilestones(p, updatedMilestones, at);

  const ledgerEntry: LedgerEntry = {
    id: ledgerEntryId,
    type: 'escrow_released',
    paymentId: p.id,
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    accountOwnerId: p.payeeId,
    amount: target.amount,
    note: `Escrow milestone ${kind} released to payee ${p.payeeId}`,
    at,
  };

  return { payment: updatedPayment, ledgerEntry };
}

/**
 * Releases all milestones that are held with releaseAfter <= now.
 * Idempotent: returns empty ledgerEntries if none due.
 */
export function releaseDueMilestones(
  p: Payment,
  now: Date,
  newId: () => string,
): { payment: Payment; ledgerEntries: LedgerEntry[] } {
  if (!p.milestones) {
    return { payment: p, ledgerEntries: [] };
  }

  const at = now.toISOString();
  const ledgerEntries: LedgerEntry[] = [];
  const updatedMilestones: PaymentMilestone[] = [];

  for (const m of p.milestones) {
    if (m.status === 'held' && m.releaseAfter && new Date(m.releaseAfter).getTime() <= now.getTime()) {
      updatedMilestones.push({
        ...m,
        status: 'released',
        releasedAt: at,
      });
      ledgerEntries.push({
        id: newId(),
        type: 'escrow_released',
        paymentId: p.id,
        subjectType: p.subjectType,
        subjectId: p.subjectId,
        accountOwnerId: p.payeeId,
        amount: m.amount,
        note: `Escrow milestone ${m.kind} released to payee ${p.payeeId}`,
        at,
      });
    } else {
      updatedMilestones.push(m);
    }
  }

  if (ledgerEntries.length === 0) {
    return { payment: p, ledgerEntries: [] };
  }

  const updatedPayment = withMilestones(p, updatedMilestones, at);
  return { payment: updatedPayment, ledgerEntries };
}

/**
 * Flags a specific milestone as disputed.
 */
export function disputeMilestone(p: Payment, kind: MilestoneKind, now: Date): Payment {
  if (!p.milestones) {
    throw new DomainError('conflict');
  }
  const target = p.milestones.find((m) => m.kind === kind);
  if (!target || (target.status !== 'held' && target.status !== 'released')) {
    throw new DomainError('conflict');
  }

  const at = now.toISOString();
  const updatedMilestones: PaymentMilestone[] = p.milestones.map((m) =>
    m.kind === kind ? { ...m, status: 'disputed' as const } : m,
  );

  return withMilestones(p, updatedMilestones, at);
}
