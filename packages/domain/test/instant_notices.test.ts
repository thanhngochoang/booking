import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { chatIdFor } from '../src/chat.js';
import type { InstantOffer, InstantOfferRow, InstantRequest } from '../src/instant.js';
import { instantNotices, instantTrackShouldGo, offerPushMessage, syncInstantChat, type InstantNotice } from '../src/instant_notices.js';
import {
  notifyInstantArrived,
  notifyInstantAssigned,
  notifyInstantCancelled,
  notifyInstantFinished,
  notifyInstantMissed,
  notifyInstantNoMatch,
  notifyInstantRoundEnded,
} from '../src/notification_hooks.js';
import type { NotifyDeps } from '../src/notification_ports.js';
import { openInquiry } from '../src/open_inquiry.js';
import { T0, aRequest, at, MIN } from './support/instant_fixtures.js';
import { createChatWorld } from './support/chat_world.js';
import { createNotifyWorld } from './support/notify_world.js';

const row = (over: Partial<InstantOfferRow>): InstantOfferRow => ({
  offerId: 'o1', photographerId: 'p1', name: 'Hà', avatarUrl: null, tomatoPct: 0, reviewCount: 0, etaMinutes: 4,
  outcome: 'pending', expiresAt: at(60_000), ...over,
});

const searching = aRequest({ status: 'searching', committedAt: T0, offers: [row({}), row({ offerId: 'o2', photographerId: 'p2' })] });
const job = (status: InstantRequest['status'], over: Partial<InstantRequest> = {}): InstantRequest =>
  aRequest({ status, committedAt: T0, photographerId: 'p1', chatId: chatIdFor('c-lan', 'p1'), etaMinutes: 4, assignedAt: T0, ...over });

/** What Task 5's trigger does with a notice: the matching #138 hook. */
function fire(d: NotifyDeps, n: InstantNotice, r: InstantRequest) {
  const base = { customerId: r.customerId, requestId: r.id };
  switch (n.hook) {
    case 'assigned':
      return notifyInstantAssigned(d, { ...base, photographerId: r.photographerId ?? '', etaMinutes: r.etaMinutes ?? 0 });
    case 'round_ended':
      return notifyInstantRoundEnded(d, { ...base, round: n.round });
    case 'no_match':
      return notifyInstantNoMatch(d, { ...base, round: n.round, amount: r.amountVnd });
    case 'arrived':
      return notifyInstantArrived(d, { ...base, photographerId: r.photographerId ?? '', place: r.meetPoint.name });
    case 'finished':
      return notifyInstantFinished(d, { ...base, photographerId: r.photographerId ?? '' });
    case 'cancelled':
      return notifyInstantCancelled(d, { ...base, by: n.by, photographerId: n.photographerId, feeVnd: n.feeVnd });
    case 'missed':
      return notifyInstantMissed(d, { photographerId: n.photographerId, offerId: n.offerId });
  }
}

/** Runs the decider and every hook; returns the single inbox row written. */
async function only(before: InstantRequest | null, after: InstantRequest, expected: InstantNotice) {
  const notices = instantNotices(before, after);
  assert.deepEqual(notices, [expected]);
  const nw = createNotifyWorld();
  nw.users.users.set('p1', { name: 'Hà Trần', avatarUrl: null });
  nw.users.users.set('c-lan', { name: 'Lan Anh', avatarUrl: null });
  for (const n of notices) await fire(nw.deps, n, after);
  const rows = [...nw.store.rows.values()];
  assert.equal(rows.length, 1);
  const r = rows[0];
  assert.ok(r);
  return r;
}

