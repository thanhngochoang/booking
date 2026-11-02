import 'package:flutter/widgets.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// One icon and one tone per notification type (spec §3h.2: green = success,
/// yellow = needs action, red = refused, purple = default). Unknown types read
/// as an info row in the default tone.
///
/// [variant] refines the tone for types whose outcome differs (`approved`,
/// `needs_info`, `rejected`, `revoked`, `expired`; for the S27 `*_result`
/// types the domain's `outcome`: `accepted`/`collaborator`/`member` success,
/// `declined`/`expired` muted); rows carry only the type, so the inbox calls
/// this without one.
({IconData icon, NotificationTone tone}) notificationVisualOf(
  String type, {
  String? variant,
}) {
  switch (type) {
    case 'booking_accepted':
    case 'booking_assigned':
      return (icon: AppIcons.calendar, tone: NotificationTone.success);
    case 'booking_declined':
    case 'booking_cancelled':
    case 'assign_overdue':
      return (icon: AppIcons.calendar, tone: NotificationTone.danger);
    case 'booking_request':
    case 'assign_reminder':
    case 'assignment_returned':
      return (icon: AppIcons.calendar, tone: NotificationTone.action);
    case 'booking_reassigned':
      return (icon: AppIcons.calendar, tone: NotificationTone.neutral);
    case 'shoot_reminder':
      return (icon: AppIcons.camera, tone: NotificationTone.neutral);
    case 'refund_done':
    case 'payout_released':
    case 'dispute_resolved':
      return (icon: AppIcons.payment, tone: NotificationTone.success);
    case 'payout_account_needed':
    case 'refund_account_needed':
    case 'collab_pay_due':
      return (icon: AppIcons.payment, tone: NotificationTone.action);
    case 'collab_pay_reported':
      return (icon: AppIcons.payment, tone: NotificationTone.neutral);
    case 'collab_pay_disputed':
      return (icon: AppIcons.payment, tone: NotificationTone.danger);
    case 'payout_account_changed':
      return (icon: AppIcons.lock, tone: NotificationTone.action);
    case 'quote_new':
    case 'quote_withdrawn':
    case 'job_match':
    case 'job_invited':
    case 'recruit_post_new':
      return (icon: AppIcons.work, tone: NotificationTone.neutral);
    case 'recruit_application_result':
      return (icon: AppIcons.work, tone: _outcomeTone(variant));
    case 'quote_accepted':
    case 'job_selected':
      return (icon: AppIcons.work, tone: NotificationTone.success);
    case 'quote_not_selected':
      return (icon: AppIcons.work, tone: NotificationTone.muted);
    case 'recruit_application_new':
      return (icon: AppIcons.work, tone: NotificationTone.action);
    case 'collab_invite':
    case 'collab_assignment_offer':
      return (icon: AppIcons.handshake, tone: NotificationTone.action);
    case 'collab_invite_result':
    case 'collab_assignment_result':
      return (icon: AppIcons.handshake, tone: _outcomeTone(variant));
    case 'job_expiring':
      return (icon: AppIcons.calendar, tone: NotificationTone.action);
    case 'job_expired':
      return (icon: AppIcons.calendar, tone: NotificationTone.muted);
    case 'instant_assigned':
    case 'instant_arrived':
      return (icon: AppIcons.instant, tone: NotificationTone.success);
    case 'instant_missed':
      return (icon: AppIcons.instant, tone: NotificationTone.muted);
    case 'instant_round_ended':
    case 'instant_no_match':
    case 'instant_finished':
      return (icon: AppIcons.instant, tone: NotificationTone.action);
    case 'instant_cancelled':
      return (icon: AppIcons.instant, tone: NotificationTone.danger);
    case 'event_soon':
      return (icon: AppIcons.ticket, tone: NotificationTone.neutral);
    case 'event_host_invited':
      // Staff created an event for this photographer: accept or decline
      // within 24 h (owner decision O1), so it needs action.
      return (icon: AppIcons.ticket, tone: NotificationTone.action);
    case 'award_reviewed':
      return (
        icon: AppIcons.award,
        tone: switch (variant) {
          'approved' => NotificationTone.success,
          'needs_info' => NotificationTone.action,
          'rejected' || 'revoked' => NotificationTone.danger,
          _ => NotificationTone.neutral,
        },
      );
    case 'artist_granted':
      return (icon: AppIcons.award, tone: NotificationTone.success);
    case 'artist_revoked':
    case 'badge_new':
      return (icon: AppIcons.award, tone: NotificationTone.neutral);
    case 'review_new':
      return (icon: AppIcons.star, tone: NotificationTone.neutral);
    case 'review_tomato':
      return (icon: AppIcons.favorite, tone: NotificationTone.success);
    case 'review_brick':
      return (icon: AppIcons.chat, tone: NotificationTone.action);
    case 'delivery_submitted':
    case 'delivery_revision_requested':
      return (icon: AppIcons.image, tone: NotificationTone.action);
    case 'delivery_approved':
      return (icon: AppIcons.image, tone: NotificationTone.success);
    case 'delivery_extra_round':
      return (icon: AppIcons.image, tone: NotificationTone.neutral);
    case 'delivery_cancelled_late':
      return (icon: AppIcons.info, tone: NotificationTone.danger);
    case 'delivery_auto_approve_soon':
    case 'verification_reminder':
      return (icon: AppIcons.schedule, tone: NotificationTone.action);
    case 'studio_invite':
    case 'studio_join_request':
    case 'studio_invite_expiring':
      return (icon: AppIcons.store, tone: NotificationTone.action);
    case 'studio_invite_accepted':
    case 'studio_join_approved':
    case 'business_verified':
      return (icon: AppIcons.store, tone: NotificationTone.success);
    case 'studio_removed':
      return (icon: AppIcons.store, tone: NotificationTone.muted);
    case 'business_rejected':
      return (icon: AppIcons.store, tone: NotificationTone.danger);
    case 'change_requested':
      return (icon: AppIcons.swap, tone: NotificationTone.action);
    case 'change_answered':
      return (icon: AppIcons.swap, tone: NotificationTone.neutral);
    case 'verification_approved':
      return (icon: AppIcons.verified, tone: NotificationTone.success);
    case 'verification_rejected':
    case 'verification_revoked':
      return (icon: AppIcons.verified, tone: NotificationTone.danger);
    case 'dispute_opened':
      return (icon: AppIcons.flag, tone: NotificationTone.action);
    case 'support_reply':
      return (icon: AppIcons.supportAgent, tone: NotificationTone.neutral);
    case 'chat_message':
    case 'dispute_message':
      return (icon: AppIcons.chat, tone: NotificationTone.neutral);
    default:
      return (icon: AppIcons.info, tone: NotificationTone.neutral);
  }
}

