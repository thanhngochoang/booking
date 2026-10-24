/**
 * Vietnamese copy of every emitted notification, in one table so the owner can
 * review it in one place (plan 10a Decision 2, ruling R4). Pure.
 */

export type NotificationContent =
  | { type: 'booking_request'; customer: string; service: string; day: string; start: string }
  | { type: 'booking_accepted'; photographer: string; day: string; start: string; place: string }
  | { type: 'booking_declined'; reason: 'declined' | 'expired'; photographer: string; percent: number }
  | { type: 'booking_cancelled'; by: 'party' | 'system'; name: string; day: string; start: string; percent: number | null }
  | { type: 'refund_done'; amount: number; bookingId: string }
  | { type: 'shoot_reminder'; hours: 24 | 2; service: string; counterpart: string; day: string; start: string }
  | { type: 'event_host_invited'; title: string }
  | { type: 'review_new'; customer: string; rating: number; text: string }
  | { type: 'badge_new'; name: string; description: string }
  | { type: 'award_reviewed'; status: 'approved' | 'needs_info' | 'rejected' | 'revoked' }
  | { type: 'artist_granted' }
  | { type: 'artist_revoked' }
  | { type: 'chat_message'; sender: string; preview: string; count: number }
  // S17 catalogue. `day` fields are yyyy-MM-dd (Vietnam) and render as `formatDayShortVi`; `start` is HH:mm.
  | { type: 'payout_released'; amount: number; count: number }
  /** Grouped: `notify` passes `count` and the row's actors' `names`, newest first. */
  | { type: 'quote_new'; jobTitle: string; count: number; names: readonly string[] }
  | { type: 'quote_withdrawn'; photographer: string; jobTitle: string; auto: boolean }
  | { type: 'job_expiring'; jobTitle: string; quoteCount: number }
  | { type: 'job_expired'; jobTitle: string }
  | { type: 'job_match'; jobTitle: string; day: string; area: string }
  | { type: 'job_invited'; customer: string; jobTitle: string }
  | { type: 'quote_accepted'; customer: string; jobTitle: string }
  | { type: 'quote_not_selected'; jobTitle: string; reason: 'awarded' | 'expired' | 'closed' | 'declined' }
  /** Deprecated (S17 Decision 2): `quote_accepted` replaces it; kept so old rows still render. */
  | { type: 'job_selected' }
  | { type: 'instant_assigned'; photographer: string; etaMinutes: number }
  | { type: 'instant_missed' }
  | { type: 'instant_round_ended'; round: number }
  /** `amount` = money held for the request; 0 when nothing was paid (every #140 request). */
  | { type: 'instant_no_match'; amount: number }
  | { type: 'instant_arrived'; photographer: string; place: string }
  | { type: 'instant_finished'; photographer: string }
  | { type: 'instant_cancelled'; to: 'photographer' | 'customer'; name: string; feeVnd: number }
  | { type: 'event_soon'; title: string; daysLeft: number; start: string; place: string }
  | { type: 'review_tomato'; hits: number; day: string; text: string }
  | { type: 'review_brick'; day: string; text: string }
  | { type: 'delivery_submitted'; deliverer: string; count: number }
  | { type: 'delivery_revision_requested'; customer: string; round: number }
  | { type: 'delivery_approved'; customer: string }
  | { type: 'delivery_auto_approve_soon'; deliverer: string }
  | { type: 'delivery_extra_round'; deliverer: string; granted: boolean }
  | { type: 'studio_invite'; studio: string }
  | { type: 'studio_join_request'; photographer: string }
  | { type: 'studio_invite_accepted'; photographer: string }
  | { type: 'studio_join_approved'; studio: string }
  | { type: 'studio_removed'; studio: string }
  | { type: 'studio_invite_expiring'; studio: string }
  | { type: 'booking_assigned'; to: 'customer' | 'assignee'; studio: string; assignee: string; day: string; start: string }
  | { type: 'booking_reassigned'; to: 'customer' | 'old' | 'new'; studio: string; assignee: string; day: string; start: string }
  | { type: 'assign_reminder'; hours: 48 | 26; day: string; start: string }
  | { type: 'assign_overdue'; to: 'customer' | 'studio'; day: string; start: string }
  /** `respondBy` is already 'HH:mm dd/MM' (Vietnam). */
  | { type: 'change_requested'; customer: string; day: string; respondBy: string }
  | { type: 'change_answered'; studio: string; outcome: 'reassigned' | 'declined' | 'expired' }
  | { type: 'assignment_returned'; assignee: string; day: string; start: string }
  | { type: 'payout_account_needed'; amount: number }
  /** `activeFrom` is already 'HH:mm dd/MM' (Vietnam). */
  | { type: 'payout_account_changed'; bank: string; last4: string; activeFrom: string }
  | { type: 'verification_approved' }
  | { type: 'verification_rejected' }
  | { type: 'verification_revoked' }
  | { type: 'verification_reminder'; stepsLeft: number }
  | { type: 'business_verified' }
  | { type: 'business_rejected' }
  | { type: 'dispute_opened'; customer: string; subject: string; ticket: boolean }
  | { type: 'dispute_resolved'; subject: string; kind: 'release' | 'refund' | 'split'; provider: string; refund: number; release: number }
  /** Grouped per dispute: `notify` passes `count`. */
  | { type: 'dispute_message'; sender: string; preview: string; count: number }
  | { type: 'support_reply'; preview: string }
  | { type: 'refund_account_needed'; amount: number; hasPayer: boolean }
  | { type: 'recruit_post_new'; studio: string; title: string }
  /** Grouped per post: `notify` passes `count` and the applicants' `names`, newest first. */
  | { type: 'recruit_application_new'; names: readonly string[]; title: string; count: number }
  | { type: 'recruit_application_result'; outcome: 'collaborator' | 'member' | 'declined' | 'expired'; studio: string; title: string }
  | { type: 'collab_invite'; studio: string }
  | { type: 'collab_invite_result'; outcome: 'accepted' | 'declined' | 'expired'; name: string }
  /** `deadline` is already formatted by the emitter. */
  | { type: 'collab_assignment_offer'; studio: string; service: string; day: string; start: string; fee: number; deadline: string }
  | {
      type: 'collab_assignment_result';
      outcome: 'accepted' | 'declined' | 'expired' | 'ended';
      name: string;
      service: string;
      day: string;
      start: string;
      deadline: string;
    }
  | { type: 'collab_pay_due'; name: string; amount: number; service: string; day: string }
  | { type: 'collab_pay_reported'; studio: string; amount: number; method: 'bank' | 'cash' | 'other' }
  | { type: 'collab_pay_disputed'; name: string; amount: number; service: string; day: string };

