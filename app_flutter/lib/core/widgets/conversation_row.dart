// lib/core/widgets/conversation_row.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// Conversation entry item in the chat list (mock S07.02).
///
/// Features:
/// - User avatar on the left.
/// - Recipient/Photographer name with optional status badge.
/// - Message preview with single-line truncation.
/// - Timestamp and unread counter badge.
/// - Screen-reader label for unread messages: "{n} tin chưa đọc".
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.preview,
    required this.timeLabel,
    this.unread = 0,
    this.badge,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final String preview;
  final String timeLabel;
  final int unread;
  final Widget? badge;
  final VoidCallback? onTap;

  static Widget skeleton() => const _ConversationRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: 10,
            ),
            child: Row(
              children: [
                AppAvatar(
                  name: name,
                  url: avatarUrl,
                  size: AppAvatarSize.sm,
                  decorative: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            badge!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unread > 0
                              ? theme.colorScheme.onSurface
                              : secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                        fontSize: AppText.xs,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (unread > 0)
                      Semantics(
                        label: '$unread tin chưa đọc',
                        child: ExcludeSemantics(
                          child: Container(
                            height: 18,
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationRowSkeleton extends StatelessWidget {
  const _ConversationRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('conversation_row_skeleton'),
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: 10,
        ),
        child: Row(
          children: [
            AppSkeleton.circle(size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.5,
                    child: AppSkeleton.line(height: 13),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.8,
                    child: AppSkeleton.line(height: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppSkeleton.line(width: 32, height: 10),
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
