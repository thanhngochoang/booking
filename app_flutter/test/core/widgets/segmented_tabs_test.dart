import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _options = [
  SegmentOption(value: 0, label: 'Dịch vụ'),
  SegmentOption(value: 1, label: 'Địa điểm'),
  SegmentOption(value: 2, label: 'Phong cách'),
  SegmentOption(value: 3, label: 'Thợ ảnh'),
];

void main() {
  testWidgets('tapping a segment reports its value', (tester) async {
    int? seen;
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(
          options: _options,
          value: 0,
          onChanged: (v) => seen = v,
        ),
      ),
    );
    await tester.tap(find.text('Phong cách'));
    expect(seen, 2);
  });

  testWidgets('four segments fit 320dp at 1.3x on one line each', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 1, onChanged: (_) {}),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    final heights = {
      for (final o in _options) tester.getSize(find.text(o.label)).height,
    };
    expect(heights.length, 1, reason: 'no label wraps to a second line');
  });

  testWidgets('the selected segment is exposed as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 1, onChanged: (_) {}),
      ),
    );
    final selected = tester.getSemantics(find.bySemanticsLabel('Địa điểm'));
    final other = tester.getSemantics(find.bySemanticsLabel('Dịch vụ'));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(selected.role, SemanticsRole.tab);
    expect(other.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('segments are at least 48dp tall', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 0, onChanged: (_) {}),
      ),
    );
    expect(
      tester.getSize(find.byType(SegmentedTabs<int>)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a disabled segment cannot be tapped', (tester) async {
    final seen = <int>[];
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(
          options: const [
            SegmentOption(value: 0, label: 'Gradient'),
            SegmentOption(value: 1, label: 'Ảnh đại diện', enabled: false),
          ],
          value: 0,
          onChanged: seen.add,
        ),
      ),
    );
    await tester.tap(find.text('Ảnh đại diện'));
    await tester.pump();
    expect(seen, isEmpty);
    await tester.tap(find.text('Gradient'));
    expect(seen, [0]);
  });

  testWidgets('a disabled segment is announced as disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(
          options: const [
            SegmentOption(value: 0, label: 'Gradient'),
            SegmentOption(value: 1, label: 'Ảnh đại diện', enabled: false),
          ],
          value: 0,
          onChanged: (_) {},
        ),
      ),
    );
    final off = tester.getSemantics(find.bySemanticsLabel('Ảnh đại diện'));
    final on = tester.getSemantics(find.bySemanticsLabel('Gradient'));
    expect(off.flagsCollection.isEnabled, Tristate.isFalse);
    expect(on.flagsCollection.isEnabled, Tristate.isTrue);
    handle.dispose();
  });

  test('enabled defaults to true', () {
    expect(const SegmentOption(value: 0, label: 'a').enabled, isTrue);
  });
}
