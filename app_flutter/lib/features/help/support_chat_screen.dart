import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/data/support/support_thread.dart';
import 'package:photobooking/features/help/support_thread_view.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class SupportChatScreen extends ConsumerWidget {
  const SupportChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final repo = ref.watch(supportRepositoryProvider);
    final threadId = repo.helpThreadIdFor(uid);

    return ScreenCode(
      ScreenCodes.help,
      label: 'chat',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.supportChatTitle)),
          body: SupportThreadView(
            threadId: threadId,
            enabled: true,
            hint: l.supportChatHint,
            senderLabel: (msg) {
              if (msg.senderRole == SupportSenderRole.staff) {
                return msg.senderName.isNotEmpty
                    ? msg.senderName
                    : l.supportChatTitle;
              }
              return '';
            },
            header: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpace.s3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcons.lock,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        l.supportChatNote,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            emptyPlaceholder: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppIcons.supportAgent,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      l.supportChatEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
