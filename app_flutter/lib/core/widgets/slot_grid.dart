// lib/core/widgets/slot_grid.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Grid of slot start times (mock `.pkg`, S29.06): a free slot shows its
/// start in bold and "–{end}" under it; a taken one is dimmed with "Đã kín"
/// and cannot be picked. Four columns, three on a narrow width.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.slots,
    this.selected,
    required this.onPick,
    this.semanticsLabel,
  });

  final List<({String start, String end, bool free})> slots;

  /// The picked start (`HH:mm`), if any.
  final String? selected;
  final ValueChanged<String> onPick;

  /// Name of the radio group for screen readers ("Giờ bắt đầu").
  final String? semanticsLabel;

  static const double _gap = AppSpace.s2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth >= 300 ? 4 : 3;
          final width = (constraints.maxWidth - _gap * (cols - 1)) / cols;
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final s in slots)
                SizedBox(
                  width: width,
                  child: _SlotCell(
                    key: Key('slot-${s.start}'),
                    start: s.start,
                    end: s.end,
                    free: s.free,
                    selected: s.free && s.start == selected,
                    onTap: s.free ? () => onPick(s.start) : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    super.key,
    required this.start,
    required this.end,
    required this.free,
    required this.selected,
    required this.onTap,
  });

  final String start;
  final String end;
  final bool free;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = selected
        ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      side: BorderSide(color: selected ? scheme.primary : scheme.outline),
    );
    final second = free ? '–$end' : context.l10n.slotTaken;
    final tabular = const [FontFeature.tabularFigures()];

    Widget cell = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: ShapeDecoration(color: fill, shape: shape),
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s1,
              vertical: AppSpace.s2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  start,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppText.base2,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    fontFeatures: tabular,
                  ),
                ),
                Text(
                  second,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppText.xs2,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!free) cell = Opacity(opacity: 0.5, child: cell);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: free,
      button: free,
      label: free ? '$start–$end' : '$start, $second',
      excludeSemantics: true,
      onTap: onTap,
      child: cell,
    );
  }
}
