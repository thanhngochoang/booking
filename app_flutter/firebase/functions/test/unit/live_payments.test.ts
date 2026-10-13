import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { liveSettlementDeps } from '../../src/infra/live_payments.js';

describe('liveSettlementDeps', () => {
  it('registers booking and event_registration settlers and one gateway', () => {
    const deps = liveSettlementDeps();
    assert.ok(deps.payments);
    assert.ok(deps.gateway);
    assert.ok(deps.clock);
    assert.ok(deps.subjects.booking);
    assert.ok(deps.subjects.event_registration);
  });
});
