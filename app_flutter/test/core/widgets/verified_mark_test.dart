// test/core/widgets/verified_mark_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('mark is a small blue disc with an accessible name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const VerifiedMark()));
    expect(find.bySemanticsLabel('Đã xác minh'), findsOneWidget);
    final disc = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(VerifiedMark),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((disc.decoration as BoxDecoration).color, AppColors.ctaStart);
    expect(tester.getSize(find.byType(VerifiedMark)), const Size(14, 14));
    handle.dispose();
  });

  testWidgets('long press shows the tooltip', (tester) async {
    await tester.pumpWidget(hostWidget(const VerifiedMark()));
    await tester.longPress(find.byType(VerifiedMark));
    await tester.pumpAndSettle();
    expect(find.text('Đã xác minh'), findsOneWidget);
  });

  testWidgets('beside a name the mark sits higher than the text centre', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(const VerifiedName('Minh Thư')));
    final mark = tester.getRect(find.byType(VerifiedMark));
    final line = tester.getRect(find.byType(Text).first);
    expect(mark.center.dy, lessThan(line.center.dy));
    expect(mark.left, greaterThan(line.left));
  });

  testWidgets('name plus mark wrap instead of overflowing at 320dp, 1.3x', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const VerifiedName('Nguyễn Thị Phương Anh Nhiếp Ảnh Gia Chân Dung'),
        width: 120,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
