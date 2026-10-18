import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/safety/block_confirm.dart';
import 'package:photobooking/l10n/app_localizations.dart';

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((ref) async {
  // Invalidate when block index changes so unblocking updates immediately
  ref.watch(blockIndexProvider);
  final repo = ref.watch(safetyRepositoryProvider);
  return repo.blocked();
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final usersAsync = ref.watch(blockedUsersProvider);

    return ScreenCode(
      ScreenCodes.blockedUsers,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(l.blockedTitle),
          ),
          body: AsyncView<List<BlockedUser>>(
            value: usersAsync,
            isEmpty: (users) => users.isEmpty,
            empty: (context) => Center(
              child: EmptyState(
                title: l.blockedEmptyTitle,
                body: l.blockedEmptyBody,
              ),
            ),
            error: (context, _, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.reportFailed),
                  const SizedBox(height: AppSpace.s2),
                  AppButton.outline(
                    'Thử lại',
                    onPressed: () => ref.invalidate(blockedUsersProvider),
                  ),
                ],
              ),
            ),
            data: (context, users) {

              final dateFormat = DateFormat('d/M');

              return ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s4),
                    child: Text(
                      l.blockedNote,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  GlassCard(
                    highlight: false,
                    child: Column(
                      children: [
                        for (var i = 0; i < users.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.2),
                            ),
                          _BlockedUserTile(
                            user: users[i],
                            dateFormatted: dateFormat.format(users[i].blockedAt),
                            onUnblock: () async {
                              final unblocked = await confirmUnblock(
                                context,
                                ref,
                                userId: users[i].userId,
                                name: users[i].displayName,
                              );
                              if (unblocked) {
                                ref.invalidate(blockedUsersProvider);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.dateFormatted,
    required this.onUnblock,
  });

  final BlockedUser user;
  final String dateFormatted;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s3,
      ),
      child: Row(
        children: [
          AppAvatar(
            url: user.avatarUrl,
            name: user.displayName,
            size: AppAvatarSize.sm,
            decorative: true,
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.blockedSince(dateFormatted),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          AppButton.outline(
            l.blockedUnblock,
            size: AppButtonSize.xsmall,
            onPressed: onUnblock,
          ),
        ],
      ),
    );
  }
}
