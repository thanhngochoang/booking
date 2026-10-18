import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

class CheckWindowCard extends StatelessWidget {
  const CheckWindowCard({
    super.key,
    required this.checkUntil,
    required this.now,
    this.onReport,
  });

  final DateTime checkUntil;
  final DateTime now;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final cardBorder = dark ? AppColorsDark.border : AppColors.border;
    final cardBg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final textMuted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    final accent = dark ? AppColorsDark.primary : AppColors.primary;
    final errorColor = dark ? AppColorsDark.destructive : AppColors.destructive;

    final diff = checkUntil.difference(now);
    final isExpired = diff <= Duration.zero;

    if (isExpired) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cardBorder),
        ),
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          children: [
            AppIcon(AppIcons.checkCircle, size: 20, color: textMuted),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                l10n.deliveryCheckExpired,
                style: theme.textTheme.bodyMedium?.copyWith(color: textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final hoursLeft = diff.inHours;
    final fraction = (hoursLeft / 48.0).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${l10n.deliveryCheckCardTitle}: ',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.deliveryCheckCardHoursLeft(hoursLeft),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Semantics(
            label: '${l10n.deliveryCheckCardTitle} ${l10n.deliveryCheckCardHoursLeft(hoursLeft)}',
            value: '$hoursLeft/48',
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: dark ? AppColorsDark.surface : AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 6,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l10n.deliveryCheckCardHint,
            style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
          ),
          if (onReport != null) ...[
            const SizedBox(height: AppSpace.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton.text(
                l10n.deliveryReportOriginals,
                size: AppButtonSize.small,
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(errorColor),
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                onPressed: onReport,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
