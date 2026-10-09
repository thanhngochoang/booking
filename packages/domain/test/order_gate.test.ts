import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { FakeBlockGate } from '../src/fake_block_gate.js';
import { blockDocId } from '../src/block_ports.js';
import { assertOrderAllowed, orderBlocker } from '../src/order_gate.js';
import { DomainError } from '../src/errors.js';
import type { ProviderOrderGate } from '../src/booking_ports.js';

/** A provider gate backed by a map: ids not in `accepting` do not accept orders. */
const gateOf = (accepting: readonly string[] = ['p1', 'p2']): ProviderOrderGate => {
  const open = new Set(accepting);
  return { acceptsOrders: async (id) => open.has(id) };
};

const parties = { customerId: 'c1', providerId: 'p1' } as const;

describe('order gate', () => {
  it('blockDocId joins blocker and blocked', () => {
    assert.equal(blockDocId('a', 'b'), 'a_b');
  });

  it('orderBlocker returns null for an accepting provider and no block', async () => {
    const blocks = new FakeBlockGate();
    assert.equal(await orderBlocker({ providers: gateOf(), blocks }, parties), null);
  });

  it('orderBlocker returns not_accepting_orders for a provider who does not accept orders', async () => {
    const deps = { providers: gateOf([]), blocks: new FakeBlockGate() };
    assert.equal(await orderBlocker(deps, parties), 'not_accepting_orders');
  });

  it('orderBlocker returns blocked when the provider blocked the customer', async () => {
    const deps = { providers: gateOf(), blocks: new FakeBlockGate([['p1', 'c1']]) };
    assert.equal(await orderBlocker(deps, parties), 'blocked');
  });

  it('orderBlocker returns blocked when the customer blocked the provider', async () => {
    const deps = { providers: gateOf(), blocks: new FakeBlockGate([['c1', 'p1']]) };
    assert.equal(await orderBlocker(deps, parties), 'blocked');
  });

  it('a block between other people does not refuse', async () => {
    const deps = { providers: gateOf(), blocks: new FakeBlockGate([['c1', 'p2']]) };
    assert.equal(await orderBlocker(deps, parties), null);
  });

  it('not_accepting_orders wins over blocked and the block gate is not consulted', async () => {
    const blocks = new FakeBlockGate([['p1', 'c1']]);
    const deps = { providers: gateOf([]), blocks };
    assert.equal(await orderBlocker(deps, parties), 'not_accepting_orders');
    assert.deepEqual(blocks.calls, []);
  });

  it('without blocks deps orderBlocker ignores blocks', async () => {
    assert.equal(await orderBlocker({ providers: gateOf() }, parties), null);
  });

  it('assertOrderAllowed throws DomainError with the blocker code and resolves when null', async () => {
    await assert.rejects(
      assertOrderAllowed({ providers: gateOf([]) }, parties),
      (e: unknown) => e instanceof DomainError && e.code === 'not_accepting_orders',
    );
    await assert.rejects(
      assertOrderAllowed({ providers: gateOf(), blocks: new FakeBlockGate([['c1', 'p1']]) }, parties),
      (e: unknown) => e instanceof DomainError && e.code === 'blocked',
    );
    await assert.doesNotReject(assertOrderAllowed({ providers: gateOf(), blocks: new FakeBlockGate() }, parties));
  });

  it('FakeBlockGate unblock removes only that direction', async () => {
    const blocks = new FakeBlockGate([
      ['a', 'b'],
      ['b', 'a'],
    ]);
    blocks.unblock('a', 'b');
    assert.equal(await blocks.isBlockedEitherWay('a', 'b'), true); // b still blocks a
    blocks.unblock('b', 'a');
    assert.equal(await blocks.isBlockedEitherWay('a', 'b'), false);
    assert.deepEqual(blocks.calls, [
      ['a', 'b'],
      ['a', 'b'],
    ]);
  });
});
