import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { Dispute } from '../src/dispute.js';
import { notifyDisputeChange } from '../src/dispute_notifications.js';
import { openDispute, resolveDispute } from '../src/dispute_use_cases.js';
import { notifySupportMessage } from '../src/support_notifications.js';
import type { SupportMessage, SupportThread } from '../src/support_thread.js';
import { createDisputeWorld, openInput, seedApprovedBooking, seedTicket } from './support/dispute_world.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

function notifyWorld(): NotifyWorld {
  const n = createNotifyWorld();
  n.users.users.set('c1', { name: 'An', avatarUrl: null });
  n.users.users.set('p1', { name: 'Minh Trí', avatarUrl: null });
  return n;
}

async function opened(ticketPlatform = false): Promise<{ dispute: Dispute; thread: SupportThread }> {
  const w = createDisputeWorld();
  if (ticketPlatform) {
    seedTicket(w, { platform: true });
  } else {
    seedApprovedBooking(w);
  }
  const input = ticketPlatform
    ? openInput({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', reason: 'event_not_held' })
    : openInput();
  const dispute = await openDispute(w.deps, 'c1', input);
  const thread = w.store.threads.get(dispute.threadId);
  assert.ok(thread);
  return { dispute, thread };
}

const message = (over: Partial<SupportMessage>): SupportMessage => ({
  id: 'm1',
  threadId: 'dispute_d1',
  senderId: 'p1',
  senderRole: 'provider',
  senderName: 'Minh Trí',
  body: 'Tôi đã gửi lại link',
  createdAt: '2026-10-20T10:05:00.000Z',
  ...over,
});

describe('dispute notifications', () => {
  it('open calls notifyDisputeOpened for the provider only, not a platform payee', async () => {
    const n = notifyWorld();
    const { dispute } = await opened();
    await notifyDisputeChange(n.deps, null, dispute);
    const rows = n.store.rowsOf('p1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'dispute_opened');
    assert.equal(rows[0]?.target, '/disputes/d1');
    assert.equal(rows[0]?.title, 'An báo vấn đề với buổi chụp');
    assert.equal(rows[0]?.body, 'Minh Trí · Chân dung. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại.');
    assert.equal(n.store.rowsOf('c1').length, 0);

    const platform = notifyWorld();
    const { dispute: ticket } = await opened(true);
    await notifyDisputeChange(platform.deps, null, ticket);
    assert.equal(platform.store.rows.size, 0);
  });

  it('resolve calls notifyDisputeResolved for every party', async () => {
    const n = notifyWorld();
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    const before = await openDispute(w.deps, 'c1', openInput());
    const { dispute: after } = await resolveDispute(w.deps, 'staff1', {
      disputeId: 'd1', outcome: 'split', refundPercent: 40, note: 'Thiếu một phần ảnh',
    });
    await notifyDisputeChange(n.deps, before, after);
    for (const uid of ['c1', 'p1']) {
      const rows = n.store.rowsOf(uid);
      assert.equal(rows.length, 1, uid);
      assert.equal(rows[0]?.type, 'dispute_resolved');
      assert.equal(rows[0]?.title, 'Khiếu nại đã có kết quả');
      assert.match(rows[0]?.body ?? '', /^Minh Trí · Chân dung: hoàn 200\.000\s?₫ cho khách, chuyển 300\.000\s?₫ cho Minh Trí\.$/);
    }
    // An unchanged open dispute (a later write) notifies nobody again.
    const quiet = notifyWorld();
    await notifyDisputeChange(quiet.deps, before, before);
    await notifyDisputeChange(quiet.deps, after, after);
    await notifyDisputeChange(quiet.deps, after, null);
    assert.equal(quiet.store.rows.size, 0);
  });

  it('staff message in a dispute thread calls notifySupportReply for all participants', async () => {
    const n = notifyWorld();
    const { thread } = await opened();
    await notifySupportMessage(n.deps, thread, message({ id: 'm_staff', senderId: 'staff1', senderRole: 'staff', senderName: 'Hỗ trợ', body: 'Đã nhận' }));
    for (const uid of ['c1', 'p1']) {
      const rows = n.store.rowsOf(uid);
      assert.equal(rows.length, 1, uid);
      assert.equal(rows[0]?.type, 'support_reply');
      assert.equal(rows[0]?.target, '/disputes/d1');
    }
  });

  it('a provider message calls notifyDisputeMessage for the customer', async () => {
    const n = notifyWorld();
    const { thread } = await opened();
    await notifySupportMessage(n.deps, thread, message({}));
    const rows = n.store.rowsOf('c1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'dispute_message');
    assert.equal(rows[0]?.title, 'Minh Trí nhắn trong khiếu nại');
    assert.equal(rows[0]?.body, 'Tôi đã gửi lại link');
    assert.equal(n.store.rowsOf('p1').length, 0);

    // The customer's own message goes to the provider.
    await notifySupportMessage(n.deps, thread, message({ id: 'm2', senderId: 'c1', senderRole: 'customer', senderName: 'An', body: 'Vẫn hỏng' }));
    assert.equal(n.store.rowsOf('p1')[0]?.type, 'dispute_message');
  });

  it('system messages notify nobody', async () => {
    const n = notifyWorld();
    const { thread } = await opened();
    await notifySupportMessage(n.deps, thread, message({ id: 'm_sys', senderId: null, senderRole: 'system', senderName: 'Hệ thống', body: 'Đã mở' }));
    assert.equal(n.store.rows.size, 0);
  });
  it('opening a dispute notifies the provider once', async () => {
    const n = notifyWorld();
    const w = createDisputeWorld();
    seedApprovedBooking(w);
    const dispute = await openDispute(w.deps, 'c1', openInput());
    const thread = w.store.threads.get(dispute.threadId);
    assert.ok(thread);
    const written = await w.store.listMessages(dispute.threadId, 10);
    assert.equal(written.length, 2);
    // The description carries the opening marker; the system line does not.
    assert.deepEqual(written.filter((m) => m.opening === true).map((m) => m.senderRole), ['customer']);

    // What the two triggers do with this one open: the dispute write, then each created message.
    await notifyDisputeChange(n.deps, null, dispute);
    for (const m of written) await notifySupportMessage(n.deps, thread, m);
    const rows = n.store.rowsOf('p1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'dispute_opened');
    assert.equal(n.store.rowsOf('c1').length, 0);

    // A later customer message is a dispute_message again.
    await notifySupportMessage(n.deps, thread, message({ id: 'm9', senderId: 'c1', senderRole: 'customer', senderName: 'An', body: 'Bổ sung ảnh' }));
    assert.deepEqual(n.store.rowsOf('p1').map((r) => r.type).sort(), ['dispute_message', 'dispute_opened']);
  });
});
