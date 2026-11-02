import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/notifications/notification_visuals.dart';

typedef _Visual = (IconData, NotificationTone);

/// The plan's App contract (S17, icons and tones per type).
final Map<String, _Visual> _contract = {
  'review_tomato': (AppIcons.favorite, NotificationTone.success),
  'review_brick': (AppIcons.chat, NotificationTone.action),
  'delivery_submitted': (AppIcons.image, NotificationTone.action),
  'delivery_revision_requested': (AppIcons.image, NotificationTone.action),
  'delivery_approved': (AppIcons.image, NotificationTone.success),
  'delivery_auto_approve_soon': (AppIcons.schedule, NotificationTone.action),
  'delivery_extra_round': (AppIcons.image, NotificationTone.neutral),
  'delivery_cancelled_late': (AppIcons.info, NotificationTone.danger),
  'studio_invite': (AppIcons.store, NotificationTone.action),
  'studio_join_request': (AppIcons.store, NotificationTone.action),
  'studio_invite_expiring': (AppIcons.store, NotificationTone.action),
  'studio_invite_accepted': (AppIcons.store, NotificationTone.success),
  'studio_join_approved': (AppIcons.store, NotificationTone.success),
  'studio_removed': (AppIcons.store, NotificationTone.muted),
  'booking_assigned': (AppIcons.calendar, NotificationTone.success),
  'booking_reassigned': (AppIcons.calendar, NotificationTone.neutral),
  'assign_reminder': (AppIcons.calendar, NotificationTone.action),
  'assign_overdue': (AppIcons.calendar, NotificationTone.danger),
  'change_requested': (AppIcons.swap, NotificationTone.action),
  'change_answered': (AppIcons.swap, NotificationTone.neutral),
  'assignment_returned': (AppIcons.calendar, NotificationTone.action),
  'instant_assigned': (AppIcons.instant, NotificationTone.success),
  'instant_missed': (AppIcons.instant, NotificationTone.muted),
  'instant_round_ended': (AppIcons.instant, NotificationTone.action),
  'instant_no_match': (AppIcons.instant, NotificationTone.action),
  'instant_arrived': (AppIcons.instant, NotificationTone.success),
  'instant_finished': (AppIcons.instant, NotificationTone.action),
  'instant_cancelled': (AppIcons.instant, NotificationTone.danger),
  'payout_account_needed': (AppIcons.payment, NotificationTone.action),
  'payout_account_changed': (AppIcons.lock, NotificationTone.action),
  'verification_approved': (AppIcons.verified, NotificationTone.success),
  'verification_rejected': (AppIcons.verified, NotificationTone.danger),
  'verification_revoked': (AppIcons.verified, NotificationTone.danger),
  'verification_reminder': (AppIcons.schedule, NotificationTone.action),
  'business_verified': (AppIcons.store, NotificationTone.success),
  'business_rejected': (AppIcons.store, NotificationTone.danger),
  'dispute_opened': (AppIcons.flag, NotificationTone.action),
  'dispute_resolved': (AppIcons.payment, NotificationTone.success),
  'dispute_message': (AppIcons.chat, NotificationTone.neutral),
  'support_reply': (AppIcons.supportAgent, NotificationTone.neutral),
  'refund_account_needed': (AppIcons.payment, NotificationTone.action),
  'recruit_post_new': (AppIcons.work, NotificationTone.neutral),
  'recruit_application_new': (AppIcons.work, NotificationTone.action),
  'recruit_application_result': (AppIcons.work, NotificationTone.neutral),
  'collab_invite': (AppIcons.handshake, NotificationTone.action),
  'collab_invite_result': (AppIcons.handshake, NotificationTone.neutral),
  'collab_assignment_offer': (AppIcons.handshake, NotificationTone.action),
  'collab_assignment_result': (AppIcons.handshake, NotificationTone.neutral),
  'collab_pay_due': (AppIcons.payment, NotificationTone.action),
  'collab_pay_reported': (AppIcons.payment, NotificationTone.neutral),
  'collab_pay_disputed': (AppIcons.payment, NotificationTone.danger),
  // Types that already had a visual before S17 Task 4 (rows must not change).
  'booking_request': (AppIcons.calendar, NotificationTone.action),
  'booking_accepted': (AppIcons.calendar, NotificationTone.success),
  'booking_declined': (AppIcons.calendar, NotificationTone.danger),
  'booking_cancelled': (AppIcons.calendar, NotificationTone.danger),
  'refund_done': (AppIcons.payment, NotificationTone.success),
  'shoot_reminder': (AppIcons.camera, NotificationTone.neutral),
  'payout_released': (AppIcons.payment, NotificationTone.success),
  'quote_new': (AppIcons.work, NotificationTone.neutral),
  'quote_withdrawn': (AppIcons.work, NotificationTone.neutral),
  'job_match': (AppIcons.work, NotificationTone.neutral),
  'job_invited': (AppIcons.work, NotificationTone.neutral),
  'quote_accepted': (AppIcons.work, NotificationTone.success),
  'job_selected': (AppIcons.work, NotificationTone.success),
  'quote_not_selected': (AppIcons.work, NotificationTone.muted),
  'job_expiring': (AppIcons.calendar, NotificationTone.action),
  'job_expired': (AppIcons.calendar, NotificationTone.muted),
  'event_soon': (AppIcons.ticket, NotificationTone.neutral),
  'event_host_invited': (AppIcons.ticket, NotificationTone.action),
  'award_reviewed': (AppIcons.award, NotificationTone.neutral),
  'artist_granted': (AppIcons.award, NotificationTone.success),
  'artist_revoked': (AppIcons.award, NotificationTone.neutral),
  'badge_new': (AppIcons.award, NotificationTone.neutral),
  'review_new': (AppIcons.star, NotificationTone.neutral),
  'chat_message': (AppIcons.chat, NotificationTone.neutral),
};

