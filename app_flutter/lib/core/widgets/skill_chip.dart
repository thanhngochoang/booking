import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/widgets/app_chip.dart';

/// Multi-select chip for a catalogue item (S38, S39).
///
/// [disabled] means "this group is full": an unselected chip is dimmed and
/// announces "Đã đủ số lượng", but taps are still reported so the screen can
/// explain the limit (spec S38: "chọn thể loại thứ 7 → báo").
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final dim = disabled && !selected;
    return MergeSemantics(
      child: Semantics(
        hint: dim ? context.l10n.skillChipFull : null,
        child: Opacity(
          opacity: dim ? 0.5 : 1,
          child: AppChip(
            label: label,
            selected: selected,
            kind: AppChipKind.context,
            onChanged: (_) => onTap(),
          ),
        ),
      ),
    );
  }
}
