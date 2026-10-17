import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/safety/block_confirm.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class BlockedProfileView extends ConsumerWidget {
  const BlockedProfileView({
    super.key,
    required this.uid,
    required this.name,
    required this.byMe,
  });

  final String uid;
  final String name;
  final bool byMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ScreenCode(
      ScreenCodes.photographerProfile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: EmptyState(
              illustration: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    AppIcons.block,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: byMe
                  ? l.profileBlockedByMeTitle(name)
                  : l.profileBlockedByThemTitle,
              body: byMe ? l.profileBlockedByMeBody : l.profileBlockedByThemBody,
              actionLabel: byMe ? l.blockedUnblock : null,
              onAction: byMe
                  ? () => confirmUnblock(context, ref, userId: uid, name: name)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
