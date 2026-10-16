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
          appBar: AppBar(
            title: Text(l?.supportChatTitle ?? 'Hỗ trợ'),
          ),
          body: SupportThreadView(
            threadId: threadId,
            enabled: true,
            hint: l?.supportChatHint ?? 'Nhắn cho hỗ trợ…',
            senderLabel: (msg) {
              if (msg.senderRole == SupportSenderRole.staff) {
                return msg.senderName.isNotEmpty ? msg.senderName : 'Hỗ trợ';
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        l?.supportChatNote ??
                            'Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP.',
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
                      l?.supportChatEmpty ??
                          'Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới.',
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
