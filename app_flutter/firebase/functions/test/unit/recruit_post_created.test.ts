import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { RecruitDeps } from '@photobooking/domain';
import { handleRecruitPostCreated } from '../../src/triggers/recruit_post_created.js';
import { MAX_EVENT_AGE_MS } from '../../src/triggers/photographer_write.js';

const NOW = new Date('2026-10-10T03:00:00.000Z');
const deps = {} as RecruitDeps;

describe('onRecruitPostCreated', () => {
  it('calls notifyRecruitMatches once per created post', async () => {
    const calls: string[] = [];
    const out = await handleRecruitPostCreated(
      { postId: 'post_1', time: NOW.toISOString() },
      deps,
      NOW,
      async (d, postId) => {
        assert.equal(d, deps);
        calls.push(postId);
        return { sent: 2, capped: 1 };
      },
    );
    assert.deepEqual(calls, ['post_1']);
    assert.deepEqual(out, { sent: 2, capped: 1 });
  });

  it('an expired event (older than MAX_EVENT_AGE_MS) does nothing', async () => {
    const calls: string[] = [];
    const old = new Date(NOW.getTime() - MAX_EVENT_AGE_MS - 1).toISOString();
    const out = await handleRecruitPostCreated({ postId: 'post_1', time: old }, deps, NOW, async (_d, postId) => {
      calls.push(postId);
      return { sent: 0, capped: 0 };
    });
    assert.equal(out, 'expired');
    assert.deepEqual(calls, []);
  });
});
