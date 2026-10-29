import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// One icon + text line of the primer's benefit list.
@immutable
class PrimerBenefit {
  const PrimerBenefit(this.icon, this.text);

  final IconData icon;
  final String text;
}

class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({
    super.key,
    required this.title,
    required this.benefits,
    this.note,
    required this.onEnable,
    required this.onLater,
    this.enabling = false,
    this.icon,
    this.enableLabel,
    this.laterLabel,
  });

  final String title;
  final List<PrimerBenefit> benefits;

  /// Small print under the buttons (e.g. when the question comes back).
  final String? note;
  final VoidCallback onEnable;
  final VoidCallback onLater;

  /// Puts the primary button in its loading state while the OS dialog is up.
  final bool enabling;

  /// Defaults to the notification bell (S17.03); S30.07 shows a camera.
  final IconData? icon;

  /// Replace "Bật thông báo" / "Để sau" for another permission.
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
                child: AppIcon(
                  icon ?? AppIcons.notificationsActive,
                  size: 28,
                  color: context.mutedForeground,
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
          const SizedBox(height: AppSpace.s4),
          for (final b in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s3),
              child: Row(
                key: const ValueKey('primer_benefit'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(b.icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Text(
                      b.text,
                      style: TextStyle(fontSize: AppText.sm, color: fgSec),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          AppButton.primary(
            enableLabel ?? l.primerEnableNotification,
            loading: enabling,
            onPressed: onEnable,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.text(
            laterLabel ?? l.primerLater,
            onPressed: enabling ? null : onLater,
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              note!,
              key: const ValueKey('primer_note'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.xs, color: fgSec),
            ),
          ],
        ],
      ),
    );
  }
}
