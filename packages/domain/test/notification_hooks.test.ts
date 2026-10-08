import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { NOTIFICATION_TYPES, type NotificationType } from '../src/notification.js';
import {
  notifyAssignmentReturned,
  notifyAssignOverdue,
  notifyAssignReminder,
  notifyBookingAssigned,
  notifyBookingReassigned,
  notifyBusinessDecision,
  notifyChangeAnswered,
  notifyChangeRequested,
  notifyCollabAssignmentOffer,
  notifyCollabAssignmentResult,
  notifyCollabInvite,
  notifyCollabInviteResult,
  notifyCollabPayDisputed,
  notifyCollabPayDue,
  notifyCollabPayReported,
  notifyDeliveryApproved,
  notifyDeliveryAutoApproveSoon,
  notifyDeliveryExtraRound,
  notifyDeliveryRevisionRequested,
  notifyDeliverySubmitted,
  notifyDisputeMessage,
  notifyDisputeOpened,
  notifyDisputeResolved,
  notifyInstantArrived,
  notifyInstantAssigned,
  notifyInstantCancelled,
  notifyInstantFinished,
  notifyInstantMissed,
  notifyInstantNoMatch,
  notifyInstantRoundEnded,
  notifyJobExpired,
  notifyJobExpiring,
  notifyJobInvited,
  notifyJobMatch,
  notifyPayoutAccountChanged,
  notifyPayoutAccountNeeded,
  notifyPayoutReleased,
  notifyQuoteAccepted,
  notifyQuoteNew,
  notifyQuoteNotSelected,
  notifyQuoteWithdrawn,
  notifyRecruitApplicationNew,
  notifyRecruitApplicationResult,
  notifyRecruitPostNew,
  notifyRefundAccountNeeded,
  notifyReviewVerdict,
  notifyStudioInvite,
  notifyStudioInviteAccepted,
  notifyStudioInviteExpiring,
  notifyStudioJoinApproved,
  notifyStudioJoinRequest,
  notifyStudioRemoved,
  notifySupportReply,
  notifyVerificationDecision,
  notifyVerificationReminder,
} from '../src/notification_hooks.js';
import type { NotifyDeps } from '../src/notification_ports.js';
import { notify, type NotifyResult } from '../src/notification_use_cases.js';
import { isAllowedTarget } from './client_targets.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

const DAY = '2026-10-12'; // T2 12/10
const JOB = 'Chụp kỷ yếu';
const POST = 'Tuyển thợ cưới';
const AT = '2026-10-10T10:00:00.000Z';
/** 2026-10-10 16:00 UTC = 23:00 in Vietnam (quiet hours). */
const NIGHT = new Date('2026-10-10T16:00:00.000Z');

function seededWorld(): NotifyWorld {
  const w = createNotifyWorld();
  const users: [string, string][] = [
    ['c1', 'An'],
    ['p1', 'Minh Trí'],
    ['p2', 'Lan Chi'],
    ['p3', 'Hà'],
    ['s1', 'Studio Mây'],
    ['a1', 'Bảo'],
    ['a2', 'Cường'],
  ];
  for (const [id, name] of users) w.users.users.set(id, { name, avatarUrl: `https://img/${id}.jpg` });
  return w;
}

interface ExpectedRow {
  readonly userId: string;
  readonly type: NotificationType;
  readonly target: string;
  /** The row id: `n_` + dedupe key with `:` → `_`. */
  readonly id: string;
  readonly title: string;
}

interface HookCase {
  readonly name: string;
  readonly run: (d: NotifyDeps) => Promise<NotifyResult | NotifyResult[] | null>;
  readonly rows: readonly ExpectedRow[];
}

const row = (userId: string, type: NotificationType, target: string, id: string, title: string): ExpectedRow => ({
  userId,
  type,
  target,
  id,
  title,
});

