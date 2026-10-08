import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _lines = [
  EarningBreakdownLine(label: 'Đã chuyển theo mốc', value: '1.500.000₫'),
  EarningBreakdownLine(label: 'Thuế khấu trừ (7%)', value: '105.000₫'),
  EarningBreakdownLine(label: 'Thực nhận', value: '1.395.000₫', strong: true),
];

Widget _row({
  String? note,
  IconData? icon,
  VoidCallback? onTap,
  List<EarningBreakdownLine>? breakdown,
  bool expanded = false,
}) => EarningRow(
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
  breakdown: breakdown,
  expanded: expanded,
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

  testWidgets('collapsed shows no breakdown; expanded shows each line label '
      'and value', (tester) async {
    await tester.pumpWidget(hostWidget(_row(onTap: () {}, breakdown: _lines)));
    expect(find.text('Thuế khấu trừ (7%)'), findsNothing);
    expect(find.text('1.395.000₫'), findsNothing);

    await tester.pumpWidget(
      hostWidget(_row(onTap: () {}, breakdown: _lines, expanded: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    for (final t in [
      'Đã chuyển theo mốc',
      '1.500.000₫',
      'Thuế khấu trừ (7%)',
      '105.000₫',
      'Thực nhận',
      '1.395.000₫',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('the strong line is bolder than the others', (tester) async {
    await tester.pumpWidget(
      hostWidget(_row(breakdown: _lines, expanded: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final strong = tester.widget<Text>(find.text('Thực nhận')).style!;
    final plain = tester.widget<Text>(find.text('Thuế khấu trừ (7%)')).style!;
    expect(strong.fontWeight!.value, greaterThan(plain.fontWeight!.value));
  });

  testWidgets('expanded is announced to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(_row(onTap: () {}, breakdown: _lines, expanded: true)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    var node = tester.getSemantics(find.byType(EarningRow));
    expect(node, isSemantics(hasExpandedState: true, isExpanded: true));
    // The lines are part of what is read.
    expect(node.label, contains('Thực nhận, 1.395.000₫'));

    await tester.pumpWidget(hostWidget(_row(onTap: () {}, breakdown: _lines)));
    await tester.pump(const Duration(milliseconds: 300));
    node = tester.getSemantics(find.byType(EarningRow));
    expect(node, isSemantics(hasExpandedState: true, isExpanded: false));
    expect(node.label, isNot(contains('1.395.000₫')));
    handle.dispose();
  });

  testWidgets('a row without a breakdown announces no expanded state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_row(onTap: () {})));
    final node = tester.getSemantics(find.byType(EarningRow));
    expect(node, isSemantics(hasExpandedState: false));
    handle.dispose();
  });

  testWidgets('fits 320 dp at 1.3× text', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        _row(
          note: 'Lý do: Khách đã báo vấn đề, đang chờ xử lý',
          icon: AppIcons.warning,
          breakdown: const [
            EarningBreakdownLine(
              label: 'Đã chuyển theo mốc',
              value: '1.500.000₫',
            ),
            EarningBreakdownLine(label: 'Hoa hồng (7,5%)', value: '112.500₫'),
            EarningBreakdownLine(
              label: 'Thuế khấu trừ (7%)',
              value: '105.000₫',
            ),
            EarningBreakdownLine(
              label: 'Thực nhận dự kiến',
              value: '1.282.500₫',
              strong: true,
            ),
          ],
          expanded: true,
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