const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'] as const;

/** '2026-10-12' → 'T2 12/10' (weekday short + d/M). */
export function formatDayShortVi(day: string): string {
  const [y, m, d] = day.split('-').map(Number);
  const wd = new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, d ?? 1)).getUTCDay();
  return `${WEEKDAYS[wd] ?? ''} ${d}/${m}`;
}

/** 450000 → '450.000₫' (integer VND, dot-grouped). */
export function formatVnd(amount: number): string {
  return `${Math.round(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}₫`;
}

/** First `max` grapheme clusters; adds an ellipsis when something was cut. */
export function truncateGraphemes(text: string, max: number): string {
  const parts = Array.from(new Intl.Segmenter('vi', { granularity: 'grapheme' }).segment(text.trim()), (s) => s.segment);
  return parts.length <= max ? parts.join('') : `${parts.slice(0, max).join('')}…`;
}

/** Chat preview of one message for `chat_message.preview`. */
export function chatPreview(kind: 'text' | 'image' | 'location', text: string): string {
  if (kind === 'image') return 'Đã gửi một ảnh';
  if (kind === 'location') return 'Đã gửi một vị trí';
  return truncateGraphemes(text, 80);
}

/** A name from a grouped row's actors, or the generic fallback when the row has fewer names than count. */
const nameAt = (names: readonly string[], i: number, fallback: string): string => names[i] ?? fallback;

/** Job and recruit-post titles in copy: 40 graphemes and typographic quotes. */
const job = (title: string): string => `“${truncateGraphemes(title, 40)}”`;

const quote80 = (text: string): string => `“${truncateGraphemes(text, 80)}”`;