/** Every non-grouped hook of the plan's hooks table. */
const CASES: readonly HookCase[] = [
  {
    name: 'notifyQuoteWithdrawn',
    run: (d) => notifyQuoteWithdrawn(d, { customerId: 'c1', jobId: 'j1', jobTitle: JOB, photographerId: 'p1', quoteVersion: 2, auto: false }),
    rows: [row('c1', 'quote_withdrawn', '/jobs/j1/applications', 'n_quote_withdrawn_j1_p1_2', 'Minh Trí đã rút báo giá')],
  },
  {
    name: 'notifyJobExpiring',
    run: (d) => notifyJobExpiring(d, { customerId: 'c1', jobId: 'j1', jobTitle: JOB, quoteCount: 3, quoteDeadline: '2026-10-11T10:00:00.000Z' }),
    rows: [row('c1', 'job_expiring', '/jobs/j1/applications', 'n_job_expiring_j1_2026-10-11T10_00_00.000Z', 'Việc “Chụp kỷ yếu” hết hạn sau 24 giờ')],
  },
  {
    name: 'notifyJobExpired',
    run: (d) => notifyJobExpired(d, { customerId: 'c1', jobId: 'j1', jobTitle: JOB }),
    rows: [row('c1', 'job_expired', '/jobs/j1', 'n_job_expired_j1', 'Việc “Chụp kỷ yếu” đã hết hạn')],
  },
  {
    name: 'notifyJobMatch',
    run: (d) => notifyJobMatch(d, { photographerId: 'p1', jobId: 'j1', jobTitle: JOB, day: DAY, area: 'Quận 1' }),
    rows: [row('p1', 'job_match', '/jobs/j1', 'n_job_match_j1_p1', 'Việc mới hợp với bạn: “Chụp kỷ yếu”')],
  },
  {
    name: 'notifyJobInvited',
    run: (d) => notifyJobInvited(d, { photographerId: 'p1', customerId: 'c1', jobId: 'j1', jobTitle: JOB }),
    rows: [row('p1', 'job_invited', '/jobs/j1', 'n_job_invited_j1_p1', 'An mời bạn báo giá')],
  },
  {
    name: 'notifyQuoteAccepted',
    run: (d) => notifyQuoteAccepted(d, { photographerId: 'p1', customerId: 'c1', jobId: 'j1', bookingId: 'b1', jobTitle: JOB }),
    rows: [row('p1', 'quote_accepted', '/b/b1', 'n_quote_accepted_j1_p1', 'An đã chọn báo giá của bạn')],
  },
  {
    name: 'notifyQuoteNotSelected',
    run: (d) => notifyQuoteNotSelected(d, { photographerId: 'p1', jobId: 'j1', jobTitle: JOB, reason: 'awarded' }),
    rows: [row('p1', 'quote_not_selected', '/jobs/j1', 'n_quote_not_selected_j1_p1', 'Báo giá cho “Chụp kỷ yếu” chưa được chọn')],
  },
  {
    name: 'notifyInstantAssigned',
    run: (d) => notifyInstantAssigned(d, { customerId: 'c1', requestId: 'r1', photographerId: 'p1', etaMinutes: 15 }),
    rows: [row('c1', 'instant_assigned', '/instant/r1', 'n_instant_assigned_r1', 'Đã match với Minh Trí')],
  },
  {
    name: 'notifyInstantMissed',
    run: (d) => notifyInstantMissed(d, { photographerId: 'p1', offerId: 'o1' }),
    rows: [row('p1', 'instant_missed', '/work/instant', 'n_instant_missed_o1', 'Bạn đã bỏ lỡ một lời mời')],
  },
  {
    name: 'notifyInstantRoundEnded',
    run: (d) => notifyInstantRoundEnded(d, { customerId: 'c1', requestId: 'r1', round: 1 }),
    rows: [row('c1', 'instant_round_ended', '/instant/r1', 'n_instant_round_ended_r1_1', 'Chụp ngay')],
  },
  {
    name: 'notifyInstantNoMatch',
    run: (d) => notifyInstantNoMatch(d, { customerId: 'c1', requestId: 'r1', round: 3, amount: 300_000 }),
    rows: [row('c1', 'instant_no_match', '/instant/r1', 'n_instant_no_match_r1', 'Chưa tìm được nhiếp ảnh gia')],
  },
  {
    name: 'notifyInstantArrived',
    run: (d) => notifyInstantArrived(d, { customerId: 'c1', requestId: 'r1', photographerId: 'p1', place: 'Hồ Gươm' }),
    rows: [row('c1', 'instant_arrived', '/instant/r1', 'n_instant_arrived_r1', 'Minh Trí đã đến điểm hẹn')],
  },
  {
    name: 'notifyInstantFinished',
    run: (d) => notifyInstantFinished(d, { customerId: 'c1', requestId: 'r1', photographerId: 'p1' }),
    rows: [row('c1', 'instant_finished', '/instant/r1', 'n_instant_finished_r1', 'Minh Trí đã hoàn thành buổi chụp')],
  },
  {
    name: 'notifyInstantCancelled by customer',
    run: (d) => notifyInstantCancelled(d, { requestId: 'r1', by: 'customer', customerId: 'c1', photographerId: 'p1', feeVnd: 50_000 }),
    rows: [row('p1', 'instant_cancelled', '/work/instant/r1', 'n_instant_cancelled_r1_customer', 'Khách đã huỷ chụp ngay')],
  },
  {
    name: 'notifyInstantCancelled by photographer',
    run: (d) => notifyInstantCancelled(d, { requestId: 'r1', by: 'photographer', customerId: 'c1', photographerId: 'p1', feeVnd: 0 }),
    rows: [row('c1', 'instant_cancelled', '/instant/r1', 'n_instant_cancelled_r1_photographer', 'Minh Trí đã huỷ')],
  },
  {
    name: 'notifyReviewVerdict tomato',
    run: (d) => notifyReviewVerdict(d, { bookingId: 'b1', subjectUserId: 'p1', customerId: 'c1', verdict: 'tomato', hits: 3, day: DAY, text: 'Đẹp' }),
    rows: [row('p1', 'review_tomato', '/u/p1?tab=reviews', 'n_review_tomato_b1_p1', 'Bạn nhận 🍅 ×3 từ buổi chụp T2 12/10')],
  },
  {
    name: 'notifyReviewVerdict brick',
    run: (d) => notifyReviewVerdict(d, { bookingId: 'b1', subjectUserId: 's1', customerId: 'c1', verdict: 'brick', hits: 0, day: DAY, text: 'Trễ' }),
    rows: [row('s1', 'review_brick', '/u/s1?tab=reviews', 'n_review_brick_b1_s1', 'Có góp ý mới về buổi chụp T2 12/10')],
  },
  {
    name: 'notifyDeliverySubmitted',
    run: (d) => notifyDeliverySubmitted(d, { bookingId: 'b1', customerId: 'c1', delivererId: 'p1', round: 1, count: 20 }),
    rows: [row('c1', 'delivery_submitted', '/b/b1/delivery', 'n_delivery_submitted_b1_1', 'Minh Trí đã gửi ảnh mẫu')],
  },
  {
    name: 'notifyDeliveryRevisionRequested',
    run: (d) => notifyDeliveryRevisionRequested(d, { bookingId: 'b1', customerId: 'c1', delivererId: 'p1', round: 1 }),
    rows: [row('p1', 'delivery_revision_requested', '/b/b1', 'n_delivery_revision_b1_1', 'An muốn chỉnh sửa vòng 1')],
  },
  {
    name: 'notifyDeliveryApproved',
    run: (d) => notifyDeliveryApproved(d, { bookingId: 'b1', customerId: 'c1', delivererId: 'p1' }),
    rows: [row('p1', 'delivery_approved', '/b/b1', 'n_delivery_approved_b1', 'An đã đồng ý ảnh')],
  },
  {
    name: 'notifyDeliveryAutoApproveSoon',
    run: (d) => notifyDeliveryAutoApproveSoon(d, { bookingId: 'b1', customerId: 'c1', delivererId: 'p1', round: 1 }),
    rows: [row('c1', 'delivery_auto_approve_soon', '/b/b1/delivery', 'n_delivery_auto_soon_b1_1', 'Còn 24 giờ để xem ảnh mẫu')],
  },
  {
    name: 'notifyDeliveryExtraRound',
    run: (d) => notifyDeliveryExtraRound(d, { bookingId: 'b1', customerId: 'c1', delivererId: 'p1', round: 2, granted: true }),
    rows: [row('c1', 'delivery_extra_round', '/b/b1/delivery', 'n_delivery_extra_b1_2', 'Minh Trí cho thêm một vòng sửa')],
  },
  {
    name: 'notifyStudioInvite',
    run: (d) => notifyStudioInvite(d, { photographerId: 'p1', studioId: 's1', inviteId: 'i1' }),
    rows: [row('p1', 'studio_invite', '/me/studio', 'n_studio_invite_i1', 'Studio Mây mời bạn làm thành viên')],
  },
  {
    name: 'notifyStudioJoinRequest',
    run: (d) => notifyStudioJoinRequest(d, { studioId: 's1', photographerId: 'p1', requestId: 'q1' }),
    rows: [row('s1', 'studio_join_request', '/studio/members', 'n_studio_join_request_q1', 'Minh Trí xin gia nhập studio')],
  },
  {
    name: 'notifyStudioInviteAccepted',
    run: (d) => notifyStudioInviteAccepted(d, { studioId: 's1', photographerId: 'p1', inviteId: 'i1' }),
    rows: [row('s1', 'studio_invite_accepted', '/studio/members', 'n_studio_invite_accepted_i1', 'Minh Trí đã nhận lời mời')],
  },
  {
    name: 'notifyStudioJoinApproved',
    run: (d) => notifyStudioJoinApproved(d, { photographerId: 'p1', studioId: 's1', requestId: 'q1' }),
    rows: [row('p1', 'studio_join_approved', '/me/studio', 'n_studio_join_approved_q1', 'Studio Mây đã duyệt bạn')],
  },
  {
    name: 'notifyStudioRemoved',
    run: (d) => notifyStudioRemoved(d, { photographerId: 'p1', studioId: 's1', membershipId: 'm1' }),
    rows: [row('p1', 'studio_removed', '/me/studio', 'n_studio_removed_m1', 'Bạn không còn là thành viên của Studio Mây')],
  },
  {
    name: 'notifyStudioInviteExpiring',
    run: (d) => notifyStudioInviteExpiring(d, { photographerId: 'p1', studioId: 's1', inviteId: 'i1' }),
    rows: [row('p1', 'studio_invite_expiring', '/me/studio', 'n_studio_invite_expiring_i1', 'Lời mời của Studio Mây hết hạn ngày mai')],
  },
  {
    name: 'notifyBookingAssigned',
    run: (d) => notifyBookingAssigned(d, { bookingId: 'b1', customerId: 'c1', studioId: 's1', assigneeId: 'a1', day: DAY, start: '15:30' }),
    rows: [
      row('c1', 'booking_assigned', '/b/b1', 'n_booking_assigned_b1_a1_customer', 'Studio Mây đã báo thợ chụp cho bạn'),
      row('a1', 'booking_assigned', '/b/b1', 'n_booking_assigned_b1_a1_assignee', 'Studio Mây giao cho bạn buổi T2 12/10 · 15:30'),
    ],
  },
  {
    name: 'notifyBookingReassigned',
    run: (d) =>
      notifyBookingReassigned(d, { bookingId: 'b1', customerId: 'c1', studioId: 's1', oldAssigneeId: 'a1', newAssigneeId: 'a2', day: DAY, start: '15:30' }),
    rows: [
      row('c1', 'booking_reassigned', '/b/b1', 'n_booking_reassigned_b1_a1_a2_customer', 'Studio Mây đã đổi thợ chụp'),
      row('a1', 'booking_reassigned', '/b/b1', 'n_booking_reassigned_b1_a1_a2_old', 'Buổi T2 12/10 · 15:30 đã giao cho người khác'),
      row('a2', 'booking_reassigned', '/b/b1', 'n_booking_reassigned_b1_a1_a2_new', 'Studio Mây giao cho bạn buổi T2 12/10 · 15:30'),
    ],
  },
  {
    name: 'notifyAssignReminder',
    run: (d) => notifyAssignReminder(d, { bookingId: 'b1', studioId: 's1', hours: 48, day: DAY, start: '15:30' }),
    rows: [row('s1', 'assign_reminder', '/b/b1', 'n_assign_reminder_b1_48', 'Còn 48 giờ để giao thợ')],
  },
  {
    name: 'notifyAssignOverdue',
    run: (d) => notifyAssignOverdue(d, { bookingId: 'b1', customerId: 'c1', studioId: 's1', day: DAY, start: '15:30' }),
    rows: [
      row('c1', 'assign_overdue', '/b/b1', 'n_assign_overdue_b1_customer', 'Studio chưa báo thợ chụp đúng hạn'),
      row('s1', 'assign_overdue', '/b/b1', 'n_assign_overdue_b1_studio', 'Quá hạn giao thợ buổi T2 12/10 · 15:30'),
    ],
  },
  {
    name: 'notifyChangeRequested',
    run: (d) => notifyChangeRequested(d, { bookingId: 'b1', customerId: 'c1', studioId: 's1', day: DAY, respondBy: '18:00 11/10' }),
    rows: [row('s1', 'change_requested', '/b/b1', 'n_change_requested_b1', 'An xin đổi thợ')],
  },
  {
    name: 'notifyChangeAnswered',
    run: (d) => notifyChangeAnswered(d, { bookingId: 'b1', customerId: 'c1', studioId: 's1', outcome: 'declined' }),
    rows: [row('c1', 'change_answered', '/b/b1', 'n_change_answered_b1_declined', 'Studio Mây không đổi thợ')],
  },
  {
    name: 'notifyAssignmentReturned',
    run: (d) => notifyAssignmentReturned(d, { bookingId: 'b1', studioId: 's1', assigneeId: 'a1', day: DAY, start: '15:30' }),
    rows: [row('s1', 'assignment_returned', '/b/b1', 'n_assignment_returned_b1_a1', 'Bảo đã trả việc')],
  },
  {
    name: 'notifyPayoutAccountNeeded',
    run: (d) => notifyPayoutAccountNeeded(d, { payeeId: 'p1', amount: 1_250_000 }),
    rows: [row('p1', 'payout_account_needed', '/work/earnings/account', 'n_payout_account_needed_p1', 'Thêm tài khoản để nhận 1.250.000₫')],
  },
  {
    name: 'notifyPayoutAccountChanged',
    run: (d) =>
      notifyPayoutAccountChanged(d, { uid: 'p1', accountId: 'acc1', bankCode: 'VCB', accountLast4: '6789', activeFrom: '2026-10-12T02:30:00.000Z' }),
    rows: [row('p1', 'payout_account_changed', '/work/earnings/account', 'n_payout_account_changed_acc1', 'Tài khoản nhận tiền đã đổi')],
  },
  {
    name: 'notifyVerificationDecision approved',
    run: (d) => notifyVerificationDecision(d, { uid: 'p1', outcome: 'approved', decidedAt: AT }),
    rows: [row('p1', 'verification_approved', '/verify/start', 'n_verification_approved_p1_2026-10-10T10_00_00.000Z', 'Bạn đã có thể nhận đơn')],
  },
  {
    name: 'notifyVerificationDecision rejected',
    run: (d) => notifyVerificationDecision(d, { uid: 'p1', outcome: 'rejected', decidedAt: AT }),
    rows: [row('p1', 'verification_rejected', '/verify/start', 'n_verification_rejected_p1_2026-10-10T10_00_00.000Z', 'Hồ sơ chưa được duyệt')],
  },
  {
    name: 'notifyVerificationDecision revoked',
    run: (d) => notifyVerificationDecision(d, { uid: 'p1', outcome: 'revoked', decidedAt: AT }),
    rows: [row('p1', 'verification_revoked', '/verify/start', 'n_verification_revoked_p1_2026-10-10T10_00_00.000Z', 'Xác minh đã bị thu hồi')],
  },
  {
    name: 'notifyBusinessDecision verified',
    run: (d) => notifyBusinessDecision(d, { uid: 's1', outcome: 'verified', decidedAt: AT }),
    rows: [row('s1', 'business_verified', '/verify/business', 'n_business_verified_s1_2026-10-10T10_00_00.000Z', 'Studio đã xác minh doanh nghiệp')],
  },
  {
    name: 'notifyBusinessDecision rejected',
    run: (d) => notifyBusinessDecision(d, { uid: 's1', outcome: 'rejected', decidedAt: AT }),
    rows: [row('s1', 'business_rejected', '/verify/business', 'n_business_rejected_s1_2026-10-10T10_00_00.000Z', 'Xác minh doanh nghiệp chưa được duyệt')],
  },
  {
    name: 'notifyVerificationReminder',
    run: (d) => notifyVerificationReminder(d, { uid: 'p1', stepsLeft: 2, since: '2026-10-09' }),
    rows: [row('p1', 'verification_reminder', '/verify/start', 'n_verification_reminder_p1_2026-10-09', 'Còn 2 bước để nhận đơn')],
  },
  {
    name: 'notifyDisputeOpened',
    run: (d) => notifyDisputeOpened(d, { disputeId: 'd1', providerId: 'p1', customerId: 'c1', subject: 'Minh Trí · Chân dung', ticket: false }),
    rows: [row('p1', 'dispute_opened', '/disputes/d1', 'n_dispute_opened_d1', 'An báo vấn đề với buổi chụp')],
  },
  {
    name: 'notifyDisputeResolved',
    run: (d) =>
      notifyDisputeResolved(d, {
        disputeId: 'd1', recipientIds: ['c1', 'p1'], subject: 'Chân dung', kind: 'refund', providerName: 'Minh Trí', refund: 1_000_000, release: 0,
      }),
    rows: [
      row('c1', 'dispute_resolved', '/disputes/d1', 'n_dispute_resolved_d1', 'Khiếu nại đã có kết quả'),
      row('p1', 'dispute_resolved', '/disputes/d1', 'n_dispute_resolved_d1', 'Khiếu nại đã có kết quả'),
    ],
  },
  {
    name: 'notifySupportReply with a dispute',
    run: (d) => notifySupportReply(d, { threadId: 't1', disputeId: 'd1', messageId: 'msg1', recipientIds: ['c1', 'p1'], preview: 'Đã kiểm tra.' }),
    rows: [
      row('c1', 'support_reply', '/disputes/d1', 'n_support_reply_msg1', 'Hỗ trợ đã trả lời'),
      row('p1', 'support_reply', '/disputes/d1', 'n_support_reply_msg1', 'Hỗ trợ đã trả lời'),
    ],
  },
  {
    name: 'notifySupportReply without a dispute',
    run: (d) => notifySupportReply(d, { threadId: 't2', disputeId: null, messageId: 'msg2', recipientIds: ['c1'], preview: 'Chào bạn.' }),
    rows: [row('c1', 'support_reply', '/help/chat', 'n_support_reply_msg2', 'Hỗ trợ đã trả lời')],
  },
  {
    name: 'notifyRefundAccountNeeded',
    run: (d) => notifyRefundAccountNeeded(d, { uid: 'c1', refundId: 'rf1', amount: 450_000, hasPayer: true }),
    rows: [row('c1', 'refund_account_needed', '/me/payments', 'n_refund_account_needed_rf1', 'Chọn tài khoản nhận hoàn')],
  },
  {
    name: 'notifyRecruitPostNew',
    run: (d) => notifyRecruitPostNew(d, { recipientId: 'p1', studioId: 's1', postId: 'post1', title: POST }),
    rows: [row('p1', 'recruit_post_new', '/recruit/post1', 'n_recruit_post_new_post1', 'Tin tuyển hợp với bạn')],
  },
  {
    name: 'notifyRecruitApplicationResult',
    run: (d) => notifyRecruitApplicationResult(d, { applicantId: 'p1', studioId: 's1', postId: 'post1', title: POST, outcome: 'member' }),
    rows: [row('p1', 'recruit_application_result', '/recruit/post1', 'n_recruit_application_result_post1_member', 'Studio đã nhận bạn')],
  },
  {
    name: 'notifyCollabInvite',
    run: (d) => notifyCollabInvite(d, { collaboratorId: 'p1', studioId: 's1', invitedAt: AT }),
    rows: [row('p1', 'collab_invite', '/collab', 'n_collab_invite_s1_2026-10-10T10_00_00.000Z', 'Lời mời cộng tác')],
  },
  {
    name: 'notifyCollabInviteResult',
    run: (d) => notifyCollabInviteResult(d, { studioId: 's1', collaboratorId: 'p1', invitedAt: AT, outcome: 'accepted' }),
    rows: [row('s1', 'collab_invite_result', '/collab', 'n_collab_invite_result_p1_2026-10-10T10_00_00.000Z_accepted', 'Lời mời cộng tác')],
  },
  {
    name: 'notifyCollabAssignmentOffer',
    run: (d) =>
      notifyCollabAssignmentOffer(d, {
        collaboratorId: 'p1', studioId: 's1', bookingId: 'b1', service: 'Cưới', day: DAY, start: '08:00', fee: 1_500_000, deadline: '14:00 11/10',
      }),
    rows: [row('p1', 'collab_assignment_offer', '/collab?offer=b1', 'n_collab_assignment_offer_b1_p1', 'Việc cộng tác mới')],
  },
  {
    name: 'notifyCollabAssignmentResult',
    run: (d) =>
      notifyCollabAssignmentResult(d, {
        studioId: 's1', collaboratorId: 'p1', bookingId: 'b1', outcome: 'declined', service: 'Cưới', day: DAY, start: '08:00', deadline: '14:00 11/10',
      }),
    rows: [row('s1', 'collab_assignment_result', '/b/b1', 'n_collab_assignment_result_b1_p1_declined', 'Minh Trí từ chối việc')],
  },
  {
    name: 'notifyCollabPayDue',
    run: (d) => notifyCollabPayDue(d, { studioId: 's1', collaboratorId: 'p1', bookingId: 'b1', amount: 1_500_000, service: 'Cưới', day: DAY }),
    rows: [row('s1', 'collab_pay_due', '/collab', 'n_collab_pay_due_b1_p1', 'Đến hạn trả thù lao')],
  },
  {
    name: 'notifyCollabPayReported',
    run: (d) => notifyCollabPayReported(d, { collaboratorId: 'p1', studioId: 's1', bookingId: 'b1', amount: 1_500_000, method: 'cash' }),
    rows: [row('p1', 'collab_pay_reported', '/collab', 'n_collab_pay_reported_b1_p1', 'Studio báo đã trả thù lao')],
  },
  {
    name: 'notifyCollabPayDisputed',
    run: (d) => notifyCollabPayDisputed(d, { studioId: 's1', collaboratorId: 'p1', bookingId: 'b1', amount: 1_500_000, service: 'Cưới', day: DAY }),
    rows: [row('s1', 'collab_pay_disputed', '/collab', 'n_collab_pay_disputed_b1_p1', 'Cộng tác viên chưa nhận thù lao')],
  },
  {
    name: 'notifyPayoutReleased',
    run: (d) => notifyPayoutReleased(d, { payoutId: 'po1', payeeId: 'p1', amount: 1_250_000, count: 3 }),
    rows: [row('p1', 'payout_released', '/work/earnings', 'n_payout_released_po1', 'Đã chuyển 1.250.000₫ cho bạn')],
  },
];

