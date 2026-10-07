import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _row({String? note, IconData? icon, VoidCallback? onTap}) => EarningRow(
  title: 'Lan Anh · Chân dung 2h',
  meta: 'T7 12/10',
  amount: '450K',
  amountLabel: '450.000₫',
  badge: const StatusBadge.custom(
    label: 'Đang giữ',
    color: AppColors.bookingWaiting,
    onColor: AppColors.foregroundInverse,
  ),
  note: note,
  noteIcon: icon,
  onTap: onTap,
);

void main() {
  testWidgets('earning row reads title, date, full amount and badge', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_row(onTap: () {})));
    expect(find.text('Lan Anh · Chân dung 2h'), findsOneWidget);
    expect(find.text('T7 12/10'), findsOneWidget);
    expect(find.text('450K'), findsOneWidget);
    expect(find.text('ĐANG GIỮ'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Lan Anh · Chân dung 2h, T7 12/10, 450.000₫'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the amount uses tabular figures', (tester) async {
    await tester.pumpWidget(hostWidget(_row()));
    final style = tester.widget<Text>(find.text('450K')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('earning row shows its note with an icon', (tester) async {
    await tester.pumpWidget(
      hostWidget(_row(note: 'Lý do: x', icon: AppIcons.warning)),
    );
    expect(find.text('Lý do: x'), findsOneWidget);
    expect(find.byType(AppIcon), findsOneWidget);
  });

  testWidgets('a row with onTap calls it and is at least 48 dp tall', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(hostWidget(_row(onTap: () => taps++)));
    expect(
      tester.getSize(find.byType(EarningRow)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(EarningRow));
    expect(taps, 1);
  });

  testWidgets('skeleton has the row\'s shape', (tester) async {
    await tester.pumpWidget(
      hostWidget(Column(children: [_row(), EarningRow.skeleton()])),
    );
    final row = tester.getSize(find.byType(EarningRow));
    final sk = tester.getSize(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_EarningRowSkeleton',
      ),
    );
    expect(sk.width, row.width);
    expect(sk.height, closeTo(row.height, 12));
  });

  testWidgets('fits 320 dp at text scale 1.3', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        _row(
          note: 'Lý do: Khách đã báo vấn đề, đang chờ xử lý',
          icon: AppIcons.warning,
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