describe('instantNotices through #138 hooks', () => {
  test('assigned notifies the customer', async () => {
    const r = await only(searching, job('assigned'), { hook: 'assigned' });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_assigned', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Đã match với Hà Trần', 'Hà Trần đến trong khoảng 4 phút.']);
  });

  test('round ended notifies the customer', async () => {
    const after = aRequest({ ...searching, status: 'choosing', roundEnded: true, round: 2,
      offers: searching.offers.map((o) => ({ ...o, outcome: 'declined' as const })) });
    const r = await only({ ...searching, round: 2 }, after, { hook: 'round_ended', round: 2 });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_round_ended', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Chụp ngay', 'Chưa ai nhận. Chọn thêm người nhé.']);
  });

  test('no_match notifies the customer', async () => {
    const before = aRequest({ ...searching, status: 'choosing', roundEnded: true, round: 3, offers: [] });
    const r = await only(before, { ...before, status: 'no_match', roundEnded: false }, { hook: 'no_match', round: 3 });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_no_match', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Chưa tìm được nhiếp ảnh gia', '690.000₫ vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ.']);
  });

  test('arrived notifies the customer', async () => {
    const r = await only(job('en_route'), job('arrived'), { hook: 'arrived' });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_arrived', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Hà Trần đã đến điểm hẹn', 'Gặp nhau ở Cổng Trương Định, Công viên Tao Đàn.']);
  });

  test('finished notifies the customer', async () => {
    const r = await only(job('in_progress'), job('finished'), { hook: 'finished' });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_finished', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Hà Trần đã hoàn thành buổi chụp', 'Xác nhận hoàn thành trong 2 giờ, nếu không sẽ tự hoàn thành.']);
  });

  test('a customer cancel after assignment notifies the photographer', async () => {
    const after = job('cancelled_by_customer', { active: false, cancelledBy: 'customer', cancelRule: 'unpaid', feeVnd: 0 });
    const r = await only(job('en_route'), after, { hook: 'cancelled', by: 'customer', photographerId: 'p1', feeVnd: 0 });
    assert.deepEqual([r.userId, r.type, r.target], ['p1', 'instant_cancelled', '/work/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Khách đã huỷ chụp ngay', 'Không cần tới điểm hẹn nữa.']);
    assert.deepEqual(instantNotices(searching, aRequest({ ...searching, status: 'cancelled_by_customer', active: false })), []);
  });

  test('a photographer cancel notifies the customer', async () => {
    const after = aRequest({ status: 'choosing', committedAt: T0, cancelledBy: 'photographer', roundEnded: true, excludedIds: ['p1'] });
    const r = await only(job('assigned'), after, { hook: 'cancelled', by: 'photographer', photographerId: 'p1', feeVnd: 0 });
    assert.deepEqual([r.userId, r.type, r.target], ['c-lan', 'instant_cancelled', '/instant/ir_01']);
    assert.deepEqual([r.title, r.body], ['Hà Trần đã huỷ', 'Chọn người khác, không trả thêm.']);
  });

  test('each expired row notifies its photographer once (missed)', async () => {
    const after = { ...searching, offers: [row({ outcome: 'expired' }), searching.offers[1] as InstantOfferRow] };
    const r = await only(searching, after, { hook: 'missed', photographerId: 'p1', offerId: 'o1' });
    assert.deepEqual([r.userId, r.type, r.target, r.id], ['p1', 'instant_missed', '/work/instant', 'n_instant_missed_o1']);
    assert.deepEqual([r.title, r.body], ['Bạn đã bỏ lỡ một lời mời', 'Lời mời chụp ngay đã hết hạn.']);
    const both = { ...searching, status: 'choosing' as const, roundEnded: true,
      offers: searching.offers.map((o) => ({ ...o, outcome: 'expired' as const })) };
    assert.deepEqual(instantNotices(searching, both), [
      { hook: 'missed', photographerId: 'p1', offerId: 'o1' },
      { hook: 'missed', photographerId: 'p2', offerId: 'o2' },
      { hook: 'round_ended', round: 1 },
    ]);
  });

  test('no notice for a write that changes nothing visible (heartbeat-like version bump)', () => {
    assert.deepEqual(instantNotices(searching, { ...searching, version: searching.version + 1, updatedAt: at(MIN) }), []);
    assert.deepEqual(instantNotices(job('assigned'), { ...job('assigned'), version: 9 }), []);
    assert.deepEqual(instantNotices(null, aRequest()), []);
    assert.deepEqual(instantNotices(searching, null), []);
  });
});

