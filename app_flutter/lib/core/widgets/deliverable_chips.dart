// lib/core/widgets/deliverable_chips.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

@immutable
class DeliverableItem {
  const DeliverableItem({
    required this.label,
    this.value,
    this.positive = false,
  });

  final String label;
  final String? value;
  final bool positive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliverableItem &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value &&
          positive == other.positive;

  @override
  int get hashCode => Object.hash(label, value, positive);
}

/// Deliverables row or 4-tile grid (mock `.dl`, `.dl.big`, S15.03, S15.04).
///
/// In row mode (`grid = false`), displays each item as a rounded chip. Positive
/// chips (e.g. "Rảnh 20/10") use the free/success token colors.
/// In grid mode (`grid = true`), displays 4 tiles side-by-side with big serif numbers
/// (`AppFonts.display`) above labels; missing values show '—'.
class DeliverableChips extends StatelessWidget {
  const DeliverableChips({
    super.key,
    required this.items,
    this.grid = false,
  });

  final List<DeliverableItem> items;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    if (grid) {
      return _DeliverableGrid(items: items);
    }
    return _DeliverableRow(items: items);
  }
}

class _DeliverableRow extends StatelessWidget {
  const _DeliverableRow({required this.items});

  final List<DeliverableItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final defaultFg = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final posBg = dark ? AppColorsDark.freeBg : AppColors.freeBg;
    final posFg = dark ? AppColorsDark.freeInk : AppColors.freeInk;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final item in items)
          DecoratedBox(
            decoration: BoxDecoration(
              color: item.positive ? posBg : defaultBg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                item.value != null ? '${item.value} ${item.label}' : item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: item.positive ? FontWeight.w600 : FontWeight.w500,
                  color: item.positive ? posFg : defaultFg,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeliverableGrid extends StatelessWidget {
  const _DeliverableGrid({required this.items});

  final List<DeliverableItem> items;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final ink = dark ? AppColorsDark.foreground : AppColors.foreground;
    final subInk = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      items[i].value != null && items[i].value!.isNotEmpty
                          ? items[i].value!
                          : '—',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: subInk,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
