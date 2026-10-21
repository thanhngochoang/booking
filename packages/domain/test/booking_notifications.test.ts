import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { Booking } from '../src/booking.js';
import {
  bookingNotices,
  dueReminders,
  notifyBookingChange,
  sendDueReminders,
} from '../src/booking_notifications.js';
import { makeTestBooking } from './support/booking_fixtures.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

const b = (over: Partial<Booking>): Booking => makeTestBooking({ day: '2026-10-12', start: '15:30', ...over });

describe('bookingNotices', () => {
  it('maps status changes to recipients', () => {
    assert.deepEqual(bookingNotices(b({ status: 'draft' }), b({ status: 'requested' })), [{ to: 'photographer', kind: 'request' }]);
    assert.deepEqual(bookingNotices(b({ status: 'requested' }), b({ status: 'accepted' })), [{ to: 'customer', kind: 'accepted' }]);
    assert.deepEqual(bookingNotices(b({ status: 'requested' }), b({ status: 'upcoming' })), [{ to: 'customer', kind: 'accepted' }]);
    assert.deepEqual(bookingNotices(b({ status: 'requested' }), b({ status: 'declined' })), [{ to: 'customer', kind: 'declined' }]);
    assert.deepEqual(bookingNotices(b({ status: 'requested' }), b({ status: 'expired' })), [{ to: 'customer', kind: 'expired' }]);
  });

  it('cancel goes to the other party; system to both', () => {
    const cancel = (by: 'customer' | 'photographer' | 'system') =>
      bookingNotices(b({ status: 'upcoming' }), b({ status: 'cancelled', cancel: { by, at: 'x', refundPercent: 50 } }));
    assert.deepEqual(cancel('customer'), [{ to: 'photographer', kind: 'cancelled' }]);
    assert.deepEqual(cancel('photographer'), [{ to: 'customer', kind: 'cancelled' }]);
    assert.deepEqual(cancel('system'), [
      { to: 'customer', kind: 'cancelled' },
      { to: 'photographer', kind: 'cancelled' },
    ]);
  });

  it('a studio_fault cancel is the customer\'s: only the studio hears about it (#136)', () => {
    const cancelled = b({ status: 'cancelled', cancel: { by: 'studio_fault', reason: 'assign_overdue', at: 'x', refundPercent: 100 } });
    assert.deepEqual(bookingNotices(b({ status: 'accepted' }), cancelled), [{ to: 'photographer', kind: 'cancelled' }]);
  });

  it('refund once when depositRefundedAt appears', () => {
    const was = b({ status: 'declined' });
    const now = b({ status: 'declined', depositRefundedAt: '2026-10-10T10:00:00.000Z', depositRefunded: 300000 });
    assert.deepEqual(bookingNotices(was, now), [{ to: 'customer', kind: 'refund' }]);
    assert.deepEqual(bookingNotices(now, { ...now, version: 9 }), []);
    assert.deepEqual(bookingNotices(was, b({ status: 'declined', depositRefundedAt: 'x', depositRefunded: 0 })), []);
  });

  it('creation, deletion, upcoming, completed and reviewed send nothing', () => {
    assert.deepEqual(bookingNotices(null, b({ status: 'draft' })), []);
    assert.deepEqual(bookingNotices(b({ status: 'draft' }), null), []);
    assert.deepEqual(bookingNotices(b({ status: 'accepted' }), b({ status: 'upcoming' })), []);
    assert.deepEqual(bookingNotices(b({ status: 'upcoming' }), b({ status: 'completed' })), []);
    assert.deepEqual(bookingNotices(b({ status: 'completed' }), b({ status: 'reviewed' })), []);
  });
});

