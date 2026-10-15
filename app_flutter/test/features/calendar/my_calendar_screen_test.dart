import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';

import '../../support/photographer_world.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);
final _routes = <RouteBase>[
  GoRoute(path: '/work/calendar', builder: (_, _) => const MyCalendarScreen()),
];

Future<PhotographerWorld> _world() async {
  final w = PhotographerWorld();
  await w.init();
  w.availability
    ..seed(
      w.uid,
      AvailabilityDay(day: _d(10), state: DayState.booked, bookingId: 'b1'),
    )
    ..seed(
      w.uid,
      AvailabilityDay(day: _d(11), state: DayState.pending, bookingId: 'b2'),
    )
    ..seed(w.uid, AvailabilityDay(day: _d(12), state: DayState.off))
    ..seed(
      w.uid,
      AvailabilityDay(day: _d(15), state: DayState.booked, eventId: 'e1'),
    );
  return w;
}

Finder _day(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('shows the month with its four states and the legend', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Lịch của tôi'), findsOneWidget);
    expect(find.byKey(const Key('month-tabs')), findsOneWidget);
    expect(_day('10 tháng 10, đã đặt'), findsOneWidget);
    expect(_day('11 tháng 10, chờ nhận'), findsOneWidget);
    expect(_day('12 tháng 10, nghỉ'), findsOneWidget);
    expect(_day('15 tháng 10, đã đặt, có sự kiện'), findsOneWidget);
    expect(
      find.text(
        'Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.',
      ),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('a tap marks a free day off, and "Hoàn tác" frees it again', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)]!.state, DayState.off);
    expect(find.text('Đã đánh dấu nghỉ'), findsOneWidget);
    expect(_day('13 tháng 10, nghỉ'), findsOneWidget);
    expect(find.text('Thứ 3, 13/10'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)], isNull);
    h.dispose();
  });

  testWidgets('a tap on an off day frees it', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('12 tháng 10, nghỉ'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(12)], isNull);
    expect(find.text('Đã bỏ nghỉ'), findsOneWidget);
    h.dispose();
  });

  testWidgets(
    'booked and pending days cannot be marked and link to the booking',
    (tester) async {
      final h = tester.ensureSemantics();
      final w = await _world();
      await tester.pumpWidget(
        w.app(location: '/work/calendar', routes: _routes),
      );
      await tester.pumpAndSettle();
      await tester.tap(_day('10 tháng 10, đã đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Ngày này đã có lịch'), findsWidgets);
      expect(w.availability.writes, 0);
      expect(find.byKey(const Key('mark-off')), findsNothing);
      await tester.tap(find.byKey(const Key('open-booking')));
      await tester.pumpAndSettle();
      expect(find.text('stub /b/b1'), findsOneWidget);
      h.dispose();
    },
  );

  testWidgets('an event day opens the event', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('15 tháng 10, đã đặt, có sự kiện'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-event')));
    await tester.pumpAndSettle();
    expect(find.text('stub /events/e1/manage'), findsOneWidget);
    h.dispose();
  });

  testWidgets(
    'hold the first day, tap the last: the free days between are off',
    (tester) async {
      final h = tester.ensureSemantics();
      final w = await _world();
      await tester.pumpWidget(
        w.app(location: '/work/calendar', routes: _routes),
      );
      await tester.pumpAndSettle();
      await tester.longPress(_day('9 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chạm ngày cuối để đánh dấu nghỉ cả khoảng.'),
        findsOneWidget,
      );
      await tester.tap(_day('13 tháng 10, rảnh'));
      await tester.pumpAndSettle();
      final stored = w.availability.stored(w.uid);
      expect(
        [
          for (final d in [9, 10, 11, 12, 13]) stored[_d(d)]!.state,
        ],
        [
          DayState.off,
          DayState.booked,
          DayState.pending,
          DayState.off,
          DayState.off,
        ],
      );
      expect(find.text('Đã đánh dấu nghỉ 2 ngày'), findsOneWidget);
      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(w.availability.stored(w.uid)[_d(9)], isNull);
      expect(
        w.availability.stored(w.uid)[_d(12)]!.state,
        DayState.off,
        reason: 'undo only frees the days it marked',
      );
      h.dispose();
    },
  );

  testWidgets('the panel action does the same as tapping the day', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.today = _d(1);
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(
      find.text('Thứ 5, 1/10'),
      findsOneWidget,
      reason: 'today is selected first',
    );
    await tester.tap(find.byKey(const Key('mark-off')));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(1)]!.state, DayState.off);
    await tester.tap(find.byKey(const Key('clear-off')));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(1)], isNull);
    h.dispose();
  });

  testWidgets('past days are read-only', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.today = _d(14);
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.writes, 0);
    h.dispose();
  });

  testWidgets('the month tabs switch the month and slide with it', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng 11'));
    await tester.pumpAndSettle();
    expect(_day('2 tháng 11, rảnh'), findsOneWidget);
    await tester.tap(find.text('Tháng 12'));
    await tester.pumpAndSettle();
    expect(_day('2 tháng 12, rảnh'), findsOneWidget);
    expect(
      find.text('Tháng 1'),
      findsOneWidget,
      reason: 'the tabs slide with the month',
    );
    expect(find.text('Tháng 10'), findsNothing);
    h.dispose();
  });

  testWidgets('a failed save says so and changes nothing', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.availability.failWrites = true;
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được lịch. Thử lại nhé.'), findsOneWidget);
    expect(_day('13 tháng 10, rảnh'), findsOneWidget);
    h.dispose();
  });

  testWidgets('"Hoàn tác" still frees the day after leaving the screen', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(
      w.app(
        location: '/home',
        routes: [
          ..._routes,
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    w.router.push('/work/calendar');
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)]!.state, DayState.off);
    w.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(MyCalendarScreen), findsNothing);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(w.availability.stored(w.uid)[_d(13)], isNull);
    h.dispose();
  });

  testWidgets('a failed load says so, ignores taps and retries', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.availability.failWatch = true;
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được lịch.'), findsOneWidget);
    await tester.tap(_day('13 tháng 10, rảnh'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(w.availability.writes, 0);
    w.availability.failWatch = false;
    await tester.tap(find.byKey(const Key('calendar-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được lịch.'), findsNothing);
    expect(_day('10 tháng 10, đã đặt'), findsOneWidget);
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)]!.state, DayState.off);
    h.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world();
      await tester.pumpWidget(
        w.app(
          location: '/work/calendar',
          routes: _routes,
          brightness: b,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
