import assert from 'node:assert/strict';
import { describe, test, type TestContext } from 'node:test';
import {
  BOOKING_CHAT_READONLY_DAYS,
  MemoryChatStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  chatIdFor,
  type ChatDeps,
  type InstantOfferRow,
  type InstantRequest,
  type NotifyDeps,
} from '@photobooking/domain';
import { handleInstantRequestWrite, type InstantRequestWriteDeps } from '../../src/triggers/instant_request_write.js';
import { T0, aRequest } from '../../../../../packages/domain/test/support/instant_fixtures.js';

const at = (ms: number): Date => new Date(T0.getTime() + ms);
const EVENT_TIME = T0.toISOString();
const CHAT = chatIdFor('c-lan', 'p1');

const row = (over: Partial<InstantOfferRow>): InstantOfferRow => ({
  offerId: 'o1', photographerId: 'p1', name: 'Hà', avatarUrl: null, tomatoPct: 0, reviewCount: 0, etaMinutes: 4,
  outcome: 'pending', expiresAt: at(60_000), ...over,
});

const searching = aRequest({ status: 'searching', committedAt: T0, offers: [row({}), row({ offerId: 'o2', photographerId: 'p2' })] });
const job = (status: InstantRequest['status'], over: Partial<InstantRequest> = {}): InstantRequest =>
  aRequest({ status, committedAt: T0, photographerId: 'p1', chatId: CHAT, etaMinutes: 4, assignedAt: T0, ...over });

function world() {
  const store = new MemoryNotificationStore();
  const users = new MemoryUserDirectory();
  users.users.set('p1', { name: 'Hà Trần', avatarUrl: null });
  users.users.set('c-lan', { name: 'Lan Anh', avatarUrl: null });
  const notify: NotifyDeps = { store, push: new MemoryPushSender(), users, clock: { now: () => T0 } };
  const chats = new MemoryChatStore();
  const chat: ChatDeps = {
    chats,
    photographers: { acceptsInquiries: async () => true },
    blocks: { isBlockedEitherWay: async () => false } as unknown as ChatDeps['blocks'],
    clock: { now: () => T0 },
    ids: { newId: () => 'id_1' },
  };
  const deleted: string[] = [];
  const deps: InstantRequestWriteDeps = { notify, chat, deleteTrack: async (id) => { deleted.push(id); } };
  return { deps, store, chats, deleted };
}

/** Swallows the trigger's structured log lines so the test output stays clean; returns them. */
function quietLogs(t: TestContext): string[] {
  const lines: string[] = [];
  const keep = (chunk: unknown) => { lines.push(String(chunk)); return true; };
  t.mock.method(process.stdout, 'write', keep);
  t.mock.method(process.stderr, 'write', keep);
  return lines;
}

