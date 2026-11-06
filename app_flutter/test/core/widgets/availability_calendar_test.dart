// test/core/widgets/availability_calendar_test.dart
import 'dart:ui' show Tristate;

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

Finder _cell(DateTime d) =>
    find.byKey(ValueKey('app-calendar-day-${vnDateKey(d)}'));
Finder _solar(DateTime d) =>
    find.byKey(ValueKey('app-calendar-solar-${vnDateKey(d)}'));
Finder _lunar(DateTime d) =>
    find.byKey(ValueKey('app-calendar-lunar-${vnDateKey(d)}'));

/// What a screen reader says for the cell of [d].
String _said(WidgetTester tester, DateTime d) =>
    tester.getSemantics(_cell(d)).label;

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
  testWidgets('every day shows its lunar day (R6): 1/10 on 9 Nov 2026', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(month: DateTime.utc(2026, 11), states: const {}),
      ),
    );
    expect(tester.widget<Text>(_lunar(DateTime.utc(2026, 11, 9))).data, '1/10');
    expect(tester.widget<Text>(_lunar(DateTime.utc(2026, 11, 23))).data, '15');
    // The solar number is still there.
    expect(tester.widget<Text>(_solar(DateTime.utc(2026, 11, 9))).data, '9');
  });

  testWidgets('a note sits under the number of its day, in the month only', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(
          month: _oct,
          states: _states,
          today: _d(1),
          notes: {
            _d(3): (text: '1,8M', accent: false),
            _d(17): (text: 'Lễ 2,2M', accent: true),
            // Not in October: drawn nowhere.
            DateTime.utc(2026, 11, 1): (text: '9M', accent: false),
          },
        ),
      ),
    );
    expect(find.text('1,8M'), findsOneWidget);
    expect(find.text('Lễ 2,2M'), findsOneWidget);
    expect(find.text('9M'), findsNothing);
    // Read aloud with the day.
    expect(_said(tester, _d(3)), contains('rảnh'));
    expect(_said(tester, _d(3)), endsWith('1,8M'));
    expect(_said(tester, _d(4)), isNot(contains('M')));
    h.dispose();
  });

  testWidgets('shows the month, the weekdays and every state in words', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal()));
    expect(find.text('Tháng 10 / 2026'), findsOneWidget);
    for (final w in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(w), findsOneWidget);
    }
    expect(_said(tester, _d(10)), contains('10 tháng 10'));
    expect(_said(tester, _d(10)), contains('đã đặt'));
    expect(_said(tester, _d(11)), contains('chờ nhận'));
    expect(_said(tester, _d(12)), contains('nghỉ'));
    expect(_said(tester, _d(13)), contains('rảnh'));
    expect(_said(tester, _d(1)), contains('rảnh, hôm nay'));
    expect(
      find.bySemanticsLabel(RegExp('28 tháng 9')),
      findsNothing,
      reason: 'days of other months are decoration',
    );
    h.dispose();
  });

  testWidgets('booking mode selects free days only', (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(onSelect: picked.add)));
    await tester.tap(_cell(_d(13)));
    await tester.tap(_cell(_d(10)));
    await tester.tap(_cell(_d(11)));
    await tester.tap(_cell(_d(12)));
    expect(picked, [_d(13)]);
  });

  testWidgets('the selected day is filled and read as selected', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(
          month: _oct,
          states: _states,
          selected: _d(15),
          onSelect: (_) {},
        ),
      ),
    );
    Tristate selected(DateTime d) =>
        tester.getSemantics(_cell(d)).flagsCollection.isSelected;
    expect(selected(_d(15)), Tristate.isTrue);
    expect(selected(_d(16)), Tristate.isFalse);
    h.dispose();
  });

  testWidgets('selectedDays marks several days selected (S29.04)', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(
          month: _oct,
          states: _states,
          selectedDays: {_d(17), _d(18)},
          onSelect: (_) {},
        ),
      ),
    );
    bool selected(DateTime d) =>
        tester.getSemantics(_cell(d)).flagsCollection.isSelected ==
        Tristate.isTrue;
    expect(selected(_d(17)), isTrue);
    expect(selected(_d(18)), isTrue);
    expect(selected(_d(19)), isFalse);
    h.dispose();
  });

  testWidgets('a full day shows Hết chỗ and is not tappable', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(
          month: _oct,
          states: {..._states, _d(14): DayState.full},
          onSelect: picked.add,
          today: _d(1),
        ),
      ),
    );
    expect(_said(tester, _d(14)), endsWith('hết chỗ'));
    final data = tester.getSemantics(_cell(_d(14))).getSemanticsData();
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    await tester.tap(_cell(_d(14)));
    expect(picked, isEmpty);
    // Drawn like a booked day: struck through, and not dimmed like a day
    // outside the bounds.
    final text = tester.widget<Text>(_solar(_d(14)));
    expect(text.style?.decoration, TextDecoration.lineThrough);
    expect(
      find.ancestor(of: _solar(_d(14)), matching: find.byType(Opacity)),
      findsNothing,
    );
    h.dispose();
  });

  testWidgets('pending is accent text on a dashed outline, off is filled', (
    tester,
  ) async {
    await tester.pumpWidget(hostWidget(_cal(onSelect: (_) {})));
    final accent = Theme.of(tester.element(_cell(_d(11)))).colorScheme.primary;
    expect(tester.widget<Text>(_solar(_d(11))).style?.color, accent);
    expect(
      find.descendant(
        of: _cell(_d(11)),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter != null,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(_solar(_d(10))).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      find.descendant(
        of: _cell(_d(12)),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color != null,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('editable mode reports every day and long presses', (
    tester,
  ) async {
    final picked = <DateTime>[];
    final held = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(
        _cal(editable: true, onSelect: picked.add, onLongPress: held.add),
      ),
    );
    await tester.tap(_cell(_d(12)));
    await tester.tap(_cell(_d(10)));
    await tester.longPress(_cell(_d(20)));
    expect(picked, [_d(12), _d(10)]);
    expect(held, [_d(20)]);
  });

  testWidgets('rangeStart outlines its day', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AvailabilityCalendar(
          month: _oct,
          states: const {},
          editable: true,
          rangeStart: _d(20),
          onSelect: (_) {},
        ),
      ),
    );
    bool outlined(DateTime d) => find
        .descendant(
          of: _cell(d),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border != null,
          ),
        )
        .evaluate()
        .isNotEmpty;
    expect(outlined(_d(20)), isTrue);
    expect(outlined(_d(21)), isFalse);
  });

  testWidgets('days before minDate cannot be picked', (tester) async {
    final picked = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(_cal(editable: true, onSelect: picked.add, minDate: _d(5))),
    );
    await tester.tap(_cell(_d(3)));
    await tester.tap(_cell(_d(5)));
    expect(picked, [_d(5)]);
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
            find.widgetWithIcon(IconButton, AppIcons.chevronLeft),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('event days are marked and said', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal(eventDays: {_d(15)})));
    expect(_said(tester, _d(15)), contains('rảnh, có sự kiện'));
    expect(_said(tester, _d(16)), isNot(contains('có sự kiện')));
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
      expect(tester.getSize(_cell(_d(13))).height, greaterThanOrEqualTo(44));
    });
  }
}
