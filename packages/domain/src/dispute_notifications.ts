import type { Dispute } from './dispute.js';
import { notifyDisputeOpened, notifyDisputeResolved } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';

/** S18.02 `disputePlatformName`: who receives a platform event's money. */
const PLATFORM_NAME = 'ứng dụng';

/**
 * Decides the notifications of a dispute write (the `onDisputeWrite` trigger; Decision 11), through
 * #138's hooks, which own the copy, targets and dedupe keys:
 * - created open → `notifyDisputeOpened` (the provider; nobody for a platform event);
 * - open → resolved → `notifyDisputeResolved` for every party.
 * Any other write (a mirror, a retry with nothing changed, a delete) notifies nobody.
 */
export async function notifyDisputeChange(deps: NotifyDeps, before: Dispute | null, after: Dispute | null): Promise<void> {
  if (after === null) return;
  if (before === null) {
    if (after.status !== 'open') return;
    await notifyDisputeOpened(deps, {
      disputeId: after.id,
      providerId: after.providerId,
      customerId: after.customerId,
      subject: after.snapshot.title,
      ticket: after.subjectType === 'ticket',
    });
    return;
  }
  if (before.status === 'open' && after.status === 'resolved' && after.outcome !== null) {
    await notifyDisputeResolved(deps, {
      disputeId: after.id,
      recipientIds: after.parties,
      subject: after.snapshot.title,
      kind: after.outcome.kind,
      providerName: after.providerId === 'platform' ? PLATFORM_NAME : (after.snapshot.providerName ?? PLATFORM_NAME),
      refund: after.outcome.refundAmount,
      release: after.outcome.releaseAmount,
    });
  }
}
