// lib/core/widgets/milestone_table.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

@immutable
class MilestoneLine {
  const MilestoneLine({
    required this.title,
    required this.subtitle,
    required this.amountVnd,
  });

  final String title;
  final String subtitle;
  final int amountVnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneLine &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          subtitle == other.subtitle &&
          amountVnd == other.amountVnd;

  @override
  int get hashCode => Object.hash(title, subtitle, amountVnd);
}

/// Milestone breakdown table (mock `.mrow`, S15.04).
///
/// Each line displays a numbered disc, title + small subtitle, and tabular amount.
class MilestoneTable extends StatelessWidget {
  const MilestoneTable({super.key, required this.lines});

  final List<MilestoneLine> lines;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final lineBorder = Theme.of(context).colorScheme.outlineVariant;
    final discBg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final discFg = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: lineBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: discBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: discFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lines[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      if (lines[i].subtitle.isNotEmpty)
                        Text(
                          lines[i].subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: fgSec,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(lines[i].amountVnd),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