describe('handleInstantRequestWrite', () => {
  test('assignment notifies the customer and creates the chat', async () => {
    const w = world();
    const out = await handleInstantRequestWrite(
      { requestId: 'ir_01', before: searching, after: job('assigned'), time: EVENT_TIME }, w.deps, at(1_000));
    assert.deepEqual(out, { notices: 1, chat: 'created', trackDeleted: false });
    const rows = [...w.store.rows.values()];
    assert.deepEqual(rows.map((r) => [r.userId, r.type, r.target]), [['c-lan', 'instant_assigned', '/instant/ir_01']]);
    const chat = w.chats.chats.get(CHAT);
    assert.ok(chat);
    assert.deepEqual([chat.kind, chat.customerId, chat.photographerId, chat.bookingId, chat.readOnlyAt], ['booking', 'c-lan', 'p1', null, null]);
  });

  test('trigger notifies missed offers once', async () => {
    const w = world();
    const expired = { ...searching, status: 'choosing' as const, roundEnded: true,
      offers: searching.offers.map((o) => ({ ...o, outcome: 'expired' as const })) };
    const input = { requestId: 'ir_01', before: searching, after: expired, time: EVENT_TIME };
    const first = await handleInstantRequestWrite(input, w.deps, at(61_000));
    assert.equal(first.notices, 3); // two missed + round ended
    const keys = () => [...w.store.rows.values()].filter((r) => r.type === 'instant_missed').map((r) => `${r.userId}/${r.id}`).sort();
    const once = keys();
    assert.deepEqual(once, ['p1/n_instant_missed_o1', 'p2/n_instant_missed_o2']);
    const writes = w.store.writes;
    // Functions redelivers the same event: the same dedupe keys, nothing written twice.
    await handleInstantRequestWrite(input, w.deps, at(62_000));
    assert.deepEqual(keys(), once);
    assert.equal(w.store.writes, writes);
    assert.equal(w.store.rows.size, 3);
  });

  test('leaving en_route deletes the track', async () => {
    const w = world();
    const out = await handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('en_route'), after: job('arrived', { arrivedAt: T0 }), time: EVENT_TIME }, w.deps, at(1_000));
    assert.equal(out.trackDeleted, true);
    assert.deepEqual(w.deleted, ['ir_01']);
    // Any other write leaves the track alone.
    await handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('assigned'), after: job('en_route'), time: EVENT_TIME }, w.deps, at(1_000));
    assert.deepEqual(w.deleted, ['ir_01']);
  });

  test('a stale event (> 1 h) does nothing', async (t) => {
    const lines = quietLogs(t);
    const w = world();
    const out = await handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('en_route'), after: job('arrived'), time: EVENT_TIME }, w.deps, at(60 * 60_000 + 1));
    t.mock.restoreAll();
    assert.deepEqual(out, { notices: 0, chat: 'expired', trackDeleted: false });
    assert.equal(w.store.rows.size, 0);
    assert.equal(w.chats.chats.size, 0);
    assert.deepEqual(w.deleted, []);
    assert.equal(lines.length, 1);
    assert.doesNotMatch(lines[0] ?? '', /Tao Đàn|c-lan/);
  });

  test('a failing notice does not stop the others', async (t) => {
    const lines = quietLogs(t);
    const w = world();
    // The prefs of p1 cannot be read: the missed notice of p1 throws, the one of p2 and the
    // round-ended notice still go out.
    const store = w.store;
    store.getPrefs = async (uid) => {
      if (uid === 'p1') throw new Error('prefs of p1 unavailable at Tao Đàn');
      return null;
    };
    const failing: InstantRequestWriteDeps = { ...w.deps, notify: { ...w.deps.notify, store } };
    const expired = { ...searching, status: 'choosing' as const, roundEnded: true,
      offers: searching.offers.map((o) => ({ ...o, outcome: 'expired' as const })) };
    const out = await handleInstantRequestWrite(
      { requestId: 'ir_01', before: searching, after: expired, time: EVENT_TIME }, failing, at(61_000));
    t.mock.restoreAll();
    assert.equal(out.notices, 2);
    assert.deepEqual([...w.store.rows.values()].map((r) => [r.userId, r.type]).sort(),
      [['c-lan', 'instant_round_ended'], ['p2', 'instant_missed']]);
    assert.equal(lines.length, 1);
    assert.match(lines[0] ?? '', /notice failed/);
    assert.doesNotMatch(lines[0] ?? '', /Tao Đàn/);
  });

  test('an unpaid no_match row carries no money sentence', async () => {
    const w = world();
    const before = aRequest({ ...searching, status: 'choosing', roundEnded: true, round: 3, offers: [] });
    await handleInstantRequestWrite(
      { requestId: 'ir_01', before, after: { ...before, status: 'no_match', roundEnded: false }, time: EVENT_TIME }, w.deps, at(1_000));
    const rows = [...w.store.rows.values()];
    assert.deepEqual(rows.map((r) => [r.type, r.body]),
      [['instant_no_match', 'Gần bạn lúc này ít người đang sẵn sàng. Chọn thêm người nhé.']]);
  });

  test('the end of the job closes the pair chat 7 days later', async () => {
    const w = world();
    await handleInstantRequestWrite({ requestId: 'ir_01', before: searching, after: job('assigned'), time: EVENT_TIME }, w.deps, at(1_000));
    const done = job('completed', { active: false, completedAt: T0 });
    const out = await handleInstantRequestWrite({ requestId: 'ir_01', before: job('finished'), after: done, time: EVENT_TIME }, w.deps, at(1_000));
    assert.equal(out.chat, 'closed');
    assert.equal(w.chats.chats.get(CHAT)?.readOnlyAt?.getTime(), T0.getTime() + BOOKING_CHAT_READONLY_DAYS * 86_400_000);
  });

  test('a failed track delete is retried (rethrown) after the notices went out', async (t) => {
    quietLogs(t);
    const w = world();
    const deps: InstantRequestWriteDeps = { ...w.deps, deleteTrack: () => Promise.reject(Object.assign(new Error('unavailable'), { code: 14 })) };
    await assert.rejects(handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('en_route'), after: job('arrived', { arrivedAt: T0 }), time: EVENT_TIME }, deps, at(1_000)));
    t.mock.restoreAll();
    assert.deepEqual([...w.store.rows.values()].map((r) => r.type), ['instant_arrived']);
  });
});
