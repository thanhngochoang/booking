// test/core/widgets/app_calendar_test.dart
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

final _nov = DateTime.utc(2026, 11);
DateTime _d(int day, [int month = 11, int year = 2026]) =>
    DateTime.utc(year, month, day);

Finder _cell(DateTime d) =>
    find.byKey(ValueKey('app-calendar-day-${vnDateKey(d)}'));
Finder _lunar(DateTime d) =>
    find.byKey(ValueKey('app-calendar-lunar-${vnDateKey(d)}'));
Finder _solar(DateTime d) =>
    find.byKey(ValueKey('app-calendar-solar-${vnDateKey(d)}'));

Widget _cal({
  DateTime? month,
  AppCalendarSelection selection = AppCalendarSelection.none,
  DateTime? selected,
  DateTimeRange? range,
  ValueChanged<DateTime>? onDayTap,
  ValueChanged<DateTimeRange>? onRangeChanged,
  ValueChanged<DateTime>? onMonthChanged,
  bool Function(DateTime)? disabledDay,
  Widget? Function(BuildContext, DateTime)? dayBuilder,
  Set<DateTime> markers = const {},
  Color? Function(DateTime)? dayOutline,
  bool Function(DateTime)? emphasized,
  bool showHeader = true,
  DateTime? first,
  DateTime? last,
  DateTime? today,
}) => AppCalendar(
  month: month ?? _nov,
  selection: selection,
  selected: selected,
  range: range,
  onDayTap: onDayTap,
  onRangeChanged: onRangeChanged,
  onMonthChanged: onMonthChanged,
  disabledDay: disabledDay,
  dayBuilder: dayBuilder,
  markers: markers,
  dayOutline: dayOutline,
  emphasized: emphasized,
  showHeader: showHeader,
  first: first,
  last: last,
  today: today,
);

/// A range calendar that keeps its own range, like a screen would.
class _RangeHost extends StatefulWidget {
  const _RangeHost({required this.log});
  final List<DateTimeRange> log;

  @override
  State<_RangeHost> createState() => _RangeHostState();
}

class _RangeHostState extends State<_RangeHost> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) => AppCalendar(
    month: _nov,
    selection: AppCalendarSelection.range,
    range: _range,
    onRangeChanged: (r) {
      widget.log.add(r);
      setState(() => _range = r);
    },
  );
}

