// lib/core/widgets/stat_tile.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

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
        child: DecoratedBox(
          // Translucent fill, no blur: tiles sit on cards that already blur.
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            // Mock .kpi: padding 10 8 10 12, content pinned to the bottom.
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
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
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
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
