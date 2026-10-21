import type { Clock } from './ports.js';
import { DomainError } from './errors.js';
import { REAUTH_MAX_AGE_SECONDS } from './payout_account.js';

export const DELETED_USER_NAME = 'Người dùng đã xoá';
export const ACCOUNT_RESTORE_DAYS = 30; // Owner 2026-10-07
export const OPEN_BOOKING_EXCLUDED = [
  'draft',
  'declined',
  'expired',
  'cancelled',
  'completed',
  'reviewed',
] as const; // every other status is open

export const BLOCKER_KINDS = [
  'open_booking',
  'open_job',
  'open_job_post',
  'open_quote',
  'active_instant',
  'studio_membership',
  'open_collab',
  'live_ticket',
  'hosted_event',
  'open_dispute',
  'held_payment',
  'refund_in_progress',
  'unpaid_earnings',
] as const;
export type BlockerKind = (typeof BLOCKER_KINDS)[number];

export interface BlockerItem {
  readonly id: string;
  readonly title: string;
  readonly day: string | null;
  readonly eventId?: string;
}

export interface Blocker {
  readonly kind: BlockerKind;
  readonly count: number;
  readonly amount: number | null;
  readonly first: BlockerItem | null;
}

export interface PayerMoneyItem {
  readonly paymentId: string;
  readonly state: 'held' | 'disputed' | 'refunding';
  readonly amount: number;
  readonly item: BlockerItem;
}

export interface AccountSnapshot {
  readonly openBookings: readonly BlockerItem[];
  readonly openJobs: readonly BlockerItem[]; // openJobs: photographerId or assigneeId == uid
  readonly openJobPosts: readonly BlockerItem[];
  readonly openQuotes: readonly BlockerItem[]; // #139
  readonly activeInstants: readonly BlockerItem[]; // #140
  readonly studioRelations: readonly BlockerItem[];
  readonly openCollabs: readonly BlockerItem[]; // #136, #151
  readonly liveTickets: readonly BlockerItem[];
  readonly hostedEvents: readonly BlockerItem[];
  readonly payerMoney: readonly PayerMoneyItem[]; // from payments (payerId == uid) and their refunds
  readonly unpaidEarnings: number;
}

