import { FakeAccountNameLookup } from '../../src/account_lookup.js';
import type { BookingDeps } from '../../src/booking_ports.js';
import type { DisputeDeps } from '../../src/dispute_ports.js';
import type { RefundStatus } from '../../src/escrow.js';
import type { EventPaymentDeps } from '../../src/event_ports.js';
import { chooseRefundAccount, type RefundAccountDeps } from '../../src/refund_account.js';
import { createBookingWorld } from './booking_world.js';
import { createDisputeWorld } from './dispute_world.js';
import { createTicketPaymentWorld } from './event_world.js';

/**
 * S22.04 deps (#141) around the test's own worlds (booking, ticket, dispute deps); the missing ones
 * are empty worlds. The clock is the first given world's. The fake lookup echoes `echoName`.
 */
export function refundAccountDepsOf(o: {
  readonly bookings?: BookingDeps;
  readonly events?: EventPaymentDeps;
  readonly disputes?: DisputeDeps;
  readonly echoName?: string | null;
}): RefundAccountDeps {
  const bookings = o.bookings ?? createBookingWorld().deps;
  return {
    bookings,
    events: o.events ?? createTicketPaymentWorld().deps,
    disputes: o.disputes ?? createDisputeWorld().deps,
    lookup: new FakeAccountNameLookup(o.echoName ?? null),
    clock: o.bookings?.clock ?? o.events?.clock ?? o.disputes?.clock ?? bookings.clock,
  };
}

/**
 * The customer confirms the paying account on S22.04 for a waiting bank-QR policy refund (#141
 * Decision 5): the step V2-era tests now take before a cancel, decline or event-cancel refund is sent.
 */
export async function confirmRefundToPayer(deps: RefundAccountDeps, refundId: string, uid = 'c1'): Promise<RefundStatus> {
  return (await chooseRefundAccount(deps, { uid }, { refundId, use: 'payer' })).status;
}
