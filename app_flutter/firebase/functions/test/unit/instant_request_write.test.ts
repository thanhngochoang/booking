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
    // The others still go out, then the event is retried (the dedupe keys make the replay safe).
    await assert.rejects(handleInstantRequestWrite(
      { requestId: 'ir_01', before: searching, after: expired, time: EVENT_TIME }, failing, at(61_000)));
    t.mock.restoreAll();
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
      [['instant_no_match', 'Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn']]);
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

  test('photographer cancels, a second accepts: a second instant_assigned row; a replay still dedupes', async () => {
    const w = world();
    (w.deps.notify.users as MemoryUserDirectory).users.set('p2', { name: 'Minh Trí', avatarUrl: null });
    const first = job('assigned', { assignedAt: at(1_000) });
    await handleInstantRequestWrite({ requestId: 'ir_01', before: searching, after: first, time: EVENT_TIME }, w.deps, at(2_000));
    const reopened = aRequest({ status: 'choosing', committedAt: T0, cancelledBy: 'photographer', roundEnded: true, round: 2 });
    const cancel = { requestId: 'ir_01', before: first, after: reopened, time: EVENT_TIME };
    await handleInstantRequestWrite(cancel, w.deps, at(3_000));
    const second = job('assigned', { photographerId: 'p2', chatId: chatIdFor('c-lan', 'p2'), assignedAt: at(90_000), round: 2 });
    const assign2 = { requestId: 'ir_01', before: reopened, after: second, time: EVENT_TIME };
    await handleInstantRequestWrite(assign2, w.deps, at(91_000));
    const writes = w.store.writes;
    await handleInstantRequestWrite(assign2, w.deps, at(92_000)); // redelivered
    await handleInstantRequestWrite(cancel, w.deps, at(92_000));
    assert.equal(w.store.writes, writes);
    const ids = [...w.store.rows.values()].map((r) => r.id).sort();
    assert.deepEqual(ids, [
      `n_instant_assigned_ir_01_${at(1_000).getTime()}`,
      `n_instant_assigned_ir_01_${at(90_000).getTime()}`,
      `n_instant_cancelled_ir_01_photographer_${at(1_000).getTime()}`,
    ]);
    const titles = [...w.store.rows.values()].filter((r) => r.type === 'instant_assigned').map((r) => r.title).sort();
    assert.deepEqual(titles, ['Đã match với Hà Trần', 'Đã match với Minh Trí']);
  });

  test('a chat-sync failure is rethrown after the notices and the track delete ran', async (t) => {
    quietLogs(t);
    const w = world();
    const chat: ChatDeps = { ...w.deps.chat, chats: { ...w.chats, runTransaction: () => Promise.reject(new Error('unavailable')),
      pendingProposal: async () => null } };
    await assert.rejects(handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('en_route'), after: job('cancelled_by_customer', { active: false, cancelledBy: 'customer', feeVnd: 0 }),
        time: EVENT_TIME }, { ...w.deps, chat }, at(1_000)));
    t.mock.restoreAll();
    assert.deepEqual([...w.store.rows.values()].map((r) => r.type), ['instant_cancelled']);
    assert.deepEqual(w.deleted, ['ir_01']);
  });

  test('a job notice without a photographer is skipped and logged, never sent to an empty id', async (t) => {
    const lines = quietLogs(t);
    const w = world();
    const out = await handleInstantRequestWrite(
      { requestId: 'ir_01', before: job('in_progress'), after: job('finished', { photographerId: null }), time: EVENT_TIME }, w.deps, at(1_000));
    t.mock.restoreAll();
    assert.equal(out.notices, 0);
    assert.equal(w.store.rows.size, 0);
    assert.ok(lines.some((l) => /missing_photographer/.test(l)));
  });
});
