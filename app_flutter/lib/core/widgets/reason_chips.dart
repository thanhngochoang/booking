// lib/core/widgets/reason_chips.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/data/content/reason.dart';

/// Why this photographer is recommended: up to [max] short chips. Dropped
/// reasons are not scrolled to; the card stays calm.
class ReasonChips extends StatelessWidget {
  const ReasonChips({super.key, required this.reasons, this.max = 2});

  final List<Reason> reasons;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = reasons.take(max).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.reasonsSemantics(shown.map((r) => r.text).join(', ')),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: AppSpace.s1,
          runSpacing: AppSpace.s1,
          children: [
            for (final r in shown)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    child: Text(
                      r.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurface),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
