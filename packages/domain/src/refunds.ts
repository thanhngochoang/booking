/**
 * Dispatch refund to payment gateway and update refund status.
 */

import type { BookingDeps } from './booking_ports.js';
import type { PaymentProvider } from './booking.js';
import type { Refund } from './escrow.js';

export async function dispatchRefund(
  deps: BookingDeps,
  refund: Refund,
  provider: PaymentProvider,
): Promise<Refund> {
  const gatewayResult = await deps.gateway.issueRefund({
    paymentId: refund.paymentId,
    refundId: refund.id,
    amount: refund.amount,
    provider,
    providerRef: refund.providerRef,
  });

  const now = deps.clock.now();
  const updatedRefund: Refund = {
    ...refund,
    status: gatewayResult.success ? 'done' : 'failed',
    manual: !gatewayResult.success,
    providerRef: gatewayResult.providerRef ?? refund.providerRef,
    updatedAt: now.toISOString(),
  };

  await deps.store.runTransaction(async (tx) => {
    await tx.addRefund(updatedRefund);
  });

  return updatedRefund;
}
