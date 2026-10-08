import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  chatPreview,
  formatDayShortVi,
  formatVnd,
  renderNotification,
  type NotificationContent,
} from '../src/notification_render.js';

describe('renderNotification', () => {
  it('booking_request reads like the plan copy', () => {
    assert.deepEqual(
      renderNotification({ type: 'booking_request', customer: 'An', service: 'Chân dung', day: 'T7 10/10', start: '15:30' }),
      { title: 'Yêu cầu đặt lịch mới', body: 'An · Chân dung, T7 10/10 · 15:30. Còn 24 giờ để nhận.' },
    );
  });

  it('booking_accepted matches the mock row', () => {
    assert.deepEqual(
      renderNotification({ type: 'booking_accepted', photographer: 'Minh Trí', day: 'T7 12/10', start: '15:30', place: 'Bến Bạch Đằng' }),
      { title: 'Minh Trí đã nhận lịch', body: 'T7 12/10 · 15:30, Bến Bạch Đằng. Nhắn tin để chốt chi tiết.' },
    );
  });

  it('booking_declined has a declined and an expired variant', () => {
    assert.deepEqual(renderNotification({ type: 'booking_declined', reason: 'declined', photographer: 'Lan Chi', percent: 100 }), {
      title: 'Lan Chi không nhận được lịch',
      body: 'Đã hoàn 100% số đã trả. Xem các nhiếp ảnh gia còn rảnh.',
    });
    assert.deepEqual(renderNotification({ type: 'booking_declined', reason: 'expired', photographer: 'Lan Chi', percent: 100 }), {
      title: 'Lan Chi chưa trả lời kịp',
      body: 'Yêu cầu đã hết hạn. Đã hoàn 100% số đã trả.',
    });
  });

  it('booking_cancelled by a party, with and without refund, and by the system', () => {
    const base = { type: 'booking_cancelled', name: 'An', day: 'T7 10/10', start: '15:30' } as const;
    assert.deepEqual(renderNotification({ ...base, by: 'party', percent: 50 }), {
      title: 'An đã huỷ lịch',
      body: 'T7 10/10 · 15:30. Hoàn 50% số đã trả.',
    });
    assert.deepEqual(renderNotification({ ...base, by: 'party', percent: null }), {
      title: 'An đã huỷ lịch',
      body: 'T7 10/10 · 15:30.',
    });
    assert.deepEqual(renderNotification({ ...base, by: 'system', percent: null }), {
      title: 'Lịch T7 10/10 · 15:30 đã bị huỷ',
      body: 'Xem chi tiết trong lịch hẹn.',
    });
  });

  it('refund_done shows 450.000₫ and #A0C2', () => {
    assert.deepEqual(renderNotification({ type: 'refund_done', amount: 450000, bookingId: 'bk_x9a0c2' }), {
      title: 'Đã hoàn 450.000₫',
      body: 'Khoản thanh toán buổi chụp #A0C2 đã về tài khoản của bạn.',
    });
  });

  it('shoot_reminder matches the mock row', () => {
    assert.deepEqual(
      renderNotification({ type: 'shoot_reminder', hours: 24, service: 'Chân dung 2 giờ', counterpart: 'Minh Trí', day: 'T7 12/10', start: '15:30' }),
      { title: 'Nhắc lịch: còn 24 giờ', body: 'Chân dung 2 giờ với Minh Trí, T7 12/10 lúc 15:30.' },
    );
  });

  it('review excerpt stops at 80 graphemes with an ellipsis', () => {
    const long = 'á'.repeat(90);
    const r = renderNotification({ type: 'review_new', customer: 'An', rating: 5, text: long });
    assert.equal(r.title, 'An đã đánh giá 5 sao');
    assert.equal(r.body, `“${'á'.repeat(80)}…”`);
    assert.equal(renderNotification({ type: 'review_new', customer: 'An', rating: 4, text: 'Tốt' }).body, '“Tốt”');
  });

  it('badge_new, artist and chat copy', () => {
    assert.deepEqual(renderNotification({ type: 'badge_new', name: 'Khen đúng giờ', description: '5 đánh giá khen đúng giờ' }), {
      title: 'Bạn nhận huy hiệu “Khen đúng giờ”',
      body: '5 đánh giá khen đúng giờ',
    });
    assert.equal(renderNotification({ type: 'artist_granted' }).title, 'Bạn đã lên hạng Nhiếp ảnh gia');
    assert.equal(renderNotification({ type: 'artist_revoked' }).title, 'Hạng Nhiếp ảnh gia đã thay đổi');
    assert.deepEqual(renderNotification({ type: 'chat_message', sender: 'Lan', preview: 'Chào bạn', count: 1 }), {
      title: 'Lan',
      body: 'Chào bạn',
    });
  });

  it("chat count 3 reads '3 tin nhắn mới'", () => {
    assert.equal(renderNotification({ type: 'chat_message', sender: 'Lan', preview: 'x', count: 3 }).body, '3 tin nhắn mới');
  });

  it('chatPreview names images and locations and cuts text', () => {
    assert.equal(chatPreview('image', ''), 'Đã gửi một ảnh');
    assert.equal(chatPreview('location', ''), 'Đã gửi một vị trí');
    assert.equal(chatPreview('text', 'a'.repeat(100)), `${'a'.repeat(80)}…`);
  });

  it('award statuses each have a title', () => {
    const titles = (['approved', 'needs_info', 'rejected', 'revoked'] as const).map(
      (status) => renderNotification({ type: 'award_reviewed', status } satisfies NotificationContent).title,
    );
    assert.deepEqual(titles, [
      'Giải thưởng đã được duyệt',
      'Giải thưởng cần bổ sung',
      'Giải thưởng chưa được duyệt',
      'Giải thưởng đã bị thu hồi',
    ]);
  });
});

describe('formatting helpers', () => {
  it('formatDayShortVi gives T7 10/10 for 2026-10-10 and CN 11/10 for 2026-10-11', () => {
    assert.equal(formatDayShortVi('2026-10-10'), 'T7 10/10');
    assert.equal(formatDayShortVi('2026-10-11'), 'CN 11/10');
    assert.equal(formatDayShortVi('2026-10-12'), 'T2 12/10');
  });

  it('formatVnd groups thousands with dots', () => {
    assert.equal(formatVnd(450000), '450.000₫');
    assert.equal(formatVnd(1200000), '1.200.000₫');
    assert.equal(formatVnd(500), '500₫');
  });
});
