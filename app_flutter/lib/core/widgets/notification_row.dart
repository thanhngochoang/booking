import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

enum NotificationKind { booking, payment, chat, event, badge, system }

@immutable
class NotificationRowData {
  const NotificationRowData({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.unread,
    this.thumbUrl,
    this.groupAvatars = const [],
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final String? thumbUrl;
  final List<String> groupAvatars;
}

IconData notificationKindIcon(NotificationKind kind) => switch (kind) {
  NotificationKind.booking => Icons.calendar_today,
  NotificationKind.payment => Icons.account_balance_wallet,
  NotificationKind.chat => Icons.chat_bubble_outline,
  NotificationKind.event => Icons.celebration,
  NotificationKind.badge => Icons.military_tech,
  NotificationKind.system => Icons.info_outline,
};

/// Row representing a notification in the inbox (spec S17.01).
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    required this.onMuteKind,
  });

  final NotificationRowData item;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onMuteKind;

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
                  leading: const Icon(Icons.done_all),
                  title: Text(l.notificationMarkRead),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onMarkRead();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(l.notificationMuteKind),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onMuteKind();
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

    final semanticsLabel = item.unread
        ? '${l.notificationUnreadPrefix}. ${item.title}. ${item.body}. ${item.timeLabel}'
        : '${item.title}. ${item.body}. ${item.timeLabel}';

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (item.unread)
        CustomSemanticsAction(label: l.notificationMarkRead): onMarkRead,
      CustomSemanticsAction(label: l.notificationMuteKind): onMuteKind,
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
                  // Kind icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColorsDark.surfaceMuted
                          : AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        notificationKindIcon(item.kind),
                        key: ValueKey('notification_kind_icon_${item.kind.name}'),
                        size: 20,
                        color: theme.colorScheme.primary,
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
                                maxLines: 1,
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
                          style: TextStyle(
                            fontSize: AppText.sm,
                            color: fgSec,
                          ),
                        ),
                        if (item.groupAvatars.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.s2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (index, url) in item.groupAvatars.take(3).indexed)
                                Padding(
                                  key: ValueKey('notification_group_avatar_$index'),
                                  padding: const EdgeInsets.only(right: AppSpace.s1),
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
                        errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 40),
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
