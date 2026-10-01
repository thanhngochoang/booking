import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import '../../data/auth/auth_providers.dart';
import '../auth/auth_controller.dart';

/// The profile could not be loaded (offline on first sign-in, rules denial…).
class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.sessionErrorTitle,
                  style: t.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  l.sessionErrorBody,
                  style: t.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(
                  l.retry,
                  key: const Key('session-retry'),
                  onPressed: () => ref.invalidate(currentProfileProvider),
                ),
                const SizedBox(height: AppSpace.s2),
                AppButton.text(
                  l.signOut,
                  key: const Key('session-sign-out'),
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