const PHOTOGRAPHER = 'Nhiếp ảnh gia';

const QUOTE_NOT_SELECTED = {
  awarded: 'Khách đã chọn người khác. Cảm ơn bạn đã báo giá.',
  expired: 'Việc đã hết hạn mà khách chưa chọn ai.',
  closed: 'Khách đã đóng việc.',
  declined: 'Khách đã từ chối báo giá này.',
} as const;

const PAY_METHOD = { bank: 'chuyển khoản', cash: 'tiền mặt', other: 'cách khác' } as const;

const AWARD_COPY = {
  approved: ['Giải thưởng đã được duyệt', 'Giải thưởng đã hiện trên hồ sơ của bạn.'],
  needs_info: ['Giải thưởng cần bổ sung', 'Xem ghi chú và gửi lại minh chứng.'],
  rejected: ['Giải thưởng chưa được duyệt', 'Xem lý do trong mục Giải thưởng.'],
  revoked: ['Giải thưởng đã bị thu hồi', 'Xem lý do trong mục Giải thưởng.'],
} as const;

export function renderNotification(c: NotificationContent): { title: string; body: string } {
  switch (c.type) {
    case 'booking_request':
      return {
        title: 'Yêu cầu đặt lịch mới',
        body: `${c.customer} · ${c.service}, ${c.day} · ${c.start}. Còn 24 giờ để nhận.`,
      };
    case 'booking_accepted':
      return {
        title: `${c.photographer} đã nhận lịch`,
        body: `${c.day} · ${c.start}, ${c.place}. Nhắn tin để chốt chi tiết.`,
      };
    case 'booking_declined':
      return c.reason === 'declined'
        ? {
            title: `${c.photographer} không nhận được lịch`,
            body: `Đã hoàn ${c.percent}% số bạn đã trả. Xem các nhiếp ảnh gia còn rảnh.`,
          }
        : {
            title: `${c.photographer} chưa trả lời kịp`,
            body: `Yêu cầu đã hết hạn. Đã hoàn ${c.percent}% số bạn đã trả.`,
          };
    case 'booking_cancelled':
      return c.by === 'system'
        ? { title: `Lịch ${c.day} · ${c.start} đã bị huỷ`, body: 'Xem chi tiết trong lịch hẹn.' }
        : {
            title: `${c.name} đã huỷ lịch`,
            body: `${c.day} · ${c.start}.${c.percent === null ? '' : ` Hoàn ${c.percent}% số bạn đã trả.`}`,
          };
    case 'refund_done':
      return {
        title: `Đã hoàn ${formatVnd(c.amount)}`,
        body: `Tiền buổi chụp #${c.bookingId.slice(-4).toUpperCase()} đã về tài khoản của bạn.`,
      };
    case 'shoot_reminder':
      return {
        title: `Nhắc lịch: còn ${c.hours} giờ`,
        body: `${c.service} với ${c.counterpart}, ${c.day} lúc ${c.start}.`,
      };
    case 'event_host_invited':
      return {
        title: 'Bạn được mời làm chủ một sự kiện',
        body: `“${truncateGraphemes(c.title, 60)}”. Trả lời trong 24 giờ để sự kiện được giữ lại.`,
      };
    case 'review_new':
      return {
        title: `${c.customer} đã đánh giá ${c.rating} sao`,
        body: `“${truncateGraphemes(c.text, 80)}”`,
      };
    case 'badge_new':
      return { title: `Bạn nhận huy hiệu “${c.name}”`, body: c.description };
    case 'award_reviewed': {
      const [title, body] = AWARD_COPY[c.status];
      return { title, body };
    }
    case 'artist_granted':
      return { title: 'Bạn đã lên hạng Nhiếp ảnh gia', body: 'Hồ sơ của bạn có dấu Nhiếp ảnh gia từ hôm nay.' };
    case 'artist_revoked':
      return {
        title: 'Hạng Nhiếp ảnh gia đã thay đổi',
        body: 'Hồ sơ của bạn hiện là Cá nhân. Xem chi tiết trong mục Giải thưởng.',
      };
    case 'chat_message':
      return { title: c.sender, body: c.count > 1 ? `${c.count} tin nhắn mới` : c.preview };
    // S17 catalogue (plan 2026-10-07 Contract table, verbatim).
    case 'payout_released':
      return {
        title: `Đã chuyển ${formatVnd(c.amount)} cho bạn`,
        body: c.count > 0
          ? `Tiền của ${c.count} khoản đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.`
          : 'Tiền đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.',
      };
    case 'quote_new': {
      const first = nameAt(c.names, 0, PHOTOGRAPHER);
      if (c.count <= 1) return { title: `${first} đã báo giá cho việc ${job(c.jobTitle)}`, body: 'Xem báo giá và chọn người phù hợp.' };
      const title = `${c.count} nhiếp ảnh gia đã báo giá cho việc ${job(c.jobTitle)}`;
      const second = nameAt(c.names, 1, PHOTOGRAPHER);
      return c.count === 2
        ? { title, body: `${first} và ${second}. Xem và so sánh báo giá.` }
        : { title, body: `${first}, ${second} và ${c.count - 2} người khác. Xem và so sánh báo giá.` };
    }
    case 'quote_withdrawn':
      return {
        title: `${c.photographer} đã rút báo giá`,
        body: c.auto
          ? `Việc ${job(c.jobTitle)}: thợ đã kín lịch nên báo giá tự rút.`
          : `Việc ${job(c.jobTitle)}. Xem các báo giá còn lại.`,
      };
    case 'job_expiring':
      return {
        title: `Việc ${job(c.jobTitle)} hết hạn sau 24 giờ`,
        body: `Bạn có ${c.quoteCount} báo giá. Chọn một người trước khi việc hết hạn.`,
      };
    case 'job_expired':
      return { title: `Việc ${job(c.jobTitle)} đã hết hạn`, body: 'Đăng lại hoặc gia hạn để nhận thêm báo giá.' };
    case 'job_match':
      return {
        title: `Việc mới hợp với bạn: ${job(c.jobTitle)}`,
        body: `${formatDayShortVi(c.day)} · ${c.area}. Xem và gửi báo giá.`,
      };
    case 'job_invited':
      return { title: `${c.customer} mời bạn báo giá`, body: `Việc ${job(c.jobTitle)}. Xem chi tiết và gửi báo giá.` };
    case 'quote_accepted':
      return {
        title: `${c.customer} đã chọn báo giá của bạn`,
        body: `Việc ${job(c.jobTitle)} đã thanh toán. Mở buổi chụp để chốt chi tiết.`,
      };
    case 'quote_not_selected':
      return { title: `Báo giá cho ${job(c.jobTitle)} chưa được chọn`, body: QUOTE_NOT_SELECTED[c.reason] };
    case 'job_selected':
      return { title: 'Bạn được chọn cho một việc', body: 'Mở Công việc để xem chi tiết.' };
    case 'instant_assigned':
      return { title: `Đã match với ${c.photographer}`, body: `${c.photographer} đến trong khoảng ${c.etaMinutes} phút.` };
    case 'instant_missed':
      return { title: 'Bạn đã bỏ lỡ một lời mời', body: 'Lời mời chụp ngay đã hết hạn.' };
    case 'instant_round_ended':
      return { title: 'Chụp ngay', body: 'Chưa ai nhận. Chọn thêm người nhé.' };
    case 'instant_no_match':
      return {
        title: 'Chưa tìm được nhiếp ảnh gia',
        // amount 0 = nothing paid (#140 moves no money): no money sentence, the spec §7 "nobody near" line.
        body: c.amount > 0
          ? `${formatVnd(c.amount)} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ.`
          : 'Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn',
      };
    case 'instant_arrived':
      return { title: `${c.photographer} đã đến điểm hẹn`, body: `Gặp nhau ở ${c.place}.` };
    case 'instant_finished':
      return {
        title: `${c.photographer} đã hoàn thành buổi chụp`,
        body: 'Xác nhận hoàn thành trong 2 giờ, nếu không sẽ tự hoàn thành.',
      };
    case 'instant_cancelled':
      return c.to === 'photographer'
        ? {
            title: 'Khách đã huỷ chụp ngay',
            body: c.feeVnd > 0 ? `Bạn nhận ${formatVnd(c.feeVnd)} phí đi lại.` : 'Không cần tới điểm hẹn nữa.',
          }
        : { title: `${c.name} đã huỷ`, body: 'Chọn người khác, không trả thêm.' };
    case 'event_soon': {
      const when = c.daysLeft >= 2 ? `sau ${c.daysLeft} ngày` : c.daysLeft === 1 ? 'ngày mai' : 'hôm nay';
      return {
        title: `${truncateGraphemes(c.title, 40)} bắt đầu ${when}`,
        body: `Tập trung ${c.start} tại ${c.place}. Mang vé trong mục Vé.`,
      };
    }
    case 'review_tomato':
      return { title: `Bạn nhận 🍅 ×${c.hits} từ buổi chụp ${formatDayShortVi(c.day)}`, body: quote80(c.text) };
    case 'review_brick':
      return { title: `Có góp ý mới về buổi chụp ${formatDayShortVi(c.day)}`, body: quote80(c.text) };
    case 'delivery_submitted':
      return { title: `${c.deliverer} đã gửi ảnh mẫu`, body: `Xem ${c.count} ảnh mẫu và đồng ý để nhận ảnh gốc.` };
    case 'delivery_revision_requested':
      return { title: `${c.customer} muốn chỉnh sửa vòng ${c.round}`, body: 'Xem ghi chú của khách và nộp lại bàn giao.' };
    case 'delivery_approved':
      return { title: `${c.customer} đã đồng ý ảnh`, body: 'Tiền chuyển cho bạn sau 48 giờ kiểm tra.' };
    case 'delivery_auto_approve_soon':
      return { title: 'Còn 24 giờ để xem ảnh mẫu', body: `Không phản hồi thì ảnh của ${c.deliverer} được tự đồng ý.` };
    case 'delivery_extra_round':
      return c.granted
        ? { title: `${c.deliverer} cho thêm một vòng sửa`, body: 'Bạn có thể yêu cầu chỉnh sửa thêm một lần.' }
        : {
            title: `${c.deliverer} không cho thêm vòng sửa`,
            body: 'Bạn vẫn có thể đồng ý ảnh hoặc báo vấn đề với ảnh gốc.',
          };
    case 'studio_invite':
      return { title: `${c.studio} mời bạn làm thành viên`, body: 'Lời mời hết hạn sau 7 ngày.' };
    case 'studio_join_request':
      return { title: `${c.photographer} xin gia nhập studio`, body: 'Duyệt hoặc từ chối trong mục Thành viên.' };
    case 'studio_invite_accepted':
      return { title: `${c.photographer} đã nhận lời mời`, body: `${c.photographer} là thành viên của studio từ hôm nay.` };
    case 'studio_join_approved':
      return { title: `${c.studio} đã duyệt bạn`, body: `Bạn là thành viên của ${c.studio} từ hôm nay.` };
    case 'studio_removed':
      return { title: `Bạn không còn là thành viên của ${c.studio}`, body: 'Xem chi tiết trong mục Studio của tôi.' };
    case 'studio_invite_expiring':
      return { title: `Lời mời của ${c.studio} hết hạn ngày mai`, body: 'Chấp nhận hoặc từ chối trong mục Studio của tôi.' };
    case 'booking_assigned': {
      const slot = `${formatDayShortVi(c.day)} · ${c.start}`;
      return c.to === 'customer'
        ? { title: `${c.studio} đã báo thợ chụp cho bạn`, body: `${c.assignee} sẽ chụp buổi ${slot}.` }
        : { title: `${c.studio} giao cho bạn buổi ${slot}`, body: 'Mở buổi chụp để xem chi tiết.' };
    }
    case 'booking_reassigned': {
      const slot = `${formatDayShortVi(c.day)} · ${c.start}`;
      if (c.to === 'customer') return { title: `${c.studio} đã đổi thợ chụp`, body: `${c.assignee} sẽ chụp buổi ${slot}.` };
      if (c.to === 'old') {
        return { title: `Buổi ${slot} đã giao cho người khác`, body: `${c.studio} đã đổi thợ cho buổi chụp này.` };
      }
      return { title: `${c.studio} giao cho bạn buổi ${slot}`, body: 'Mở buổi chụp để xem chi tiết.' };
    }
    case 'assign_reminder':
      return {
        title: `Còn ${c.hours} giờ để giao thợ`,
        body: `Buổi ${formatDayShortVi(c.day)} · ${c.start} chưa có thợ chụp.`,
      };
    case 'assign_overdue': {
      const slot = `${formatDayShortVi(c.day)} · ${c.start}`;
      return c.to === 'customer'
        ? {
            title: 'Studio chưa báo thợ chụp đúng hạn',
            body: `Buổi ${slot}. Bạn có thể chờ hoặc huỷ và được hoàn 100%.`,
          }
        : { title: `Quá hạn giao thợ buổi ${slot}`, body: 'Giao thợ ngay để khách không huỷ.' };
    }
    case 'change_requested':
      return {
        title: `${c.customer} xin đổi thợ`,
        body: `Buổi ${formatDayShortVi(c.day)}. Trả lời trước ${c.respondBy}.`,
      };
    case 'change_answered':
      if (c.outcome === 'reassigned') return { title: `${c.studio} đã đổi thợ cho bạn`, body: 'Xem thợ mới trong buổi chụp.' };
      if (c.outcome === 'declined') return { title: `${c.studio} không đổi thợ`, body: 'Xem lý do trong buổi chụp.' };
      return {
        title: `${c.studio} chưa trả lời yêu cầu đổi thợ`,
        body: 'Yêu cầu đã hết hạn. Bạn vẫn có thể nhắn tin cho studio.',
      };
    case 'assignment_returned':
      return {
        title: `${c.assignee} đã trả việc`,
        body: `Buổi ${formatDayShortVi(c.day)} · ${c.start} cần giao người khác.`,
      };
    case 'payout_account_needed':
      return {
        title: `Thêm tài khoản để nhận ${formatVnd(c.amount)}`,
        body: 'Tiền của bạn đã sẵn sàng chuyển. Thêm tài khoản nhận tiền để nhận mỗi ngày.',
      };
    case 'payout_account_changed':
      return {
        title: 'Tài khoản nhận tiền đã đổi',
        body: `${c.bank} •••• ${c.last4} có hiệu lực lúc ${c.activeFrom}. Không phải bạn đổi? Liên hệ hỗ trợ ngay.`,
      };
    case 'verification_approved':
      return { title: 'Bạn đã có thể nhận đơn', body: 'Hồ sơ đã được duyệt. Tích xanh đã hiện cạnh tên bạn.' };
    case 'verification_rejected':
      return { title: 'Hồ sơ chưa được duyệt', body: 'Xem lý do và sửa để gửi lại.' };
    case 'verification_revoked':
      return { title: 'Xác minh đã bị thu hồi', body: 'Bạn tạm thời không nhận đơn. Liên hệ hỗ trợ để biết thêm.' };
    case 'verification_reminder':
      return { title: `Còn ${c.stepsLeft} bước để nhận đơn`, body: 'Làm tiếp để khách đặt được bạn.' };
    case 'business_verified':
      return {
        title: 'Studio đã xác minh doanh nghiệp',
        body: 'Con dấu Studio đã hiện trên hồ sơ, studio nhận tới 30 thợ.',
      };
    case 'business_rejected':
      return { title: 'Xác minh doanh nghiệp chưa được duyệt', body: 'Xem lý do trong mục Xác minh doanh nghiệp.' };
    case 'dispute_opened':
      return {
        title: c.ticket ? `${c.customer} báo vấn đề với vé sự kiện` : `${c.customer} báo vấn đề với buổi chụp`,
        body: `${c.subject}. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại.`,
      };
    case 'dispute_resolved': {
      const title = 'Khiếu nại đã có kết quả';
      if (c.kind === 'release') return { title, body: `${c.subject}: tiền được chuyển cho ${c.provider}.` };
      if (c.kind === 'refund') return { title, body: `${c.subject}: hoàn ${formatVnd(c.refund)} cho khách.` };
      return {
        title,
        body: `${c.subject}: hoàn ${formatVnd(c.refund)} cho khách, chuyển ${formatVnd(c.release)} cho ${c.provider}.`,
      };
    }
    case 'dispute_message':
      return {
        title: `${c.sender} nhắn trong khiếu nại`,
        body: c.count > 1 ? `${c.count} tin nhắn mới` : truncateGraphemes(c.preview, 80),
      };
    case 'support_reply':
      return { title: 'Hỗ trợ đã trả lời', body: truncateGraphemes(c.preview, 80) };
    case 'refund_account_needed':
      return {
        title: 'Chọn tài khoản nhận hoàn',
        body: c.hasPayer
          ? `Bạn được hoàn ${formatVnd(c.amount)}. Sau 24 giờ tiền tự về tài khoản đã chuyển, hoặc chọn tài khoản khác.`
          : `Bạn được hoàn ${formatVnd(c.amount)}. Chọn tài khoản để nhận tiền.`,
      };
    case 'recruit_post_new':
      return { title: 'Tin tuyển hợp với bạn', body: `${c.studio}: ${truncateGraphemes(c.title, 40)}` };
    case 'recruit_application_new':
      return {
        title: 'Ứng viên mới',
        body:
          c.count > 1
            ? `${c.count} người ứng tuyển ${job(c.title)}`
            : `${nameAt(c.names, 0, PHOTOGRAPHER)} ứng tuyển ${job(c.title)}`,
      };
    case 'recruit_application_result':
      if (c.outcome === 'collaborator') return { title: 'Studio đã nhận bạn', body: `${c.studio} nhận bạn làm cộng tác viên.` };
      if (c.outcome === 'member') return { title: 'Studio đã nhận bạn', body: `${c.studio} nhận bạn vào studio.` };
      if (c.outcome === 'declined') {
        return { title: 'Ứng tuyển chưa được nhận', body: `${c.studio} chưa nhận ứng tuyển ${job(c.title)}.` };
      }
      return { title: 'Ứng tuyển đã hết hạn', body: `Ứng tuyển ${job(c.title)} đã hết hạn sau 7 ngày.` };
    case 'collab_invite':
      return { title: 'Lời mời cộng tác', body: `${c.studio} mời bạn cộng tác theo việc. Hết hạn sau 7 ngày.` };
    case 'collab_invite_result': {
      const title = 'Lời mời cộng tác';
      if (c.outcome === 'accepted') return { title, body: `${c.name} đã nhận lời cộng tác.` };
      if (c.outcome === 'declined') return { title, body: `${c.name} đã từ chối lời mời cộng tác.` };
      return { title, body: `Lời mời cộng tác gửi ${c.name} đã hết hạn.` };
    }
    case 'collab_assignment_offer':
      return {
        title: 'Việc cộng tác mới',
        body: `${c.studio} · ${c.service}, ${formatDayShortVi(c.day)} · ${c.start}. Thù lao ${formatVnd(c.fee)}. Trả lời trước ${c.deadline}.`,
      };
    case 'collab_assignment_result':
      if (c.outcome === 'accepted') {
        return { title: `${c.name} đã nhận việc`, body: `${c.service}, ${formatDayShortVi(c.day)} · ${c.start}.` };
      }
      return {
        title:
          c.outcome === 'declined'
            ? `${c.name} từ chối việc`
            : c.outcome === 'ended'
              ? `Cộng tác với ${c.name} đã kết thúc`
              : `${c.name} chưa trả lời`,
        body: `Giao người khác trước ${c.deadline}.`,
      };
    case 'collab_pay_due':
      return {
        title: 'Đến hạn trả thù lao',
        body: `Trả ${c.name} ${formatVnd(c.amount)} cho buổi ${c.service} ${formatDayShortVi(c.day)}.`,
      };
    case 'collab_pay_reported':
      return {
        title: 'Studio báo đã trả thù lao',
        body: `${c.studio} báo đã trả ${formatVnd(c.amount)} (${PAY_METHOD[c.method]}). Bấm Đã nhận hoặc Chưa nhận.`,
      };
    case 'collab_pay_disputed':
      return {
        title: 'Cộng tác viên chưa nhận thù lao',
        body: `${c.name} báo chưa nhận ${formatVnd(c.amount)} cho buổi ${c.service} ${formatDayShortVi(c.day)}.`,
      };
  }
}
