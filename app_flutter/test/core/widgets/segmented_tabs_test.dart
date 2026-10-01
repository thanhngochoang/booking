import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
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
}