const results = (r: NotifyResult | NotifyResult[] | null): (NotifyResult | null)[] => (Array.isArray(r) ? r : [r]);

const quote = (d: NotifyDeps, photographerId: string, quoteVersion = 1) =>
  notifyQuoteNew(d, { customerId: 'c1', jobId: 'j1', jobTitle: JOB, photographerId, quoteVersion });

describe('hooks (table-driven)', () => {
  for (const c of CASES) {
    it(`${c.name} writes one row for each recipient with the type, target and dedupe id of the plan table; a second call is a duplicate`, async () => {
      const w = seededWorld();
      const first = results(await c.run(w.deps));
      assert.deepEqual(first, c.rows.map(() => 'created'));
      const written = [...w.store.rows.values()].map((r) => ({ userId: r.userId, type: r.type, target: r.target, id: r.id, title: r.title }));
      assert.deepEqual(
        written.sort((a, b) => a.userId.localeCompare(b.userId)),
        [...c.rows].sort((a, b) => a.userId.localeCompare(b.userId)),
      );
      for (const r of w.store.rows.values()) {
        assert.equal(r.category, NOTIFICATION_TYPES[r.type].category);
        assert.equal(r.tab, NOTIFICATION_TYPES[r.type].tab);
      }
      const writes = w.store.writes;
      assert.deepEqual(results(await c.run(w.deps)), c.rows.map(() => 'duplicate'));
      assert.equal(w.store.writes, writes);
    });
  }
});

