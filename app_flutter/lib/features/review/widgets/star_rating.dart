import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 40,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  void _handleDrag(Offset localPosition, double totalWidth) {
    if (onChanged == null || totalWidth <= 0) return;
    final fraction = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    final target = (fraction * 5).floor() + 1;
    final clamped = target.clamp(1, 5);
    if (clamped != value) {
      onChanged!(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveValue = value.clamp(0, 5);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = AppColors.warning;
    final inactiveColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
        : theme.colorScheme.outlineVariant;

    final starsRow = LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = size * 5 + AppSpace.s2 * 4;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: onChanged == null
              ? null
              : (details) => _handleDrag(details.localPosition, totalWidth),
          onHorizontalDragUpdate: onChanged == null
              ? null
              : (details) => _handleDrag(details.localPosition, totalWidth),
          child: SizedBox(
            width: totalWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++) ...[
                  if (i > 1) const SizedBox(width: AppSpace.s2),
                  GestureDetector(
                    key: Key('star_$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onChanged == null ? null : () => onChanged!(i),
                    child: Icon(
                      i <= effectiveValue
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: size,
                      color: i <= effectiveValue ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    final nextIncrease = effectiveValue < 5 ? effectiveValue + 1 : null;
    final nextDecrease = effectiveValue > 1 ? effectiveValue - 1 : null;

    final l10n = context.l10n;
    return Semantics(
      slider: true,
      value: l10n.reviewStarsSemantics(effectiveValue),
      increasedValue:
          nextIncrease != null ? l10n.reviewStarsSemantics(nextIncrease) : null,
      decreasedValue:
          nextDecrease != null ? l10n.reviewStarsSemantics(nextDecrease) : null,
      onIncrease: (onChanged != null && nextIncrease != null)
          ? () => onChanged!(nextIncrease)
          : null,
      onDecrease: (onChanged != null && nextDecrease != null)
          ? () => onChanged!(nextDecrease)
          : null,
      child: starsRow,
    );
  }
}
