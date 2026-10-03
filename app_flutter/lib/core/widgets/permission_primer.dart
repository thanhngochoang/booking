import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({
    super.key,
    required this.title,
    required this.benefit,
    required this.onEnable,
    required this.onLater,
    this.enableLabel,
    this.laterLabel,
  });

  final String title;
  final String benefit;
  final VoidCallback onEnable;
  final VoidCallback onLater;
  final String? enableLabel;
  final String? laterLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final l = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: dark
                    ? AppColorsDark.primarySubtle
                    : AppColors.primarySubtle,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.xl,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            benefit,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.sm,
              color: fgSec,
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          AppButton.primary(
            enableLabel ?? l.primerEnableNotification,
            onPressed: onEnable,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.text(
            laterLabel ?? l.primerLater,
            onPressed: onLater,
          ),
        ],
      ),
    );
  }
}