describe('notifyQuoteNew (grouped)', () => {
  let w: NotifyWorld;
  beforeEach(() => {
    w = seededWorld();
  });

  it('three quotes → one row "3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”" with three actors', async () => {
    assert.equal(await quote(w.deps, 'p3'), 'created');
    assert.equal(await quote(w.deps, 'p2'), 'grouped');
    assert.equal(await quote(w.deps, 'p1'), 'grouped');
    const rows = w.store.rowsOf('c1');
    assert.equal(rows.length, 1);
    const r = rows[0];
    assert.equal(r?.id, 'g_job_j1_quotes');
    assert.equal(r?.type, 'quote_new');
    assert.equal(r?.target, '/jobs/j1/applications');
    assert.equal(r?.count, 3);
    assert.deepEqual(r?.actors.map((a) => a.id), ['p1', 'p2', 'p3']);
    assert.equal(r?.title, '3 nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(r?.body, 'Minh Trí, Lan Chi và 1 người khác. Xem và so sánh báo giá.');
    assert.equal(r?.thumbUrl, 'https://img/p1.jpg');
  });

  it('the same photographer and quoteVersion twice is a duplicate', async () => {
    await quote(w.deps, 'p1', 1);
    assert.equal(await quote(w.deps, 'p1', 1), 'duplicate');
    assert.equal(w.store.rowsOf('c1')[0]?.count, 1);
    assert.equal(w.push.sent.length, 1);
  });

  it('a new quoteVersion of the same photographer does not count again', async () => {
    await quote(w.deps, 'p1', 1);
    assert.equal(await quote(w.deps, 'p1', 2), 'duplicate');
    const r = w.store.rowsOf('c1')[0];
    assert.equal(r?.count, 1);
    assert.deepEqual(r?.actors.map((a) => a.id), ['p1']);
    assert.equal(r?.title, 'Minh Trí đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(w.push.sent.length, 1);
  });

  it('after reading, the next quote restarts at 1 with one actor', async () => {
    await quote(w.deps, 'p3');
    await quote(w.deps, 'p2');
    await w.store.markRead('c1', ['g_job_j1_quotes'], w.clock.now());
    assert.equal(await quote(w.deps, 'p1'), 'created');
    const r = w.store.rowsOf('c1')[0];
    assert.equal(r?.count, 1);
    assert.deepEqual(r?.actors.map((a) => a.id), ['p1']);
    assert.equal(r?.title, 'Minh Trí đã báo giá cho việc “Chụp kỷ yếu”');
    assert.equal(r?.body, 'Xem báo giá và chọn người phù hợp.');
  });
});

describe('special hooks', () => {
  let w: NotifyWorld;
  beforeEach(() => {
    w = seededWorld();
  });

  it('notifyJobExpiring with an extended quoteDeadline sends a second notice', async () => {
    const e = { customerId: 'c1', jobId: 'j1', jobTitle: JOB, quoteCount: 2 };
    assert.equal(await notifyJobExpiring(w.deps, { ...e, quoteDeadline: '2026-10-11T10:00:00.000Z' }), 'created');
    assert.equal(await notifyJobExpiring(w.deps, { ...e, quoteDeadline: '2026-10-11T10:00:00.000Z' }), 'duplicate');
    assert.equal(await notifyJobExpiring(w.deps, { ...e, quoteDeadline: '2026-10-13T10:00:00.000Z' }), 'created');
    assert.equal(w.store.rowsOf('c1').length, 2);
  });

  it('notifyInstantCancelled by customer goes to the photographer with /work/instant/{id} and the fee line, by photographer goes to the customer with /instant/{id}', async () => {
    await notifyInstantCancelled(w.deps, { requestId: 'r1', by: 'customer', customerId: 'c1', photographerId: 'p1', feeVnd: 50_000 });
    const toP = w.store.rowsOf('p1')[0];
    assert.equal(toP?.target, '/work/instant/r1');
    assert.equal(toP?.body, 'Bạn nhận 50.000₫ phí đi lại.');
    assert.deepEqual(toP?.actors.map((a) => a.id), ['c1']);
    assert.equal(w.store.rowsOf('c1').length, 0);

    await notifyInstantCancelled(w.deps, { requestId: 'r2', by: 'photographer', customerId: 'c1', photographerId: 'p1', feeVnd: 0 });
    const toC = w.store.rowsOf('c1')[0];
    assert.equal(toC?.target, '/instant/r2');
    assert.equal(toC?.title, 'Minh Trí đã huỷ');
    assert.equal(toC?.body, 'Chọn người khác, không trả thêm.');
  });

  it('notifyDisputeOpened returns null for a platform event', async () => {
    const r = await notifyDisputeOpened(w.deps, { disputeId: 'd2', providerId: 'platform', customerId: 'c1', subject: 'Chụp phố đêm', ticket: true });
    assert.equal(r, null);
    assert.equal(w.store.rows.size, 0);
    assert.equal(w.push.sent.length, 0);
  });

  it('notifySupportReply targets /disputes/{id} with a dispute, /help/chat without', async () => {
    await notifySupportReply(w.deps, { threadId: 't1', disputeId: 'd1', messageId: 'm1', recipientIds: ['c1'], preview: 'A' });
    await notifySupportReply(w.deps, { threadId: 't2', disputeId: null, messageId: 'm2', recipientIds: ['c1'], preview: 'B' });
    const targets = w.store.rowsOf('c1').map((r) => [r.id, r.target]).sort();
    assert.deepEqual(targets, [
      ['n_support_reply_m1', '/disputes/d1'],
      ['n_support_reply_m2', '/help/chat'],
    ]);
  });

  it('notifyDisputeMessage groups per dispute with the sender as actor', async () => {
    assert.deepEqual(await notifyDisputeMessage(w.deps, { disputeId: 'd1', recipientIds: ['c1'], senderId: 'p1', preview: 'Đã gửi lại ảnh' }), ['created']);
    let r = w.store.rowsOf('c1')[0];
    assert.equal(r?.id, 'g_dispute_d1');
    assert.equal(r?.target, '/disputes/d1');
    assert.equal(r?.title, 'Minh Trí nhắn trong khiếu nại');
    assert.equal(r?.body, 'Đã gửi lại ảnh');
    assert.deepEqual(await notifyDisputeMessage(w.deps, { disputeId: 'd1', recipientIds: ['c1'], senderId: 'p1', preview: 'Còn gì nữa?' }), ['grouped']);
    r = w.store.rowsOf('c1')[0];
    assert.equal(r?.count, 2);
    assert.equal(r?.body, '2 tin nhắn mới');
    assert.deepEqual(r?.actors.map((a) => a.id), ['p1']);
  });

  it('notifyDisputeMessage with the same messageId twice counts once and pushes once', async () => {
    const msg = { disputeId: 'd1', recipientIds: ['c1'], senderId: 'p1', preview: 'Đã gửi lại ảnh', messageId: 'dm1' };
    assert.deepEqual(await notifyDisputeMessage(w.deps, msg), ['created']);
    assert.deepEqual(await notifyDisputeMessage(w.deps, msg), ['duplicate']);
    const r = w.store.rowsOf('c1')[0];
    assert.equal(r?.count, 1);
    assert.equal(r?.body, 'Đã gửi lại ảnh');
    assert.equal(r?.lastEventId, 'dm1');
    assert.equal(w.push.sent.length, 1);
    assert.deepEqual(await notifyDisputeMessage(w.deps, { ...msg, messageId: 'dm2', preview: 'Còn gì nữa?' }), ['grouped']);
    assert.equal(w.store.rowsOf('c1')[0]?.count, 2);
  });

  it('notifyBookingReassigned: a repeated A→B is a duplicate, A→B after B→A is not', async () => {
    const base = { bookingId: 'b1', customerId: 'c1', studioId: 's1', day: DAY, start: '15:30' };
    const ab1 = { ...base, oldAssigneeId: 'a1', newAssigneeId: 'a2', reassignedAt: '2026-10-10T10:00:00.000Z' };
    assert.deepEqual(await notifyBookingReassigned(w.deps, ab1), ['created', 'created', 'created']);
    assert.deepEqual(await notifyBookingReassigned(w.deps, ab1), ['duplicate', 'duplicate', 'duplicate']);
    const ba = { ...base, oldAssigneeId: 'a2', newAssigneeId: 'a1', reassignedAt: '2026-10-10T11:00:00.000Z' };
    assert.deepEqual(await notifyBookingReassigned(w.deps, ba), ['created', 'created', 'created']);
    const ab2 = { ...ab1, reassignedAt: '2026-10-10T12:00:00.000Z' };
    assert.deepEqual(await notifyBookingReassigned(w.deps, ab2), ['created', 'created', 'created']);
    assert.equal(w.store.rowsOf('c1').length, 3);
    assert.equal(w.store.rowsOf('a1').length, 3);
    assert.equal(w.store.rowsOf('a2').length, 3);
    assert.ok(w.store.rowsOf('c1').some((r) => r.id === 'n_booking_reassigned_b1_a1_a2_2026-10-10T12_00_00.000Z_customer'));
  });

  it('notifyRecruitApplicationNew groups per post', async () => {
    const app = (postId: string, applicantId: string) =>
      notifyRecruitApplicationNew(w.deps, { studioId: 's1', postId, title: POST, applicantId });
    assert.equal(await app('post1', 'p1'), 'created');
    assert.equal(await app('post1', 'p1'), 'duplicate');
    assert.equal(await app('post1', 'p2'), 'grouped');
    assert.equal(await app('post2', 'p3'), 'created');
    const rows = w.store.rowsOf('s1').sort((a, b) => a.id.localeCompare(b.id));
    assert.deepEqual(rows.map((r) => [r.id, r.target, r.count, r.body]), [
      ['g_recruit_post1_apps', '/studio/recruit?post=post1', 2, '2 người ứng tuyển “Tuyển thợ cưới”'],
      ['g_recruit_post2_apps', '/studio/recruit?post=post2', 1, 'Hà ứng tuyển “Tuyển thợ cưới”'],
    ]);
    assert.deepEqual(rows[0]?.actors.map((a) => a.id), ['p2', 'p1']);
  });

  it('notifyPayoutAccountChanged renders the bank short name and the Vietnam time', async () => {
    await notifyPayoutAccountChanged(w.deps, { uid: 'p1', accountId: 'acc1', bankCode: 'VCB', accountLast4: '6789', activeFrom: '2026-10-12T17:30:00.000Z' });
    assert.equal(
      w.store.rowsOf('p1')[0]?.body,
      'Vietcombank •••• 6789 có hiệu lực lúc 00:30 13/10. Không phải bạn đổi? Liên hệ hỗ trợ ngay.',
    );
    await notifyPayoutAccountChanged(w.deps, { uid: 'p2', accountId: 'acc2', bankCode: 'XYZ', accountLast4: '1111', activeFrom: '2026-10-12T02:30:00.000Z' });
    assert.equal(w.store.rowsOf('p2')[0]?.body, 'XYZ •••• 1111 có hiệu lực lúc 09:30 12/10. Không phải bạn đổi? Liên hệ hỗ trợ ngay.');
  });

  it('notifyBookingAssigned sends to customer and assignee with their own copy', async () => {
    await notifyBookingAssigned(w.deps, { bookingId: 'b1', customerId: 'c1', studioId: 's1', assigneeId: 'a1', day: DAY, start: '15:30' });
    assert.deepEqual(
      [w.store.rowsOf('c1')[0]?.title, w.store.rowsOf('c1')[0]?.body],
      ['Studio Mây đã báo thợ chụp cho bạn', 'Bảo sẽ chụp buổi T2 12/10 · 15:30.'],
    );
    assert.deepEqual(
      [w.store.rowsOf('a1')[0]?.title, w.store.rowsOf('a1')[0]?.body],
      ['Studio Mây giao cho bạn buổi T2 12/10 · 15:30', 'Mở buổi chụp để xem chi tiết.'],
    );
  });

  it('notifyBookingReassigned sends three rows', async () => {
    const r = await notifyBookingReassigned(w.deps, {
      bookingId: 'b1', customerId: 'c1', studioId: 's1', oldAssigneeId: 'a1', newAssigneeId: 'a2', day: DAY, start: '15:30',
    });
    assert.deepEqual(r, ['created', 'created', 'created']);
    assert.equal(w.store.rows.size, 3);
    assert.equal(w.store.rowsOf('c1')[0]?.body, 'Cường sẽ chụp buổi T2 12/10 · 15:30.');
    assert.equal(w.store.rowsOf('a1')[0]?.body, 'Studio Mây đã đổi thợ cho buổi chụp này.');
  });

  it('notifyAssignOverdue reaches the inbox even when the booking channel is off', async () => {
    for (const u of ['c1', 's1']) w.store.prefs.set(u, { channels: { booking: { push: false, inApp: false } } });
    await notifyAssignOverdue(w.deps, { bookingId: 'b1', customerId: 'c1', studioId: 's1', day: DAY, start: '15:30' });
    assert.equal(w.store.rowsOf('c1').length, 1);
    assert.equal(w.store.rowsOf('s1').length, 1);
    assert.equal(w.push.sent.length, 0);
  });

  it('a multi-recipient hook still writes the other rows and throws one error at the end', async () => {
    const getPrefs = w.store.getPrefs.bind(w.store);
    w.store.getPrefs = async (uid: string) => {
      if (uid === 'a1') throw new Error('store down');
      return getPrefs(uid);
    };
    await assert.rejects(
      notifyBookingAssigned(w.deps, { bookingId: 'b1', customerId: 'c1', studioId: 's1', assigneeId: 'a1', day: DAY, start: '15:30' }),
      /1 recipient/,
    );
    assert.equal(w.store.rowsOf('c1').length, 1);
  });
});

describe('prefs and critical flags apply to the new types', () => {
  it('events channel off suppresses event_soon; jobs channel off suppresses notifyQuoteNew', async () => {
    const w = seededWorld();
    w.store.prefs.set('c1', { channels: { events: { push: false, inApp: false }, jobs: { push: false, inApp: false } } });
    const r = await notify(w.deps, {
      userId: 'c1',
      content: { type: 'event_soon', title: 'Chụp phố đêm', daysLeft: 1, start: '19:00', place: 'Nhà hát Thành phố' },
      target: '/e/e1',
      dedupeKey: 'event_soon_e1_reg1',
    });
    assert.equal(r, 'suppressed');
    assert.equal(await quote(w.deps, 'p1'), 'suppressed');
    assert.equal(w.store.rows.size, 0);
    assert.equal(w.push.sent.length, 0);
  });

  it('assign_overdue and payout_released push with channel default at 23:00 Vietnam time', async () => {
    const w = seededWorld();
    w.clock.setTime(NIGHT);
    await notifyAssignOverdue(w.deps, { bookingId: 'b1', customerId: 'c1', studioId: 's1', day: DAY, start: '15:30' });
    await notifyPayoutReleased(w.deps, { payoutId: 'po1', payeeId: 'p1', amount: 1_000_000, count: 2 });
    assert.deepEqual(w.push.sent.map((s) => [s.msg.data.type, s.msg.channel]).sort(), [
      ['assign_overdue', 'default'],
      ['assign_overdue', 'default'],
      ['payout_released', 'default'],
    ]);
  });

  it('at 23:00 every critical hook type pushes on default and every other on quiet', async () => {
    for (const c of CASES) {
      const w = seededWorld();
      w.clock.setTime(NIGHT);
      await c.run(w.deps);
      for (const s of w.push.sent) {
        const critical = NOTIFICATION_TYPES[s.msg.data.type as NotificationType].critical;
        assert.equal(s.msg.channel, critical ? 'default' : 'quiet', `${c.name} ${s.msg.data.type}`);
      }
    }
  });
});

describe('client allowlist', () => {
  it('every hook target passes the client allowlist port', async () => {
    const w = seededWorld();
    for (const c of CASES) await c.run(w.deps);
    await quote(w.deps, 'p1');
    await notifyDisputeMessage(w.deps, { disputeId: 'd1', recipientIds: ['c1'], senderId: 'p1', preview: 'x' });
    await notifyRecruitApplicationNew(w.deps, { studioId: 's1', postId: 'post1', title: POST, applicantId: 'p2' });
    const targets = new Set([...w.store.rows.values()].map((r) => r.target));
    const expected = new Set([
      ...CASES.flatMap((c) => c.rows.map((r) => r.target)),
      '/jobs/j1/applications',
      '/disputes/d1',
      '/studio/recruit?post=post1',
    ]);
    assert.deepEqual([...targets].sort(), [...expected].sort());
    for (const t of targets) assert.equal(isAllowedTarget(t), true, t);
    for (const s of w.push.sent) assert.equal(isAllowedTarget(s.msg.data.target), true, s.msg.data.target);
  });

  it('the port refuses what the app refuses', () => {
    for (const bad of [
      '/collab?post=x',
      '/studio/recruit',
      '/studio/recruit?post=x&a=1',
      '/studio/recruit?post=../x',
      '/jobs/../x',
      `/e/${'a'.repeat(129)}`,
      '/e/x?tab=1',
      'https://evil.example/b/x',
      '//evil.example/b/x',
      '/b/x#frag',
      '/unknown',
    ]) {
      assert.equal(isAllowedTarget(bad), false, bad);
    }
    for (const ok of ['/bookings', '/u/p1?tab=reviews', '/collab?offer=b1', '/studio/recruit?post=p1', '/events/e1/manage', '/e/e1']) {
      assert.equal(isAllowedTarget(ok), true, ok);
    }
  });
});

describe('fallback names', () => {
  it('a hook never throws for a missing user name (fallback names)', async () => {
    for (const c of CASES) {
      const w = createNotifyWorld();
      await c.run(w.deps);
      assert.ok(w.store.rows.size > 0, c.name);
    }
    const w = createNotifyWorld();
    await quote(w.deps, 'p1');
    await notifyStudioInvite(w.deps, { photographerId: 'p2', studioId: 's1', inviteId: 'i1' });
    await notifyJobInvited(w.deps, { photographerId: 'p3', customerId: 'c1', jobId: 'j1', jobTitle: JOB });
    await notifyRecruitApplicationNew(w.deps, { studioId: 's1', postId: 'post1', title: POST, applicantId: 'p1' });
    assert.equal(w.store.rowsOf('c1')[0]?.title, 'Nhiếp ảnh gia đã báo giá cho việc “Chụp kỷ yếu”');
    assert.deepEqual(w.store.rowsOf('c1')[0]?.actors, [{ id: 'p1', name: 'Nhiếp ảnh gia', avatarUrl: null }]);
    assert.equal(w.store.rowsOf('p2')[0]?.title, 'Studio mời bạn làm thành viên');
    assert.equal(w.store.rowsOf('p3')[0]?.title, 'Khách hàng mời bạn báo giá');
    assert.equal(w.store.rowsOf('s1')[0]?.body, 'Nhiếp ảnh gia ứng tuyển “Tuyển thợ cưới”');
  });
});
