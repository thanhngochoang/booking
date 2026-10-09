/**
 * The shared gate every order-creating path passes (bookings, payments, job offers, instant
 * booking): the provider must accept orders, then the two people must not have blocked each
 * other. It refuses new orders only; an existing booking, payment or refund is never touched.
 */

import type { BlockGate } from './block_ports.js';
import type { ProviderOrderGate } from './booking_ports.js';
import { DomainError } from './errors.js';

export type OrderBlock = 'not_accepting_orders' | 'blocked';

export interface OrderGateDeps {
  readonly providers: ProviderOrderGate;
  /** Missing → blocks are not checked. Every live deps sets it (liveBlockGate()). */
  readonly blocks?: BlockGate;
}

export interface OrderParties {
  readonly customerId: string;
  readonly providerId: string;
}

/** Provider gate first, then blocks. null = the order may go ahead. */
export async function orderBlocker(deps: OrderGateDeps, p: OrderParties): Promise<OrderBlock | null> {
  if (!(await deps.providers.acceptsOrders(p.providerId))) return 'not_accepting_orders';
  if (deps.blocks && (await deps.blocks.isBlockedEitherWay(p.customerId, p.providerId))) return 'blocked';
  return null;
}

/** Throws DomainError(orderBlocker's answer) when it is not null. */
export async function assertOrderAllowed(deps: OrderGateDeps, p: OrderParties): Promise<void> {
  const blocker = await orderBlocker(deps, p);
  if (blocker) throw new DomainError(blocker);
}
