// lib/core/widgets/stat_tile.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/glass_card.dart';

/// A big number over a one-line label. Put two or three in a [StatTileRow].
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Semantics(
      label: '$value, $label',
      child: ExcludeSemantics(
        child: GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(fontSize: 10.5, color: secondary),
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

/// Tiles side by side, equal width and equal height.
class StatTileRow extends StatelessWidget {
  const StatTileRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s2),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