/// Every key of `NOTIFICATION_TYPES` in packages/domain/src/notification.ts
/// except `promo` (never shown in the inbox: promo rows are off by default and
/// have no copy).
const _serverTypes = [
  'booking_request',
  'booking_accepted',
  'booking_declined',
  'booking_cancelled',
  'refund_done',
  'shoot_reminder',
  'payout_released',
  'quote_new',
  'quote_withdrawn',
  'job_expiring',
  'job_expired',
  'job_match',
  'job_invited',
  'quote_accepted',
  'quote_not_selected',
  'job_selected',
  'instant_assigned',
  'instant_missed',
  'instant_round_ended',
  'instant_no_match',
  'instant_arrived',
  'instant_finished',
  'instant_cancelled',
  'event_soon',
  'event_host_invited',
  'review_new',
  'review_tomato',
  'review_brick',
  'badge_new',
  'award_reviewed',
  'artist_granted',
  'artist_revoked',
  'delivery_submitted',
  'delivery_revision_requested',
  'delivery_approved',
  'delivery_auto_approve_soon',
  'delivery_extra_round',
  'delivery_cancelled_late',
  'studio_invite',
  'studio_join_request',
  'studio_invite_accepted',
  'studio_join_approved',
  'studio_removed',
  'studio_invite_expiring',
  'booking_assigned',
  'booking_reassigned',
  'assign_reminder',
  'assign_overdue',
  'change_requested',
  'change_answered',
  'assignment_returned',
  'payout_account_needed',
  'payout_account_changed',
  'verification_approved',
  'verification_rejected',
  'verification_revoked',
  'verification_reminder',
  'business_verified',
  'business_rejected',
  'dispute_opened',
  'dispute_resolved',
  'dispute_message',
  'support_reply',
  'refund_account_needed',
  'recruit_post_new',
  'recruit_application_new',
  'recruit_application_result',
  'collab_invite',
  'collab_invite_result',
  'collab_assignment_offer',
  'collab_assignment_result',
  'collab_pay_due',
  'collab_pay_reported',
  'collab_pay_disputed',
  'chat_message',
];

