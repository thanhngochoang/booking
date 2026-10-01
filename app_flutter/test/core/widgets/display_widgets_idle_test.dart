// test/core/widgets/display_widgets_idle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  final cases = <String, Widget>{
    'VerifiedName': const VerifiedName('Minh Thư'),
    'FreeTag': const FreeTag(),
    'FreeBanner': const FreeBanner(),
    'StatTileRow': const StatTileRow(
      tiles: [
        StatTile(value: '12,4M', label: 'Đang giữ'),
        StatTile(value: '3,2M', label: 'Sắp nhận'),
        StatTile(value: '5', label: 'Đã nhận'),
      ],
    ),
    'CapacityBar': const CapacityBar(used: 14, total: 20),
    'StepProgress': const StepProgress(current: 2, total: 4),
  };
  for (final MapEntry(:key, :value) in cases.entries) {
    for (final b in Brightness.values) {
      testWidgets('$key is idle at rest (${b.name})', (tester) async {
        await tester.pumpWidget(hostWidget(value, brightness: b));
        await expectIdle(tester);
      });
    }
  }

  testWidgets('a row of stat tiles adds no blur pass', (tester) async {
    await tester.pumpWidget(hostWidget(cases['StatTileRow']!));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a long list of verified names builds lazily', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SizedBox(
          height: 400,
          child: ListView.builder(
            itemCount: 1000,
            itemBuilder: (_, i) => VerifiedName('Nhiếp ảnh gia $i'),
          ),
        ),
      ),
    );
    expect(find.byType(VerifiedMark).evaluate().length, lessThan(60));
  });
}
