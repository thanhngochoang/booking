import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// One choice of a single-choice list (mock `.opt`, S02.05; later S04.02, S13.01):
/// a bordered glass card with a radio. Selected = accent border, accent-soft
/// fill and a filled radio. No blur, so it is safe in long lists. The [icon]
/// variant (S08.01, Settings provider-type sheet) puts a 40dp icon tile on
/// the left and the radio on the right.
class AppOptionTile extends StatelessWidget {
  static Widget skeleton({Key? key, bool withThumb = false}) =>
      _AppOptionTileSkeleton(key: key, withThumb: withThumb);

  const AppOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.icon,
    this.description,
  }) : assert(
         icon == null || leading == null,
         'icon and leading are mutually exclusive',
       );

  final String label;

  /// Optional second line under [label] (mock `.opt .d`).
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  /// Optional icon between the radio and the label (radio-left layout only;
  /// see [icon]).
  final Widget? leading;

  /// Mock `.opt .oi` (S08.01-type): a 40dp rounded tile on the left holding
  /// this icon — field colour, or primary with an onPrimary icon when
  /// selected — and the radio moves to the right end. Mutually exclusive
  /// with [leading].
  final IconData? icon;

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
      label: description == null ? label : '$label. $description',
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
                    if (icon != null) ...[
                      Container(
                        key: const ValueKey('option-icon-tile'),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary : scheme.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Center(
                          child: AppIcon(
                            icon!,
                            size: 20,
                            color: selected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2h),
                    ] else ...[
                      _Radio(selected: selected, edge: edge),
                      const SizedBox(width: AppSpace.s2h),
                    ],
                    if (leading != null) ...[
                      IconTheme.merge(
                        data: const IconThemeData(size: 18),
                        child: leading!,
                      ),
                      const SizedBox(width: AppSpace.s2),
                    ],
                    Expanded(
                      child: description == null
                          ? Text(label, style: theme.textTheme.bodyMedium)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: dark
                                        ? AppColorsDark.foregroundMuted
                                        : AppColors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: AppSpace.s2),
                      _Radio(selected: selected, edge: edge),
                    ],
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

class _AppOptionTileSkeleton extends StatelessWidget {
  const _AppOptionTileSkeleton({super.key, this.withThumb = false});
  final bool withThumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? AppColorsDark.glass : AppColors.glass;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2h,
            ),
            child: Row(
              children: [
                AppSkeleton.circle(size: 18),
                const SizedBox(width: AppSpace.s2h),
                if (withThumb) ...[
                  AppSkeleton.box(width: 18, height: 18, radius: AppRadius.sm),
                  const SizedBox(width: AppSpace.s2),
                ],
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppSkeleton.line(height: 14),
                    ),
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
