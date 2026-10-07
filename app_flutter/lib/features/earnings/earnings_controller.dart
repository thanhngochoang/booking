// lib/features/earnings/earnings_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/earnings/earnings.dart';

/// Rows asked from the server; "Xem thêm" adds one more page.
const int earningsPageSize = 30;

class EarningsLimit extends Notifier<int> {
  @override
  int build() => earningsPageSize;

  void more() => state += earningsPageSize;
}

final earningsLimitProvider = NotifierProvider.autoDispose<EarningsLimit, int>(
  EarningsLimit.new,
);

/// Rows grouped by `yyyy-MM` in the order they come (newest first); the day
/// order inside a month is kept.
List<({String monthKey, List<EarningItem> items})> groupByMonth(
  List<EarningItem> items,
) {
  final order = <String>[];
  final byMonth = <String, List<EarningItem>>{};
  for (final item in items) {
    final key = item.day.length >= 7 ? item.day.substring(0, 7) : item.day;
    final list = byMonth.putIfAbsent(key, () {
      order.add(key);
      return <EarningItem>[];
    });
    list.add(item);
  }
  return [for (final k in order) (monthKey: k, items: byMonth[k]!)];
}