void main() {
  test('event_host_invited needs an answer: ticket icon, action tone (O1)', () {
    final v = notificationVisualOf('event_host_invited');
    expect(v.icon, AppIcons.ticket);
    expect(v.tone, NotificationTone.action);
  });

  test('an unknown type stays an info row in the default tone', () {
    final v = notificationVisualOf('something_new');
    expect(v.icon, AppIcons.info);
    expect(v.tone, NotificationTone.neutral);
  });

  group('each new type has the plan icon and tone', () {
    for (final e in _contract.entries) {
      test(e.key, () {
        final v = notificationVisualOf(e.key);
        expect(v.icon, e.value.$1, reason: '${e.key} icon');
        expect(v.tone, e.value.$2, reason: '${e.key} tone');
      });
    }
  });

  test('the contract table covers exactly the server types', () {
    expect(_contract.keys.toSet(), _serverTypes.toSet());
    expect(_serverTypes.toSet().length, _serverTypes.length);
  });

  test('every server type of the plan table has a non-default visual', () {
    final fallback = notificationVisualOf('something_new');
    for (final type in _serverTypes) {
      final v = notificationVisualOf(type);
      expect(
        v.icon == fallback.icon && v.tone == fallback.tone,
        isFalse,
        reason: '$type falls back to the info row',
      );
    }
  });

  test('recruit_* and collab_* types get work/handshake icons with tones', () {
    // S27 (#151 Task 6): recruit notices are work, the collaboration is a
    // handshake, the off-app pay record keeps the payment glyph.
    for (final t in [
      'recruit_post_new',
      'recruit_application_new',
      'recruit_application_result',
    ]) {
      expect(notificationVisualOf(t).icon, AppIcons.work, reason: t);
    }
    for (final t in [
      'collab_invite',
      'collab_invite_result',
      'collab_assignment_offer',
      'collab_assignment_result',
    ]) {
      expect(notificationVisualOf(t).icon, AppIcons.handshake, reason: t);
    }
    expect(
      notificationVisualOf('collab_assignment_offer').tone,
      NotificationTone.action,
    );
    // The outcome variant of the *_result types (renderNotification outcomes).
    for (final t in [
      'recruit_application_result',
      'collab_invite_result',
      'collab_assignment_result',
    ]) {
      for (final declined in ['declined', 'expired']) {
        expect(
          notificationVisualOf(t, variant: declined).tone,
          NotificationTone.muted,
          reason: '$t $declined',
        );
      }
      expect(notificationVisualOf(t).tone, NotificationTone.neutral, reason: t);
    }
    for (final (t, accepted) in [
      ('recruit_application_result', 'collaborator'),
      ('recruit_application_result', 'member'),
      ('collab_invite_result', 'accepted'),
      ('collab_assignment_result', 'accepted'),
    ]) {
      expect(
        notificationVisualOf(t, variant: accepted).tone,
        NotificationTone.success,
        reason: '$t $accepted',
      );
    }
    expect(
      notificationVisualOf('collab_assignment_result', variant: 'ended').tone,
      NotificationTone.neutral,
    );
    expect(
      notificationVisualOf('collab_pay_disputed').tone,
      NotificationTone.danger,
    );
    expect(notificationVisualOf('collab_pay_due').tone, NotificationTone.action);
    expect(notificationVisualOf('collab_pay_due').icon, AppIcons.payment);
  });

  test('mock S17.01 rows: grouped quote, event, refund, declined', () {
    expect(notificationVisualOf('quote_new').icon, AppIcons.work);
    expect(notificationVisualOf('quote_new').tone, NotificationTone.neutral);
    expect(notificationVisualOf('event_soon').icon, AppIcons.ticket);
    expect(notificationVisualOf('refund_done').icon, AppIcons.payment);
    expect(notificationVisualOf('refund_done').tone, NotificationTone.success);
    expect(notificationVisualOf('booking_declined').icon, AppIcons.calendar);
    expect(
      notificationVisualOf('booking_declined').tone,
      NotificationTone.danger,
    );
  });
}
