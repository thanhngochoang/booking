import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  group('groupByVnMonth', () {
    test('keeps order inside a month and month order as given', () {
      final g = groupByVnMonth<(String, String)>([
        ('a', '2026-10-12'),
        ('b', '2026-10-01'),
        ('c', '2026-09-30'),
        ('d', '2025-12-02'),
      ], (e) => e.$2);
      expect(g.map((e) => e.monthKey), ['2026-10', '2026-09', '2025-12']);
      expect(g.first.items.map((e) => e.$1), ['a', 'b']);
    });

    test('a short key is its own month; empty gives no groups', () {
      expect(
        groupByVnMonth<String>(['2026-09'], (e) => e).single.monthKey,
        '2026-09',
      );
      expect(groupByVnMonth<String>(const [], (e) => e), isEmpty);
    });
  });
}
