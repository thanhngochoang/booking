import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// "Độ khớp hồ sơ 72%" with a gradient bar and the next thing to do
/// (S38, later S30 and S22). Only the photographer sees it. The number is
/// the server's (`skills.completeness`); [percent] is null until the server
/// has scored the profile ("Chưa có điểm", empty bar).
class CompletenessMeter extends StatelessWidget {
  const CompletenessMeter({super.key, required this.percent, this.nextHint});

  final int? percent;
  final String? nextHint;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final p = percent?.clamp(0, 100);
    final value = p == null ? l.completenessNone : l.completenessPercent(p);
    final radius = BorderRadius.circular(AppRadius.full);
    return Semantics(
      container: true,
      label: l.completenessTitle,
      value: value,
      hint: nextHint,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.completenessTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          SizedBox(
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: radius,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (p ?? 0) / 100,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ctaGradientFor(theme.brightness),
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (nextHint != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              nextHint!,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
