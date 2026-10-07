// lib/core/widgets/earning_row.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// One money row of S06.05 (mock `.card`): title and date on the left, the
/// short amount (tabular figures) and a state badge on the right, and an
/// optional note line (the hold reason) under both. The amount is plain
/// foreground colour: accent is for actions, never money.
class EarningRow extends StatelessWidget {
  const EarningRow({
    super.key,
    required this.title,
    required this.meta,
    required this.amount,
    required this.amountLabel,
    required this.badge,
    this.note,
    this.noteIcon,
    this.onTap,
  });

  static Widget skeleton({Key? key}) => _EarningRowSkeleton(key: key);

  final String title;
  final String meta;

  /// Already formatted, short (`450K`).
  final String amount;

  /// The full amount, read by screen readers (`450.000₫`).
  final String amountLabel;
  final Widget badge;
  final String? note;
  final IconData? noteIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.md);
    final n = note;
    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label: [title, meta, amountLabel, ?n].join(', '),
      child: ExcludeSemantics(
        child: Material(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.base2,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                ),
                              ),
                              const SizedBox(height: AppSpace.s1),
                              Text(
                                meta,
                                style: TextStyle(
                                  fontSize: AppText.xs2,
                                  color: fgSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.s3),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: fg,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpace.s1),
                            badge,
                          ],
                        ),
                      ],
                    ),
                    if (n != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (noteIcon != null) ...[
                            AppIcon(noteIcon!, size: 16, color: fgSec),
                            const SizedBox(width: AppSpace.s1),
                          ],
                          Expanded(
                            child: Text(
                              n,
                              style: TextStyle(
                                fontSize: AppText.xs2,
                                color: fgSec,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _EarningRowSkeleton extends StatelessWidget {
  const _EarningRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(widthFactor: 0.7),
                    const SizedBox(height: AppSpace.s1),
                    AppSkeleton.line(widthFactor: 0.3),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppSkeleton.box(width: 40, height: 14),
                  const SizedBox(height: AppSpace.s1),
                  AppSkeleton.box(width: 64, height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