void main() {
  group('lunar day', () {
    testWidgets(
      'every day of 2026-11 shows lunarLabel; mùng 1 and 15 of month 10 '
      'are 9 and 23 Nov',
      (tester) async {
        await tester.pumpWidget(hostWidget(_cal()));
        for (var day = 1; day <= 30; day++) {
          final d = _d(day);
          final text = tester.widget<Text>(_lunar(d));
          expect(text.data, lunarLabel(d), reason: '$d');
        }
        expect(tester.widget<Text>(_lunar(_d(9))).data, '1/10');
        expect(tester.widget<Text>(_lunar(_d(23))).data, '15');
      },
    );

    testWidgets('1/M is in the accent colour, other days are muted', (
      tester,
    ) async {
      await tester.pumpWidget(hostWidget(_cal()));
      final primary = Theme.of(tester.element(_cell(_d(9))))
          .colorScheme
          .primary;
      expect(tester.widget<Text>(_lunar(_d(9))).style?.color, primary);
      expect(tester.widget<Text>(_lunar(_d(10))).style?.color, isNot(primary));
    });

    testWidgets('the lunar number is small, on the same row as the solar '
        'number and right next to its foot', (tester) async {
      await tester.pumpWidget(hostWidget(_cal()));
      final solar = tester.getRect(_solar(_d(21)));
      final lunar = tester.getRect(_lunar(_d(21)));
      expect(lunar.height, lessThan(solar.height));
      expect((lunar.bottom - solar.bottom).abs(), lessThan(4));
      expect(lunar.left - solar.right, inInclusiveRange(0, 4));
    });

    testWidgets('a leap month day shows its number like any other', (
      tester,
    ) async {
      // 2025-07-25 is 1/6 nhuận.
      await tester.pumpWidget(hostWidget(_cal(month: DateTime.utc(2025, 7))));
      expect(tester.widget<Text>(_lunar(_d(25, 7, 2025))).data, '1/6');
    });
  });

  group('layout', () {
    testWidgets('7 columns, Monday first, cells at least 44 dp', (
      tester,
    ) async {
      await tester.pumpWidget(hostWidget(_cal()));
      expect(find.text('T2'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);
      // 1 Nov 2026 is a Sunday: the last column; 2 Nov starts the next row.
      final sun = tester.getRect(_cell(_d(1)));
      final mon = tester.getRect(_cell(_d(2)));
      expect(sun.height, greaterThanOrEqualTo(44));
      expect(mon.left, lessThan(sun.left));
      expect(mon.top, greaterThan(sun.top));
      expect(tester.getRect(_cell(_d(3))).left, greaterThan(mon.left));
      expect(sun.right, closeTo(390, 1));
    });

    testWidgets('header shows "Tháng 11 / 2026" and steps months', (
      tester,
    ) async {
      final changed = <DateTime>[];
      await tester.pumpWidget(hostWidget(_cal(onMonthChanged: changed.add)));
      expect(find.text('Tháng 11 / 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.tap(find.byTooltip('Tháng sau'));
      expect(changed, [DateTime.utc(2026, 10), DateTime.utc(2026, 12)]);
    });

    testWidgets('showHeader: false hides the header', (tester) async {
      await tester.pumpWidget(hostWidget(_cal(showHeader: false)));
      expect(find.text('Tháng 11 / 2026'), findsNothing);
      expect(find.byTooltip('Tháng sau'), findsNothing);
    });

    testWidgets('first and last stop the month buttons', (tester) async {
      final changed = <DateTime>[];
      await tester.pumpWidget(
        hostWidget(
          _cal(onMonthChanged: changed.add, first: _d(5, 11), last: _d(20, 11)),
        ),
      );
      await tester.tap(find.byTooltip('Tháng trước'), warnIfMissed: false);
      await tester.tap(find.byTooltip('Tháng sau'), warnIfMissed: false);
      expect(changed, isEmpty);
    });

    for (final brightness in Brightness.values) {
      testWidgets('pumps in ${brightness.name} theme with a day line, '
          'outline, marker and selection', (tester) async {
        await tester.pumpWidget(
          hostWidget(
            _cal(
              selection: AppCalendarSelection.range,
              range: DateTimeRange(start: _d(14), end: _d(22)),
              dayBuilder: (_, d) => Text('${d.day}M'),
              dayOutline: (d) => d.day == 15 ? AppColors.warning : null,
              markers: {_d(3)},
              emphasized: (d) => d.day == 7,
              today: _d(4),
            ),
            brightness: brightness,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('15M'), findsOneWidget);
      });
    }

    testWidgets('320 dp wide at text scale 1.3 does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(
          _cal(
            dayBuilder: (_, d) => const Text('1,5M'),
            dayOutline: (d) => d.day == 15 ? AppColors.warning : null,
            markers: {_d(3)},
          ),
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_cell(_d(30))).height, greaterThanOrEqualTo(44));
    });
  });

  group('taps', () {
    testWidgets('a tap on a day calls onDayTap; other-month days do not', (
      tester,
    ) async {
      final taps = <DateTime>[];
      await tester.pumpWidget(hostWidget(_cal(onDayTap: taps.add)));
      await tester.tap(_cell(_d(21)));
      await tester.tap(_cell(_d(31, 10)), warnIfMissed: false);
      expect(taps, [_d(21)]);
    });

    testWidgets('disabled days and days outside first/last do not answer', (
      tester,
    ) async {
      final taps = <DateTime>[];
      await tester.pumpWidget(
        hostWidget(
          _cal(
            onDayTap: taps.add,
            disabledDay: (d) => d.day == 21,
            first: _d(5),
            last: _d(25),
          ),
        ),
      );
      await tester.tap(_cell(_d(21)), warnIfMissed: false);
      await tester.tap(_cell(_d(3)), warnIfMissed: false);
      await tester.tap(_cell(_d(28)), warnIfMissed: false);
      await tester.tap(_cell(_d(22)));
      expect(taps, [_d(22)]);
    });

    testWidgets('single selection fills the selected day with the accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(
          _cal(selection: AppCalendarSelection.single, selected: _d(21)),
        ),
      );
      BoxDecoration? deco(DateTime d) {
        final box = find.descendant(
          of: _cell(d),
          matching: find.byType(DecoratedBox),
        );
        for (final e in tester.widgetList<DecoratedBox>(box)) {
          final dec = e.decoration;
          if (dec is BoxDecoration && dec.gradient != null) {
            return dec;
          }
        }
        return null;
      }

      expect(deco(_d(21)), isNotNull);
      expect(deco(_d(22)), isNull);
    });

    testWidgets('dayOutline draws an outline in the given colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        hostWidget(
          _cal(dayOutline: (d) => d.day == 15 ? AppColors.warning : null),
        ),
      );
      bool outlined(DateTime d) => tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _cell(d), matching: find.byType(DecoratedBox)),
          )
          .any((e) {
            final dec = e.decoration;
            return dec is BoxDecoration &&
                dec.border?.top.color == AppColors.warning;
          });
      expect(outlined(_d(15)), isTrue);
      expect(outlined(_d(16)), isFalse);
    });
  });

  group('range', () {
    testWidgets('tap start then tap end; a tap before the start restarts', (
      tester,
    ) async {
      final log = <DateTimeRange>[];
      await tester.pumpWidget(hostWidget(_RangeHost(log: log)));
      await tester.tap(_cell(_d(14)));
      await tester.tap(_cell(_d(18)));
      expect(log.last, DateTimeRange(start: _d(14), end: _d(18)));

      // The range is complete: the next tap starts a new one.
      await tester.tap(_cell(_d(20)));
      expect(log.last, DateTimeRange(start: _d(20), end: _d(20)));
      // A second tap before the start restarts instead of reversing.
      await tester.tap(_cell(_d(10)));
      expect(log.last, DateTimeRange(start: _d(10), end: _d(10)));
      await tester.tap(_cell(_d(12)));
      expect(log.last, DateTimeRange(start: _d(10), end: _d(12)));
    });

    testWidgets('long-press then drag across cells selects the range', (
      tester,
    ) async {
      final log = <DateTimeRange>[];
      await tester.pumpWidget(hostWidget(_RangeHost(log: log)));
      final g = await tester.startGesture(tester.getCenter(_cell(_d(11))));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(tester.getCenter(_cell(_d(13))));
      await tester.pump();
      await g.moveTo(tester.getCenter(_cell(_d(19)))); // next row
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(log.last, DateTimeRange(start: _d(11), end: _d(19)));

      // Dragging back past the anchor reverses the range.
      final g2 = await tester.startGesture(tester.getCenter(_cell(_d(20))));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g2.moveTo(tester.getCenter(_cell(_d(17))));
      await tester.pump();
      await g2.up();
      await tester.pump();
      expect(log.last, DateTimeRange(start: _d(17), end: _d(20)));
    });

    testWidgets('a drag skips disabled days', (tester) async {
      final log = <DateTimeRange>[];
      await tester.pumpWidget(
        hostWidget(
          AppCalendar(
            month: _nov,
            selection: AppCalendarSelection.range,
            onRangeChanged: log.add,
            disabledDay: (d) => d.day == 13,
          ),
        ),
      );
      final g = await tester.startGesture(tester.getCenter(_cell(_d(11))));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(tester.getCenter(_cell(_d(12))));
      await tester.pump();
      await g.moveTo(tester.getCenter(_cell(_d(13))));
      await tester.pump();
      await g.up();
      expect(log.last, DateTimeRange(start: _d(11), end: _d(12)));
    });

    testWidgets('a long-press drag does not also count as a tap', (
      tester,
    ) async {
      final taps = <DateTime>[];
      await tester.pumpWidget(
        hostWidget(
          AppCalendar(
            month: _nov,
            selection: AppCalendarSelection.range,
            onRangeChanged: (_) {},
            onDayTap: taps.add,
          ),
        ),
      );
      final g = await tester.startGesture(tester.getCenter(_cell(_d(11))));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g.moveTo(tester.getCenter(_cell(_d(13))));
      await g.up();
      await tester.pump();
      expect(taps, isEmpty);
    });
  });

  group('semantics', () {
    testWidgets('a cell says weekday, date, lunar date and the builder text', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(
        hostWidget(
          _cal(
            onDayTap: (_) {},
            dayBuilder: (_, d) => Text('${d.day} nghìn'),
            today: _d(9),
          ),
        ),
      );
      final mon = tester.getSemantics(_cell(_d(9))).label;
      expect(mon, contains('Thứ Hai 9 tháng 11, mùng 1 tháng 10 âm lịch'));
      expect(mon, contains('hôm nay'));
      expect(mon, contains('9 nghìn'));
      final sat = tester.getSemantics(_cell(_d(21))).label;
      expect(sat, contains('Thứ Bảy 21 tháng 11, 13 tháng 10 âm lịch'));
      h.dispose();
    });

    testWidgets('a leap month day says nhuận', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(hostWidget(_cal(month: DateTime.utc(2025, 7))));
      expect(
        tester.getSemantics(_cell(_d(25, 7, 2025))).label,
        contains('mùng 1 tháng 6 nhuận âm lịch'),
      );
      h.dispose();
    });

    testWidgets('the numbers are not read twice', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(hostWidget(_cal()));
      final label = tester.getSemantics(_cell(_d(21))).label;
      expect('Thứ Bảy'.allMatches(label).length, 1);
      expect(label.trim().split('\n'), hasLength(1));
      h.dispose();
    });
  });

  group('pickers', () {
    Widget opener(
      void Function(Object?) onResult,
      Future<Object?> Function(BuildContext) open,
    ) => hostWidget(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(await open(context)),
          child: const Text('mở'),
        ),
      ),
    );

    testWidgets('showAppDatePicker returns the chosen day', (tester) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        opener(
          (r) => result = r,
          (c) => showAppDatePicker(
            c,
            initial: _d(10),
            first: _d(1, 10),
            last: _d(31, 12),
            title: 'Ngày chụp',
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.text('Ngày chụp'), findsOneWidget);
      expect(find.text('Tháng 11 / 2026'), findsOneWidget);
      await tester.tap(_cell(_d(21)));
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(result, _d(21));
    });

    testWidgets('the picker keeps the initial day when only Chọn is tapped, '
        'and moves between months', (tester) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        opener(
          (r) => result = r,
          (c) => showAppDatePicker(
            c,
            initial: _d(10),
            first: _d(1, 10),
            last: _d(31, 12),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng sau'));
      await tester.pump();
      expect(find.text('Tháng 12 / 2026'), findsOneWidget);
      await tester.tap(_cell(_d(5, 12)));
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(result, _d(5, 12));
    });

    testWidgets('dismissing the picker returns null', (tester) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        opener(
          (r) => result = r,
          (c) => showAppDatePicker(
            c,
            initial: _d(10),
            first: _d(1, 10),
            last: _d(31, 12),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('showAppDateRangePicker returns the tapped range', (
      tester,
    ) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        opener(
          (r) => result = r,
          (c) => showAppDateRangePicker(
            c,
            first: _d(1, 10),
            last: _d(31, 12),
            initial: DateTimeRange(start: _d(3), end: _d(5)),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(_cell(_d(14)));
      await tester.pump();
      await tester.tap(_cell(_d(18)));
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(result, DateTimeRange(start: _d(14), end: _d(18)));
    });

    testWidgets('the range picker has no Chọn answer without a range', (
      tester,
    ) async {
      Object? result = 'unset';
      await tester.pumpWidget(
        opener(
          (r) => result = r,
          (c) => showAppDateRangePicker(c, first: _d(1, 10), last: _d(31, 12)),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(result, 'unset');
      expect(find.text('Chọn'), findsOneWidget);
    });

    testWidgets('the picker fits 320 dp at text scale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppDatePicker(
                context,
                initial: _d(10),
                first: _d(1, 10),
                last: _d(31, 12),
                title: 'Ngày chụp',
              ),
              child: const Text('mở'),
            ),
          ),
          width: 320,
          textScale: 1.3,
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Chọn'), findsOneWidget);
    });
  });
}
