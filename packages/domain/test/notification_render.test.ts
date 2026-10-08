import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { NOTIFICATION_TYPES } from '../src/notification.js';
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
      body: 'Đã hoàn 100% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.',
    });
    assert.deepEqual(renderNotification({ type: 'booking_declined', reason: 'expired', photographer: 'Lan Chi', percent: 100 }), {
      title: 'Lan Chi chưa trả lời kịp',
      body: 'Yêu cầu đã hết hạn. Đã hoàn 100% số bạn đã trả.',
    });
  });

  it('booking_cancelled by a party, with and without refund, and by the system', () => {
    const base = { type: 'booking_cancelled', name: 'An', day: 'T7 10/10', start: '15:30' } as const;
    assert.deepEqual(renderNotification({ ...base, by: 'party', percent: 50 }), {
      title: 'An đã huỷ lịch',
      body: 'T7 10/10 · 15:30. Hoàn 50% số bạn đã trả.',
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
      body: 'Tiền buổi chụp #A0C2 đã về tài khoản của bạn.',
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

const DAY = '2026-10-12'; // T2 12/10
const JOB = 'Chụp kỷ yếu';
const POST = 'Tuyển thợ cưới';

/** The S17 Contract table, verbatim: [content, title, body]. */
const CASES: readonly (readonly [NotificationContent, string, string])[] = [
  [{ type: 'payout_released', amount: 1_250_000, count: 3 }, 'Đã chuyển 1.250.000₫ cho bạn', 'Tiền của 3 khoản đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.'],
  [{ type: 'quote_new', jobTitle: JOB, count: 1, names: ['Minh Trí'] }, 'Minh Trí đã báo giá cho việc “Chụp kỷ yếu”', 'Xem báo giá và chọn người phù hợp.'],
  [{ type: 'quote_new', jobTitle: JOB, count: 2, names: ['Minh Trí', 'Lan Chi'] }, '2 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”', 'Minh Trí và Lan Chi. Xem và so sánh báo giá.'],
  [{ type: 'quote_new', jobTitle: JOB, count: 3, names: ['Minh Trí', 'Lan Chi', 'Hà'] }, '3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”', 'Minh Trí, Lan Chi và 1 người khác. Xem và so sánh báo giá.'],
  [{ type: 'quote_withdrawn', photographer: 'Minh Trí', jobTitle: JOB, auto: true }, 'Minh Trí đã rút báo giá', 'Việc “Chụp kỷ yếu”: thợ đã kín lịch nên báo giá tự rút.'],
  [{ type: 'quote_withdrawn', photographer: 'Minh Trí', jobTitle: JOB, auto: false }, 'Minh Trí đã rút báo giá', 'Việc “Chụp kỷ yếu”. Xem các báo giá còn lại.'],
  [{ type: 'job_expiring', jobTitle: JOB, quoteCount: 4 }, 'Việc “Chụp kỷ yếu” hết hạn sau 24 giờ', 'Bạn có 4 báo giá. Chọn một người trước khi việc hết hạn.'],
  [{ type: 'job_expired', jobTitle: JOB }, 'Việc “Chụp kỷ yếu” đã hết hạn', 'Đăng lại hoặc gia hạn để nhận thêm báo giá.'],
  [{ type: 'job_match', jobTitle: JOB, day: DAY, area: 'Quận 1' }, 'Việc mới hợp với bạn: “Chụp kỷ yếu”', 'T2 12/10 · Quận 1. Xem và gửi báo giá.'],
  [{ type: 'job_invited', customer: 'An', jobTitle: JOB }, 'An mời bạn báo giá', 'Việc “Chụp kỷ yếu”. Xem chi tiết và gửi báo giá.'],
  [{ type: 'quote_accepted', customer: 'An', jobTitle: JOB }, 'An đã chọn báo giá của bạn', 'Việc “Chụp kỷ yếu” đã thanh toán. Mở buổi chụp để chốt chi tiết.'],
  [{ type: 'quote_not_selected', jobTitle: JOB, reason: 'awarded' }, 'Báo giá cho “Chụp kỷ yếu” chưa được chọn', 'Khách đã chọn người khác. Cảm ơn bạn đã báo giá.'],
  [{ type: 'quote_not_selected', jobTitle: JOB, reason: 'expired' }, 'Báo giá cho “Chụp kỷ yếu” chưa được chọn', 'Việc đã hết hạn mà khách chưa chọn ai.'],
  [{ type: 'quote_not_selected', jobTitle: JOB, reason: 'closed' }, 'Báo giá cho “Chụp kỷ yếu” chưa được chọn', 'Khách đã đóng việc.'],
  [{ type: 'quote_not_selected', jobTitle: JOB, reason: 'declined' }, 'Báo giá cho “Chụp kỷ yếu” chưa được chọn', 'Khách đã từ chối báo giá này.'],
  [{ type: 'job_selected' }, 'Bạn được chọn cho một việc', 'Mở Công việc để xem chi tiết.'],
  [{ type: 'instant_assigned', photographer: 'Minh Trí', etaMinutes: 15 }, 'Đã match với Minh Trí', 'Minh Trí đến trong khoảng 15 phút.'],
  [{ type: 'instant_missed' }, 'Bạn đã bỏ lỡ một lời mời', 'Lời mời chụp ngay đã hết hạn.'],
  [{ type: 'instant_round_ended', round: 1 }, 'Chụp ngay', 'Chưa ai nhận. Chọn thêm người nhé.'],
  [{ type: 'instant_no_match', amount: 300_000 }, 'Chưa tìm được nhiếp ảnh gia', '300.000₫ vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ.'],
  [{ type: 'instant_arrived', photographer: 'Minh Trí', place: 'Hồ Gươm' }, 'Minh Trí đã đến điểm hẹn', 'Gặp nhau ở Hồ Gươm.'],
  [{ type: 'instant_finished', photographer: 'Minh Trí' }, 'Minh Trí đã hoàn thành buổi chụp', 'Xác nhận hoàn thành trong 2 giờ, nếu không sẽ tự hoàn thành.'],
  [{ type: 'instant_cancelled', to: 'photographer', name: 'An', feeVnd: 50_000 }, 'Khách đã huỷ chụp ngay', 'Bạn nhận 50.000₫ phí đi lại.'],
  [{ type: 'instant_cancelled', to: 'photographer', name: 'An', feeVnd: 0 }, 'Khách đã huỷ chụp ngay', 'Không cần tới điểm hẹn nữa.'],
  [{ type: 'instant_cancelled', to: 'customer', name: 'Minh Trí', feeVnd: 0 }, 'Minh Trí đã huỷ', 'Chọn người khác, không trả thêm.'],
  [{ type: 'event_soon', title: 'Chụp phố đêm', daysLeft: 2, start: '19:00', place: 'Nhà hát Thành phố' }, 'Chụp phố đêm bắt đầu sau 2 ngày', 'Tập trung 19:00 tại Nhà hát Thành phố. Mang vé trong mục Vé.'],
  [{ type: 'review_tomato', hits: 3, day: DAY, text: 'Rất đẹp' }, 'Bạn nhận 🍅 ×3 từ buổi chụp T2 12/10', '“Rất đẹp”'],
  [{ type: 'review_brick', day: DAY, text: 'Trễ giờ' }, 'Có góp ý mới về buổi chụp T2 12/10', '“Trễ giờ”'],
  [{ type: 'delivery_submitted', deliverer: 'Minh Trí', count: 20 }, 'Minh Trí đã gửi ảnh mẫu', 'Xem 20 ảnh mẫu và đồng ý để nhận ảnh gốc.'],
  [{ type: 'delivery_revision_requested', customer: 'An', round: 2 }, 'An muốn chỉnh sửa vòng 2', 'Xem ghi chú của khách và nộp lại bàn giao.'],
  [{ type: 'delivery_approved', customer: 'An' }, 'An đã đồng ý ảnh', 'Tiền chuyển cho bạn sau 48 giờ kiểm tra.'],
  [{ type: 'delivery_auto_approve_soon', deliverer: 'Minh Trí' }, 'Còn 24 giờ để xem ảnh mẫu', 'Không phản hồi thì ảnh của Minh Trí được tự đồng ý.'],
  [{ type: 'delivery_extra_round', deliverer: 'Minh Trí', granted: true }, 'Minh Trí cho thêm một vòng sửa', 'Bạn có thể yêu cầu chỉnh sửa thêm một lần.'],
  [{ type: 'delivery_extra_round', deliverer: 'Minh Trí', granted: false }, 'Minh Trí không cho thêm vòng sửa', 'Bạn vẫn có thể đồng ý ảnh hoặc báo vấn đề với ảnh gốc.'],
  [{ type: 'studio_invite', studio: 'Studio Mây' }, 'Studio Mây mời bạn làm thành viên', 'Lời mời hết hạn sau 7 ngày.'],
  [{ type: 'studio_join_request', photographer: 'Minh Trí' }, 'Minh Trí xin gia nhập studio', 'Duyệt hoặc từ chối trong mục Thành viên.'],
  [{ type: 'studio_invite_accepted', photographer: 'Minh Trí' }, 'Minh Trí đã nhận lời mời', 'Minh Trí là thành viên của studio từ hôm nay.'],
  [{ type: 'studio_join_approved', studio: 'Studio Mây' }, 'Studio Mây đã duyệt bạn', 'Bạn là thành viên của Studio Mây từ hôm nay.'],
  [{ type: 'studio_removed', studio: 'Studio Mây' }, 'Bạn không còn là thành viên của Studio Mây', 'Xem chi tiết trong mục Studio của tôi.'],
  [{ type: 'studio_invite_expiring', studio: 'Studio Mây' }, 'Lời mời của Studio Mây hết hạn ngày mai', 'Chấp nhận hoặc từ chối trong mục Studio của tôi.'],
  [{ type: 'booking_assigned', to: 'customer', studio: 'Studio Mây', assignee: 'Minh Trí', day: DAY, start: '15:30' }, 'Studio Mây đã báo thợ chụp cho bạn', 'Minh Trí sẽ chụp buổi T2 12/10 · 15:30.'],
  [{ type: 'booking_assigned', to: 'assignee', studio: 'Studio Mây', assignee: 'Minh Trí', day: DAY, start: '15:30' }, 'Studio Mây giao cho bạn buổi T2 12/10 · 15:30', 'Mở buổi chụp để xem chi tiết.'],
  [{ type: 'booking_reassigned', to: 'customer', studio: 'Studio Mây', assignee: 'Lan Chi', day: DAY, start: '15:30' }, 'Studio Mây đã đổi thợ chụp', 'Lan Chi sẽ chụp buổi T2 12/10 · 15:30.'],
  [{ type: 'booking_reassigned', to: 'old', studio: 'Studio Mây', assignee: 'Lan Chi', day: DAY, start: '15:30' }, 'Buổi T2 12/10 · 15:30 đã giao cho người khác', 'Studio Mây đã đổi thợ cho buổi chụp này.'],
  [{ type: 'booking_reassigned', to: 'new', studio: 'Studio Mây', assignee: 'Lan Chi', day: DAY, start: '15:30' }, 'Studio Mây giao cho bạn buổi T2 12/10 · 15:30', 'Mở buổi chụp để xem chi tiết.'],
  [{ type: 'assign_reminder', hours: 48, day: DAY, start: '15:30' }, 'Còn 48 giờ để giao thợ', 'Buổi T2 12/10 · 15:30 chưa có thợ chụp.'],
  [{ type: 'assign_reminder', hours: 26, day: DAY, start: '15:30' }, 'Còn 26 giờ để giao thợ', 'Buổi T2 12/10 · 15:30 chưa có thợ chụp.'],
  [{ type: 'assign_overdue', to: 'customer', day: DAY, start: '15:30' }, 'Studio chưa báo thợ chụp đúng hạn', 'Buổi T2 12/10 · 15:30. Bạn có thể chờ hoặc huỷ và được hoàn 100%.'],
  [{ type: 'assign_overdue', to: 'studio', day: DAY, start: '15:30' }, 'Quá hạn giao thợ buổi T2 12/10 · 15:30', 'Giao thợ ngay để khách không huỷ.'],
  [{ type: 'change_requested', customer: 'An', day: DAY, respondBy: '18:00 11/10' }, 'An xin đổi thợ', 'Buổi T2 12/10. Trả lời trước 18:00 11/10.'],
  [{ type: 'change_answered', studio: 'Studio Mây', outcome: 'reassigned' }, 'Studio Mây đã đổi thợ cho bạn', 'Xem thợ mới trong buổi chụp.'],
  [{ type: 'change_answered', studio: 'Studio Mây', outcome: 'declined' }, 'Studio Mây không đổi thợ', 'Xem lý do trong buổi chụp.'],
  [{ type: 'change_answered', studio: 'Studio Mây', outcome: 'expired' }, 'Studio Mây chưa trả lời yêu cầu đổi thợ', 'Yêu cầu đã hết hạn. Bạn vẫn có thể nhắn tin cho studio.'],
  [{ type: 'assignment_returned', assignee: 'Minh Trí', day: DAY, start: '15:30' }, 'Minh Trí đã trả việc', 'Buổi T2 12/10 · 15:30 cần giao người khác.'],
  [{ type: 'payout_account_needed', amount: 1_250_000 }, 'Thêm tài khoản để nhận 1.250.000₫', 'Tiền của bạn đã sẵn sàng chuyển. Thêm tài khoản nhận tiền để nhận mỗi ngày.'],
  [{ type: 'payout_account_changed', bank: 'Vietcombank', last4: '6789', activeFrom: '09:30 12/10' }, 'Tài khoản nhận tiền đã đổi', 'Vietcombank •••• 6789 có hiệu lực lúc 09:30 12/10. Không phải bạn đổi? Liên hệ hỗ trợ ngay.'],
  [{ type: 'verification_approved' }, 'Bạn đã có thể nhận đơn', 'Hồ sơ đã được duyệt. Tích xanh đã hiện cạnh tên bạn.'],
  [{ type: 'verification_rejected' }, 'Hồ sơ chưa được duyệt', 'Xem lý do và sửa để gửi lại.'],
  [{ type: 'verification_revoked' }, 'Xác minh đã bị thu hồi', 'Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.'],
  [{ type: 'verification_reminder', stepsLeft: 2 }, 'Còn 2 bước để nhận đơn', 'Làm tiếp để khách đặt được bạn.'],
  [{ type: 'business_verified' }, 'Studio đã xác minh doanh nghiệp', 'Con dấu Studio đã hiện trên hồ sơ, studio nhận tới 30 thợ.'],
  [{ type: 'business_rejected' }, 'Xác minh doanh nghiệp chưa được duyệt', 'Xem lý do trong mục Xác minh doanh nghiệp.'],
  [{ type: 'dispute_opened', customer: 'An', subject: 'Minh Trí · Chân dung', ticket: false }, 'An báo vấn đề với buổi chụp', 'Minh Trí · Chân dung. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại.'],
  [{ type: 'dispute_opened', customer: 'An', subject: 'Chụp phố đêm', ticket: true }, 'An báo vấn đề với vé sự kiện', 'Chụp phố đêm. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại.'],
  [{ type: 'dispute_resolved', subject: 'Chân dung', kind: 'release', provider: 'Minh Trí', refund: 0, release: 1_000_000 }, 'Khiếu nại đã có kết quả', 'Chân dung: tiền được chuyển cho Minh Trí.'],
  [{ type: 'dispute_resolved', subject: 'Chân dung', kind: 'refund', provider: 'Minh Trí', refund: 1_000_000, release: 0 }, 'Khiếu nại đã có kết quả', 'Chân dung: hoàn 1.000.000₫ cho khách.'],
  [{ type: 'dispute_resolved', subject: 'Chân dung', kind: 'split', provider: 'ứng dụng', refund: 500_000, release: 500_000 }, 'Khiếu nại đã có kết quả', 'Chân dung: hoàn 500.000₫ cho khách, chuyển 500.000₫ cho ứng dụng.'],
  [{ type: 'dispute_message', sender: 'An', preview: 'Ảnh bị thiếu', count: 1 }, 'An nhắn trong khiếu nại', 'Ảnh bị thiếu'],
  [{ type: 'dispute_message', sender: 'An', preview: 'Ảnh bị thiếu', count: 3 }, 'An nhắn trong khiếu nại', '3 tin nhắn mới'],
  [{ type: 'support_reply', preview: 'Chúng tôi đã kiểm tra.' }, 'Hỗ trợ đã trả lời', 'Chúng tôi đã kiểm tra.'],
  [{ type: 'refund_account_needed', amount: 450_000, hasPayer: true }, 'Chọn tài khoản nhận hoàn', 'Bạn được hoàn 450.000₫. Sau 24 giờ tiền tự về tài khoản đã chuyển, hoặc chọn tài khoản khác.'],
  [{ type: 'refund_account_needed', amount: 450_000, hasPayer: false }, 'Chọn tài khoản nhận hoàn', 'Bạn được hoàn 450.000₫. Chọn tài khoản để nhận tiền.'],
  [{ type: 'recruit_post_new', studio: 'Studio Mây', title: POST }, 'Tin tuyển hợp với bạn', 'Studio Mây: Tuyển thợ cưới'],
  [{ type: 'recruit_application_new', names: ['Minh Trí'], title: POST, count: 1 }, 'Ứng viên mới', 'Minh Trí ứng tuyển “Tuyển thợ cưới”'],
  [{ type: 'recruit_application_new', names: ['Minh Trí', 'Lan Chi'], title: POST, count: 4 }, 'Ứng viên mới', '4 người ứng tuyển “Tuyển thợ cưới”'],
  [{ type: 'recruit_application_result', outcome: 'collaborator', studio: 'Studio Mây', title: POST }, 'Studio đã nhận bạn', 'Studio Mây nhận bạn làm cộng tác viên.'],
  [{ type: 'recruit_application_result', outcome: 'member', studio: 'Studio Mây', title: POST }, 'Studio đã nhận bạn', 'Studio Mây nhận bạn vào studio.'],
  [{ type: 'recruit_application_result', outcome: 'declined', studio: 'Studio Mây', title: POST }, 'Ứng tuyển chưa được nhận', 'Studio Mây chưa nhận ứng tuyển “Tuyển thợ cưới”.'],
  [{ type: 'recruit_application_result', outcome: 'expired', studio: 'Studio Mây', title: POST }, 'Ứng tuyển đã hết hạn', 'Ứng tuyển “Tuyển thợ cưới” đã hết hạn sau 7 ngày.'],
  [{ type: 'collab_invite', studio: 'Studio Mây' }, 'Lời mời cộng tác', 'Studio Mây mời bạn cộng tác theo việc. Hết hạn sau 7 ngày.'],
  [{ type: 'collab_invite_result', outcome: 'accepted', name: 'Minh Trí' }, 'Lời mời cộng tác', 'Minh Trí đã nhận lời cộng tác.'],
  [{ type: 'collab_invite_result', outcome: 'declined', name: 'Minh Trí' }, 'Lời mời cộng tác', 'Minh Trí đã từ chối lời mời cộng tác.'],
  [{ type: 'collab_invite_result', outcome: 'expired', name: 'Minh Trí' }, 'Lời mời cộng tác', 'Lời mời cộng tác gửi Minh Trí đã hết hạn.'],
  [{ type: 'collab_assignment_offer', studio: 'Studio Mây', service: 'Cưới', day: DAY, start: '08:00', fee: 1_500_000, deadline: '14:00 11/10' }, 'Việc cộng tác mới', 'Studio Mây · Cưới, T2 12/10 · 08:00. Thù lao 1.500.000₫. Trả lời trước 14:00 11/10.'],
  [{ type: 'collab_assignment_result', outcome: 'accepted', name: 'Minh Trí', service: 'Cưới', day: DAY, start: '08:00', deadline: '14:00 11/10' }, 'Minh Trí đã nhận việc', 'Cưới, T2 12/10 · 08:00.'],
  [{ type: 'collab_assignment_result', outcome: 'declined', name: 'Minh Trí', service: 'Cưới', day: DAY, start: '08:00', deadline: '14:00 11/10' }, 'Minh Trí từ chối việc', 'Giao người khác trước 14:00 11/10.'],
  [{ type: 'collab_assignment_result', outcome: 'expired', name: 'Minh Trí', service: 'Cưới', day: DAY, start: '08:00', deadline: '14:00 11/10' }, 'Minh Trí chưa trả lời', 'Giao người khác trước 14:00 11/10.'],
  [{ type: 'collab_pay_due', name: 'Minh Trí', amount: 1_500_000, service: 'Cưới', day: DAY }, 'Đến hạn trả thù lao', 'Trả Minh Trí 1.500.000₫ cho buổi Cưới T2 12/10.'],
  [{ type: 'collab_pay_reported', studio: 'Studio Mây', amount: 1_500_000, method: 'bank' }, 'Studio báo đã trả thù lao', 'Studio Mây báo đã trả 1.500.000₫ (chuyển khoản). Bấm Đã nhận hoặc Chưa nhận.'],
  [{ type: 'collab_pay_reported', studio: 'Studio Mây', amount: 1_500_000, method: 'cash' }, 'Studio báo đã trả thù lao', 'Studio Mây báo đã trả 1.500.000₫ (tiền mặt). Bấm Đã nhận hoặc Chưa nhận.'],
  [{ type: 'collab_pay_reported', studio: 'Studio Mây', amount: 1_500_000, method: 'other' }, 'Studio báo đã trả thù lao', 'Studio Mây báo đã trả 1.500.000₫ (cách khác). Bấm Đã nhận hoặc Chưa nhận.'],
  [{ type: 'collab_pay_disputed', name: 'Minh Trí', amount: 1_500_000, service: 'Cưới', day: DAY }, 'Cộng tác viên chưa nhận thù lao', 'Minh Trí báo chưa nhận 1.500.000₫ cho buổi Cưới T2 12/10.'],
];

/** Types rendered by the tests above this table (copy from earlier plans). */
const EARLIER_TYPES = [
  'booking_request', 'booking_accepted', 'booking_declined', 'booking_cancelled', 'refund_done', 'shoot_reminder',
  'event_host_invited', 'review_new', 'badge_new', 'award_reviewed', 'artist_granted', 'artist_revoked', 'chat_message',
];

describe('S17 copy table', () => {
  it('each type renders its verbatim title and body', () => {
    for (const [content, title, body] of CASES) {
      assert.deepEqual(renderNotification(content), { title, body }, `${content.type} ${JSON.stringify(content)}`);
    }
  });

  it('every type except promo has copy', () => {
    const covered = new Set([...CASES.map(([c]) => c.type as string), ...EARLIER_TYPES]);
    const missing = Object.keys(NOTIFICATION_TYPES).filter((t) => t !== 'promo' && !covered.has(t));
    assert.deepEqual(missing, []);
  });

  it('quote_new 1, 2 and 3+ actors', () => {
    const q = (count: number, names: string[]) => renderNotification({ type: 'quote_new', jobTitle: JOB, count, names });
    assert.equal(q(1, ['Minh Trí']).title, 'Minh Trí đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(q(2, ['Minh Trí', 'Lan Chi']).body, 'Minh Trí và Lan Chi. Xem và so sánh báo giá.');
    assert.equal(q(5, ['Minh Trí', 'Lan Chi', 'Hà']).title, '5 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(q(5, ['Minh Trí', 'Lan Chi', 'Hà']).body, 'Minh Trí, Lan Chi và 3 người khác. Xem và so sánh báo giá.');
  });

  it('quote_new with fewer names than count falls back to "Nhiếp ảnh gia"', () => {
    const q = (count: number, names: string[]) => renderNotification({ type: 'quote_new', jobTitle: JOB, count, names });
    assert.equal(q(1, []).title, 'Nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(q(2, ['Minh Trí']).body, 'Minh Trí và Nhiếp ảnh gia. Xem và so sánh báo giá.');
    assert.equal(q(3, ['Minh Trí']).body, 'Minh Trí, Nhiếp ảnh gia và 1 người khác. Xem và so sánh báo giá.');
  });

  it('event_soon 2 days / tomorrow / today', () => {
    const e = (daysLeft: number) =>
      renderNotification({ type: 'event_soon', title: 'Chụp phố đêm', daysLeft, start: '19:00', place: 'Nhà hát Thành phố' }).title;
    assert.equal(e(2), 'Chụp phố đêm bắt đầu sau 2 ngày');
    assert.equal(e(1), 'Chụp phố đêm bắt đầu ngày mai');
    assert.equal(e(0), 'Chụp phố đêm bắt đầu hôm nay');
    const long = renderNotification({ type: 'event_soon', title: 'a'.repeat(50), daysLeft: 1, start: '19:00', place: 'X' }).title;
    assert.equal(long, `${'a'.repeat(40)}… bắt đầu ngày mai`);
  });

  it('job titles are cut to 40 graphemes with …', () => {
    const title = 'ả'.repeat(45);
    const cut = `“${'ả'.repeat(40)}…”`;
    assert.equal(renderNotification({ type: 'job_expired', jobTitle: title }).title, `Việc ${cut} đã hết hạn`);
    assert.equal(
      renderNotification({ type: 'quote_new', jobTitle: title, count: 1, names: ['An'] }).title,
      `An đã báo giá cho việc ${cut}`,
    );
    assert.equal(renderNotification({ type: 'job_match', jobTitle: title, day: DAY, area: 'Q1' }).title, `Việc mới hợp với bạn: ${cut}`);
    assert.equal(renderNotification({ type: 'job_expired', jobTitle: 'ả'.repeat(40) }).title, `Việc “${'ả'.repeat(40)}” đã hết hạn`);
  });

  it('booking_declined, booking_cancelled and refund_done no longer contain "Cọc" and match the mock S17.01 strings', () => {
    const rendered = [
      renderNotification({ type: 'booking_declined', reason: 'declined', photographer: 'Lan Chi', percent: 100 }),
      renderNotification({ type: 'booking_declined', reason: 'expired', photographer: 'Lan Chi', percent: 100 }),
      renderNotification({ type: 'booking_cancelled', by: 'party', name: 'An', day: 'T7 10/10', start: '15:30', percent: 100 }),
      renderNotification({ type: 'refund_done', amount: 450_000, bookingId: 'bk_x9a0c2' }),
    ];
    for (const r of rendered) assert.doesNotMatch(`${r.title} ${r.body}`, /cọc/i);
    assert.deepEqual(rendered[0], {
      title: 'Lan Chi không nhận được lịch',
      body: 'Đã hoàn 100% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.',
    });
    assert.deepEqual(rendered[3], { title: 'Đã hoàn 450.000₫', body: 'Tiền buổi chụp #A0C2 đã về tài khoản của bạn.' });
  });
});
