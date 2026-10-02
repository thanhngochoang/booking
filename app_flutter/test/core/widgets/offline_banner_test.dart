import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('displays cloud off icon and offline banner text', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(const OfflineBanner()));
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Đang xem dữ liệu đã lưu'), findsOneWidget);
  });

  testWidgets('fits 320dp without overflow', (tester) async {
    await tester.pumpWidget(
      hostWidget(const OfflineBanner(), width: 320, textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Đang xem dữ liệu đã lưu'), findsOneWidget);
  });
}
