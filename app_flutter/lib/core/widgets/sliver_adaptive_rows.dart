// lib/core/widgets/sliver_adaptive_rows.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Rows of one item below 600dp and two from 600dp, in a sliver.
class SliverAdaptiveRows extends StatelessWidget {
  const SliverAdaptiveRows({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = AppSpace.s3,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double gap;

  static const wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent >= wideBreakpoint ? 2 : 1;
        final rows = (itemCount / columns).ceil();
        return SliverList.separated(
          itemCount: rows,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (context, row) {
            if (columns == 1) {
              return itemBuilder(context, row);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < columns; k++) ...[
                  if (k > 0) SizedBox(width: gap),
                  Expanded(
                    child: row * columns + k < itemCount
                        ? itemBuilder(context, row * columns + k)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
