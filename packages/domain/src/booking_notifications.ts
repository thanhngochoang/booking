import type { Booking } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import type { NotificationActor, NotifyDeps, NotifyRequest } from './notification_ports.js';
import type { NotificationContent } from './notification_render.js';
import { formatDayShortVi } from './notification_render.js';
import { notify } from './notification_use_cases.js';

export interface BookingNotice {
  readonly to: 'customer' | 'photographer';
  readonly kind: 'request' | 'accepted' | 'declined' | 'expired' | 'cancelled' | 'refund';
}

/** Who must hear about a booking change. Pure; creation, deletion and later steps send nothing. */
export function bookingNotices(before: Booking | null, after: Booking | null): BookingNotice[] {
  if (!before || !after) return [];
  const out: BookingNotice[] = [];

  if (before.status !== after.status) {
    if (before.status === 'draft' && after.status === 'requested') {
      out.push({ to: 'photographer', kind: 'request' });
    } else if (before.status === 'requested' && (after.status === 'accepted' || after.status === 'upcoming')) {
      out.push({ to: 'customer', kind: 'accepted' });
    } else if (before.status === 'requested' && after.status === 'declined') {
      out.push({ to: 'customer', kind: 'declined' });
    } else if (before.status === 'requested' && after.status === 'expired') {
      out.push({ to: 'customer', kind: 'expired' });
    } else if (after.status === 'cancelled') {
      // A studio-fault cancel is the customer's own (#136 Decision 12): only the studio hears about it.
      const by = after.cancel?.by === 'studio_fault' ? 'customer' : (after.cancel?.by ?? 'system');
      // The party that did not cancel hears about it; both when the system cancelled.
      if (by !== 'customer') out.push({ to: 'customer', kind: 'cancelled' });
      if (by !== 'photographer') out.push({ to: 'photographer', kind: 'cancelled' });
    }
  }

  if (!before.depositRefundedAt && after.depositRefundedAt && (after.depositRefunded ?? 0) > 0) {
    out.push({ to: 'customer', kind: 'refund' });
  }
  return out;
}

const CUSTOMER_FALLBACK = 'Khách hàng';
const PHOTOGRAPHER_FALLBACK = 'Nhiếp ảnh gia';

async function actorOf(deps: NotifyDeps, id: string, fallback: string): Promise<NotificationActor> {
  const u = await deps.users.get(id);
  return { id, name: u?.name ?? fallback, avatarUrl: u?.avatarUrl ?? null };
}

function requestFor(
  b: Booking,
  n: BookingNotice,
  names: { customer: NotificationActor; photographer: NotificationActor },
): NotifyRequest {
  const day = formatDayShortVi(b.day);
  const userId = n.to === 'customer' ? b.customerId : b.photographerId;
  const counterpart = n.to === 'customer' ? names.photographer : names.customer;
  const common = { userId, actor: counterpart, thumbUrl: counterpart.avatarUrl, target: `/b/${b.id}` };
  const percent = b.cancel?.refundPercent ?? 100;

  switch (n.kind) {
    case 'request':
      return {
        ...common,
        target: '/bookings',
        dedupeKey: `booking_request_${b.id}`,
        content: { type: 'booking_request', customer: names.customer.name, service: b.serviceSnapshot.name, day, start: b.start },
      };
    case 'accepted':
      return {
        ...common,
        dedupeKey: `booking_accepted_${b.id}`,
        content: { type: 'booking_accepted', photographer: names.photographer.name, day, start: b.start, place: b.place.name },
      };
    case 'declined':
    case 'expired':
      return {
        ...common,
        dedupeKey: `booking_${n.kind}_${b.id}`,
        content: {
          type: 'booking_declined',
          reason: n.kind,
          photographer: names.photographer.name,
          percent,
        },
      };
    case 'cancelled': {
      const by = b.cancel?.by ?? 'system';
      const content: NotificationContent = {
        type: 'booking_cancelled',
        by: by === 'system' ? 'system' : 'party',
        name: counterpart.name,
        day,
        start: b.start,
        percent: n.to === 'customer' && by !== 'system' ? (b.cancel?.refundPercent ?? null) : null,
      };
      return { ...common, dedupeKey: `booking_cancelled_${b.id}_${n.to}`, content };
    }
    case 'refund':
      return {
        ...common,
        dedupeKey: `refund_done_${b.id}`,
        content: { type: 'refund_done', amount: b.depositRefunded ?? 0, bookingId: b.id },
      };
  }
}

