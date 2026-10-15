import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// Semantic colour of a row's icon disc (spec S17.01: green = success, yellow
/// = needs action, red = refused, purple = default).
enum NotificationTone { neutral, success, action, danger, muted }

@immutable
class NotificationRowData {
  const NotificationRowData({
    required this.id,
    required this.icon,
    this.tone = NotificationTone.neutral,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.unread,
    this.thumbUrl,
    this.groupAvatars = const [],
  });

  final String id;
  final IconData icon;
  final NotificationTone tone;
  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final String? thumbUrl;
  final List<String> groupAvatars;
}

(Color disc, Color glyph) _toneColors(NotificationTone tone, bool dark) {
  return switch (tone) {
    NotificationTone.neutral => (
      dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
      dark ? AppColorsDark.primary : AppColors.primary,
    ),
    NotificationTone.success => (
      dark ? AppColorsDark.successSubtle : AppColors.successSubtle,
      dark ? AppColorsDark.success : AppColors.success,
    ),
    // Fixed dark ink on the pale yellow disc in both themes (the dark theme's
    // own foreground is near-white, ~1.1:1 on this disc).
    NotificationTone.action => (
      dark ? AppColorsDark.warningSubtle : AppColors.warningSubtle,
      AppColors.foreground,
    ),
    NotificationTone.danger => (
      dark ? AppColorsDark.errorSubtle : AppColors.errorSubtle,
      dark ? AppColorsDark.error : AppColors.error,
    ),
    NotificationTone.muted => (
      dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
      dark ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted,
    ),
  };
}

/// Row representing a notification in the inbox (spec S17.01).
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    this.onMuteKind,
  });

  final NotificationRowData item;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  /// Null hides the "Tắt loại thông báo này" menu item and custom action
  /// (transaction notifications cannot be muted).
  final VoidCallback? onMuteKind;

  static Widget skeleton() => const _NotificationRowSkeleton();

  void _showMenu(BuildContext context) {
    final l = context.l10n;
    showAppSheet(
      context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.unread)
                ListTile(
                  leading: const AppIcon(AppIcons.doneAll),
                  title: Text(l.notificationMarkRead),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onMarkRead();
                  },
                ),
              if (onMuteKind != null)
                ListTile(
                  leading: const AppIcon(AppIcons.notificationsOff),
                  title: Text(l.notificationMuteKind),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onMuteKind!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final l = context.l10n;
    final (discColor, glyphColor) = _toneColors(item.tone, dark);

    final semanticsLabel = item.unread
        ? '${l.notificationUnreadPrefix}. ${item.title}. ${item.body}. ${item.timeLabel}'
        : '${item.title}. ${item.body}. ${item.timeLabel}';

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (item.unread)
        CustomSemanticsAction(label: l.notificationMarkRead): onMarkRead,
      CustomSemanticsAction(label: l.notificationMuteKind): ?onMuteKind,
    };

    return Semantics(
      label: semanticsLabel,
      button: true,
      customSemanticsActions: actions,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showMenu(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread indicator dot
                  SizedBox(
                    width: 12,
                    height: 40,
                    child: Center(
                      child: item.unread
                          ? Container(
                              key: const ValueKey('notification_unread_dot'),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.bookingWaiting,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  // Icon disc
                  Container(
                    key: const ValueKey('notification_disc'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: discColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        item.icon,
                        key: const ValueKey('notification_icon'),
                        size: 20,
                        color: glyphColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  // Content column
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                // Spec S17.01: the title wraps, only the body is capped.
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.base,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Text(
                              item.timeLabel,
                              style: TextStyle(
                                fontSize: AppText.xs,
                                color: fgSec,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          item.body,
                          key: const ValueKey('notification_body_text'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppText.sm, color: fgSec),
                        ),
                        if (item.groupAvatars.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.s2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (index, url)
                                  in item.groupAvatars.take(3).indexed)
                                Padding(
                                  key: ValueKey(
                                    'notification_group_avatar_$index',
                                  ),
                                  padding: const EdgeInsets.only(
                                    right: AppSpace.s1,
                                  ),
                                  child: AppAvatar(
                                    url: url,
                                    name: '',
                                    size: AppAvatarSize.xs,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.thumbUrl != null && item.thumbUrl!.isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        item.thumbUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const SizedBox(width: 40, height: 40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRowSkeleton extends StatelessWidget {
  const _NotificationRowSkeleton()
    : super(key: const ValueKey('notification_row_skeleton'));

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.s12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 12),
            const SizedBox(width: AppSpace.s2),
            AppSkeleton.circle(size: 40),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.7,
                          child: AppSkeleton.line(height: 18),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      AppSkeleton.line(width: 40, height: 14),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s1),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.95,
                    child: AppSkeleton.line(height: 16),
                  ),
                  const SizedBox(height: 2),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.6,
                    child: AppSkeleton.line(height: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
