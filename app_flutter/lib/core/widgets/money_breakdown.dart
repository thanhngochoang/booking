// lib/core/widgets/money_breakdown.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

enum MoneyLineStyle { normal, strong, muted }

@immutable
class MoneyLine {
  const MoneyLine({
    required this.label,
    required this.vnd,
    this.style = MoneyLineStyle.normal,
  });

  final String label;
  final int vnd;
  final MoneyLineStyle style;
}

/// Renders a list of price breakdown lines (spec .row inside #moneybreakdown):
/// normal, strong (bold highlight) or muted (secondary notice).
class MoneyBreakdown extends StatelessWidget {
  const MoneyBreakdown({super.key, required this.lines});

  final List<MoneyLine> lines;

  static Widget skeleton({int lines = 3}) =>
      _MoneyBreakdownSkeleton(linesCount: lines);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _buildRow(lines[i], fg: fg, fgSec: fgSec),
        ],
      ],
    );
  }

  Widget _buildRow(MoneyLine line, {required Color fg, required Color fgSec}) {
    final TextStyle labelStyle;
    final TextStyle numStyle;

    switch (line.style) {
      case MoneyLineStyle.strong:
        labelStyle = TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: fg,
          height: 1.25,
        );
        numStyle = TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: fg,
          height: 1.25,
        );
        break;
      case MoneyLineStyle.muted:
        labelStyle = TextStyle(
          fontSize: AppText.chip,
          color: fgSec,
          height: 1.25,
        );
        numStyle = TextStyle(
          fontSize: AppText.chip,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: fgSec,
          height: 1.25,
        );
        break;
      case MoneyLineStyle.normal:
        labelStyle = TextStyle(fontSize: 12.5, color: fg, height: 1.25);
        numStyle = TextStyle(
          fontSize: 12.5,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: fg,
          height: 1.25,
        );
        break;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              line.label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(formatMoney(line.vnd), style: numStyle),
        ],
      ),
    );
  }
}

class _MoneyBreakdownSkeleton extends StatelessWidget {
  const _MoneyBreakdownSkeleton({required this.linesCount})
    : super(key: const ValueKey('money_breakdown_skeleton'));

  final int linesCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < linesCount; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 18),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.65,
                    child: AppSkeleton.line(height: 12),
                  ),
                ),
                SizedBox(width: 8),
                AppSkeleton.line(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
