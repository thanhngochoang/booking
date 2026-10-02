import { describe, test, type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import type { ScoreSkillsDeps } from '@photobooking/domain';
import { handlePhotographerEvent, isPermanentFirestoreError, MAX_EVENT_AGE_MS } from '../../src/triggers/photographer_write.js';

// Final review item 5: onPhotographerWrite is deployed with retry: true; permanent failures and
// old events must end instead of being retried for ~7 days.

const NOW = new Date('2026-10-02T10:00:00Z');
const skills = { schemaVersion: 1, specialties: [{ id: 'portrait', level: 2, evidencePostIds: [] }], languages: ['vi'] };
const input = (ageMs: number) => ({
  uid: 'p1',
  time: new Date(NOW.getTime() - ageMs).toISOString(),
  before: undefined,
  after: { skills },
});

function failingDeps(error: unknown): ScoreSkillsDeps {
  return {
    posts: { owned: async () => new Set<string>() },
    writer: { write: () => Promise.reject(error), reread: () => assert.fail('no reread') },
  };
}

/**
 * Captures the error logs: the Functions logger keeps the original console methods, and
 * console.error writes structured JSON to stderr.
 */
function captureErrorLogs(t: TestContext): string[] {
  const lines: string[] = [];
  t.mock.method(process.stderr, 'write', (chunk: unknown) => {
    lines.push(String(chunk));
    return true;
  });
  return lines;
}

describe('onPhotographerWrite event policy', () => {
  test('permanent Firestore codes are INVALID_ARGUMENT (3) and PERMISSION_DENIED (7) only', () => {
    assert.equal(isPermanentFirestoreError({ code: 3 }), true);
    assert.equal(isPermanentFirestoreError({ code: 7 }), true);
    for (const e of [{ code: 14 }, { code: 4 }, { code: 9 }, new Error('x'), null, 'boom']) assert.equal(isPermanentFirestoreError(e), false);
  });

  test('an event older than 1 hour is dropped with an error log (uid only), before any Firestore access', async (t) => {
    const logs = captureErrorLogs(t);
    const outcome = await handlePhotographerEvent(input(MAX_EVENT_AGE_MS + 1), () => assert.fail('no deps for an old event'), NOW);
    assert.equal(outcome, 'expired');
    assert.equal(logs.length, 1);
    assert.match(logs[0] ?? '', /p1/);
    assert.doesNotMatch(logs[0] ?? '', /portrait|schemaVersion/);
  });

  test('an event just under 1 hour old is still handled', async () => {
    const writes: unknown[] = [];
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: { write: async (u) => (writes.push(u), 'written'), reread: () => assert.fail('no reread') },
    };
    assert.equal(await handlePhotographerEvent(input(MAX_EVENT_AGE_MS - 1_000), () => deps, NOW), 'written');
    assert.equal(writes.length, 1);
  });

  test('a permanent Firestore error is logged (uid and code, no message) and not rethrown', async (t) => {
    const logs = captureErrorLogs(t);
    const error = Object.assign(new Error('secret detail +84912000001'), { code: 7 });
    assert.equal(await handlePhotographerEvent(input(0), () => failingDeps(error), NOW), 'failed');
    assert.equal(logs.length, 1);
    assert.match(logs[0] ?? '', /p1/);
    assert.match(logs[0] ?? '', /7/);
    assert.doesNotMatch(logs[0] ?? '', /secret|\+84/);
  });

  test('a transient error is rethrown so Functions retries the event', async () => {
    const error = Object.assign(new Error('unavailable'), { code: 14 });
    await assert.rejects(handlePhotographerEvent(input(0), () => failingDeps(error), NOW), /unavailable/);
  });

  test('a missing or unparsable event time is handled (never dropped as old)', async () => {
    const deps: ScoreSkillsDeps = {
      posts: { owned: async () => new Set<string>() },
      writer: { write: async () => 'written', reread: () => assert.fail('no reread') },
    };
    assert.equal(await handlePhotographerEvent({ ...input(0), time: 'not a time' }, () => deps, NOW), 'written');
  });
});
