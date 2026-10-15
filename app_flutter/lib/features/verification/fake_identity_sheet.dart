// lib/features/verification/fake_identity_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// Fake mode only (`identityModeRealProvider` false): stands in for the
/// VNeID app. "Đồng ý chia sẻ" returns true and the caller completes the
/// session (`completeIdentityVerification` hands back a test identity);
/// closing the sheet returns false.
Future<bool> showFakeIdentitySheet(BuildContext context) async =>
    await showAppSheet<bool>(
      context,
      builder: (_) => const FakeIdentitySheet(),
    ) ??
    false;

class FakeIdentitySheet extends StatelessWidget {
  const FakeIdentitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s2,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.badge,
                color: dark ? AppColorsDark.accent : AppColors.accent,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.verifyIdFakeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.verifyIdFakeBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: dark
                  ? AppColorsDark.foregroundSecondary
                  : AppColors.foregroundSecondary,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.verifyIdFakeAgree,
            key: const Key('verify-fake-agree'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
