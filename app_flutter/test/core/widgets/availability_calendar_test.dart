// test/core/widgets/availability_calendar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

final _oct = DateTime.utc(2026, 10);
DateTime _d(int day) => DateTime.utc(2026, 10, day);
final _states = {
  _d(10): DayState.booked,
  _d(11): DayState.pending,
  _d(12): DayState.off,
};

Widget _cal({
  bool editable = false,
  ValueChanged<DateTime>? onSelect,
  ValueChanged<DateTime>? onLongPress,
  ValueChanged<DateTime>? onMonthChanged,
  DateTime? minDate,
  DateTime? maxDate,
  Set<DateTime> eventDays = const {},
}) => AvailabilityCalendar(
  month: _oct,
  states: _states,
  editable: editable,
  onSelect: onSelect,
  onLongPress: onLongPress,
  onMonthChanged: onMonthChanged,
  minDate: minDate,
  maxDate: maxDate,
  today: _d(1),
  eventDays: eventDays,
);

void main() {
  testWidgets('shows the month, the weekdays and every state in words', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal()));
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
    for (final w in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.bySemanticsLabel('10 tháng 10, đã đặt'), findsOneWidget);
    expect(find.bySemanticsLabel('11 tháng 10, chờ nhận'), findsOneWidget);
    expect(find.bySemanticsLabel('12 tháng 10, nghỉ'), findsOneWidget);
    expect(find.bySemanticsLabel('13 tháng 10, rảnh'), findsOneWidget);
    expect(find.bySemanticsLabel('1 tháng 10, rảnh, hôm nay'), findsOneWidget);
    expect(
      find.bySemanticsLabel('28 tháng 9, rảnh'),
      findsNothing,
      reason: 'days of other months are decoration',
    );
    h.dispose();
  });

  testWidgets('booking mode selects free days only', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(onSelect: picked.add)));
    await tester.tap(find.bySemanticsLabel('13 tháng 10, rảnh'));
    await tester.tap(find.bySemanticsLabel('10 tháng 10, đã đặt'));
    await tester.tap(find.bySemanticsLabel('11 tháng 10, chờ nhận'));
    await tester.tap(find.bySemanticsLabel('12 tháng 10, nghỉ'));
    expect(picked, [_d(13)]);
    h.dispose();
  });

  testWidgets('editable mode reports every day and long presses', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    final held = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(
        _cal(editable: true, onSelect: picked.add, onLongPress: held.add),
      ),
    );
    await tester.tap(find.bySemanticsLabel('12 tháng 10, nghỉ'));
    await tester.tap(find.bySemanticsLabel('10 tháng 10, đã đặt'));
    await tester.longPress(find.bySemanticsLabel('20 tháng 10, rảnh'));
    expect(picked, [_d(12), _d(10)]);
    expect(held, [_d(20)]);
    h.dispose();
  });

  testWidgets('days before minDate cannot be picked', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(_cal(editable: true, onSelect: picked.add, minDate: _d(5))),
    );
    await tester.tap(find.bySemanticsLabel('3 tháng 10, rảnh'));
    await tester.tap(find.bySemanticsLabel('5 tháng 10, rảnh'));
    expect(picked, [_d(5)]);
    h.dispose();
  });

  testWidgets('swipe and arrows change the month inside the bounds', (
    tester,
  ) async {
    final months = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(onMonthChanged: months.add)));
    await tester.fling(
      find.byType(AvailabilityCalendar),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tháng trước'));
    expect(months, [DateTime.utc(2026, 11), DateTime.utc(2026, 9)]);

    months.clear();
    await tester.pumpWidget(
      hostWidget(
        _cal(onMonthChanged: months.add, minDate: _d(1), maxDate: _d(31)),
      ),
    );
    await tester.fling(
      find.byType(AvailabilityCalendar),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(months, isEmpty);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('event days are marked and said', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal(eventDays: {_d(15)})));
    expect(
      find.bySemanticsLabel('15 tháng 10, rảnh, có sự kiện'),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('the legend names the four states', (tester) async {
    await tester.pumpWidget(hostWidget(const AvailabilityLegend()));
    for (final t in ['Rảnh', 'Đã đặt', 'Chờ nhận', 'Nghỉ']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text, cells stay 44dp tall (${b.name})', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(
        hostWidget(
          Column(
            children: [
              _cal(editable: true, onSelect: (_) {}),
              const AvailabilityLegend(),
            ],
          ),
          brightness: b,
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.bySemanticsLabel('13 tháng 10, rảnh')).height,
        greaterThanOrEqualTo(44),
      );
      h.dispose();
    });
  }
}
