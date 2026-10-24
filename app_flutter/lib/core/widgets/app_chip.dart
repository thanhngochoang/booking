import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Which look a selected chip takes (spec section 1).
enum AppChipKind {
  /// A filter: selected is a solid `primary` pill (S02.06, S11.01, S02.04 radius).
  filter,

  /// A single choice or context (category row, style): selected is
  /// `primarySubtle` with a primary border and text (S02.01, S04.02, S12.01, S08.04; S02.04 date and free toggles).
  context,
}

/// Rounded choice pill: 34dp tall, 48dp touch area.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.kind = AppChipKind.filter,
    this.leading,
    this.trailing,
    this.semanticsLabel,
  });

  final String label;

  /// Read instead of [label] when the visible text needs its [leading] icon
  /// to make sense (the Find chip "🍅 90%+" reads "Từ 90% cà chua").
  final String? semanticsLabel;
  final bool selected;

  /// Called with the value the chip would take, i.e. `!selected`.
  final ValueChanged<bool> onChanged;
  final AppChipKind kind;
  final Widget? leading;

  /// After the label, e.g. `expand_more` on a chip that opens a picker
  /// (S27.01 "Khu vực ▾").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final secondaryInk = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final (fill, text, edge) = !selected
        ? (glass, secondaryInk, scheme.outline)
        : kind == AppChipKind.filter
        ? (scheme.primary, scheme.onPrimary, scheme.primary)
        : (subtle, scheme.primary, scheme.primary);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: () => onChanged(!selected),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: fill,
              shape: StadiumBorder(side: BorderSide(color: edge)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(!selected),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading != null) ...[
                          IconTheme(
                            data: IconThemeData(color: text, size: 16),
                            child: leading!,
                          ),
                          const SizedBox(width: AppSpace.s1),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontSize: AppText.chip,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 2),
                          IconTheme(
                            data: IconThemeData(color: text, size: 16),
                            child: trailing!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