describe('offer push, chat and track', () => {
  const offer: InstantOffer = {
    id: 'o9', requestId: 'ir_01', photographerId: 'p1', round: 1, offeredAt: T0, expiresAt: at(60_000), outcome: 'pending',
    decidedAt: null, packageCode: 'p60', durationMin: 60, photos: 30, genre: 'portrait', areaLabel: 'Quận 1, TP.HCM',
    distanceKm: 1.2, etaMinutes: 6, earningVnd: 552_000, note: '', invitedCount: 3,
  };

  test("offerPushMessage text and data {type: 'instant_offer', target: '/work/instant/offer/{id}'}, channel default", () => {
    assert.deepEqual(offerPushMessage(offer), {
      title: 'Lời mời chụp ngay',
      body: 'Chân dung 1 giờ · Quận 1, TP.HCM · bạn nhận 552.000₫. Còn 60 giây.',
      channel: 'default',
      data: { type: 'instant_offer', target: '/work/instant/offer/o9' },
    });
    assert.equal(offerPushMessage({ ...offer, genre: 'event', durationMin: 30 }).body,
      'Sự kiện nhỏ 30 phút · Quận 1, TP.HCM · bạn nhận 552.000₫. Còn 60 giây.');
  });

  test('syncInstantChat creates a booking-kind chat on assignment, upgrades an inquiry chat, closes it 7 days after the end', async () => {
    const cw = createChatWorld();
    assert.equal(await syncInstantChat(cw.deps, searching, job('assigned')), 'created');
    const id = chatIdFor('c-lan', 'p1');
    const chat = cw.chats.chats.get(id);
    assert.deepEqual([chat?.kind, chat?.bookingId, chat?.readOnlyAt], ['booking', null, null]);
    assert.equal(await syncInstantChat(cw.deps, job('assigned'), job('en_route')), 'none');
    const done = job('completed', { active: false, completedAt: T0 });
    assert.equal(await syncInstantChat(cw.deps, job('finished'), done), 'closed');
    assert.deepEqual(cw.chats.chats.get(id)?.readOnlyAt, new Date(cw.clock.now().getTime() + 7 * 86_400_000));
    assert.equal(await syncInstantChat(cw.deps, job('finished'), done), 'none');

    const iw = createChatWorld();
    const { chatId } = await openInquiry(iw.deps, { customerId: 'c-lan', photographerId: 'p1' });
    assert.equal(iw.chats.chats.get(chatId)?.kind, 'inquiry');
    assert.equal(await syncInstantChat(iw.deps, searching, job('assigned')), 'upgraded');
    assert.deepEqual([iw.chats.chats.get(chatId)?.kind, iw.chats.chats.get(chatId)?.readOnlyAt], ['booking', null]);
    const dropped = aRequest({ status: 'choosing', committedAt: T0, cancelledBy: 'photographer' });
    assert.equal(await syncInstantChat(iw.deps, job('assigned'), dropped), 'closed');
  });

  test('instantTrackShouldGo when leaving en_route', () => {
    assert.equal(instantTrackShouldGo(job('en_route'), job('arrived')), true);
    assert.equal(instantTrackShouldGo(job('en_route'), job('cancelled_by_customer', { active: false })), true);
    assert.equal(instantTrackShouldGo(job('en_route'), null), true);
    assert.equal(instantTrackShouldGo(job('en_route'), job('en_route', { version: 3 })), false);
    assert.equal(instantTrackShouldGo(job('assigned'), job('en_route')), false);
  });
});
