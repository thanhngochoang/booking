// test/core/widgets/milestone_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/milestone_table.dart';

import 'widget_host.dart';

void main() {
  group('MilestoneTable', () {
    testWidgets('two lines with numbers 1 and 2 and formatted amounts', (tester) async {
      final lines = [
        const MilestoneLine(
          title: 'Sau buổi chụp',
          subtitle: 'thả cho thợ ảnh',
          amountVnd: 2100000,
        ),
        const MilestoneLine(
          title: 'Khi bạn đồng ý ảnh + 48 giờ kiểm tra',
          subtitle: 'hoặc tự đồng ý sau 3 ngày',
          amountVnd: 2100000,
        ),
      ];

      await tester.pumpWidget(
        hostWidget(MilestoneTable(lines: lines)),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Sau buổi chụp'), findsOneWidget);
      expect(find.text('thả cho thợ ảnh'), findsOneWidget);
      expect(find.text('Khi bạn đồng ý ảnh + 48 giờ kiểm tra'), findsOneWidget);
      expect(find.text('hoặc tự đồng ý sau 3 ngày'), findsOneWidget);
      expect(find.text('2.100.000₫'), findsNWidgets(2));
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      final lines = [
        const MilestoneLine(
          title: 'Sau buổi chụp',
          subtitle: 'thả cho thợ ảnh',
          amountVnd: 2100000,
        ),
        const MilestoneLine(
          title: 'Khi bạn đồng ý ảnh + 48 giờ kiểm tra',
          subtitle: 'hoặc tự đồng ý sau 3 ngày',
          amountVnd: 2100000,
        ),
      ];

      await tester.pumpWidget(
        hostWidget(
          MilestoneTable(lines: lines),
          width: 320,
          textScale: 1.3,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
