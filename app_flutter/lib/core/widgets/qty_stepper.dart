import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/app_icons.dart';

/// Minus, count, plus. The count is announced through [valueLabel] (a live
/// region), so the screen decides the noun ("2 vé", "2 người").
///
/// Keys are `<keyPrefix>-minus`, `<keyPrefix>-quantity`, `<keyPrefix>-plus`.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.valueLabel,
    required this.decrementLabel,
    required this.incrementLabel,
    this.min = 1,
    required this.max,
    this.enabled = true,
    this.keyPrefix = 'qty',
  });

  final int value;

  /// Called with `value - 1` or `value + 1`; never outside `[min, max]`.
  final ValueChanged<int> onChanged;

  /// What a screen reader says for the current value.
  final String valueLabel;

  /// Tooltip and semantics of the two buttons.
  final String decrementLabel;
  final String incrementLabel;
  final int min;
  final int max;

  /// False disables both buttons (a locked or submitting form).
  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('$keyPrefix-minus'),
          tooltip: decrementLabel,
          icon: const AppIcon(AppIcons.remove),
          onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
        ),
        Semantics(
          liveRegion: true,
          label: valueLabel,
          child: ExcludeSemantics(
            child: SizedBox(
              width: 32,
              child: Text(
                '$value',
                key: Key('$keyPrefix-quantity'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('$keyPrefix-plus'),
          tooltip: incrementLabel,
          icon: const AppIcon(AppIcons.add),
          onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