/** Sends the notices of one booking change. A failing recipient never blocks the other; one error is thrown at the end. */
export async function notifyBookingChange(
  deps: NotifyDeps,
  before: Booking | null,
  after: Booking | null,
): Promise<void> {
  const notices = bookingNotices(before, after);
  if (notices.length === 0 || !after) return;
  const names = {
    customer: await actorOf(deps, after.customerId, CUSTOMER_FALLBACK),
    photographer: await actorOf(deps, after.photographerId, PHOTOGRAPHER_FALLBACK),
  };
  const results = await Promise.allSettled(
    notices.map((n) => notify(deps, requestFor(after, n, names))),
  );
  const failed = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failed.length > 0) {
    throw new Error(`booking notification failed for ${failed.length} recipient(s): ${String(failed[0]?.reason)}`);
  }
}

const HOUR_MS = 60 * 60 * 1000;

/** Decision 13: h24 when start − now ∈ (20 h, 24 h], h2 when ∈ (0, 2 h]; only `upcoming` bookings. */
export function dueReminders(
  bookings: readonly Booking[],
  now: Date,
): { booking: Booking; variant: 'h24' | 'h2' }[] {
  const out: { booking: Booking; variant: 'h24' | 'h2' }[] = [];
  for (const booking of bookings) {
    if (booking.status !== 'upcoming') continue;
    const left = parseVnDateTime(booking.day, booking.start).getTime() - now.getTime();
    if (left > 20 * HOUR_MS && left <= 24 * HOUR_MS) out.push({ booking, variant: 'h24' });
    else if (left > 0 && left <= 2 * HOUR_MS) out.push({ booking, variant: 'h2' });
  }
  return out;
}

/** Sends the due reminders to both parties. Returns how many new rows/pushes were created; repeats are duplicates. */
export async function sendDueReminders(deps: NotifyDeps, bookings: readonly Booking[]): Promise<number> {
  const due = dueReminders(bookings, deps.clock.now());
  let sent = 0;
  const jobs: Promise<void>[] = [];
  for (const { booking: b, variant } of due) {
    jobs.push(
      (async () => {
        const customer = await actorOf(deps, b.customerId, CUSTOMER_FALLBACK);
        const photographer = await actorOf(deps, b.photographerId, PHOTOGRAPHER_FALLBACK);
        const results = await Promise.allSettled(
          (
            [
              [b.customerId, photographer],
              [b.photographerId, customer],
            ] as const
          ).map(async ([userId, other]) => {
            const r = await notify(deps, {
              userId,
              actor: other,
              thumbUrl: other.avatarUrl,
              target: `/b/${b.id}`,
              dedupeKey: `shoot_reminder_${b.id}_${variant}`,
              reminder: variant,
              content: {
                type: 'shoot_reminder',
                hours: variant === 'h24' ? 24 : 2,
                service: b.serviceSnapshot.name,
                counterpart: other.name,
                day: formatDayShortVi(b.day),
                start: b.start,
              },
            });
            if (r === 'created') sent += 1;
          }),
        );
        const bad = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
        if (bad) throw bad.reason;
      })(),
    );
  }
  const results = await Promise.allSettled(jobs);
  const failed = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
  if (failed.length > 0) throw new Error(`reminders failed for ${failed.length} booking(s): ${String(failed[0]?.reason)}`);
  return sent;
}
