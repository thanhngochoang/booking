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
  | { type: 'chat_message'; sender: string; preview: string; count: number };

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
            body: `Cọc đã hoàn ${c.percent}%. Xem các nhiếp ảnh gia còn rảnh.`,
          }
        : {
            title: `${c.photographer} chưa trả lời kịp`,
            body: `Yêu cầu đã hết hạn. Cọc đã hoàn ${c.percent}%.`,
          };
    case 'booking_cancelled':
      return c.by === 'system'
        ? { title: `Lịch ${c.day} · ${c.start} đã bị huỷ`, body: 'Xem chi tiết trong lịch hẹn.' }
        : {
            title: `${c.name} đã huỷ lịch`,
            body: `${c.day} · ${c.start}.${c.percent === null ? '' : ` Cọc hoàn ${c.percent}%.`}`,
          };
    case 'refund_done':
      return {
        title: `Đã hoàn ${formatVnd(c.amount)}`,
        body: `Khoản cọc buổi chụp #${c.bookingId.slice(-4).toUpperCase()} đã về tài khoản của bạn.`,
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
  }
}
