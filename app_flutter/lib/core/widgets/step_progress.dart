// lib/core/widgets/step_progress.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// "n / N" with one bar segment per step; segments up to [current] are filled
/// with the theme gradient. Used by booking, event creation and profile setup.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.current,
    required this.total,
    this.label,
  });

  final int current;
  final int total;

  /// Name of the current step, shown before the count.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final filled = current.clamp(0, total);
    return Semantics(
      label: l.stepProgressSemantics(filled, total),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  l.stepProgressCount(filled, total),
                  style: const TextStyle(
                    fontSize: AppText.sm,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s1),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: SizedBox(
                        key: const Key('step-segment'),
                        height: 4,
                        child: i < filled
                            ? DecoratedBox(
                                key: const Key('step-filled'),
                                decoration: BoxDecoration(
                                  gradient: ctaGradientFor(theme.brightness),
                                ),
                              )
                            : ColoredBox(color: theme.colorScheme.secondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