/// Relative time of a row: Vừa xong, {n} phút, {n} giờ (same Vietnam day),
/// Hôm qua, {n} ngày (up to 30), then d/M.
String notificationTimeLabel(
  DateTime createdAt,
  DateTime now,
  AppLocalizations l,
) {
  final elapsed = now.difference(createdAt);
  if (elapsed < const Duration(minutes: 1)) {
    return l.notifTimeNow;
  }
  if (elapsed < const Duration(hours: 1)) {
    return l.notifTimeMinutes(elapsed.inMinutes);
  }
  final days = _vnDayDiff(createdAt, now);
  if (days <= 0) {
    return l.notifTimeHours(elapsed.inHours);
  }
  if (days == 1) {
    return l.notifTimeYesterday;
  }
  if (days <= 30) {
    return l.notifTimeDays(days);
  }
  final vn = toVn(createdAt);
  return '${vn.day}/${vn.month}';
}

enum NotificationSection { today, week, earlier }

/// Whole Vietnam calendar days from [createdAt] to [now].
int _vnDayDiff(DateTime createdAt, DateTime now) {
  final a = toVn(createdAt);
  final b = toVn(now);
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Hôm nay = the Vietnam calendar day of [now]; 7 ngày qua = the 7 days
/// before it; everything older is Trước đó.
NotificationSection sectionOf(DateTime createdAt, DateTime now) {
  final days = _vnDayDiff(createdAt, now);
  if (days <= 0) {
    return NotificationSection.today;
  }
  return days <= 7 ? NotificationSection.week : NotificationSection.earlier;
}

/// The tone of an S27 `*_result` row by the domain's `outcome`; neutral
/// without one (the inbox rows carry only the type) or for `ended`.
NotificationTone _outcomeTone(String? outcome) => switch (outcome) {
  'accepted' || 'collaborator' || 'member' => NotificationTone.success,
  'declined' || 'expired' => NotificationTone.muted,
  _ => NotificationTone.neutral,
};