export function accountDeletionBlockers(s: AccountSnapshot): readonly Blocker[] {
  const result: Blocker[] = [];

  // 1. open_booking
  if (s.openBookings.length > 0 && s.openBookings[0] !== undefined) {
    result.push({
      kind: 'open_booking',
      count: s.openBookings.length,
      amount: null,
      first: s.openBookings[0],
    });
  }

  // 2. open_job
  if (s.openJobs.length > 0 && s.openJobs[0] !== undefined) {
    result.push({
      kind: 'open_job',
      count: s.openJobs.length,
      amount: null,
      first: s.openJobs[0],
    });
  }

  // 3. open_job_post
  if (s.openJobPosts.length > 0 && s.openJobPosts[0] !== undefined) {
    result.push({
      kind: 'open_job_post',
      count: s.openJobPosts.length,
      amount: null,
      first: s.openJobPosts[0],
    });
  }

  // 4. open_quote
  if (s.openQuotes.length > 0 && s.openQuotes[0] !== undefined) {
    result.push({
      kind: 'open_quote',
      count: s.openQuotes.length,
      amount: null,
      first: s.openQuotes[0],
    });
  }

  // 5. active_instant
  if (s.activeInstants.length > 0 && s.activeInstants[0] !== undefined) {
    result.push({
      kind: 'active_instant',
      count: s.activeInstants.length,
      amount: null,
      first: s.activeInstants[0],
    });
  }

  // 6. studio_membership
  if (s.studioRelations.length > 0 && s.studioRelations[0] !== undefined) {
    result.push({
      kind: 'studio_membership',
      count: s.studioRelations.length,
      amount: null,
      first: s.studioRelations[0],
    });
  }

  // 7. open_collab
  if (s.openCollabs.length > 0 && s.openCollabs[0] !== undefined) {
    result.push({
      kind: 'open_collab',
      count: s.openCollabs.length,
      amount: null,
      first: s.openCollabs[0],
    });
  }

  // 8. live_ticket
  if (s.liveTickets.length > 0 && s.liveTickets[0] !== undefined) {
    result.push({
      kind: 'live_ticket',
      count: s.liveTickets.length,
      amount: null,
      first: s.liveTickets[0],
    });
  }

  // 9. hosted_event
  if (s.hostedEvents.length > 0 && s.hostedEvents[0] !== undefined) {
    result.push({
      kind: 'hosted_event',
      count: s.hostedEvents.length,
      amount: null,
      first: s.hostedEvents[0],
    });
  }

  // 10. open_dispute
  const disputes = s.payerMoney.filter((m) => m.state === 'disputed');
  if (disputes.length > 0 && disputes[0] !== undefined) {
    const totalAmount = disputes.reduce((sum, item) => sum + item.amount, 0);
    result.push({
      kind: 'open_dispute',
      count: disputes.length,
      amount: totalAmount,
      first: disputes[0].item,
    });
  }

  // 11. held_payment
  const held = s.payerMoney.filter((m) => m.state === 'held');
  if (held.length > 0 && held[0] !== undefined) {
    const totalAmount = held.reduce((sum, item) => sum + item.amount, 0);
    result.push({
      kind: 'held_payment',
      count: held.length,
      amount: totalAmount,
      first: held[0].item,
    });
  }

  // 12. refund_in_progress
  const refunding = s.payerMoney.filter((m) => m.state === 'refunding');
  if (refunding.length > 0 && refunding[0] !== undefined) {
    const totalAmount = refunding.reduce((sum, item) => sum + item.amount, 0);
    result.push({
      kind: 'refund_in_progress',
      count: refunding.length,
      amount: totalAmount,
      first: refunding[0].item,
    });
  }

  // 13. unpaid_earnings
  if (s.unpaidEarnings > 0) {
    result.push({
      kind: 'unpaid_earnings',
      count: 1,
      amount: s.unpaidEarnings,
      first: null,
    });
  }

  return result;
}

export type DeletionStatus = 'pending' | 'restored' | 'purging' | 'blocked' | 'done';

export interface AccountDeletionRecord {
  readonly uid: string;
  readonly status: DeletionStatus;
  readonly requestedAt: string;
  readonly restoreUntil: string;
  readonly done: readonly string[];
}

export interface AccountDeletionDeps {
  snapshot(uid: string, now: Date): Promise<AccountSnapshot>;
  lock(uid: string, requestedAt: Date, restoreUntil: Date): Promise<'locked' | 'already'>;
  unlock(uid: string, now: Date): Promise<'restored' | 'not_pending' | 'expired'>;
  startPurge(uid: string, now: Date): Promise<boolean>;
  duePending(now: Date, limit: number): Promise<readonly string[]>;
  revokeSessions(uid: string): Promise<void>;
  readonly clock: Clock;
}

export async function getAccountDeletionBlockers(
  deps: AccountDeletionDeps,
  caller: { uid: string },
): Promise<{ blockers: readonly Blocker[] }> {
  const now = deps.clock.now();
  const snap = await deps.snapshot(caller.uid, now);
  return { blockers: accountDeletionBlockers(snap) };
}

