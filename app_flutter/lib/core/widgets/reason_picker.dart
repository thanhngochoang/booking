// lib/core/widgets/reason_picker.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_chip.dart';
import 'package:photobooking/core/widgets/app_option_tile.dart';

/// Style representation of [ReasonPicker]: choice chips (S05.03, S13.08)
/// or radio option tiles (S06.03).
enum ReasonPickerStyle { chips, radio }

/// Single-choice reason picker for cancellations and rejections.
///
/// Selecting "Lý do khác" reveals a text input with character counting
/// and min/max length constraints.
class ReasonPicker extends StatefulWidget {
  const ReasonPicker({
    super.key,
    required this.reasons,
    required this.selected,
    required this.onSelected,
    this.style = ReasonPickerStyle.chips,
    this.otherLabel,
    this.onOtherText,
    this.otherMinLength = 0,
    this.otherMaxLength = 200,
  });

  final List<String> reasons;
  final int? selected;
  final ValueChanged<int> onSelected;
  final ReasonPickerStyle style;

  /// Custom label that identifies the "other" option. Defaults to matching "khác".
  final String? otherLabel;

  /// Callback when the "other" text input changes.
  final ValueChanged<String>? onOtherText;

  /// Minimum character length required for the "other" explanation.
  final int otherMinLength;

  /// Maximum character length allowed for the "other" explanation.
  final int otherMaxLength;

  @override
  State<ReasonPicker> createState() => _ReasonPickerState();
}

class _ReasonPickerState extends State<ReasonPicker> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isOther(int index) {
    if (index < 0 || index >= widget.reasons.length) return false;
    final text = widget.reasons[index];
    if (widget.otherLabel != null) {
      return text == widget.otherLabel;
    }
    return text.toLowerCase().contains('khác');
  }

  bool get _isOtherSelected =>
      widget.selected != null && _isOther(widget.selected!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.style == ReasonPickerStyle.chips)
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (var i = 0; i < widget.reasons.length; i++)
                AppChip(
                  label: widget.reasons[i],
                  selected: widget.selected == i,
                  onChanged: (_) => widget.onSelected(i),
                  kind: AppChipKind.filter,
                ),
            ],
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.reasons.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpace.s2),
                AppOptionTile(
                  label: widget.reasons[i],
                  selected: widget.selected == i,
                  onTap: () => widget.onSelected(i),
                ),
              ],
            ],
          ),
        if (_isOtherSelected) ...[
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const ValueKey('reason_picker_other_field'),
            controller: _controller,
            maxLength: widget.otherMaxLength,
            maxLines: 3,
            minLines: 1,
            style: theme.textTheme.bodyMedium,
            onChanged: (val) {
              setState(() {});
              widget.onOtherText?.call(val);
            },
            decoration: InputDecoration(
              hintText: 'Nhập lý do cụ thể...',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              helperText:
                  widget.otherMinLength > 0 &&
                      _controller.text.trim().length < widget.otherMinLength
                  ? 'Tối thiểu ${widget.otherMinLength} ký tự'
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
