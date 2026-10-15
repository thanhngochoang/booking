import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('displays title without action when action is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(const SectionHeader(title: 'Nhiếp ảnh gia')),
    );
    expect(find.text('Nhiếp ảnh gia'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsNothing);
  });

  testWidgets('displays action label and calls onAction when tapped', (
    tester,
  ) async {
    var actionTapped = false;
    await tester.pumpWidget(
      hostWidget(
        SectionHeader(
          title: 'Dịch vụ nổi bật',
          actionLabel: 'Xem tất cả',
          onAction: () => actionTapped = true,
        ),
      ),
    );
    expect(find.text('Dịch vụ nổi bật'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);

    await tester.tap(find.text('Xem tất cả'));
    expect(actionTapped, isTrue);
  });

  testWidgets('fits 320dp width with 1.3x text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        SectionHeader(
          title: 'Một tiêu đề khá dài cho phần dịch vụ',
          actionLabel: 'Xem thêm',
          onAction: () {},
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Một tiêu đề khá dài cho phần dịch vụ'), findsOneWidget);
  });
}