export async function requestAccountDeletion(
  deps: AccountDeletionDeps,
  caller: { uid: string; authTime: Date | null },
  raw: unknown,
): Promise<{ status: 'deletion_pending'; restoreUntil: string }> {
  if (raw !== null && typeof raw === 'object' && Object.keys(raw).length > 0) {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  if (
    !caller.authTime ||
    now.getTime() - caller.authTime.getTime() > REAUTH_MAX_AGE_SECONDS * 1000
  ) {
    throw new DomainError('reauth_required');
  }

  const snap = await deps.snapshot(caller.uid, now);
  const blockers = accountDeletionBlockers(snap);
  if (blockers.length > 0) {
    throw new DomainError('conflict');
  }

  const restoreUntil = new Date(now.getTime() + ACCOUNT_RESTORE_DAYS * 24 * 60 * 60 * 1000);
  await deps.lock(caller.uid, now, restoreUntil);
  await deps.revokeSessions(caller.uid);

  return {
    status: 'deletion_pending',
    restoreUntil: restoreUntil.toISOString(),
  };
}

export async function restoreAccount(
  deps: AccountDeletionDeps,
  caller: { uid: string },
  raw: unknown,
): Promise<{ status: 'restored' }> {
  if (raw !== null && typeof raw === 'object' && Object.keys(raw).length > 0) {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  const result = await deps.unlock(caller.uid, now);
  if (result === 'not_pending') {
    throw new DomainError('not_found');
  }
  if (result === 'expired') {
    throw new DomainError('deadline_passed');
  }

  return { status: 'restored' };
}

export async function startDueAccountPurges(
  deps: AccountDeletionDeps,
  now: Date,
  limit: number,
): Promise<number> {
  const dues = await deps.duePending(now, limit);
  let started = 0;
  for (const uid of dues) {
    const ok = await deps.startPurge(uid, now);
    if (ok) started++;
  }
  return started;
}

export const ACCOUNT_DATA_MAP: ReadonlyArray<{
  readonly target: string;
  readonly action: 'delete' | 'anonymize' | 'tombstone' | 'keep';
  readonly note: string;
}> = [
  { target: 'users/{uid}', action: 'tombstone', note: 'anonymize name and avatar, keep role' },
  { target: 'users/{uid}/private/*', action: 'delete', note: 'private subcollections' },
  { target: 'notifications/*', action: 'delete', note: 'notifications' },
  { target: 'badges/*', action: 'delete', note: 'badges' },
  { target: 'payments/*', action: 'delete', note: 'payment history projection rows' },
  { target: 'photographers/{uid}', action: 'delete', note: 'photographer profile' },
  { target: 'photographers/{uid}/services/*', action: 'delete', note: 'services' },
  { target: 'photographers/{uid}/private/*', action: 'delete', note: 'photographer private data' },
  { target: 'availability/{uid}/days/*', action: 'delete', note: 'calendar days' },
  { target: 'payoutAccounts/{uid}', action: 'delete', note: 'payout account records' },
  { target: 'earnings/{uid}', action: 'delete', note: 'earnings summary' },
  { target: 'devices', action: 'delete', note: 'FCM push devices' },
  { target: 'likes/saves/follows', action: 'delete', note: 'social relations' },
  { target: 'posts', action: 'delete', note: 'own posts' },
  { target: 'albums/awards', action: 'delete', note: 'portfolio and award proofs' },
  { target: 'bookings/*/private/contact', action: 'delete', note: 'contact snapshot in customer bookings' },
  { target: 'events/*/registrations/*', action: 'anonymize', note: 'anonymize name and avatar, delete contact' },
  { target: 'events', action: 'anonymize', note: 'anonymize host details' },
  { target: 'jobs', action: 'anonymize', note: 'anonymize customerName' },
  { target: 'Storage', action: 'delete', note: 'Storage prefixes: avatars, posts, users, awardProofs, eventCovers, exports' },
  { target: 'identity', action: 'delete', note: 'delete identity, keep idHash' },
  { target: 'Auth user', action: 'delete', note: 'deleted last after all steps' },
];

export function tombstoneOf(user: { role?: unknown }, now: Date): Record<string, unknown> {
  const result: Record<string, unknown> = {
    displayName: DELETED_USER_NAME,
    avatarUrl: null,
    avatarPath: null,
    deleted: true,
    deletedAt: now.toISOString(),
    accountStatus: null,
    restoreUntil: null,
  };
  if (user.role !== undefined) {
    result.role = user.role;
  }
  return result;
}
