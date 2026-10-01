// lib/core/widgets/capacity_bar.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// Filled share of a limited resource (event seats, badge progress), always
/// with text so the meaning does not rest on the bar alone.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.used,
    required this.total,
    this.label,
  });

  final int used;
  final int total;

  /// Replaces "{used} / {total} đã đăng ký".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = label ?? context.l10n.capacityUsed(used, total);
    final fraction = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: SizedBox(
                key: const Key('capacity-track'),
                height: 6,
                width: double.infinity,
                child: ColoredBox(
                  color: theme.colorScheme.secondary,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: fraction == 0
                        ? null
                        : FractionallySizedBox(
                            widthFactor: fraction,
                            child: DecoratedBox(
                              key: const Key('capacity-fill'),
                              decoration: BoxDecoration(
                                gradient: ctaGradientFor(theme.brightness),
                              ),
                              child: const SizedBox(height: 6),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(text, style: const TextStyle(fontSize: AppText.sm)),
          ],
        ),
      ),
    );
  }
}
