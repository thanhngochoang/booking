import { strict as assert } from 'node:assert';
import test from 'node:test';
import { handleFollowWrite } from '../../src/triggers/engagement_counters.js';
import type { FollowerCounter, ApplyOutcome } from '../../src/infra/follower_counter.js';

class FakeFollowerCounter implements FollowerCounter {
  calls: Array<{ pid: string; eventAt: string; recount: number }> = [];
  recounts = new Map<string, number>();
  outcomes = new Map<string, ApplyOutcome>();

  async recount(pid: string): Promise<number> {
    return this.recounts.get(pid) ?? 0;
  }

  async apply(pid: string, eventAt: string, recount: number): Promise<ApplyOutcome> {
    this.calls.push({ pid, eventAt, recount });
    return this.outcomes.get(pid) ?? 'written';
  }
}

test('engagement_counters.test.ts: handleFollowWrite', async (t) => {
  await t.test('a created follow recounts its photographer and applies with the event time', async () => {
    const counter = new FakeFollowerCounter();
    counter.recounts.set('photographer_1', 3);
    const event = {
      time: '2026-10-07T10:00:00.000Z',
      before: null,
      after: { userId: 'user_1', photographerId: 'photographer_1' },
    };

    const result = await handleFollowWrite(event, counter);
    assert.equal(result, 'written');
    assert.deepEqual(counter.calls, [
      { pid: 'photographer_1', eventAt: '2026-10-07T10:00:00.000Z', recount: 3 },
    ]);
  });

  await t.test('a deleted follow recounts from before', async () => {
    const counter = new FakeFollowerCounter();
    counter.recounts.set('photographer_1', 2);
    const event = {
      time: '2026-10-07T10:05:00.000Z',
      before: { userId: 'user_1', photographerId: 'photographer_1' },
      after: null,
    };

    const result = await handleFollowWrite(event, counter);
    assert.equal(result, 'written');
    assert.deepEqual(counter.calls, [
      { pid: 'photographer_1', eventAt: '2026-10-07T10:05:00.000Z', recount: 2 },
    ]);
  });

  await t.test('an in-place update of the same marker is ignored', async () => {
    const counter = new FakeFollowerCounter();
    const event = {
      time: '2026-10-07T10:00:00.000Z',
      before: { userId: 'user_1', photographerId: 'photographer_1' },
      after: { userId: 'user_1', photographerId: 'photographer_1' },
    };

    const result = await handleFollowWrite(event, counter);
    assert.equal(result, 'ignored');
    assert.equal(counter.calls.length, 0);
  });

  await t.test('a retried event writes nothing new (apply returns unchanged)', async () => {
    const counter = new FakeFollowerCounter();
    counter.recounts.set('photographer_1', 5);
    counter.outcomes.set('photographer_1', 'unchanged');
    const event = {
      time: '2026-10-07T10:00:00.000Z',
      before: null,
      after: { userId: 'user_1', photographerId: 'photographer_1' },
    };

    const result = await handleFollowWrite(event, counter);
    assert.equal(result, 'unchanged');
  });

  await t.test('a missing photographer document returns missing', async () => {
    const counter = new FakeFollowerCounter();
    counter.recounts.set('photographer_1', 1);
    counter.outcomes.set('photographer_1', 'missing');
    const event = {
      time: '2026-10-07T10:00:00.000Z',
      before: null,
      after: { userId: 'user_1', photographerId: 'photographer_1' },
    };

    const result = await handleFollowWrite(event, counter);
    assert.equal(result, 'missing');
  });
});
