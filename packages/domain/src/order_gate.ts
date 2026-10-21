/**
 * The shared gate every order-creating path passes (bookings, payments, job offers, instant
 * booking): the provider must accept orders, then the two people must not have blocked each
 * other. It refuses new orders only; an existing booking, payment or refund is never touched.
 */

import type { BlockGate } from './block_ports.js';
import type { OrderProfile, ProviderOrderGate } from './booking_ports.js';
import { DomainError } from './errors.js';

export type OrderBlock = 'not_accepting_orders' | 'blocked';

export interface OrderGateDeps {
  readonly providers: Pick<ProviderOrderGate, 'acceptsOrders'>;
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
  return blockOf(deps, p);
}

/**
 * The same answer for a path that already read the provider's `orderProfile` (one read gives the gate and the
 * provider type, #136 Decision 8). A missing profile cannot take orders.
 */
export async function profileOrderBlocker(
  deps: Pick<OrderGateDeps, 'blocks'>,
  profile: OrderProfile | null,
  p: OrderParties,
): Promise<OrderBlock | null> {
  if (profile?.acceptsOrders !== true) return 'not_accepting_orders';
  return blockOf(deps, p);
}

async function blockOf(deps: Pick<OrderGateDeps, 'blocks'>, p: OrderParties): Promise<OrderBlock | null> {
  if (deps.blocks && (await deps.blocks.isBlockedEitherWay(p.customerId, p.providerId))) return 'blocked';
  return null;
}

/** Throws DomainError(orderBlocker's answer) when it is not null. */
export async function assertOrderAllowed(deps: OrderGateDeps, p: OrderParties): Promise<void> {
  const blocker = await orderBlocker(deps, p);
  if (blocker) throw new DomainError(blocker);
}
