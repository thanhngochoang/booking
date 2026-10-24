import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { collaboratorLimit, inCollabCooldown, isStaleInvite } from '../src/studio_collaboration.js';

describe('studio collaboration rules', () => {
  it('collaboratorLimit is 5 without business verification and 50 with it', () => {
    assert.equal(collaboratorLimit(false), 5);
    assert.equal(collaboratorLimit(true), 50);
  });

  it('the re-invite cooldown is 3 days after ended only', () => {
    const endedAt = new Date('2026-10-10T10:00:00.000Z');
    const at = (ms: number) => new Date(endedAt.getTime() + ms);
    const threeDays = 3 * 24 * 60 * 60 * 1000;
    assert.equal(inCollabCooldown({ status: 'ended', endedAt }, at(threeDays - 1)), true);
    assert.equal(inCollabCooldown({ status: 'ended', endedAt }, at(threeDays)), false);
    assert.equal(inCollabCooldown({ status: 'declined', endedAt }, at(0)), false);
    assert.equal(inCollabCooldown({ status: 'cancelled', endedAt }, at(0)), false);
  });

  it('an invite is stale from expiresAt on', () => {
    const expiresAt = new Date('2026-10-17T10:00:00.000Z');
    assert.equal(isStaleInvite({ status: 'invited', expiresAt }, new Date(expiresAt.getTime() - 1)), false);
    assert.equal(isStaleInvite({ status: 'invited', expiresAt }, expiresAt), true);
    assert.equal(isStaleInvite({ status: 'active', expiresAt }, expiresAt), false);
  });
});
