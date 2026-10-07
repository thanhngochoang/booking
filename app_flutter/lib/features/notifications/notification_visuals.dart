import 'package:flutter/widgets.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// One icon and one tone per notification type (spec §3h.2: green = success,
/// yellow = needs action, red = refused, purple = default). Unknown types read
/// as an info row in the default tone.
///
/// [variant] refines the tone for types whose outcome differs (`approved`,
/// `needs_info`, `rejected`, `revoked`, `expired`); rows carry only the type,
/// so the inbox calls this without one.
({IconData icon, NotificationTone tone}) notificationVisualOf(
  String type, {
  String? variant,
}) {
  switch (type) {
    case 'booking_accepted':
      return (icon: AppIcons.calendar, tone: NotificationTone.success);
    case 'booking_declined':
    case 'booking_cancelled':
      return (icon: AppIcons.calendar, tone: NotificationTone.danger);
    case 'booking_request':
      return (icon: AppIcons.calendar, tone: NotificationTone.action);
    case 'shoot_reminder':
      return (icon: AppIcons.camera, tone: NotificationTone.neutral);
    case 'refund_done':
    case 'payout_released':
      return (icon: AppIcons.payment, tone: NotificationTone.success);
    case 'quote_new':
    case 'quote_withdrawn':
    case 'job_match':
    case 'job_invited':
      return (icon: AppIcons.work, tone: NotificationTone.neutral);
    case 'quote_accepted':
    case 'job_selected':
      return (icon: AppIcons.work, tone: NotificationTone.success);
    case 'quote_not_selected':
      return (icon: AppIcons.work, tone: NotificationTone.muted);
    case 'job_expiring':
      return (icon: AppIcons.calendar, tone: NotificationTone.action);
    case 'job_expired':
      return (icon: AppIcons.calendar, tone: NotificationTone.muted);
    case 'instant_assigned':
      return (icon: AppIcons.instant, tone: NotificationTone.success);
    case 'instant_missed':
      return (icon: AppIcons.instant, tone: NotificationTone.muted);
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
    case 'chat_message':
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
