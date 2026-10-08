import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });
  final T value;
  final String label;

  /// A disabled segment is greyed, cannot be tapped and is announced as
  /// disabled.
  final bool enabled;
}

/// A row of equal segments of which exactly one is selected: S03.01, S02.03, S05.01,
/// S11.04, S06.01. Labels stay on one line and scale down instead of wrapping.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final disabledColor = dark
        ? AppColorsDark.foregroundDisabled
        : AppColors.foregroundDisabled;
    final radius = BorderRadius.circular(controlRadius);
    return Material(
      color: scheme.secondary,
      borderRadius: radius,
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                role: SemanticsRole.tab,
                selected: o.value == value,
                inMutuallyExclusiveGroup: true,
                label: o.label,
                enabled: o.enabled,
                excludeSemantics: true,
                onTap: o.enabled ? () => onChanged(o.value) : null,
                child: InkWell(
                  borderRadius: radius,
                  onTap: o.enabled ? () => onChanged(o.value) : null,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s1),
                      child: DecoratedBox(
                        decoration: o.value == value
                            ? BoxDecoration(
                                color: subtle,
                                borderRadius: BorderRadius.circular(
                                  controlRadius - AppSpace.s1,
                                ),
                                border: Border.all(color: scheme.primary),
                              )
                            : const BoxDecoration(),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s2,
                              ),
                              child: Text(
                                o.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: AppText.base,
                                  fontWeight: FontWeight.w600,
                                  color: !o.enabled
                                      ? disabledColor
                                      : o.value == value
                                      ? scheme.primary
                                      : secondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
