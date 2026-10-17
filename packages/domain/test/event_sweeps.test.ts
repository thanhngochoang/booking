import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { runEventSweeps } from '../src/event_sweeps.js';
import { saveEventDraft } from '../src/event_use_cases.js';
import {
  END, createEventWorld, eventRecord, publishedEvent, rawEvent, register, cu1, sales1, ph1,
} from './support/event_world.js';

const DEADLINE = new Date('2026-10-03T14:00:00.000Z');
const after = (d: Date, ms = 1000) => new Date(d.getTime() + ms);

describe('runEventSweeps', () => {
  test('past deadline closes open and full events', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 1 }, ph1, 'aaaaaaaaaaaaaaaaaaaaa');
    await publishedEvent(w, {}, sales1, 'bbbbbbbbbbbbbbbbbbbbb');
    await register(w, cu1, 'aaaaaaaaaaaaaaaaaaaaa'); // a is now full
    assert.equal(w.store.events.get('aaaaaaaaaaaaaaaaaaaaa')?.status, 'full');
    w.clock.set(DEADLINE);
    assert.deepEqual(await runEventSweeps(w.deps), { closed: 2, completed: 0, consentExpired: 0, refunded: 0 });
    assert.equal(w.store.events.get('aaaaaaaaaaaaaaaaaaaaa')?.status, 'closed');
    assert.equal(w.store.events.get('bbbbbbbbbbbbbbbbbbbbb')?.status, 'closed');
  });

  test('before the deadline nothing changes', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.clock.set(new Date(DEADLINE.getTime() - 1));
    assert.deepEqual(await runEventSweeps(w.deps), { closed: 0, completed: 0, consentExpired: 0, refunded: 0 });
  });

  test('past end completes and stamps completedAt', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const now = after(new Date(END));
    w.clock.set(now);
    const r = await runEventSweeps(w.deps);
    assert.equal(r.completed, 1);
    const ev = w.store.events.get('ev1_aaaaaaaaaaaaaaaaaaaa');
    assert.equal(ev?.status, 'completed');
    assert.equal(ev?.completedAt?.getTime(), now.getTime());
    // the group chat closes for writing 7 days later
    assert.equal(w.store.chatReadOnlyAt.get('event_ev1_aaaaaaaaaaaaaaaaaaaa')?.getTime(), now.getTime() + 7 * 86_400_000);
  });

  test('cancelled and draft events are left alone', async () => {
    const w = createEventWorld();
    w.store.seedEvent(eventRecord({ id: 'c', hashtagKey: 'c', status: 'cancelled' }));
    await saveEventDraft(w.deps, ph1, rawEvent('ddddddddddddddddddddd'));
    w.clock.set(after(new Date(END), 86_400_000));
    assert.deepEqual(await runEventSweeps(w.deps), { closed: 0, completed: 0, consentExpired: 0, refunded: 0 });
    assert.equal(w.store.events.get('c')?.status, 'cancelled');
    assert.equal(w.store.events.get('ddddddddddddddddddddd')?.status, 'draft');
  });

  test('a sweep run twice changes nothing more', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.clock.set(after(new Date(END)));
    assert.deepEqual(await runEventSweeps(w.deps), { closed: 1, completed: 1, consentExpired: 0, refunded: 0 });
    const writes = w.store.writes;
    assert.deepEqual(await runEventSweeps(w.deps), { closed: 0, completed: 0, consentExpired: 0, refunded: 0 });
    assert.equal(w.store.writes, writes);
  });

  test('O1: an unanswered consent draft is cancelled after 24 hours', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, rawEvent('ev1_aaaaaaaaaaaaaaaaaaaa', 'sales1', { hostPhotographerId: 'ph1' }));
    w.clock.advance(24 * 3_600_000 - 1);
    assert.equal((await runEventSweeps(w.deps)).consentExpired, 0);
    w.clock.advance(1);
    assert.equal((await runEventSweeps(w.deps)).consentExpired, 1);
    const ev = w.store.events.get('ev1_aaaaaaaaaaaaaaaaaaaa');
    assert.deepEqual([ev?.hostConsent, ev?.status], ['expired', 'cancelled']);
    assert.equal(w.store.hashtags.size, 0);
    assert.equal((await runEventSweeps(w.deps)).consentExpired, 0);
  });

  test('one failing event is reported and does not block the others', async () => {
    const w = createEventWorld();
    await publishedEvent(w, {}, ph1, 'aaaaaaaaaaaaaaaaaaaaa');
    await publishedEvent(w, {}, sales1, 'bbbbbbbbbbbbbbbbbbbbb');
    w.clock.set(DEADLINE);
    const real = w.store.runTransaction.bind(w.store);
    let calls = 0;
    w.store.runTransaction = ((fn: never) => {
      calls += 1;
      if (calls === 1) throw new Error('boom');
      return real(fn);
    }) as typeof w.store.runTransaction;
    const failed: string[] = [];
    const r = await runEventSweeps(w.deps, (id, step) => failed.push(`${id}:${step}`));
    assert.equal(r.closed, 1);
    assert.equal(failed.length, 1);
    assert.match(failed[0] ?? '', /:close$/);
  });
});
