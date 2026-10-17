import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/safety/block_confirm.dart';
import 'package:photobooking/features/safety/report_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<void> showSafetyMenu(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  String? blockUserId,
  String? blockName,
  VoidCallback? onShare,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheetContext) => _SafetyMenuSheet(
      parentContext: context,
      target: target,
      blockUserId: blockUserId,
      blockName: blockName,
      onShare: onShare,
    ),
  );
}

class _SafetyMenuSheet extends ConsumerWidget {
  const _SafetyMenuSheet({
    required this.parentContext,
    required this.target,
    this.blockUserId,
    this.blockName,
    this.onShare,
  });

  final BuildContext parentContext;
  final ReportTarget target;
  final String? blockUserId;
  final String? blockName;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final blockIndex =
        ref.watch(blockIndexProvider).value ?? const BlockIndex();
    final currentUid = ref.watch(authStateProvider).value?.uid;

    final targetUserId = blockUserId ?? target.ownerId;
    final targetName = blockName ?? target.ownerName ?? '';
    final isMe = targetUserId != null && targetUserId == currentUid;
    final isBlockedByMe =
        targetUserId != null && blockIndex.blockedByMe(targetUserId);

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onShare != null)
                ListTile(
                  key: const Key('safety-menu-share'),
                  leading: const AppIcon(AppIcons.share),
                  title: Text(l.safetyShareProfile),
                  onTap: () {
                    Navigator.of(context).pop();
                    onShare!();
                  },
                ),
              ListTile(
                key: const Key('safety-menu-report'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.safetyReport),
                onTap: () {
                  Navigator.of(context).pop();
                  showReportSheet(context, target: target);
                },
              ),
              if (!isMe && targetUserId != null && targetUserId.isNotEmpty) ...[
                if (isBlockedByMe)
                  ListTile(
                    key: const Key('safety-menu-unblock'),
                    leading: const AppIcon(AppIcons.block),
                    title: Text(l.safetyUnblock(targetName)),
                    onTap: () {
                      Navigator.of(context).pop();
                      confirmUnblock(
                        parentContext,
                        ref,
                        userId: targetUserId,
                        name: targetName,
                      );
                    },
                  )
                else
                  ListTile(
                    key: const Key('safety-menu-block'),
                    leading: const AppIcon(
                      AppIcons.block,
                      color: AppColors.error,
                    ),
                    title: Text(
                      l.safetyBlock(targetName),
                      style: const TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      confirmBlock(
                        parentContext,
                        ref,
                        userId: targetUserId,
                        name: targetName,
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
