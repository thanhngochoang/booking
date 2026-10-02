// lib/core/widgets/policy_table.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

@immutable
class PolicyRow {
  const PolicyRow({required this.when, required this.outcome});

  final String when;
  final String outcome;
}

/// Table displaying cancellation / refund policy milestones (spec .opt list):
/// non-clickable option tiles where the currently active milestone is highlighted
/// and announced to assistive tech with "Đang áp dụng".
class PolicyTable extends StatelessWidget {
  const PolicyTable({super.key, required this.rows, required this.activeIndex});

  final List<PolicyRow> rows;
  final int activeIndex;

  static Widget skeleton({int rows = 3}) =>
      _PolicyTableSkeleton(rowsCount: rows);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final primarySubtle = dark
        ? AppColorsDark.primarySubtle
        : AppColors.primarySubtle;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildRow(
            rows[i],
            isActive: i == activeIndex,
            fg: fg,
            primary: primary,
            primarySubtle: primarySubtle,
            glass: glass,
            outline: outline,
          ),
        ],
      ],
    );
  }

  Widget _buildRow(
    PolicyRow row, {
    required bool isActive,
    required Color fg,
    required Color primary,
    required Color primarySubtle,
    required Color glass,
    required Color outline,
  }) {
    final semanticLabel = isActive
        ? 'Đang áp dụng: ${row.when}, ${row.outcome}'
        : '${row.when}, ${row.outcome}';

    return Semantics(
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? primarySubtle : glass,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isActive ? primary : outline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    row.when,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: fg, height: 1.25),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  row.outcome,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: fg,
                    height: 1.25,
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

class _PolicyTableSkeleton extends StatelessWidget {
  const _PolicyTableSkeleton({required this.rowsCount})
    : super(key: const ValueKey('policy_table_skeleton'));

  final int rowsCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowsCount; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: glass,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: outline),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.6,
                        child: AppSkeleton.line(height: 12),
                      ),
                    ),
                    SizedBox(width: 8),
                    AppSkeleton.line(width: 64, height: 12),
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
