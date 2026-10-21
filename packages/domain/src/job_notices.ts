import type { NotifyDeps } from './notification_ports.js';
import {
  notifyQuoteAccepted,
  notifyQuoteNew,
  notifyQuoteNotSelected,
  notifyQuoteWithdrawn,
} from './notification_hooks.js';
import type { QuoteRecord } from './job.js';

export interface QuoteNotice {
  readonly to: 'customer' | 'photographer';
  readonly kind: 'new' | 'withdrawn' | 'accepted' | 'not_selected';
}

export function quoteNotices(
  before: QuoteRecord | null,
  after: QuoteRecord | null,
): QuoteNotice[] {
  if (!after) return [];

  // New or resubmitted quote
  if (!before && after.status === 'submitted') {
    return [{ to: 'customer', kind: 'new' }];
  }
  if (before && before.status === 'withdrawn' && after.status === 'submitted') {
    return [{ to: 'customer', kind: 'new' }];
  }

  // submitted -> withdrawn
  if (before && before.status === 'submitted' && after.status === 'withdrawn') {
    return [{ to: 'customer', kind: 'withdrawn' }];
  }

  // submitted -> accepted
  if (before && before.status === 'submitted' && after.status === 'accepted') {
    return [{ to: 'photographer', kind: 'accepted' }];
  }

  // submitted -> not_selected | declined
  if (
    before &&
    before.status === 'submitted' &&
    (after.status === 'not_selected' || after.status === 'declined')
  ) {
    return [{ to: 'photographer', kind: 'not_selected' }];
  }

  return [];
}

export async function emitQuoteNotices(
  n: NotifyDeps,
  before: QuoteRecord | null,
  after: QuoteRecord | null,
): Promise<number> {
  const notices = quoteNotices(before, after);
  if (notices.length === 0 || !after) return 0;

  for (const notice of notices) {
    if (notice.kind === 'new') {
      await notifyQuoteNew(n, {
        customerId: after.customerId,
        jobId: after.jobId,
        jobTitle: after.jobTitle,
        photographerId: after.photographerId,
        quoteVersion: after.version,
      });
    } else if (notice.kind === 'withdrawn') {
      await notifyQuoteWithdrawn(n, {
        customerId: after.customerId,
        jobId: after.jobId,
        jobTitle: after.jobTitle,
        photographerId: after.photographerId,
        quoteVersion: after.version,
        auto: after.autoWithdrawn,
      });
    } else if (notice.kind === 'accepted') {
      await notifyQuoteAccepted(n, {
        photographerId: after.photographerId,
        customerId: after.customerId,
        jobId: after.jobId,
        bookingId: after.bookingId ?? '',
        jobTitle: after.jobTitle,
      });
    } else if (notice.kind === 'not_selected') {
      const reason =
        after.status === 'declined'
          ? 'declined'
          : after.notSelectedReason ?? 'closed';
      await notifyQuoteNotSelected(n, {
        photographerId: after.photographerId,
        jobId: after.jobId,
        jobTitle: after.jobTitle,
        reason,
      });
    }
  }

  return notices.length;
}
