// lib/core/widgets/reorderable_row.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// One row of a sortable list (mock `.lrow`, S24.04): drag handle, optional
/// leading thumbnail, title, subtitle and a "…" menu.
///
/// Place it as an item of a `ReorderableListView` built with
/// `buildDefaultDragHandles: false`. The handle starts a drag on long press
/// (so scrolling never starts one). The menu is the way to reorder without
/// dragging: move up, move down, to top, to bottom; entries that would not
/// move the row are disabled. After a menu move the parent should announce the
/// new position with `SemanticsService.announce`.
class ReorderableRow extends StatelessWidget {
  const ReorderableRow({
    super.key,
    required this.index,
    required this.count,
    required this.title,
    this.subtitle,
    this.leading,
    this.dimmed = false,
    required this.onMove,
    this.extraMenu = const [],
  });

  /// Zero-based position; also the index handed to the drag listener.
  final int index;
  final int count;
  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Mock `.lrow.unsorted`: dashed border, no fill, for rows not yet ordered.
  final bool dimmed;

  /// Called with the new zero-based index from the menu.
  final void Function(int newIndex) onMove;

  /// Extra entries after the four move entries, e.g. Sửa, Xoá.
  final List<PopupMenuEntry<VoidCallback>> extraMenu;

  /// Key of the drag handle's 48dp hit area.
  static const handleKey = ValueKey('reorderable-row-handle');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted;
    final border = dark ? AppColorsDark.border : AppColors.border;
    final fill = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final l = context.l10n;
    final first = index <= 0;
    final last = index >= count - 1;

    final menu = PopupMenuButton<VoidCallback>(
      tooltip: l.reorderMenu,
      icon: Icon(Icons.more_horiz_rounded, color: muted),
      constraints: const BoxConstraints(minWidth: 180),
      iconSize: AppSpace.s6,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSpace.s12),
      ),
      onSelected: (run) => run(),
      itemBuilder: (_) => [
        PopupMenuItem<VoidCallback>(
          enabled: !first,
          value: () => onMove(index - 1),
          child: Text(l.reorderMoveUp),
        ),
        PopupMenuItem<VoidCallback>(
          enabled: !last,
          value: () => onMove(index + 1),
          child: Text(l.reorderMoveDown),
        ),
        PopupMenuItem<VoidCallback>(
          enabled: !first,
          value: () => onMove(0),
          child: Text(l.reorderMoveTop),
        ),
        PopupMenuItem<VoidCallback>(
          enabled: !last,
          value: () => onMove(count - 1),
          child: Text(l.reorderMoveBottom),
        ),
        if (extraMenu.isNotEmpty) const PopupMenuDivider(),
        ...extraMenu,
      ],
    );

    final handle = ReorderableDelayedDragStartListener(
      index: index,
      child: Semantics(
        label: l.reorderHandle,
        child: SizedBox(
          key: handleKey,
          width: AppSpace.s12,
          height: AppSpace.s12,
          child: Icon(Icons.drag_handle_rounded, color: muted),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
      child: Semantics(
        container: true,
        label: title,
        value: l.reorderPosition(index + 1, count),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dimmed ? Colors.transparent : fill,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              handle,
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpace.s2h),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: AppText.base2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppText.xs2,
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}
