// test/core/widgets/reason_chips_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import 'widget_host.dart';

const _a = Reason(code: ReasonCode.skillMatch, text: 'Chuyên chân dung');
const _b = Reason(code: ReasonCode.near, text: '1,2 km');
const _c = Reason(code: ReasonCode.freeOnDate, text: 'Rảnh T7 12/10');

void main() {
  testWidgets('shows at most two reasons by default, in order', (tester) async {
    await tester.pumpWidget(
      hostWidget(const ReasonChips(reasons: [_a, _b, _c])),
    );
    expect(find.text('Chuyên chân dung'), findsOneWidget);
    expect(find.text('1,2 km'), findsOneWidget);
    expect(find.text('Rảnh T7 12/10'), findsNothing);
  });

  testWidgets('max can raise the limit', (tester) async {
    await tester.pumpWidget(
      hostWidget(const ReasonChips(reasons: [_a, _b, _c], max: 3)),
    );
    expect(find.text('Rảnh T7 12/10'), findsOneWidget);
  });

  testWidgets('an empty list renders nothing', (tester) async {
    await tester.pumpWidget(hostWidget(const ReasonChips(reasons: [])));
    expect(tester.getSize(find.byType(ReasonChips)).height, 0);
  });

  testWidgets('one semantics node lists the shown reasons', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(const ReasonChips(reasons: [_a, _b, _c])),
    );
    expect(
      find.bySemanticsLabel('Gợi ý vì: Chuyên chân dung, 1,2 km'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a long reason is cut to one line inside a narrow card', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        const ReasonChips(
          reasons: [
            Reason(
              code: ReasonCode.topRated,
              text: 'Được đánh giá cao bởi rất nhiều khách hàng đã chụp cùng',
            ),
            _b,
          ],
        ),
        width: 120,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ReasonChips)).width,
      lessThanOrEqualTo(120),
    );
  });

  for (final b in Brightness.values) {
    testWidgets('has no blur on ${b.name}', (tester) async {
      await tester.pumpWidget(
        hostWidget(const ReasonChips(reasons: [_a, _b]), brightness: b),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }
}
