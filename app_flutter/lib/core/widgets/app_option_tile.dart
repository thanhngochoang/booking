import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// One choice of a single-choice list (mock `.opt`, S36; later S06, S47):
/// a bordered glass card with a radio. Selected = accent border, accent-soft
/// fill and a filled radio. No blur, so it is safe in long lists.
class AppOptionTile extends StatelessWidget {
  const AppOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional icon between the radio and the label.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = selected
        ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final edge = selected ? scheme.primary : scheme.outline;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: edge),
    );
    return Semantics(
      enabled: true,
      checked: selected,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: ShapeDecoration(color: fill, shape: shape),
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2h,
                ),
                child: Row(
                  children: [
                    _Radio(selected: selected, edge: edge),
                    const SizedBox(width: AppSpace.s2h),
                    if (leading != null) ...[
                      IconTheme.merge(
                        data: const IconThemeData(size: 18),
                        child: leading!,
                      ),
                      const SizedBox(width: AppSpace.s2),
                    ],
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock `.rd`: 18dp ring, 2px border; selected adds a 40% accent dot.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.edge});
  final bool selected;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: edge, width: 2),
      ),
      child: selected
          ? Container(
              key: const Key('option-radio-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
