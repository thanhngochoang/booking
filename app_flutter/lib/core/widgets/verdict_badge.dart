// lib/core/widgets/verdict_badge.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/verdict_icon.dart';

/// Review row pill (mock `.vbdg`): icon and `×n` in the side colour on a
/// 14 % (tomato) / 16 % (brick) tint of it.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({super.key, required this.kind, required this.hits});

  final VerdictKind kind;
  final int hits;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = verdictColor(context, kind);
    final tint = kind == VerdictKind.tomato ? 0.14 : 0.16;
    return Semantics(
      label: kind == VerdictKind.tomato
          ? l.verdictBadgeTomato(hits)
          : l.verdictBadgeBrick(hits),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: tint),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VerdictIcon(kind, size: 14, color: color),
                const SizedBox(width: 3),
                Text(
                  l.reviewHits(hits),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