describe('notifyBookingChange', () => {
  let w: NotifyWorld;
  beforeEach(() => {
    w = createNotifyWorld();
    w.users.users.set('c1', { name: 'An', avatarUrl: 'https://img/an.jpg' });
    w.users.users.set('p1', { name: 'Minh Trí', avatarUrl: 'https://img/mt.jpg' });
  });

  it('deposit paid notifies the photographer', async () => {
    await notifyBookingChange(w.deps, b({ status: 'draft' }), b({ status: 'requested' }));
    const [row] = w.store.rowsOf('p1');
    assert.equal(row?.id, 'n_booking_request_b_test_01');
    assert.equal(row?.target, '/bookings');
    assert.equal(row?.thumbUrl, 'https://img/an.jpg');
    assert.equal(row?.body, 'An · Gói Chân dung, T2 12/10 · 15:30. Còn 24 giờ để nhận.');
    assert.equal(w.store.rowsOf('c1').length, 0);
  });

  it('notification content for a booking with pickup contains no pickup text', async () => {
    const pickup = { name: 'Ga Sài Gòn, Quận 3' };
    await notifyBookingChange(w.deps, b({ status: 'draft', pickup }), b({ status: 'requested', pickup }));
    await notifyBookingChange(w.deps, b({ status: 'requested', pickup }), b({ status: 'accepted', pickup }));
    const rows = [...w.store.rowsOf('p1'), ...w.store.rowsOf('c1')];
    assert.equal(rows.length, 2);
    for (const row of rows) {
      assert.ok(!JSON.stringify(row).includes('Ga Sài Gòn'), JSON.stringify(row));
    }
  });

  it('accept notifies the customer', async () => {
    await notifyBookingChange(w.deps, b({ status: 'requested' }), b({ status: 'accepted' }));
    const [row] = w.store.rowsOf('c1');
    assert.equal(row?.title, 'Minh Trí đã nhận lịch');
    assert.equal(row?.body, 'T2 12/10 · 15:30, Phố đi bộ. Nhắn tin để chốt chi tiết.');
    assert.equal(row?.target, '/b/b_test_01');
    assert.equal(row?.thumbUrl, 'https://img/mt.jpg');
  });

  it('decline and expiry notify the customer with the refund percent', async () => {
    const cancel = { by: 'photographer' as const, at: 'x', refundPercent: 100 };
    await notifyBookingChange(w.deps, b({ status: 'requested' }), b({ status: 'declined', cancel }));
    assert.equal(w.store.rowsOf('c1')[0]?.body, 'Đã hoàn 100% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.');
    const w2 = createNotifyWorld();
    await notifyBookingChange(w2.deps, b({ status: 'requested' }), b({ status: 'expired' }));
    assert.equal(w2.store.rowsOf('c1')[0]?.title, 'Nhiếp ảnh gia chưa trả lời kịp');
    assert.equal(w2.store.rowsOf('c1')[0]?.body, 'Yêu cầu đã hết hạn. Đã hoàn 100% số bạn đã trả.');
  });

  it('a customer cancel notifies the photographer only', async () => {
    const cancel = { by: 'customer' as const, at: 'x', refundPercent: 50 };
    await notifyBookingChange(w.deps, b({ status: 'upcoming' }), b({ status: 'cancelled', cancel }));
    assert.equal(w.store.rowsOf('c1').length, 0);
    const [row] = w.store.rowsOf('p1');
    assert.equal(row?.title, 'An đã huỷ lịch');
    assert.equal(row?.body, 'T2 12/10 · 15:30.');
  });

  it('a photographer cancel tells the customer the refund', async () => {
    const cancel = { by: 'photographer' as const, at: 'x', refundPercent: 100 };
    await notifyBookingChange(w.deps, b({ status: 'upcoming' }), b({ status: 'cancelled', cancel }));
    assert.equal(w.store.rowsOf('c1')[0]?.body, 'T2 12/10 · 15:30. Hoàn 100% số bạn đã trả.');
  });

  it('a system cancel notifies both', async () => {
    const cancel = { by: 'system' as const, at: 'x', refundPercent: 100 };
    await notifyBookingChange(w.deps, b({ status: 'upcoming' }), b({ status: 'cancelled', cancel }));
    assert.equal(w.store.rowsOf('c1')[0]?.title, 'Lịch T2 12/10 · 15:30 đã bị huỷ');
    assert.equal(w.store.rowsOf('p1').length, 1);
  });

  it('refund once when depositRefundedAt appears', async () => {
    const was = b({ status: 'cancelled' });
    const now = b({ status: 'cancelled', depositRefundedAt: '2026-10-10T10:00:00.000Z', depositRefunded: 450000 });
    await notifyBookingChange(w.deps, was, now);
    await notifyBookingChange(w.deps, was, now);
    const rows = w.store.rowsOf('c1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.title, 'Đã hoàn 450.000₫');
  });

  it('upcoming, completed and reviewed send nothing', async () => {
    await notifyBookingChange(w.deps, b({ status: 'accepted' }), b({ status: 'upcoming' }));
    await notifyBookingChange(w.deps, b({ status: 'upcoming' }), b({ status: 'completed' }));
    await notifyBookingChange(w.deps, b({ status: 'completed' }), b({ status: 'reviewed' }));
    assert.equal(w.store.rows.size, 0);
    assert.equal(w.push.sent.length, 0);
  });

  it('a retried change is a duplicate', async () => {
    await notifyBookingChange(w.deps, b({ status: 'requested' }), b({ status: 'accepted' }));
    await notifyBookingChange(w.deps, b({ status: 'requested' }), b({ status: 'accepted' }));
    assert.equal(w.store.rowsOf('c1').length, 1);
    assert.equal(w.push.sent.length, 1);
  });

  it('missing users fall back to generic names', async () => {
    const w2 = createNotifyWorld();
    await notifyBookingChange(w2.deps, b({ status: 'draft' }), b({ status: 'requested' }));
    assert.match(w2.store.rowsOf('p1')[0]?.body ?? '', /^Khách hàng · /);
    assert.equal(w2.store.rowsOf('p1')[0]?.thumbUrl, null);
  });

  it('one failed recipient does not stop the other; the error is rethrown', async () => {
    const cancel = { by: 'system' as const, at: 'x', refundPercent: 100 };
    const real = w.store.getPrefs.bind(w.store);
    w.store.getPrefs = async (uid: string) => {
      if (uid === 'c1') throw new Error('boom');
      return real(uid);
    };
    await assert.rejects(
      notifyBookingChange(w.deps, b({ status: 'upcoming' }), b({ status: 'cancelled', cancel })),
      /failed for 1 recipient/,
    );
    assert.equal(w.store.rowsOf('p1').length, 1);
  });
});

describe('reminders', () => {
  const start = new Date('2026-10-12T08:30:00.000Z'); // 15:30 VN on 2026-10-12
  const at = (hoursBefore: number): Date => new Date(start.getTime() - hoursBefore * 3_600_000);
  const upcoming = b({ status: 'upcoming' });

  it('dueReminders: 23 h before → h24, 90 min before → h2, 19 h before → nothing (h24 skipped, h2 later)', () => {
    assert.deepEqual(dueReminders([upcoming], at(23)).map((d) => d.variant), ['h24']);
    assert.deepEqual(dueReminders([upcoming], at(1.5)).map((d) => d.variant), ['h2']);
    assert.deepEqual(dueReminders([upcoming], at(19)), []);
    assert.deepEqual(dueReminders([upcoming], at(24)).map((d) => d.variant), ['h24']);
    assert.deepEqual(dueReminders([upcoming], at(25)), []);
    assert.deepEqual(dueReminders([upcoming], at(0)), []);
    assert.deepEqual(dueReminders([b({ status: 'accepted' })], at(23)), []);
  });

  it('sendDueReminders notifies both parties once, repeats are duplicates, and respects the reminder switch', async () => {
    const w = createNotifyWorld(at(1.5));
    w.users.users.set('c1', { name: 'An', avatarUrl: null });
    w.users.users.set('p1', { name: 'Minh Trí', avatarUrl: null });
    assert.equal(await sendDueReminders(w.deps, [upcoming]), 2);
    assert.equal(await sendDueReminders(w.deps, [upcoming]), 0);
    assert.equal(w.store.rowsOf('c1')[0]?.id, 'n_shoot_reminder_b_test_01_h2');
    assert.equal(w.store.rowsOf('c1')[0]?.title, 'Nhắc lịch: còn 2 giờ');
    assert.equal(w.store.rowsOf('c1')[0]?.body, 'Gói Chân dung với Minh Trí, T2 12/10 lúc 15:30.');
    assert.equal(w.store.rowsOf('p1')[0]?.body, 'Gói Chân dung với An, T2 12/10 lúc 15:30.');

    const w2 = createNotifyWorld(at(1.5));
    w2.store.prefs.set('c1', { reminders: { h2: false } });
    assert.equal(await sendDueReminders(w2.deps, [upcoming]), 1);
    assert.equal(w2.store.rowsOf('c1').length, 0);
  });

  it('one failing recipient does not skip the other', async () => {
    const w = createNotifyWorld(at(1.5));
    const real = w.store.getPrefs.bind(w.store);
    w.store.getPrefs = async (uid: string) => {
      if (uid === 'c1') throw new Error('boom');
      return real(uid);
    };
    await assert.rejects(sendDueReminders(w.deps, [upcoming]), /reminders failed/);
    assert.equal(w.store.rowsOf('p1').length, 1);
  });
});
